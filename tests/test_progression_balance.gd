extends SceneTree
## Command-only policy runs. Reports simulated time, not human playtime.
var failures := 0
var registry := ContentRegistry.new()
var sim: GameSimulation
var route: Array[String] = []
var recipe_cache: Dictionary = {}
var money_station := "station_2"
var task_station := ""
var task_worker := ""
var researcher := ""
var money_recipe := ""
var last_unlocks := -1
var goal := ""
var milestones: Dictionary = {}
var merchant_workers: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not registry.load_all(false):
		printerr(registry.errors)
		quit(1)
		return
	var arguments := OS.get_cmdline_user_args()
	var paths: Array[String] = ["master", "merchant", "researcher"]
	if not arguments.is_empty():
		paths.assign(arguments)
	for path: String in paths:
		_run_path(path)
	print("BALANCE_FAILURES ", failures)
	quit(failures)

func _run_path(path: String) -> void:
	goal = path
	sim = GameSimulation.new(registry)
	sim.new_game("base:first_sparks", 20260912, "base:outskirts")
	route.clear()
	recipe_cache.clear()
	milestones.clear()
	merchant_workers.clear()
	money_station = "station_2"
	task_station = ""
	task_worker = ""
	researcher = ""
	last_unlocks = -1
	sim.execute(GameCommand.assign_staff("base:torben", "station_3"))
	var created := sim.execute(GameCommand.create_blueprint({"name":"Budget lights", "body_id":"base:simple_charm", "effect_id":"base:minor_light", "modifier_ids":["base:simple", "base:economical"]}))
	money_recipe = str(created.blueprint_id)
	sim.execute(GameCommand.configure_production(money_station, money_recipe))
	sim.execute(GameCommand.set_production_enabled(money_station, true))
	sim.execute(GameCommand.set_price(money_recipe, 84))
	_add_route("base:arcane_foundations")
	_add_route("base:arcane_core_4")
	for id: String in ["base:research_planning", "base:project_archive", "base:complex_blueprints", "base:prototype_testing", "base:workshop_expansion", "base:second_team", "base:laboratory_organisation", "base:quality_control", "base:precision_instruments", "base:serial_processes"]:
		_add_route(id)
	if path == "master":
		_add_route("base:arcane_storage_8")
	elif path == "merchant":
		_add_route("base:arcane_core_4")
		_add_route("base:arcane_precision_3")
		_add_route("base:trade_mastery")
	else:
		_add_route("base:convergent_mastery")
	for day: int in 1400:
		_manage_business()
		_manage_research()
		_manage_deliveries()
		for hour: int in 24:
			sim.tick()
			if not str(sim.state.victory).is_empty():
				if sim.state.victories.has(path):
					break
				sim.execute(GameCommand.continue_game())
		if not milestones.has("sale") and int(sim.state.market_units_sold) > 0:
			milestones.sale = sim.current_day()
		if not milestones.has("contract") and int(sim.state.regular_contracts_completed) > 0:
			milestones.contract = sim.current_day()
		var level_key := "company_" + str(sim.state.company_level)
		if not milestones.has(level_key):
			milestones[level_key] = sim.current_day()
		if not milestones.has("breakthrough") and int(sim.state.breakthroughs_completed) > 0:
			milestones.breakthrough = sim.current_day()
		if day % 100 == 0:
			print("BALANCE_PROGRESS ", path, " day=", sim.current_day(), " cash=", snappedf(float(sim.state.cash), .1), " level=", sim.state.company_level, " research=", sim.company_progress().research, " contracts=", sim.state.regular_contracts_completed, " pending=", sim.state.pending_breakthroughs.keys(), " teams=", sim.state.research_teams)
		if bool(sim.state.defeat) or sim.state.victories.has(path):
			break
	var won: bool = sim.state.victories.has(path)
	if not won:
		failures += 1
	var data := {"path":path, "won":won, "day":sim.current_day(), "cash":sim.state.cash, "company_level":sim.state.company_level, "research":sim.company_progress().research, "contracts":sim.state.regular_contracts_completed, "breakthroughs":sim.state.breakthroughs_completed, "milestones":milestones, "simulation_hours_1x":float(sim.state.hour) * 1.25 / 3600.0, "foundations":sim._completed_foundation_professions()}
	print("BALANCE_RESULT ", JSON.stringify(data))
	var folder := "user://balance"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var file := FileAccess.open(folder.path_join(path + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  "))
	SaveSystem.save_game(sim, "balance_" + path)

func _add_route(id: String) -> void:
	if route.has(id):
		return
	for required: String in registry.get_def("research", id).get("requires", []):
		_add_route(required)
	route.append(id)

func _manage_research() -> void:
	if float(sim.state.cash) < 3000 and sim.expected_daily_operating_result() < 0:
		for id: int in (sim.state.research_teams as Array).size():
			sim.execute(GameCommand.pause_research(id))
		return
	for team_id: int in (sim.state.research_teams as Array).size():
		if not str(sim.state.research_teams[team_id].project_id).is_empty():
			continue
		for id: String in route:
			if sim.research_status(id) == "available":
				sim.execute(GameCommand.start_research(id, team_id))
				break
	if not bool(sim.state.focus_chosen) and int(sim.state.company_level) >= 2:
		var focuses := sim.available_focuses()
		if not focuses.is_empty():
			sim.execute(GameCommand.change_focus(str(focuses[0].id)))

func _place(type: String) -> String:
	var definition := registry.get_def("stations", type)
	for room: Dictionary in sim.state.rooms:
		if str(room.type) != str(definition.room_type):
			continue
		var rect: Array = room.rect
		for y: int in range(int(rect[1]), int(rect[1]) + int(rect[3])):
			for x: int in range(int(rect[0]), int(rect[0]) + int(rect[2])):
				if (sim.state.stations as Array).any(func(station: Dictionary) -> bool: return station.position == [x, y]):
					continue
				var id := "station_%d" % int(sim.state.next_station)
				var result := sim.execute(GameCommand.place_station(type, Vector2i(x, y)))
				if bool(result.ok):
					return id
	return ""

func _manage_business() -> void:
	if float(sim.state.cash) < 2200:
		return
	if task_worker.is_empty():
		var candidates: Array = sim.state.applicants.duplicate()
		candidates.sort_custom(func(a: String, b: String) -> bool: return float(registry.get_def("staff", a).production_quality) > float(registry.get_def("staff", b).production_quality))
		if not candidates.is_empty() and bool(sim.execute(GameCommand.hire_staff(str(candidates[0]))).ok):
			task_worker = str(candidates[0])
			task_station = _place("base:arcane_bench")
			sim.execute(GameCommand.assign_staff(task_worker, task_station))
	if int(sim.state.company_level) >= 3 and researcher.is_empty():
		if (sim.state.staff as Array).size() >= sim.housing_capacity():
			sim.execute(GameCommand.place_room("base:residence", Rect2i(13, 3, 4, 4)))
		var candidates: Array = sim.state.applicants.duplicate()
		candidates.sort_custom(func(a: String, b: String) -> bool: return float(registry.get_def("staff", a).research) > float(registry.get_def("staff", b).research))
		if not candidates.is_empty() and bool(sim.execute(GameCommand.hire_staff(str(candidates[0]))).ok):
			researcher = str(candidates[0])
			var desk := _place("base:research_desk")
			sim.execute(GameCommand.assign_staff(researcher, desk))
	if (sim.state.research_teams as Array).size() > 1 and not researcher.is_empty():
		for staff: Dictionary in sim.state.staff:
			if str(staff.id) == researcher:
				sim.execute(GameCommand.assign_research_team(str(staff.station_id), 1))
	if goal == "merchant" and bool(sim.state.unlocked.get("base:trade_mastery", false)) and merchant_workers.size() < 3 and float(sim.state.cash) > 10000:
		var candidates: Array = sim.state.applicants.duplicate()
		candidates.sort_custom(func(a: String, b: String) -> bool: return float(registry.get_def("staff", a).production_speed) > float(registry.get_def("staff", b).production_speed))
		if not candidates.is_empty() and bool(sim.execute(GameCommand.hire_staff(str(candidates[0]))).ok):
			var worker := str(candidates[0])
			var station := _place("base:arcane_core_component_4")
			if not station.is_empty():
				merchant_workers.append(worker)
				sim.execute(GameCommand.assign_staff(worker, station))
				sim.execute(GameCommand.configure_production(station, money_recipe))
				sim.execute(GameCommand.set_production_enabled(station, true))
	if goal == "merchant" and bool(sim.state.unlocked.get("base:trade_mastery", false)) and merchant_workers.size() == 3 and float(sim.state.cash) > 10000:
		var station := _place("base:arcane_core_component_4")
		if not station.is_empty():
			merchant_workers.append("base:elara")
			sim.execute(GameCommand.assign_staff("base:elara", station))
			sim.execute(GameCommand.configure_production(station, money_recipe))
			sim.execute(GameCommand.set_production_enabled(station, true))
	# Reinvest in unlocked throughput; no station or worker is spawned directly.
	for current: String in [money_station, task_station]:
		if current.is_empty() or float(sim.state.cash) < 6000:
			continue
		var old := sim._station_by_id(current)
		var best := registry.get_def("stations", str(old.type))
		for definition: Dictionary in sim.unlocked_content("stations"):
			if str(definition.kind) == "production" and float(definition.capacity) > float(best.capacity):
				best = definition
		if str(best.id) != str(old.type):
			var station := _place(str(best.id))
			if station.is_empty():
				continue
			var worker := "base:selin" if current == money_station else task_worker
			sim.execute(GameCommand.set_production_enabled(current, false))
			sim.execute(GameCommand.assign_staff(worker, station))
			if current == money_station:
				money_station = station
				sim.execute(GameCommand.configure_production(station, money_recipe))
				sim.execute(GameCommand.set_production_enabled(station, true))
			else:
				task_station = station

func _manage_deliveries() -> void:
	if task_station.is_empty():
		return
	if int(sim.state.regular_contracts_completed) < 10:
		for id: String in sim.state.available_contracts.keys():
			sim.execute(GameCommand.accept_contract(id))
		for id: String in sim.state.active_contracts.keys():
			var contract: Dictionary = sim.state.active_contracts[id]
			if bool(sim.contract_delivery_status(contract).ready):
				sim.execute(GameCommand.submit_contract(id))
				continue
			if _produce_for(contract):
				return
	for id: String in sim.state.pending_breakthroughs.keys():
		if _deliver(id, false):
			return
	for id: String in route:
		if not sim.final_project_requirements(id).is_empty():
			if _deliver(id, true):
				return
	if not sim.state.master_project.is_empty() and not sim.state.victories.has("master"):
		if sim.current_day() > int(sim.state.master_project.deadline_day):
			sim.execute(GameCommand.restart_master_sales())
		var requirement := {"family_effect":str(sim.state.master_project.family_effect), "quantity":10, "min_quality":0}
		var id := _find_recipe(requirement)
		if not id.is_empty():
			_configure_task(id)
			sim.execute(GameCommand.set_production_enabled(task_station, true))
			sim.execute(GameCommand.set_price(id, 145))
			return
	if goal == "merchant" and bool(sim.state.unlocked.get("base:trade_mastery", false)):
		# Two advertised product lines reach several segments over a full trading window.
		var id := _find_recipe({"required_coverage":["base:arcane"], "quantity":40, "min_quality":60})
		if not id.is_empty():
			_configure_task(id)
			sim.execute(GameCommand.set_production_enabled(task_station, true))
			sim.execute(GameCommand.set_price(id, 150))
		return
	_configure_task(money_recipe)
	sim.execute(GameCommand.set_production_enabled(task_station, true))

func _deliver(project_id: String, final: bool) -> bool:
	var requirements: Array = sim.final_project_requirements(project_id) if final else registry.get_def("research", project_id).proofs
	var selection: Array = []
	var used: Dictionary = {}
	for index: int in requirements.size():
		var requirement: Dictionary = requirements[index]
		var remaining := int(requirement.quantity)
		for id: String in sim.state.products:
			if not sim.proof_product_matches(id, requirement):
				continue
			var quantity := mini(remaining, int(sim.state.products[id].quantity) - int(used.get(id, 0)))
			if quantity > 0:
				selection.append({"requirement":index,"blueprint_id":id,"quantity":quantity})
				used[id] = int(used.get(id, 0)) + quantity
				remaining -= quantity
		if remaining > 0:
			return _produce_for(requirement)
	var result := sim.execute(GameCommand.submit_final_project(project_id, selection) if final else GameCommand.submit_prototypes(project_id, selection))
	return bool(result.ok)

func _produce_for(requirement: Dictionary) -> bool:
	var id := _find_recipe(requirement)
	if id.is_empty():
		return false
	sim.execute(GameCommand.stop_sale(id))
	_configure_task(id)
	sim.execute(GameCommand.set_production_enabled(task_station, true))
	return true

func _find_recipe(requirement: Dictionary) -> String:
	if last_unlocks != (sim.state.unlocked as Dictionary).size():
		recipe_cache.clear()
		last_unlocks = (sim.state.unlocked as Dictionary).size()
	var key := JSON.stringify(requirement)
	if recipe_cache.has(key):
		return str(recipe_cache[key])
	var modifiers := sim.unlocked_content("modifiers")
	modifiers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("quality_delta", 0)) > float(b.get("quality_delta", 0)))
	var mod_sets: Array = [[], ["base:balanced", "base:polished"]]
	if modifiers.size() >= 2:
		mod_sets.push_front([str(modifiers[0].id), str(modifiers[1].id)])
	for modifier: Dictionary in modifiers:
		if str(modifier.id) != str(modifiers[0].id):
			mod_sets.append([str(modifier.id), str(modifiers[0].id)])
	var bodies := sim.unlocked_content("bodies")
	for effect: Dictionary in sim.unlocked_content("effects"):
		if requirement.has("family_effect") and str(effect.id) != str(requirement.family_effect):
			continue
		for body: Dictionary in bodies:
			for mods: Array in mod_sets:
				var recipe := {"name":"Policy: " + str(effect.name_en),"body_id":str(body.id),"effect_id":str(effect.id),"modifier_ids":mods}
				var preview := sim.preview_blueprint(recipe)
				if not bool(preview.valid) or not sim._contains_all(preview.profession_coverage, requirement.get("required_coverage", [])):
					continue
				if not (requirement.get("accepted_classes", []) as Array).is_empty() and not sim._arrays_overlap(preview.goods_classes, requirement.accepted_classes):
					continue
				var worker := registry.get_def("staff", task_worker)
				var station := registry.get_def("stations", str(sim._station_by_id(task_station).type))
				var expected := float(preview.quality_estimate) + (float(worker.production_quality) - 1) * 18 + float(station.get("quality_bonus", 0)) + sim.research_benefit("quality_bonus")
				if expected < float(requirement.get("min_quality", 0)) + 2:
					continue
				var result := sim.execute(GameCommand.create_blueprint(recipe))
				if bool(result.ok):
					recipe_cache[key] = str(result.blueprint_id)
					return str(result.blueprint_id)
	recipe_cache[key] = ""
	return ""

func _configure_task(id: String) -> void:
	var line: Dictionary = sim.state.production_lines.get(task_station, {})
	if str(line.get("blueprint_id", "")) != id:
		sim.execute(GameCommand.set_production_enabled(task_station, false))
		var result := sim.execute(GameCommand.configure_production(task_station, id))
		if not bool(result.ok):
			printerr("BALANCE_COMMAND_FAILED ", result)
