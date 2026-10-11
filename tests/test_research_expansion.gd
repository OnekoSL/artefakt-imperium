extends RefCounted

static func run(registry: ContentRegistry, check: Callable) -> void:
	_test_catalogue(registry, check)
	_test_teams(registry, check)
	_test_prototypes(registry, check)
	_test_victories(registry, check)
	_test_corrupt_states(registry, check)
	_test_school_starts(registry, check)
	_test_multischool_contracts(registry, check)

static func _new(registry: ContentRegistry, property_id: String = "base:outskirts") -> GameSimulation:
	var sim := GameSimulation.new(registry)
	sim.new_game("base:first_sparks", 4444, property_id)
	return sim

static func _unlock(sim: GameSimulation, id: String) -> void:
	sim.state.unlocked[id] = true
	sim._reconcile_unlocks()

static func _ancestors(sim: GameSimulation, id: String, seen: Dictionary) -> void:
	var project := sim.registry.get_def("research", id)
	for required: String in project.get("requires", []):
		if not seen.has(required):
			seen[required] = true
			_ancestors(sim, required, seen)
			_unlock(sim, required)

static func _recipe(sim: GameSimulation, effect: String, quantity: int = 0, quality: float = 90.0, modifiers: Array = []) -> String:
	var result := sim.execute(GameCommand.create_blueprint({"name":effect, "body_id":"base:simple_charm", "effect_id":effect, "modifier_ids":modifiers}))
	if not bool(result.ok):
		return ""
	var id := str(result.blueprint_id)
	if quantity > 0:
		sim.state.products[id] = {"quantity":quantity, "average_quality":quality, "unit_cost":float(sim.state.blueprints[id].computed.unit_cost)}
	return id

static func _selection(id: String, quantity: int, index: int = 0) -> Array:
	return [{"requirement":index, "blueprint_id":id, "quantity":quantity}]

static func _test_catalogue(registry: ContentRegistry, check: Callable) -> void:
	check.call(registry.all("research").size() == 156, "expansion has exactly 156 research projects")
	for school: Dictionary in registry.all("disciplines"):
		var projects := registry.all("research").filter(func(p: Dictionary) -> bool: return str(p.get("discipline", "")) == str(school.id) and str(p.get("track", "")) in ["core", "branch"])
		check.call(projects.size() == 20 and projects.filter(func(p: Dictionary) -> bool: return bool(p.get("capstone", false))).size() == 2, "%s has twenty projects and two capstones" % school.id)
	# Check real blueprint matching using only preceding unlocks, not merely references.
	var all_proofs_buildable := true
	for project: Dictionary in registry.all("research"):
		if (project.get("proofs", []) as Array).is_empty():
			continue
		var sim := _new(registry)
		_ancestors(sim, str(project.id), {})
		for proof: Dictionary in project.proofs:
			var found := false
			for effect: Dictionary in sim.unlocked_content("effects"):
				var preview := sim.preview_blueprint({"body_id":"base:simple_charm", "effect_id":str(effect.id), "modifier_ids":[]})
				if not bool(preview.valid):
					continue
				var id := _recipe(sim, str(effect.id), int(proof.quantity), 90.0)
				if not id.is_empty() and sim.proof_product_matches(id, proof):
					found = true
					break
			if not found:
				printerr("UNBUILDABLE_PROOF ", project.id, " ", proof)
			all_proofs_buildable = all_proofs_buildable and found
	check.call(all_proofs_buildable, "every prototype has a valid preceding blueprint without its own unlock")
	var broken := ContentRegistry.new()
	broken.load_all(false)
	broken.get_def("research", "base:arcane_foundations").requires = ["base:arcane_mastery"]
	broken.errors.clear()
	broken._validate_references()
	check.call(not broken.errors.is_empty(), "content rejects cyclic research dependencies")

static func _test_teams(registry: ContentRegistry, check: Callable) -> void:
	var sim := _new(registry)
	check.call(not bool(sim.execute(GameCommand.start_research("base:arcane_mastery")).ok), "company and research gates are enforced by simulation")
	_unlock(sim, "base:second_team")
	sim.state.research_teams.append({"project_id":"", "ramp":0})
	sim.state.company_level = 3
	sim.state.stations.append({"id":"station_4", "type":"base:research_desk", "position":[7,1]})
	sim.execute(GameCommand.assign_staff("base:torben", "station_4"))
	check.call(bool(sim.execute(GameCommand.assign_research_team("station_4", 1)).ok), "second desk can be assigned to second team")
	sim.execute(GameCommand.start_research("base:arcane_foundations", 0))
	check.call(not bool(sim.execute(GameCommand.start_research("base:arcane_foundations", 1)).ok), "two teams cannot research the same project")
	sim.execute(GameCommand.start_research("base:rune_foundations", 1))
	var cash := float(sim.state.cash)
	sim.tick()
	check.call(is_equal_approx(float(sim.state.cash), cash - 2) and float(sim.state.research_progress["base:arcane_foundations"]) > 0 and float(sim.state.research_progress["base:rune_foundations"]) > 0, "independent teams advance and charge each project once")
	var copy := _new(registry)
	check.call(bool(copy.restore(JSON.parse_string(JSON.stringify(sim.serialize()))).ok), "two active teams roundtrip through JSON")
	for hour: int in 48:
		sim.tick()
		copy.tick()
	check.call(JSON.stringify(JSON.parse_string(JSON.stringify(sim.serialize()))) == JSON.stringify(JSON.parse_string(JSON.stringify(copy.serialize()))), "two teams remain deterministic after JSON restore")
	_unlock(sim, "base:arcane_storage_2")
	_unlock(sim, "base:arcane_precision_2")
	var cost_before := float(sim.state.cash)
	check.call(bool(sim.execute(GameCommand.change_focus("base:arcane_storage")).ok) and float(sim.state.cash) == cost_before, "first eligible focus is free")
	var boosted := sim.research_rate("base:arcane_storage_3", false, 0)
	sim.state.focus_branch = ""
	var neutral := sim.research_rate("base:arcane_storage_3", false, 0)
	sim.state.focus_branch = "base:arcane_storage"
	check.call(is_equal_approx(boosted, neutral * 1.2), "focus gives exactly twenty percent to its branch")
	sim.state.cash = 5000
	check.call(bool(sim.execute(GameCommand.change_focus("base:arcane_precision", 0)).ok) and is_equal_approx(float(sim.state.cash), 3000) and str(sim.state.focus_branch).is_empty(), "paid focus change removes old bonus immediately")
	var restored := _new(registry)
	check.call(bool(restored.restore(sim.serialize()).ok), "pending focus change roundtrips")
	for hour: int in 160:
		sim.tick()
		restored.tick()
	check.call(str(sim.state.focus_branch) == "base:arcane_precision" and sim.state.focus_change.is_empty() and JSON.stringify(sim.serialize()) == JSON.stringify(restored.serialize()), "focus work completes deterministically without overlapping bonuses")

static func _test_prototypes(registry: ContentRegistry, check: Callable) -> void:
	var sim := _new(registry)
	_ancestors(sim, "base:arcane_core_4", {})
	sim.state.company_level = 3
	var project := registry.get_def("research", "base:arcane_core_4")
	check.call(bool(sim.execute(GameCommand.start_research(str(project.id))).ok), "eligible breakthrough research starts")
	sim.state.research_progress[str(project.id)] = float(project.cost_hours) - 0.1
	sim.tick()
	check.call(sim.state.pending_breakthroughs.has(str(project.id)) and not sim.state.unlocked.has(str(project.id)) and str(sim.state.research_teams[0].project_id).is_empty(), "theory completion frees team but withholds unlocks")
	var before_cost := float(sim.state.cash)
	sim.tick()
	check.call(float(sim.state.cash) == before_cost, "waiting breakthrough incurs no hourly research cost")
	var id := _recipe(sim, "base:mana_focus", 2, 60)
	var before := JSON.stringify(sim.serialize())
	var duplicate := _selection(id, 1) + _selection(id, 1)
	check.call(not bool(sim.execute(GameCommand.submit_prototypes(str(project.id), duplicate)).ok) and JSON.stringify(sim.serialize()) == before, "duplicate prototype entries are rejected atomically")
	check.call(not bool(sim.execute(GameCommand.submit_prototypes(str(project.id), _selection(id, 1))).ok) and JSON.stringify(sim.serialize()) == before, "incomplete prototype delivery preserves state and stock")
	check.call(bool(sim.execute(GameCommand.submit_prototypes(str(project.id), _selection(id, 2))).ok) and int(sim.state.products[id].quantity) == 0 and sim.state.unlocked.has(str(project.id)), "valid prototype delivery consumes goods and unlocks research")
	check.call(not bool(sim.execute(GameCommand.submit_prototypes(str(project.id), _selection(id, 2))).ok), "completed breakthrough cannot consume stock twice")
	check.call(str(sim.state.victory).is_empty(), "high research tier alone does not award victory")
	var mixed := _recipe(sim, "base:mana_focus", 3, 60)
	var shared_requirements := [project.proofs[0], project.proofs[0]]
	check.call(not bool(sim.proof_selection_status(shared_requirements, _selection(mixed, 2, 0) + _selection(mixed, 2, 1)).ok), "goods cannot be counted twice across proof requirements")

static func _test_victories(registry: ContentRegistry, check: Callable) -> void:
	var sim := _new(registry)
	sim.state.company_level = 4
	var master := "base:arcane_storage_8"
	_unlock(sim, master)
	var effect := str(registry.get_def("research", master).family_effect)
	var id := _recipe(sim, effect, 15, 90)
	check.call(bool(sim.execute(GameCommand.submit_final_project(master, _selection(id, 5))).ok) and int(sim.state.products[id].quantity) == 10, "master project consumes five qualified masterworks")
	sim.state.hour = (int(sim.state.master_project.deadline_day) + 1) * 24
	sim._record_master_sale(sim.state.blueprints[id], 10)
	sim._check_victory()
	check.call(not sim.state.victories.has("master") and bool(sim.execute(GameCommand.restart_master_sales()).ok), "expired master market proof can restart without another masterwork delivery")
	sim.execute(GameCommand.set_price(id, 80))
	for day: int in 10:
		sim.state.hour = int(sim.state.hour) + 24
		sim._run_market()
		sim._check_victory()
		if sim.state.victories.has("master"):
			break
	check.call(sim.state.victories.has("master") and bool(sim.state.paused) and int(sim.state.company_level) == 5, "real market sales complete master path and pause once")
	var pending := _new(registry)
	check.call(bool(pending.restore(sim.serialize()).ok), "pending victory and final project save roundtrip")
	check.call(bool(sim.execute(GameCommand.continue_game()).ok) and not bool(sim.state.paused), "continue command resumes after victory")
	var hour_before := int(sim.state.hour)
	sim.tick()
	check.call(int(sim.state.hour) == hour_before + 1, "simulation ticks continue after a victory")
	var convergence := "base:convergent_mastery"
	_unlock(sim, convergence)
	id = _recipe(sim, "base:unified_convergence", 13, 90)
	check.call(bool(sim.execute(GameCommand.submit_final_project(convergence, _selection(id, 3))).ok) and not sim.state.researcher_project.is_empty(), "convergence demonstration creates a guaranteed follow-up")
	check.call(bool(sim.execute(GameCommand.submit_final_project(convergence, _selection(id, 10))).ok) and sim.state.victories.has("researcher") and sim.state.victories.has("master"), "second independent path remains achievable after first victory")
	sim.execute(GameCommand.continue_game())
	_unlock(sim, "base:trade_mastery")
	sim.state.cash = 50000
	sim.state.loan_balance = 25000
	for day: int in 30:
		sim.state.merchant_history.append({"day":day + 1, "revenue":1000.0, "net":50.0, "customers":{"base:mages":1,"base:witches":1,"base:citizens":1}})
	sim._check_victory()
	check.call(not sim.state.victories.has("merchant"), "merchant net cash excludes outstanding debt")
	sim.state.loan_balance = 0
	sim.state.merchant_history[0].revenue = 0.0
	sim._check_victory()
	check.call(not sim.state.victories.has("merchant"), "merchant requires actual artifact revenue")
	sim.state.merchant_history[0].revenue = 1000.0
	sim._check_victory()
	check.call(sim.state.victories.size() == 3, "all three victory paths can be achieved in one save")
	var events := (sim.state.logbook as Array).filter(func(event: Dictionary) -> bool: return str(event.type) == "Victory").size()
	sim._check_victory()
	check.call((sim.state.logbook as Array).filter(func(event: Dictionary) -> bool: return str(event.type) == "Victory").size() == events, "victories are not awarded repeatedly")

static func _test_corrupt_states(registry: ContentRegistry, check: Callable) -> void:
	var sim := _new(registry)
	var saved := sim.serialize()
	var before := JSON.stringify(saved)
	var cases := [{"research_teams":[]}, {"research_teams":[{"project_id":"missing", "ramp":0}]}, {"station_teams":{"missing":0}}, {"focus_branch":"missing"}, {"focus_change":{"progress":1}}, {"pending_breakthroughs":{"base:arcane_core_4":true}}, {"company_level":6}, {"master_project":{"sales":10}}, {"researcher_project":{"demonstrated":true}}, {"victories":{"bogus":1}}, {"merchant_history":[{"day":1, "net":0, "revenue":10, "customers":{"missing":1}}]}]
	var rejected := true
	for change: Dictionary in cases:
		var invalid := saved.duplicate(true)
		invalid.merge(change, true)
		rejected = rejected and not bool(sim.restore(invalid).ok) and JSON.stringify(sim.serialize()) == before
	check.call(rejected, "malformed expansion states are rejected without state or RNG changes")
	for command: GameCommand in [GameCommand.new(GameCommand.Kind.SUBMIT_PROTOTYPES, {"project_id":"base:prototype_testing", "selection":"invalid"}), GameCommand.new(GameCommand.Kind.START_RESEARCH, {"project_id":"base:arcane_foundations", "team_id":0.5})]:
		check.call(not bool(sim.execute(command).ok) and JSON.stringify(sim.serialize()) == before, "malformed new command payload is rejected atomically")


static func _test_school_starts(registry: ContentRegistry, check: Callable) -> void:
	for property_id: String in ["base:outskirts", "base:cemetery", "base:deep_forest"]:
		for school: Dictionary in registry.all("disciplines"):
			var sim := _new(registry, property_id)
			var foundation: Dictionary = registry.all("research").filter(func(p: Dictionary) -> bool: return str(p.get("discipline", "")) == str(school.id) and int(p.tier) == 1)[0]
			sim.execute(GameCommand.assign_staff("base:torben", "station_3"))
			var starter := _recipe(sim, "base:minor_light")
			sim.execute(GameCommand.configure_production("station_2", starter))
			sim.execute(GameCommand.set_production_enabled("station_2", true))
			sim.execute(GameCommand.set_price(starter, 84))
			var started := sim.execute(GameCommand.start_research(str(foundation.id)))
			for hour: int in 40 * 24:
				sim.tick()
			check.call(bool(started.ok) and bool(sim.state.unlocked.get(str(foundation.id), false)) and str(sim.state.player_profession) == str(school.id) and float(sim.state.cash) > 0 and not bool(sim.state.defeat), "%s starts with %s and survives forty days" % [property_id, school.id])
			var own_effect := ""
			for unlock: String in foundation.unlocks:
				if registry.has_def("effects", unlock):
					own_effect = unlock
			var own := _recipe(sim, own_effect)
			sim.execute(GameCommand.set_production_enabled("station_2", false))
			sim.execute(GameCommand.configure_production("station_2", own))
			sim.execute(GameCommand.stop_sale(starter))
			sim.execute(GameCommand.set_price(own, 140))
			sim.execute(GameCommand.set_production_enabled("station_2", true))
			var sales_before := int(sim.state.market_units_sold)
			for hour: int in 40 * 24:
				sim.tick()
			check.call(not own.is_empty() and int(sim.state.market_units_sold) > sales_before and float(sim.state.cash) > 0 and not bool(sim.state.defeat), "%s sells its own %s artifacts for another forty days" % [property_id, school.id])


static func _test_multischool_contracts(registry: ContentRegistry, check: Callable) -> void:
	var sim := _new(registry)
	_unlock(sim, "base:arcane_foundations")
	_unlock(sim, "base:nature_core_1")
	sim.state.player_profession = "base:arcane"
	sim.state.market_units_sold = 1
	for definition: Dictionary in registry.all("contracts"):
		if not (definition.eligible_professions as Array).has("base:nature"):
			sim.state.contract_offer_cooldowns[str(definition.id)] = 999
	sim._update_contract_market()
	check.call(not sim.state.available_contracts.is_empty() and (sim.state.available_contracts as Dictionary).values().all(func(contract: Dictionary) -> bool: return (contract.eligible_professions as Array).has("base:nature")), "later foundation opens its own contracts despite an earlier workshop profession")
