extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("Artefakt Imperium – headless tests")
	var registry := ContentRegistry.new()
	_check(registry.load_all(false), "base content validates: %s" % " | ".join(registry.errors))
	_check(registry.all("disciplines").size() == 3, "three disciplines load")
	_check(registry.all("customers").size() == 3, "three customer segments load")
	_check(registry.all("rivals").size() == 2, "two rivals load")
	_check(registry.all("contracts").size() >= 12, "at least twelve contracts load")
	_check(registry.all("goods_classes").size() == 18, "six systematic goods classes load for each of the three professions")
	_check((registry.get_def("contracts", "base:apprentice_charms").accepted_classes as Array).has("base:rune_utility"), "apprentice talisman contract accepts runic utility goods")
	_check(registry.has_def("effects", "base:unified_convergence") and registry.has_def("research", "base:convergent_mastery"), "late triple-profession convergence content loads")
	_check(registry.all("properties").size() == 3, "three property definitions load")
	_check(registry.all("resource_sources").size() == 4, "four resource source definitions load")
	_check(registry.all("staff").size() >= 12, "expanded recruiting pool loads")
	_check(registry.all("research").filter(func(item: Dictionary) -> bool: return bool(item.get("hybrid", false))).size() == 4, "three pair hybrids and one triple convergence technology load")
	var mod_registry := ContentRegistry.new()
	_check(mod_registry.load_all(true), "base and example mod validate together")
	_check(mod_registry.has_def("materials", "example:star_iron"), "example mod content is registered")

	var first := GameSimulation.new(registry)
	var second := GameSimulation.new(registry)
	first.new_game("base:first_sparks", 123456)
	second.new_game("base:first_sparks", 123456)
	first.execute(GameCommand.start_research("base:arcane_foundations"))
	second.execute(GameCommand.start_research("base:arcane_foundations"))
	for _hour: int in 30:
		first.tick()
		second.tick()
	_check(JSON.stringify(first.serialize()) == JSON.stringify(second.serialize()), "same seed and commands are deterministic")
	var slow_speed := GameSimulation.new(registry)
	var fast_speed := GameSimulation.new(registry)
	slow_speed.new_game("base:first_sparks", 8181)
	fast_speed.new_game("base:first_sparks", 8181)
	slow_speed.set_speed(1)
	fast_speed.set_speed(4)
	slow_speed.execute(GameCommand.start_research("base:arcane_foundations"))
	fast_speed.execute(GameCommand.start_research("base:arcane_foundations"))
	for _hour: int in 48:
		slow_speed.tick()
		fast_speed.tick()
	_check(JSON.stringify(slow_speed.state.research_progress) == JSON.stringify(fast_speed.state.research_progress) and is_equal_approx(float(slow_speed.state.cash), float(fast_speed.state.cash)), "game speed changes real-time tick frequency but not per-tick simulation results")
	var no_hidden_teams := GameSimulation.new(registry)
	no_hidden_teams.new_game("base:first_sparks", 9191)
	no_hidden_teams.state.staff = []
	no_hidden_teams.state.cash = 1000.0
	for _hour: int in 24:
		no_hidden_teams.tick()
	_check(is_equal_approx(float(no_hidden_teams.state.cash), 1000.0) and not no_hidden_teams.state.has("teams"), "removed hidden teams provide neither capacity nor invisible wages")

	var wage_sim := GameSimulation.new(registry)
	wage_sim.new_game("base:first_sparks", 5151, "base:outskirts")
	_check(is_equal_approx(wage_sim.base_daily_wages(), 130.0) and is_equal_approx(wage_sim.daily_wages(), 130.0), "rebalanced starting staff costs exactly 130 gold per day at full wages")
	_check(float(registry.get_def("research", "base:arcane_foundations").hourly_cost) == 1.0 and float(registry.get_def("research", "base:arcane_resonance").hourly_cost) == 2.0 and float(registry.get_def("research", "base:arcane_mastery").hourly_cost) == 4.0 and float(registry.get_def("research", "base:crystal_hex").hourly_cost) == 3.0 and float(registry.get_def("research", "base:convergent_mastery").hourly_cost) == 5.0, "research tiers and hybrid projects use the rebalanced hourly costs")
	_check(not bool(wage_sim.execute(GameCommand.set_wage_level(0.75)).ok) and not bool(wage_sim.execute(GameCommand.set_wage_level(0.82)).ok) and not bool(wage_sim.execute(GameCommand.set_wage_level(1.25)).ok), "wage level rejects values outside 80 to 120 percent and values between five-percent steps")
	wage_sim.execute(GameCommand.start_research("base:arcane_foundations"))
	wage_sim.execute(GameCommand.set_wage_level(1.20))
	wage_sim.execute(GameCommand.set_wage_level(0.80))
	for _hour: int in 23:
		wage_sim.tick()
	_check(is_equal_approx(wage_sim.wage_performance_multiplier(), 1.0) and is_equal_approx(wage_sim.research_rate("base:arcane_foundations", false), 3.0), "scheduled wage changes do not alter work during the current day")
	wage_sim.tick()
	_check(is_equal_approx(float(wage_sim.state.market_report.wages), 130.0) and is_equal_approx(float(wage_sim.state.market_report.research_cost), 24.0), "the completed day is charged at its original wage level and records research costs")
	_check(is_equal_approx(wage_sim.wage_performance_multiplier(), 0.80) and is_equal_approx(wage_sim.daily_wages(), 104.0) and is_equal_approx(wage_sim.research_rate("base:arcane_foundations", false), 2.4), "only the last scheduled wage level activates on the following day and scales wages and research")
	var wage_blueprint_id := str(wage_sim.execute(GameCommand.create_blueprint({"name":"Wage Test", "body_id":"base:simple_charm", "effect_id":"base:minor_light", "modifier_ids":[], "material_id":"base:copper"})).blueprint_id)
	wage_sim.execute(GameCommand.configure_production("station_2", wage_blueprint_id))
	wage_sim.execute(GameCommand.set_production_enabled("station_2", true))
	wage_sim.tick()
	var wage_line: Dictionary = wage_sim.state.production_lines["station_2"]
	_check(is_equal_approx(float(wage_sim.production_line_status("station_2").rate), 1.04) and is_equal_approx(float(wage_line.quality_work) / float(wage_line.progress), 0.84), "eighty-percent wages scale production speed and weighted worker quality directly")
	wage_sim.execute(GameCommand.assign_staff("base:torben", "station_3"))
	wage_sim._tick_sources()
	_check(int((wage_sim.state.inventory["base:spring_water"] as Dictionary).quantity) == 1, "eighty-percent wages scale storage logistics before harvesting")
	var high_wage_sim := GameSimulation.new(registry)
	high_wage_sim.new_game("base:first_sparks", 5252, "base:outskirts")
	high_wage_sim.execute(GameCommand.set_wage_level(1.20))
	for _hour: int in 24:
		high_wage_sim.tick()
	_check(is_equal_approx(high_wage_sim.daily_wages(), 156.0) and is_equal_approx(high_wage_sim.research_rate("base:arcane_foundations", false), 3.6), "one-hundred-twenty-percent wages cost 156 gold and scale research directly")
	var hire_id := str(high_wage_sim.state.applicants[0])
	var hire_def := registry.get_def("staff", hire_id)
	var cash_before_hire := float(high_wage_sim.state.cash)
	high_wage_sim.execute(GameCommand.hire_staff(hire_id))
	var cash_after_hire := float(high_wage_sim.state.cash)
	high_wage_sim.execute(GameCommand.dismiss_staff(hire_id))
	_check(is_equal_approx(cash_before_hire - cash_after_hire, float(hire_def.salary) * 3.0) and is_equal_approx(cash_after_hire - float(high_wage_sim.state.cash), float(hire_def.salary) * 2.0), "hiring fees and severance remain based on base salary regardless of wage level")

	var simulation := GameSimulation.new(registry)
	simulation.new_game("base:first_sparks", 77)
	_check((simulation.state.available_contracts as Dictionary).is_empty(), "a new unknown workshop starts without contract offers")
	_check(not bool(simulation.execute(GameCommand.accept_contract("base:mage_focus")).ok), "contracts cannot be accepted before they appear")
	_check(simulation.unlocked_content("stations").size() == 3, "three starter station types are available in the workshop")
	var witch_foundations := registry.get_def("research", "base:witch_foundations")
	var rune_foundations := registry.get_def("research", "base:rune_foundations")
	_check((witch_foundations.unlocks as Array).has("base:ritual_circle"), "ritual research unlocks the ritual circle")
	_check((rune_foundations.unlocks as Array).has("base:rune_press"), "rune research unlocks the rune press")
	var initial_visible := simulation.visible_research()
	_check(initial_visible.size() == 3, "only the three immediately researchable foundations are initially visible")
	_check(initial_visible.all(func(project: Dictionary) -> bool: return (project.get("requires", []) as Array).is_empty()), "initial research list contains no locked projects")
	var start_result := simulation.execute(GameCommand.start_research("base:arcane_foundations"))
	_check(bool(start_result.ok), "research can start")
	for _hour: int in 120:
		simulation.tick()
	_check(bool((simulation.state.unlocked as Dictionary).get("base:arcane_foundations", false)), "research completes and unlocks")
	_check(str(simulation.state.player_profession) == "base:arcane", "first completed foundation permanently establishes the workshop profession")
	_check(bool((simulation.state.unlocked as Dictionary).get("base:mana_focus", false)), "research unlocks component")
	var progressed_visible := simulation.visible_research()
	_check(progressed_visible.any(func(project: Dictionary) -> bool: return str(project.id) == "base:arcane_foundations"), "completed research remains visible")
	_check(progressed_visible.any(func(project: Dictionary) -> bool: return str(project.id) == "base:arcane_resonance"), "newly researchable project becomes visible")
	_check(progressed_visible.any(func(project: Dictionary) -> bool: return str(project.id) == "base:complex_blueprints"), "neutral complex-blueprint research becomes visible after any foundation")
	_check(not progressed_visible.any(func(project: Dictionary) -> bool: return str(project.id) == "base:arcane_mastery"), "locked follow-up research remains hidden")
	_check(is_equal_approx(simulation.research_rate("base:complex_blueprints", false), 2.5), "general complex-blueprint research receives neither specialty nor property bonuses")

	var recipe_sim := GameSimulation.new(registry)
	recipe_sim.new_game("base:first_sparks", 7878, "base:outskirts")
	var locked_complex := recipe_sim.preview_blueprint({"name":"Locked", "body_id":"base:simple_charm", "effect_id":"base:minor_light", "secondary_effect_id":"base:warding_rune", "modifier_ids":[], "material_id":"base:copper", "secondary_material_id":"base:silver"})
	_check(not bool(locked_complex.valid), "secondary effects and materials remain locked before Complex Blueprints research")
	for unlock_id: String in ["base:complex_blueprints", "base:rune_foundations", "base:arcane_foundations", "base:witch_foundations", "base:arcane_resonance", "base:witch_transformations"]:
		(recipe_sim.state.unlocked as Dictionary)[unlock_id] = true
	for modifier: Dictionary in registry.all("modifiers"):
		(recipe_sim.state.unlocked as Dictionary)[str(modifier.id)] = true
	recipe_sim._reconcile_unlocks()
	var modifier_base := recipe_sim.preview_blueprint({"name":"Modifier Base", "body_id":"base:simple_charm", "effect_id":"base:minor_light", "modifier_ids":[], "material_id":"base:copper"})
	var modifier_expectations := {
		"base:balanced":{"cost":4.0,"hours":1.00,"quality":2.0,"stats":{"stability":5.0,"safety":3.0}},
		"base:polished":{"cost":8.0,"hours":1.10,"quality":3.0,"stats":{"prestige":7.0}},
		"base:economical":{"cost":-10.0,"hours":1.15,"quality":-3.0,"stats":{"power":-3.0,"prestige":-2.0}},
		"base:simple":{"cost":-6.0,"hours":0.80,"quality":-6.0,"stats":{"power":-2.0,"stability":-3.0,"prestige":-2.0}},
		"base:precision":{"cost":12.0,"hours":1.20,"quality":4.0,"stats":{"power":5.0,"stability":4.0}},
		"base:amplification":{"cost":18.0,"hours":1.10,"quality":-4.0,"stats":{"power":12.0,"safety":-3.0}},
		"base:perpetual_charge":{"cost":30.0,"hours":1.25,"quality":-5.0,"stats":{"power":15.0,"prestige":12.0}},
		"base:flexible":{"cost":10.0,"hours":0.90,"quality":-2.0,"stats":{"prestige":5.0,"stability":-2.0}},
		"base:adaptive":{"cost":18.0,"hours":1.15,"quality":-3.0,"stats":{"power":5.0,"prestige":9.0}},
		"base:self_woven_ritual":{"cost":30.0,"hours":0.80,"quality":-6.0,"stats":{"power":12.0,"prestige":16.0,"safety":-5.0}},
		"base:durable":{"cost":9.0,"hours":1.25,"quality":2.0,"stats":{"stability":10.0}},
		"base:efficient":{"cost":12.0,"hours":0.75,"quality":-4.0,"stats":{"power":3.0}},
		"base:city_ward":{"cost":32.0,"hours":1.60,"quality":-8.0,"stats":{"power":10.0,"safety":15.0,"prestige":18.0}},
	}
	for modifier_id: Variant in modifier_expectations.keys():
		var expected: Dictionary = modifier_expectations[modifier_id]
		var modified := recipe_sim.preview_blueprint({"name":"Modifier", "body_id":"base:simple_charm", "effect_id":"base:minor_light", "modifier_ids":[modifier_id], "material_id":"base:copper"})
		var exact := bool(modified.valid) and is_equal_approx(float(modified.unit_cost) - float(modifier_base.unit_cost), float(expected.cost)) and is_equal_approx(float(modified.hours), snappedf(float(modifier_base.hours) * float(expected.hours), 0.1)) and is_equal_approx(float(modified.quality_estimate) - float(modifier_base.quality_estimate), float(expected.quality))
		for stat_id: Variant in (expected.stats as Dictionary).keys():
			exact = exact and is_equal_approx(float((modified.stats as Dictionary)[stat_id]) - float((modifier_base.stats as Dictionary)[stat_id]), float((expected.stats as Dictionary)[stat_id]))
		_check(exact, "%s applies its explicit cost, effort, quality, and stat tradeoffs without hidden difficulty" % modifier_id)
	var duplicate_modifier := recipe_sim.preview_blueprint({"name":"Duplicate", "body_id":"base:simple_charm", "effect_id":"base:minor_light", "modifier_ids":["base:balanced","base:balanced"], "material_id":"base:copper"})
	_check(not bool(duplicate_modifier.valid), "the same modifier cannot be selected twice")
	var economical_preview := recipe_sim.preview_blueprint({"name":"Economical", "body_id":"base:simple_charm", "effect_id":"base:minor_light", "modifier_ids":["base:economical"], "material_id":"base:copper"})
	var economical_breakdown: Dictionary = ((economical_preview.component_breakdown as Dictionary).modifiers as Array)[0]
	_check(float(economical_preview.unit_cost) < float(modifier_base.unit_cost) and is_equal_approx(float(economical_breakdown.cost_delta), -10.0), "the economical modifier exposes a real ten-gold cost reduction")
	var simple_preview := recipe_sim.preview_blueprint({"name":"Simple", "body_id":"base:simple_charm", "effect_id":"base:minor_light", "modifier_ids":["base:simple"], "material_id":"base:copper"})
	var simple_breakdown: Dictionary = ((simple_preview.component_breakdown as Dictionary).modifiers as Array)[0]
	_check(is_equal_approx(float(simple_preview.unit_cost) - float(modifier_base.unit_cost), -6.0) and is_equal_approx(float(simple_preview.hours), snappedf(float(modifier_base.hours) * 0.80, 0.1)) and is_equal_approx(float(simple_breakdown.hours_multiplier), 0.80), "the simple modifier reduces both cost and production effort explicitly")
	var same_profession_mix := recipe_sim.preview_blueprint({"name":"Runic Mix", "body_id":"base:simple_charm", "effect_id":"base:minor_light", "secondary_effect_id":"base:warding_rune", "modifier_ids":[], "material_id":"base:copper"})
	_check(bool(same_profession_mix.valid) and is_equal_approx(float((same_profession_mix.stats as Dictionary).power) - float((modifier_base.stats as Dictionary).power), 3.6) and is_equal_approx(float((same_profession_mix.stats as Dictionary).safety) - float((modifier_base.stats as Dictionary).safety), 9.0) and (same_profession_mix.goods_classes as Array).has("base:rune_ward") and (same_profession_mix.profession_coverage as Array) == ["base:runes"], "same-profession secondary effects contribute sixty-percent stats but full classes and coverage")
	var locked_pair := recipe_sim.preview_blueprint({"name":"Locked Pair", "body_id":"base:simple_charm", "effect_id":"base:minor_light", "secondary_effect_id":"base:mana_focus", "modifier_ids":[], "material_id":"base:copper"})
	_check(not bool(locked_pair.valid) and str(locked_pair.message).contains("Runische Manufaktur"), "cross-profession secondary effects name the missing pair-hybrid research")
	(recipe_sim.state.unlocked as Dictionary)["base:runic_manufactory"] = true
	recipe_sim._reconcile_unlocks()
	var unlocked_pair := recipe_sim.preview_blueprint({"name":"Unlocked Pair", "body_id":"base:simple_charm", "effect_id":"base:minor_light", "secondary_effect_id":"base:mana_focus", "modifier_ids":[], "material_id":"base:copper"})
	_check(bool(unlocked_pair.valid) and _contains_all_for_test(unlocked_pair.profession_coverage, ["base:runes","base:arcane"]), "pair-hybrid research unlocks the matching cross-profession effect combination")
	(recipe_sim.state.unlocked as Dictionary)["base:crystal_hex"] = true
	recipe_sim._reconcile_unlocks()
	var locked_triple := recipe_sim.preview_blueprint({"name":"Locked Triple", "body_id":"base:simple_charm", "effect_id":"base:ritual_storage", "secondary_effect_id":"base:minor_light", "modifier_ids":[], "material_id":"base:copper"})
	_check(not bool(locked_triple.valid) and str(locked_triple.message).contains("Konvergente Meisterschaft"), "three-profession effect coverage remains locked behind convergence research")
	var refined_mix := recipe_sim.preview_blueprint({"name":"Refined", "body_id":"base:simple_charm", "effect_id":"base:minor_light", "modifier_ids":[], "material_id":"base:copper", "secondary_material_id":"base:silver"})
	_check(bool(refined_mix.valid) and (refined_mix.material_requirements as Array).size() == 2 and int((refined_mix.material_requirements[0] as Dictionary).quantity) == 2 and int((refined_mix.material_requirements[1] as Dictionary).quantity) == 1 and is_equal_approx(float(refined_mix.material_quality_estimate), (0.55 * 2.0 + 0.72) / 3.0) and is_equal_approx(float((refined_mix.stats as Dictionary).prestige) - float((modifier_base.stats as Dictionary).prestige), 2.5), "additional material uses a two-to-one recipe, weighted quality, and fifty-percent stats")
	_check(not bool(recipe_sim.preview_blueprint({"name":"Duplicate Material", "body_id":"base:simple_charm", "effect_id":"base:minor_light", "modifier_ids":[], "material_id":"base:copper", "secondary_material_id":"base:copper"}).valid), "primary and additional material must differ")

	var blueprint_data := {
		"name":"Test Focus",
		"body_id":"base:focus_rod",
		"effect_id":"base:mana_focus",
		"modifier_ids":["base:precision"],
		"material_id":"base:copper"
	}
	var preview := simulation.preview_blueprint(blueprint_data)
	_check(bool(preview.valid) and float(preview.stats.power) > 0, "blueprint preview derives stats")
	var create_result := simulation.execute(GameCommand.create_blueprint(blueprint_data))
	_check(bool(create_result.ok), "blueprint can be created")
	var blueprint_id := str(create_result.get("blueprint_id", ""))
	var configure_result := simulation.execute(GameCommand.configure_production("station_2", blueprint_id))
	_check(bool(configure_result.ok), "a blueprint can be assigned to a production station")
	_check(bool(simulation.execute(GameCommand.set_production_enabled("station_2", true)).ok), "continuous production can be started")
	simulation.execute(GameCommand.assign_staff("base:selin", ""))
	simulation.tick()
	_check(is_zero_approx(float((simulation.state.production_lines["station_2"] as Dictionary).progress)) and str(simulation.production_line_status("station_2").status) == "no_worker", "an unstaffed workbench waits without progress")
	simulation.execute(GameCommand.assign_staff("base:selin", "station_2"))
	simulation.tick()
	_check(is_equal_approx(float((simulation.state.production_lines["station_2"] as Dictionary).progress), 1.30), "worker speed advances production by an exact per-tick amount")
	_check(bool(simulation.execute(GameCommand.set_production_enabled("station_2", false)).ok), "continuous production can be paused")
	var paused_progress := float((simulation.state.production_lines["station_2"] as Dictionary).progress)
	simulation.tick()
	_check(is_equal_approx(float((simulation.state.production_lines["station_2"] as Dictionary).progress), paused_progress), "pausing preserves partial production progress")
	simulation.execute(GameCommand.set_production_enabled("station_2", true))
	for _hour: int in 100:
		simulation.tick()
	var product: Dictionary = (simulation.state.products as Dictionary).get(blueprint_id, {})
	_check(not product.is_empty() and int(product.quantity) >= 3, "a staffed workbench produces units continuously")
	_check(float(product.get("average_quality", 0)) > 0, "per-unit production quality is calculated")
	_check((simulation.state.logbook as Array).any(func(event: Dictionary) -> bool: return str(event.type) == "ProductionSummary"), "continuous unit output is aggregated into daily logbook summaries")
	var listing_result := simulation.execute(GameCommand.set_price(blueprint_id, 90.0))
	_check(bool(listing_result.ok), "product can be listed")
	for _hour: int in 24:
		simulation.tick()
	_check((simulation.state.market_report as Dictionary).has("daily_revenue"), "daily market produces an explainable report")
	_check(int(simulation.state.market_units_sold) > 0, "open-market sales build contract-market awareness")
	_check((simulation.state.available_contracts as Dictionary).size() == 1, "the first sale unlocks exactly one early contract offer")
	var offered_contract_id := str((simulation.state.available_contracts as Dictionary).keys()[0])
	var offered_contract: Dictionary = (simulation.state.available_contracts as Dictionary)[offered_contract_id]
	_check(int(offered_contract.deadline_day) - int(offered_contract.appeared_day) == int(offered_contract.deadline_days), "contract duration starts when the offer appears")
	var offered_deadline := int(offered_contract.deadline_day)
	var accept_contract_result := simulation.execute(GameCommand.accept_contract(offered_contract_id))
	_check(bool(accept_contract_result.ok) and int((simulation.state.active_contracts[offered_contract_id] as Dictionary).deadline_day) == offered_deadline, "accepting an offer preserves its original deadline")
	_check(simulation.contract_days_remaining(simulation.state.active_contracts[offered_contract_id]) == int(offered_contract.deadline_days), "contract deadlines expose a relative remaining duration")
	var quantity_before_stop := int(((simulation.state.products as Dictionary).get(blueprint_id, {}) as Dictionary).get("quantity", 0))
	var stop_result := simulation.execute(GameCommand.stop_sale(blueprint_id))
	_check(bool(stop_result.ok) and not (simulation.state.listings as Dictionary).has(blueprint_id), "an active market sale can be stopped")
	for _hour: int in 24:
		simulation.tick()
	var quantity_after_stop := int(((simulation.state.products as Dictionary).get(blueprint_id, {}) as Dictionary).get("quantity", 0))
	_check(quantity_after_stop == quantity_before_stop, "stopped sale leaves finished goods in warehouse")
	_check((simulation.state.available_contracts as Dictionary).is_empty(), "an active early contract prevents additional offers from piling up")
	_check(not bool(simulation.execute(GameCommand.stop_sale(blueprint_id)).ok), "stopping a non-existent sale is rejected safely")
	var active_contract: Dictionary = (simulation.state.active_contracts as Dictionary)[offered_contract_id]
	var delivery_product: Dictionary = (simulation.state.products as Dictionary)[blueprint_id]
	delivery_product.quantity = int(active_contract.quantity)
	delivery_product.average_quality = float(active_contract.min_quality)
	(simulation.state.products as Dictionary)[blueprint_id] = delivery_product
	for _hour: int in 24:
		simulation.tick()
	_check((simulation.state.active_contracts as Dictionary).has(offered_contract_id) and int((simulation.state.products[blueprint_id] as Dictionary).quantity) == int(active_contract.quantity), "eligible contract goods wait for manual delivery")
	var cash_before_delivery := float(simulation.state.cash)
	var faction_before_delivery := float((simulation.state.faction_reputation as Dictionary).get(str(active_contract.customer), 0.0))
	var submit_result := simulation.execute(GameCommand.submit_contract(offered_contract_id))
	_check(bool(submit_result.ok), "an active contract can be completed with the deliver-goods command")
	_check(not (simulation.state.active_contracts as Dictionary).has(offered_contract_id) and (simulation.state.completed_contracts as Array).has(offered_contract_id), "manual delivery closes the contract")
	_check(int((simulation.state.products[blueprint_id] as Dictionary).quantity) == 0 and float(simulation.state.cash) == cash_before_delivery + float(active_contract.reward), "manual delivery consumes goods and pays the reward")
	_check(float((simulation.state.faction_reputation as Dictionary).get(str(active_contract.customer), 0.0)) == faction_before_delivery + float(active_contract.faction_reputation_reward), "contract completion grants standing with its specific customer faction")
	_check((simulation.state.logbook as Array).any(func(event: Dictionary) -> bool: return str(event.type) == "ContractCompleted"), "contract completion is recorded in the persistent logbook")

	var saved := simulation.serialize()
	var restored := GameSimulation.new(registry)
	restored.new_game()
	var restore_result := restored.restore(saved)
	_check(bool(restore_result.ok), "save state restores with matching packages")
	_check(int(restored.state.hour) == int(simulation.state.hour), "restored clock matches")
	_check(restored.rng_quality.state == simulation.rng_quality.state, "restored RNG state matches")
	_check((restored.state.logbook as Array).size() == (simulation.state.logbook as Array).size(), "logbook survives a save-state roundtrip")
	var version_six_save := saved.duplicate(true)
	version_six_save.save_version = 6
	version_six_save.erase("wage_level")
	version_six_save.erase("pending_wage_level")
	version_six_save.erase("research_cost_today")
	version_six_save.active_contracts = {"base:mage_focus":registry.get_def("contracts", "base:mage_focus").duplicate(true)}
	var wage_migrated := GameSimulation.new(registry)
	_check(bool(wage_migrated.restore(version_six_save).ok) and is_equal_approx(wage_migrated.wage_performance_multiplier(), 1.0) and is_equal_approx(float(wage_migrated.state.pending_wage_level), 1.0), "version-six saves migrate to one-hundred-percent active and scheduled wages")
	_check((wage_migrated.state.active_contracts as Dictionary).has("base:mage_focus"), "wage migration preserves version-six active contracts")
	var version_seven_save := saved.duplicate(true)
	version_seven_save.save_version = 7
	var legacy_complex_blueprint: Dictionary = (version_seven_save.blueprints as Dictionary)[blueprint_id]
	legacy_complex_blueprint.erase("secondary_effect_id")
	legacy_complex_blueprint.erase("secondary_material_id")
	legacy_complex_blueprint.computed.erase("material_requirements")
	(version_seven_save.blueprints as Dictionary)[blueprint_id] = legacy_complex_blueprint
	version_seven_save.production_lines = {"station_2":{"blueprint_id":blueprint_id, "enabled":false, "progress":3.25, "quality_work":2.75, "material_reserved":true, "material_id":"base:copper", "material_quantity":1, "material_quality":0.61}}
	var complex_migrated := GameSimulation.new(registry)
	var complex_restore := complex_migrated.restore(version_seven_save)
	var migrated_complex_blueprint: Dictionary = (complex_migrated.state.blueprints as Dictionary).get(blueprint_id, {})
	var migrated_complex_line: Dictionary = (complex_migrated.state.production_lines as Dictionary).get("station_2", {})
	var migrated_reserved: Array = migrated_complex_line.get("reserved_materials", [])
	_check(bool(complex_restore.ok) and str(migrated_complex_blueprint.get("secondary_effect_id", "missing")).is_empty() and str(migrated_complex_blueprint.get("secondary_material_id", "missing")).is_empty(), "version-seven blueprints migrate with empty optional recipe slots")
	_check((migrated_complex_blueprint.get("computed", {}) as Dictionary).has("material_requirements"), "version-seven blueprint calculations are rebuilt for multi-material production")
	_check(is_equal_approx(float(migrated_complex_line.get("progress", 0.0)), 3.25) and is_equal_approx(float(migrated_complex_line.get("quality_work", 0.0)), 2.75), "version-seven production migration preserves work progress")
	_check(migrated_reserved.size() == 1 and str((migrated_reserved[0] as Dictionary).material_id) == "base:copper" and int((migrated_reserved[0] as Dictionary).quantity) == 1 and is_equal_approx(float((migrated_reserved[0] as Dictionary).quality), 0.61), "version-seven reserved material migrates without quantity or quality loss")
	var old_timing_save := saved.duplicate(true)
	old_timing_save.save_version = 3
	old_timing_save.erase("production_lines")
	old_timing_save.erase("production_today")
	var copper_before_migration := int((old_timing_save.inventory["base:copper"] as Dictionary).quantity)
	old_timing_save.production_queue = [{"blueprint_id":blueprint_id, "quantity":10, "progress":80.0, "total_hours":100.0, "material_quality":0.6}]
	var timing_migrated := GameSimulation.new(registry)
	var timing_restore := timing_migrated.restore(old_timing_save)
	_check(bool(timing_restore.ok) and not timing_migrated.state.has("production_queue") and (timing_migrated.state.production_lines as Dictionary).is_empty(), "legacy production queues migrate to stopped station lines: %s" % timing_restore)
	_check(int((timing_migrated.state.inventory["base:copper"] as Dictionary).quantity) == copper_before_migration + 20, "legacy queue migration refunds every reserved material unit")
	var legacy_save := saved.duplicate(true)
	(legacy_save.unlocked as Dictionary)["base:witch_foundations"] = true
	(legacy_save.unlocked as Dictionary).erase("base:ritual_circle")
	var reconciled := GameSimulation.new(registry)
	var reconcile_result := reconciled.restore(legacy_save)
	_check(bool(reconcile_result.ok) and bool((reconciled.state.unlocked as Dictionary).get("base:ritual_circle", false)), "loading reconciles new unlocks for completed legacy research")
	var profession_legacy_save := saved.duplicate(true)
	profession_legacy_save.save_version = 5
	profession_legacy_save.erase("player_profession")
	profession_legacy_save.erase("profession_choice_required")
	profession_legacy_save.erase("faction_reputation")
	(profession_legacy_save.unlocked as Dictionary)["base:arcane_foundations"] = true
	(profession_legacy_save.unlocked as Dictionary)["base:witch_foundations"] = true
	profession_legacy_save.active_contracts = {"base:mage_focus":registry.get_def("contracts", "base:mage_focus").duplicate(true)}
	profession_legacy_save.available_contracts = {"base:coven_gifts":registry.get_def("contracts", "base:coven_gifts").duplicate(true)}
	var profession_legacy := GameSimulation.new(registry)
	_check(bool(profession_legacy.restore(profession_legacy_save).ok) and bool(profession_legacy.state.profession_choice_required), "ambiguous legacy foundations request a one-time profession choice")
	_check((profession_legacy.state.active_contracts as Dictionary).is_empty() and (profession_legacy.state.available_contracts as Dictionary).is_empty(), "legacy active and offered contracts are removed without penalties")
	_check(bool(profession_legacy.execute(GameCommand.choose_profession("base:witchcraft")).ok) and str(profession_legacy.state.player_profession) == "base:witchcraft" and not bool(profession_legacy.state.profession_choice_required), "legacy profession choice is restricted to completed foundations and becomes permanent")
	var migrated_blueprint: Dictionary = (profession_legacy.state.blueprints as Dictionary)[blueprint_id]
	_check((migrated_blueprint.computed as Dictionary).has("goods_classes") and (migrated_blueprint.computed as Dictionary).has("profession_coverage"), "legacy blueprints are reclassified from their saved components")
	var file_save := SaveSystem.save_game(simulation, "automated_test")
	_check(bool(file_save.ok), "save file is written atomically")
	var disk_restored := GameSimulation.new(registry)
	disk_restored.new_game()
	var file_load := SaveSystem.load_game(disk_restored, "automated_test")
	_check(bool(file_load.ok) and int(disk_restored.state.hour) == int(simulation.state.hour), "save file loads from disk")
	var assign_result := simulation.execute(GameCommand.assign_staff("base:torben", "station_1"))
	_check(bool(assign_result.ok), "staff can be assigned to a concrete station")
	_check(str((simulation.state.staff[0] as Dictionary).station_id).is_empty(), "assigning to an occupied station makes the former occupant available")
	_check(str((simulation.state.staff[1] as Dictionary).station_id) == "station_1", "new occupant owns the selected station")

	simulation.state.cash = 10000.0
	var room_result := simulation.execute(GameCommand.place_room("base:workshop", Rect2i(12, 4, 3, 3)))
	_check(bool(room_result.ok), "a freely sized non-overlapping room can be placed")
	var overlap_result := simulation.execute(GameCommand.place_room("base:workshop", Rect2i(12, 4, 3, 3)))
	_check(not bool(overlap_result.ok), "overlapping room is rejected")
	var source_overlap := simulation.execute(GameCommand.place_room("base:workshop", Rect2i(12, 0, 3, 3)))
	_check(not bool(source_overlap.ok), "resource sources block construction tiles")

	var outskirts := GameSimulation.new(registry)
	outskirts.new_game("base:first_sparks", 9001, "base:outskirts")
	var cemetery := GameSimulation.new(registry)
	cemetery.new_game("base:first_sparks", 9001, "base:cemetery")
	var forest := GameSimulation.new(registry)
	forest.new_game("base:first_sparks", 9001, "base:deep_forest")
	_check(outskirts.grid_size() == Vector2i(20, 12) and cemetery.grid_size() == Vector2i(24, 14) and forest.grid_size() == Vector2i(30, 18), "property definitions drive workshop grid dimensions")
	_check(int(outskirts.property.applicant_count) == 3 and int(forest.property.applicant_count) == 2, "property applicant counts are applied")
	_check((forest.state.applicants as Array).size() == 2, "deep forest starts with two deterministic applicants")
	var outskirts_again := GameSimulation.new(registry)
	outskirts_again.new_game("base:first_sparks", 9001, "base:outskirts")
	_check(JSON.stringify(outskirts.state.applicants) == JSON.stringify(outskirts_again.state.applicants), "applicant selection has its own deterministic RNG")
	_check(outskirts.housing_capacity() == 4, "initial 4x4 residence provides four staff places")
	var outskirts_research := GameSimulation.new(registry)
	outskirts_research.new_game("base:first_sparks", 88, "base:outskirts")
	outskirts_research.execute(GameCommand.assign_staff("base:elara", ""))
	var research_cash_without_worker := float(outskirts_research.state.cash)
	outskirts_research.execute(GameCommand.start_research("base:arcane_foundations"))
	outskirts_research.tick()
	_check(not (outskirts_research.state.research_progress as Dictionary).has("base:arcane_foundations") and is_equal_approx(float(outskirts_research.state.cash), research_cash_without_worker) and int(outskirts_research.state.research_ramp) == 12, "research without a staffed desk makes no progress, costs nothing, and preserves ramp time")
	outskirts_research.execute(GameCommand.assign_staff("base:elara", "station_1"))
	outskirts_research.tick()
	_check(is_equal_approx(float((outskirts_research.state.research_progress as Dictionary)["base:arcane_foundations"]), 1.65) and int(outskirts_research.state.research_ramp) == 11, "staffed research applies an exact visible ramp-adjusted tick rate")
	(outskirts_research.state.stations as Array).append({"id":"station_4", "type":"base:research_desk", "position":[7,1]})
	outskirts_research.execute(GameCommand.assign_staff("base:torben", "station_4"))
	_check(is_equal_approx(outskirts_research.research_rate("base:arcane_foundations", false), 5.30), "multiple staffed research desks add their work to the shared project")
	outskirts_research.execute(GameCommand.assign_staff("base:torben", ""))
	(outskirts_research.state.stations as Array).pop_back()
	var cemetery_research := GameSimulation.new(registry)
	cemetery_research.new_game("base:first_sparks", 88, "base:cemetery")
	outskirts_research.execute(GameCommand.start_research("base:witch_foundations"))
	cemetery_research.execute(GameCommand.start_research("base:witch_foundations"))
	outskirts_research.tick()
	cemetery_research.tick()
	var outskirts_progress := float((outskirts_research.state.research_progress as Dictionary)["base:witch_foundations"])
	var cemetery_progress := float((cemetery_research.state.research_progress as Dictionary)["base:witch_foundations"])
	_check(is_equal_approx(cemetery_progress, outskirts_progress * 1.15), "cemetery applies its witchcraft research bonus")
	for market_sim: GameSimulation in [outskirts, cemetery, forest]:
		for _hour: int in 24:
			market_sim.tick()
	var outskirts_demand := int((outskirts.state.market_report["base:mages"] as Dictionary).demand)
	var cemetery_demand := int((cemetery.state.market_report["base:mages"] as Dictionary).demand)
	var forest_demand := int((forest.state.market_report["base:mages"] as Dictionary).demand)
	_check(outskirts_demand > cemetery_demand and cemetery_demand > forest_demand, "property market-demand multipliers affect daily demand")

	var profession_filter_sim := GameSimulation.new(registry)
	profession_filter_sim.new_game("base:first_sparks", 2323, "base:outskirts")
	profession_filter_sim.state.market_units_sold = 1
	profession_filter_sim._update_contract_market()
	_check((profession_filter_sim.state.available_contracts as Dictionary).is_empty(), "no contracts appear before a workshop profession is established")
	(profession_filter_sim.state.unlocked as Dictionary)["base:rune_foundations"] = true
	profession_filter_sim._reconcile_unlocks()
	profession_filter_sim.state.player_profession = "base:runes"
	profession_filter_sim._update_contract_market()
	_check(not (profession_filter_sim.state.available_contracts as Dictionary).is_empty() and (profession_filter_sim.state.available_contracts as Dictionary).values().all(func(contract: Dictionary) -> bool: return (contract.eligible_professions as Array).has("base:runes")), "hard profession filter only offers contracts eligible for the established workshop profession")

	var classification_sim := GameSimulation.new(registry)
	classification_sim.new_game("base:first_sparks", 2424, "base:outskirts")
	for unlock_id: String in ["base:arcane_foundations", "base:arcane_resonance", "base:witch_foundations", "base:rune_foundations", "base:crystal_hex", "base:runic_manufactory", "base:bound_covenant", "base:convergent_mastery"]:
		(classification_sim.state.unlocked as Dictionary)[unlock_id] = true
	classification_sim._reconcile_unlocks()
	var ordinary_cross := classification_sim.preview_blueprint({"name":"Ordinary Cross", "body_id":"base:focus_rod", "effect_id":"base:minor_light", "modifier_ids":[], "material_id":"base:copper"})
	var pair_hybrid := classification_sim.preview_blueprint({"name":"Pair Hybrid", "body_id":"base:simple_charm", "effect_id":"base:ritual_storage", "modifier_ids":[], "material_id":"base:copper"})
	var triple_hybrid := classification_sim.preview_blueprint({"name":"Triple Hybrid", "body_id":"base:simple_charm", "effect_id":"base:unified_convergence", "modifier_ids":[], "material_id":"base:copper"})
	_check((ordinary_cross.profession_coverage as Array) == ["base:runes"], "ordinary cross-discipline components keep the primary effect's single profession")
	_check((pair_hybrid.profession_coverage as Array).size() == 2 and (pair_hybrid.goods_classes as Array).has("base:arcane_storage") and (pair_hybrid.goods_classes as Array).has("base:witch_ritual"), "explicit pair hybrid carries two professions and classes from both")
	_check((triple_hybrid.profession_coverage as Array).size() == 3, "convergence effect creates genuine triple-profession goods")
	var utility_id := str(classification_sim.execute(GameCommand.create_blueprint({"name":"Utility Alternative", "body_id":"base:simple_charm", "effect_id":"base:minor_light", "modifier_ids":[], "material_id":"base:copper"})).blueprint_id)
	var ward_id := str(classification_sim.execute(GameCommand.create_blueprint({"name":"Ward Alternative", "body_id":"base:simple_charm", "effect_id":"base:warding_rune", "modifier_ids":[], "material_id":"base:copper"})).blueprint_id)
	(classification_sim.state.products as Dictionary)[utility_id] = {"quantity":4, "average_quality":60.0}
	(classification_sim.state.products as Dictionary)[ward_id] = {"quantity":4, "average_quality":60.0}
	var alternative_delivery := classification_sim.contract_delivery_status(registry.get_def("contracts", "base:apprentice_charms"))
	_check(bool(alternative_delivery.ready) and int(alternative_delivery.available) == 8, "multiple blueprints with different accepted alternative classes combine toward one contract quantity")
	var normal_storage_id := str(classification_sim.execute(GameCommand.create_blueprint({"name":"Normal Storage", "body_id":"base:simple_charm", "effect_id":"base:mana_crystal", "modifier_ids":[], "material_id":"base:copper"})).blueprint_id)
	(classification_sim.state.products as Dictionary)[normal_storage_id] = {"quantity":5, "average_quality":80.0}
	_check(not bool(classification_sim.contract_delivery_status(registry.get_def("contracts", "base:joint_symposium")).ready), "matching class alone cannot satisfy a contract that requires pair-profession coverage")

	var tier_gate_sim := GameSimulation.new(registry)
	tier_gate_sim.new_game("base:first_sparks", 2626, "base:outskirts")
	for unlock_id: String in ["base:arcane_foundations", "base:arcane_resonance"]:
		(tier_gate_sim.state.unlocked as Dictionary)[unlock_id] = true
	tier_gate_sim._reconcile_unlocks()
	tier_gate_sim.state.player_profession = "base:arcane"
	tier_gate_sim.state.market_units_sold = 1
	(tier_gate_sim.state.contract_offer_cooldowns as Dictionary)["base:mage_focus"] = 99
	(tier_gate_sim.state.contract_offer_cooldowns as Dictionary)["base:academy_reserve"] = 99
	(tier_gate_sim.state.faction_reputation as Dictionary)["base:mages"] = 9.0
	tier_gate_sim._update_contract_market()
	_check((tier_gate_sim.state.available_contracts as Dictionary).is_empty(), "tier-two customer contracts remain locked below ten faction standing")
	(tier_gate_sim.state.faction_reputation as Dictionary)["base:mages"] = 10.0
	var market_rng_before_contract := tier_gate_sim.rng_market.state
	tier_gate_sim._update_contract_market()
	_check((tier_gate_sim.state.available_contracts as Dictionary).size() == 1 and int(((tier_gate_sim.state.available_contracts as Dictionary).values()[0] as Dictionary).tier) == 2, "ten faction standing unlocks a buildable tier-two contract")
	_check(tier_gate_sim.rng_market.state == market_rng_before_contract, "contract selection uses its own RNG stream without perturbing market randomness")

	var standing_low := GameSimulation.new(registry)
	var standing_high := GameSimulation.new(registry)
	standing_low.new_game("base:first_sparks", 2525, "base:outskirts")
	standing_high.new_game("base:first_sparks", 2525, "base:outskirts")
	(standing_high.state.faction_reputation as Dictionary)["base:mages"] = 25.0
	standing_low._run_market()
	standing_high._run_market()
	_check(int((standing_high.state.market_report["base:mages"] as Dictionary).demand) > int((standing_low.state.market_report["base:mages"] as Dictionary).demand), "customer standing increases demand only for its market segment")

	var line_sim := GameSimulation.new(registry)
	line_sim.new_game("base:first_sparks", 333, "base:outskirts")
	var line_blueprint_data := {"name":"Line Test", "body_id":"base:simple_charm", "effect_id":"base:minor_light", "modifier_ids":[], "material_id":"base:copper"}
	var line_create := line_sim.execute(GameCommand.create_blueprint(line_blueprint_data))
	var line_blueprint_id := str(line_create.blueprint_id)
	var apprentice_contract := registry.get_def("contracts", "base:apprentice_charms")
	(line_sim.state.products as Dictionary)[line_blueprint_id] = {"quantity":6, "average_quality":49.0, "unit_cost":1.0}
	var apprentice_delivery := line_sim.contract_delivery_status(apprentice_contract)
	_check(int(apprentice_delivery.available) == 6 and not bool(apprentice_delivery.ready), "simple talismans of sufficient quality count toward the apprentice talisman contract")
	(line_sim.state.products as Dictionary).erase(line_blueprint_id)
	(line_sim.state.stations as Array).append({"id":"station_4", "type":"base:rune_press", "position":[2,6]})
	line_sim.execute(GameCommand.assign_staff("base:torben", "station_4"))
	line_sim.execute(GameCommand.configure_production("station_2", line_blueprint_id))
	line_sim.execute(GameCommand.configure_production("station_4", line_blueprint_id))
	line_sim.execute(GameCommand.set_production_enabled("station_2", true))
	line_sim.execute(GameCommand.set_production_enabled("station_4", true))
	line_sim.tick()
	_check(is_equal_approx(float((line_sim.state.production_lines["station_2"] as Dictionary).progress), 1.30) and is_equal_approx(float((line_sim.state.production_lines["station_4"] as Dictionary).progress), 2.00), "workbenches progress independently using worker speed and station capacity")
	line_sim.execute(GameCommand.set_production_enabled("station_2", false))
	var copper_before_switch := int((line_sim.state.inventory["base:copper"] as Dictionary).quantity)
	var second_line_data := line_blueprint_data.duplicate(true)
	second_line_data.name = "Line Switch"
	second_line_data.material_id = "base:iron"
	var second_line_id := str(line_sim.execute(GameCommand.create_blueprint(second_line_data)).blueprint_id)
	line_sim.execute(GameCommand.configure_production("station_2", second_line_id))
	_check(int((line_sim.state.inventory["base:copper"] as Dictionary).quantity) == copper_before_switch + 2 and is_zero_approx(float((line_sim.state.production_lines["station_2"] as Dictionary).progress)), "switching a paused line refunds reserved material and resets progress")
	var normal_quality_sim := GameSimulation.new(registry)
	var high_quality_sim := GameSimulation.new(registry)
	normal_quality_sim.new_game("base:first_sparks", 5151, "base:outskirts")
	high_quality_sim.new_game("base:first_sparks", 5151, "base:outskirts")
	var normal_quality_id := str(normal_quality_sim.execute(GameCommand.create_blueprint(line_blueprint_data)).blueprint_id)
	var high_quality_id := str(high_quality_sim.execute(GameCommand.create_blueprint(line_blueprint_data)).blueprint_id)
	high_quality_sim.execute(GameCommand.assign_staff("base:torben", "station_2"))
	normal_quality_sim.execute(GameCommand.configure_production("station_2", normal_quality_id))
	high_quality_sim.execute(GameCommand.configure_production("station_2", high_quality_id))
	normal_quality_sim.execute(GameCommand.set_production_enabled("station_2", true))
	high_quality_sim.execute(GameCommand.set_production_enabled("station_2", true))
	for _hour: int in 30:
		normal_quality_sim.tick()
		high_quality_sim.tick()
	_check(float((high_quality_sim.state.products[high_quality_id] as Dictionary).average_quality) > float((normal_quality_sim.state.products[normal_quality_id] as Dictionary).average_quality), "worker quality changes deterministic per-unit product quality independently of speed")
	var supply_sim := GameSimulation.new(registry)
	supply_sim.new_game("base:first_sparks", 444, "base:outskirts")
	var supply_id := str(supply_sim.execute(GameCommand.create_blueprint(line_blueprint_data)).blueprint_id)
	(supply_sim.state.inventory["base:copper"] as Dictionary).quantity = 0
	supply_sim.execute(GameCommand.configure_production("station_2", supply_id))
	supply_sim.execute(GameCommand.set_production_enabled("station_2", true))
	var supply_cash := float(supply_sim.state.cash)
	supply_sim.tick()
	_check(str(supply_sim.production_line_status("station_2").status) == "no_material" and is_equal_approx(float(supply_sim.state.cash), supply_cash), "missing material pauses production when no storage worker is assigned")
	supply_sim.execute(GameCommand.assign_staff("base:torben", "station_3"))
	supply_sim.tick()
	_check(float((supply_sim.state.production_lines["station_2"] as Dictionary).progress) > 0.0 and float(supply_sim.state.cash) < supply_cash, "a storage worker enables just-in-time automatic procurement")
	var multi_material_sim := GameSimulation.new(registry)
	multi_material_sim.new_game("base:first_sparks", 4545, "base:outskirts")
	(multi_material_sim.state.unlocked as Dictionary)["base:complex_blueprints"] = true
	var multi_id := str(multi_material_sim.execute(GameCommand.create_blueprint({"name":"Copper Silver Mix", "body_id":"base:simple_charm", "effect_id":"base:minor_light", "modifier_ids":[], "material_id":"base:copper", "secondary_material_id":"base:silver"})).blueprint_id)
	var plain_id := str(multi_material_sim.execute(GameCommand.create_blueprint({"name":"Plain Copper", "body_id":"base:simple_charm", "effect_id":"base:minor_light", "modifier_ids":[], "material_id":"base:copper"})).blueprint_id)
	(multi_material_sim.state.inventory["base:copper"] as Dictionary).quantity = 2
	(multi_material_sim.state.inventory["base:silver"] as Dictionary).quantity = 0
	multi_material_sim.execute(GameCommand.configure_production("station_2", multi_id))
	multi_material_sim.execute(GameCommand.set_production_enabled("station_2", true))
	multi_material_sim.tick()
	_check(str(multi_material_sim.production_line_status("station_2").status) == "no_material" and int((multi_material_sim.state.inventory["base:copper"] as Dictionary).quantity) == 2, "multi-material reservation removes nothing when one material is missing without a storage worker")
	multi_material_sim.execute(GameCommand.assign_staff("base:torben", "station_3"))
	multi_material_sim.state.cash = 0.0
	multi_material_sim.tick()
	_check(str(multi_material_sim.production_line_status("station_2").status) == "no_cash" and int((multi_material_sim.state.inventory["base:copper"] as Dictionary).quantity) == 2, "multi-material reservation remains atomic when automatic procurement lacks gold")
	multi_material_sim.state.cash = 1000.0
	multi_material_sim.tick()
	var multi_line: Dictionary = multi_material_sim.state.production_lines["station_2"]
	_check(bool(multi_line.material_reserved) and (multi_line.reserved_materials as Array).size() == 2 and int((multi_material_sim.state.inventory["base:copper"] as Dictionary).quantity) == 0 and int((multi_material_sim.state.inventory["base:silver"] as Dictionary).quantity) == 0 and is_equal_approx(float(multi_material_sim.state.cash), 963.2), "storage staff procure all missing recipe materials and reserve the complete two-to-one mix atomically")
	multi_material_sim.execute(GameCommand.set_production_enabled("station_2", false))
	multi_material_sim.execute(GameCommand.configure_production("station_2", plain_id))
	_check(int((multi_material_sim.state.inventory["base:copper"] as Dictionary).quantity) == 2 and int((multi_material_sim.state.inventory["base:silver"] as Dictionary).quantity) == 1 and (multi_material_sim.state.production_lines["station_2"].reserved_materials as Array).is_empty(), "switching a paused complex line refunds every reserved material with no loss")
	for procurement_sim: GameSimulation in [outskirts, forest]:
		procurement_sim.state.cash = 1000.0
		(procurement_sim.state.inventory["base:copper"] as Dictionary).quantity = 0
		procurement_sim.execute(GameCommand.purchase_material("base:copper", 2))
	_check(is_equal_approx(float(outskirts.state.cash), 992.8) and is_equal_approx(float(forest.state.cash), 990.4), "property procurement multipliers change missing-material cost")

	var material_trade := GameSimulation.new(registry)
	material_trade.new_game("base:first_sparks", 6060, "base:outskirts")
	_check(material_trade.material_capacity() == 20 and material_trade.material_free_capacity("base:copper") == 8, "one material shelf provides twenty independent spaces per raw material")
	(material_trade.state.stations as Array).append({"id":"station_4", "type":"base:stock_shelves", "position":[9, 6]})
	_check(material_trade.material_capacity() == 40 and material_trade.material_free_capacity("base:copper") == 28, "a second shelf adds twenty spaces to every raw material limit")
	(material_trade.state.stations as Array).pop_back()
	(material_trade.state.inventory["base:copper"] as Dictionary).quantity = 0
	material_trade.state.cash = 1000.0
	_check(bool(material_trade.execute(GameCommand.purchase_material("base:copper", 20)).ok), "manual material purchase can fill storage exactly to its limit")
	var cash_at_limit := float(material_trade.state.cash)
	_check(not bool(material_trade.execute(GameCommand.purchase_material("base:copper", 1)).ok) and is_equal_approx(float(material_trade.state.cash), cash_at_limit), "material purchases above the free capacity are rejected in full")
	var awareness_before_raw_sale := int(material_trade.state.market_units_sold)
	var raw_revenue_before := float(material_trade.state.raw_material_revenue)
	_check(bool(material_trade.execute(GameCommand.sell_material("base:copper", 5)).ok) and is_equal_approx(float(material_trade.state.raw_material_revenue) - raw_revenue_before, 16.5), "manual raw material sale pays the quality- and property-adjusted price")
	_check(int(material_trade.state.market_units_sold) == awareness_before_raw_sale, "raw material sales do not create artifact-market awareness")
	material_trade.state.hour = 9 * 24
	_check(is_equal_approx(material_trade.material_buy_price("base:oak"), 4.32) and is_equal_approx(material_trade.material_sell_price("base:oak", 0.64), 3.96), "active rich-harvest event changes matching material buy and sell prices")
	var rich_harvest_events := material_trade.active_material_price_events("base:oak")
	_check(rich_harvest_events.size() == 1 and int(rich_harvest_events[0].remaining_days) == 7, "material price event exposes its relative remaining duration")
	material_trade.state.hour = 16 * 24
	_check(material_trade.active_material_price_events("base:oak").is_empty(), "material price event ends after its configured inclusive day range")

	var overflow_sim := GameSimulation.new(registry)
	overflow_sim.new_game("base:first_sparks", 7070, "base:outskirts")
	overflow_sim.execute(GameCommand.assign_staff("base:torben", "station_3"))
	(overflow_sim.state.inventory["base:spring_water"] as Dictionary).quantity = overflow_sim.material_capacity()
	var overflow_cash := float(overflow_sim.state.cash)
	overflow_sim._tick_sources()
	var overflow_entry: Dictionary = (overflow_sim.state.raw_material_sales_today as Dictionary).get("base:spring_water", {})
	_check(int((overflow_sim.state.inventory["base:spring_water"] as Dictionary).quantity) == 20 and int(overflow_entry.get("automatic_units", 0)) == 2 and float(overflow_sim.state.cash) > overflow_cash, "staffed harvesting stores up to capacity and automatically sells only the new overflow")
	overflow_sim._run_market()
	_check(float((overflow_sim.state.market_report as Dictionary).get("raw_material_revenue", 0.0)) > 0.0 and (overflow_sim.state.logbook as Array).any(func(event: Dictionary) -> bool: return str(event.type) == "RawMaterialOverflowSold" and str((event.payload as Dictionary).get("material_id", "")) == "base:spring_water"), "automatic overflow revenue is separated in the daily report and summarized in the logbook")

	var overfull_save := material_trade.serialize()
	overfull_save.save_version = 4
	(overfull_save.inventory["base:copper"] as Dictionary).quantity = 55
	overfull_save.erase("raw_material_revenue")
	overfull_save.erase("artifact_revenue")
	overfull_save.erase("raw_material_sales_today")
	var overfull_restored := GameSimulation.new(registry)
	_check(bool(overfull_restored.restore(overfull_save).ok) and int((overfull_restored.state.inventory["base:copper"] as Dictionary).quantity) == 55, "legacy over-capacity material stock migrates without loss or forced sale")
	_check(not bool(overfull_restored.execute(GameCommand.purchase_material("base:copper", 1)).ok), "new purchases stay blocked while a migrated material remains over capacity")

	var resize_sim := GameSimulation.new(registry)
	resize_sim.new_game("base:first_sparks", 42, "base:outskirts")
	resize_sim.state.cash = 10000.0
	var before_expand := float(resize_sim.state.cash)
	var expand_result := resize_sim.execute(GameCommand.resize_room("room_2", Rect2i(5, 0, 6, 4)))
	_check(bool(expand_result.ok) and is_equal_approx(before_expand - float(resize_sim.state.cash), 112.0), "room expansion charges the normal field price")
	(resize_sim.state.stations[0] as Dictionary).position = [10, 3]
	var before_shrink := float(resize_sim.state.cash)
	var shrink_result := resize_sim.execute(GameCommand.resize_room("room_2", Rect2i(5, 0, 4, 4)))
	_check(bool(shrink_result.ok) and is_equal_approx(before_shrink - float(resize_sim.state.cash), 112.0), "removed room fields charge half price without a refund")
	_check((resize_sim.state.stations[0] as Dictionary).position == [5, 0], "clipped station relocates deterministically inside its room")
	_check(str((resize_sim.state.staff[0] as Dictionary).station_id) == "station_1", "assigned staff follows a relocated station")

	var applicant_id := str(outskirts.state.applicants[0])
	outskirts.state.cash = 10000.0
	var hire_result := outskirts.execute(GameCommand.hire_staff(applicant_id))
	_check(bool(hire_result.ok) and (outskirts.state.staff as Array).size() == 4, "applicant can be hired into the last free residence place")
	var blocked_residence := outskirts.execute(GameCommand.resize_room("room_1", Rect2i(0, 0, 3, 4)))
	_check(not bool(blocked_residence.ok), "residence shrink is blocked when it would remove an occupied staff place")
	var dismiss_result := outskirts.execute(GameCommand.dismiss_staff(applicant_id))
	_check(bool(dismiss_result.ok) and int((outskirts.state.dismissed_until as Dictionary).get(applicant_id, 0)) == outskirts.current_day() + 14, "dismissal applies severance and a fourteen-day cooldown")

	var sources_sim := GameSimulation.new(registry)
	sources_sim.new_game("base:first_sparks", 711, "base:outskirts")
	(sources_sim.state.sources[1] as Dictionary).reserve = 0.0
	for _hour: int in 24:
		sources_sim.tick()
	_check(int((sources_sim.state.inventory["base:spring_water"] as Dictionary).quantity) == 0 and is_equal_approx(float((sources_sim.state.sources[1] as Dictionary).reserve), 3.0), "sources regenerate but are not harvested without storage staff")
	_check(bool(sources_sim.execute(GameCommand.assign_staff("base:torben", "station_3")).ok), "staff can be assigned to a storage station")
	for _hour: int in 24:
		sources_sim.tick()
	_check(int((sources_sim.state.inventory["base:spring_water"] as Dictionary).quantity) == 2, "storage staff harvest every source using logistics")
	var spirit_sim := GameSimulation.new(registry)
	spirit_sim.new_game("base:first_sparks", 711, "base:cemetery")
	spirit_sim.execute(GameCommand.assign_staff("base:torben", "station_3"))
	for _hour: int in 24:
		spirit_sim.tick()
	var spirit_inventory: Dictionary = spirit_sim.state.inventory["base:spirit_essence"]
	_check(int(spirit_inventory.quantity) == 1 and is_equal_approx(float(spirit_inventory.quality), 0.78), "cemetery spirit source applies yield, regeneration, and quality bonuses")

	var v1_save := saved.duplicate(true)
	v1_save.save_version = 1
	v1_save.erase("property_id")
	v1_save.erase("sources")
	v1_save.erase("applicants")
	v1_save.erase("dismissed_until")
	v1_save.erase("next_applicant_refresh_day")
	v1_save.rooms = (v1_save.rooms as Array).filter(func(room: Dictionary) -> bool: return str(room.type) != "base:residence")
	for index: int in (v1_save.staff as Array).size():
		var legacy_entry: Dictionary = v1_save.staff[index]
		var station_id := str(legacy_entry.get("station_id", ""))
		legacy_entry.erase("station_id")
		legacy_entry.assignment = "research" if station_id == "station_1" else ("production" if station_id == "station_2" else "available")
		v1_save.staff[index] = legacy_entry
	var migrated := GameSimulation.new(registry)
	var migration_result := migrated.restore(v1_save)
	_check(bool(migration_result.ok) and str(migrated.state.property_id) == "base:outskirts", "version-one save migrates to the outskirts property: %s" % migration_result)
	_check(migrated.housing_capacity() >= 4 and (migrated.state.sources as Array).size() == 4, "migration adds a free residence and resource sources")
	_check((migrated.state.staff as Array).all(func(entry: Dictionary) -> bool: return entry.has("station_id")), "legacy assignments migrate to concrete stations or available")

	for economy_property: String in ["base:outskirts", "base:cemetery", "base:deep_forest"]:
		var economy_sim := GameSimulation.new(registry)
		economy_sim.new_game("base:first_sparks", 6060, economy_property)
		economy_sim.execute(GameCommand.assign_staff("base:torben", "station_3"))
		var economy_blueprint_id := str(economy_sim.execute(GameCommand.create_blueprint({"name":"Starter Series", "body_id":"base:simple_charm", "effect_id":"base:minor_light", "modifier_ids":[], "material_id":"base:copper"})).blueprint_id)
		economy_sim.execute(GameCommand.configure_production("station_2", economy_blueprint_id))
		economy_sim.execute(GameCommand.set_production_enabled("station_2", true))
		economy_sim.execute(GameCommand.set_price(economy_blueprint_id, 84.0))
		economy_sim.execute(GameCommand.start_research("base:rune_foundations"))
		for _hour: int in 40 * 24:
			economy_sim.tick()
		_check(float(economy_sim.state.cash) > 0.0 and not bool(economy_sim.state.defeat), "%s supports forty days of staffed starter production and foundation research without forced insolvency" % economy_property)

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main_ui := main_scene.instantiate()
	root.add_child(main_ui)
	await process_frame
	main_ui._start_new_game("base:outskirts")
	await process_frame
	_check(main_ui.tab_roots.has("production") and (main_ui.live_production_widgets as Dictionary).size() == 1, "management UI builds one live production card for the starting workbench")
	_check((main_ui.live_research_bars as Dictionary).size() >= 3, "research UI exposes live progress bars")
	var locked_complex_options: Array[Node] = (main_ui.tab_roots["blueprints"] as Node).find_children("*", "OptionButton", true, false).filter(func(option: Node) -> bool: return (option as OptionButton).disabled and str((option as OptionButton).tooltip_text).contains("Komplexe Baupläne"))
	_check(locked_complex_options.size() == 2, "blueprint UI visibly locks both complex recipe slots behind Complex Blueprints research")
	var wage_sliders: Array[Node] = (main_ui.tab_roots["personnel"] as Node).find_children("*", "HSlider", true, false)
	_check(not wage_sliders.is_empty() and is_equal_approx(float((wage_sliders[0] as HSlider).min_value), 80.0) and is_equal_approx(float((wage_sliders[0] as HSlider).max_value), 120.0), "personnel UI exposes the global eighty-to-one-hundred-twenty-percent wage slider")
	(main_ui.simulation.state.unlocked as Dictionary)["base:complex_blueprints"] = true
	(main_ui.simulation.state.unlocked as Dictionary)["base:warding_rune"] = true
	var visible_recipe_result: Dictionary = main_ui.simulation.execute(GameCommand.create_blueprint({"name":"Visible Complex Recipe", "body_id":"base:simple_charm", "effect_id":"base:minor_light", "secondary_effect_id":"base:warding_rune", "modifier_ids":["base:balanced"], "material_id":"base:oak", "secondary_material_id":"base:silver"}))
	main_ui._refresh_all_tabs()
	await process_frame
	var unlocked_blueprint_options: Array[Node] = (main_ui.tab_roots["blueprints"] as Node).find_children("*", "OptionButton", true, false)
	_check(unlocked_blueprint_options.size() == 7 and unlocked_blueprint_options.all(func(option: Node) -> bool: return not (option as OptionButton).disabled), "complex recipe slots become selectable after their research unlock")
	var view_buttons := main_ui.find_children("*", "Button", true, false).filter(func(button: Node) -> bool: return str((button as Button).text) in ["Ansehen", "View"])
	_check(bool(visible_recipe_result.ok) and not view_buttons.is_empty(), "saved complex blueprints provide a view button for their complete composition")
	var recipe_labels: Array[Node] = (main_ui.tab_roots["blueprints"] as Node).find_children("*", "Label", true, false)
	_check(recipe_labels.any(func(label: Node) -> bool: return str((label as Label).text).contains("Zusatzmaterial Silber") and str((label as Label).text).contains("2× Eichenholz + 1× Silber")), "saved recipe details expose the additional material and exact two-to-one mixture")
	main_ui.queue_free()
	await process_frame
	preload("res://tests/test_safety.gd").run(registry, _check)

	if failures == 0:
		print("PASS – all tests succeeded")
	else:
		printerr("FAIL – %d test(s) failed" % failures)
	quit(failures)

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ✓ ", description)
	else:
		failures += 1
		printerr("  ✗ ", description)

func _contains_all_for_test(container: Variant, required: Array) -> bool:
	if not container is Array:
		return false
	for value: Variant in required:
		if not (container as Array).has(value):
			return false
	return true
