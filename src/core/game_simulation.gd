class_name GameSimulation
extends RefCounted

signal event_emitted(event: Dictionary)
signal state_changed()

const SAVE_VERSION := 9
const SaveValidation = preload("res://src/core/save_validation.gd")
const Schema = preload("res://src/core/data_schema.gd")
const HOURS_PER_DAY := 24
const RAMP_HOURS := 12
const RESEARCH_WORK_SCALE := 2.0
const MIN_WAGE_LEVEL := 0.80
const MAX_WAGE_LEVEL := 1.20
const WAGE_LEVEL_STEP := 0.05
const COMPLEX_BLUEPRINT_RESEARCH := "base:complex_blueprints"
const SECONDARY_EFFECT_FACTOR := 0.60
const SECONDARY_MATERIAL_STAT_FACTOR := 0.50
const CONTRACT_MARKET_MIN_SALES := 1
const CONTRACT_MARKET_MIN_REPUTATION := 5.0
const CONTRACT_OFFER_COOLDOWN_DAYS := 7
const STAT_KEYS: PackedStringArray = ["power", "stability", "safety", "prestige"]

var registry: ContentRegistry
var scenario: Dictionary
var property: Dictionary
var state: Dictionary = {}
var rng_quality: DeterministicRng
var rng_market: DeterministicRng
var rng_rivals: DeterministicRng
var rng_staff: DeterministicRng
var rng_contracts: DeterministicRng
var recent_events: Array[Dictionary] = []

func _init(content_registry: ContentRegistry) -> void:
	registry = content_registry

func new_game(scenario_id: String = "base:first_sparks", seed_override: int = 0, property_id: String = "base:outskirts") -> void:
	scenario = registry.get_def("scenarios", scenario_id)
	property = registry.get_def("properties", property_id)
	if property.is_empty():
		property = registry.get_def("properties", "base:outskirts")
		property_id = "base:outskirts"
	var seed := seed_override if seed_override != 0 else int(scenario.get("seed", 1))
	rng_quality = DeterministicRng.new(seed ^ 0x13579)
	rng_market = DeterministicRng.new(seed ^ 0x24680)
	rng_rivals = DeterministicRng.new(seed ^ 0x55aa55)
	rng_staff = DeterministicRng.new(seed ^ 0x71aff)
	rng_contracts = DeterministicRng.new(seed ^ 0xc017ac7)
	state = {
		"save_version": SAVE_VERSION,
		"scenario_id": scenario_id,
		"property_id": property_id,
		"seed": seed,
		"hour": 0,
		"paused": false,
		"speed": 1,
		"cash": float(scenario.get("starting_cash", 6500)),
		"reputation": 5.0,
		"player_profession": "",
		"profession_choice_required": false,
		"faction_reputation": {"base:mages":0.0, "base:witches":0.0, "base:citizens":0.0},
		"lifetime_revenue": 0.0,
		"artifact_revenue": 0.0,
		"raw_material_revenue": 0.0,
		"raw_material_sales_today": {},
		"market_units_sold": 0,
		"revenue_history": [],
		"wage_level": 1.0,
		"pending_wage_level": 1.0,
		"research_cost_today": 0.0,
		"production_cost_today": 0.0,
		"journal": [],
		"logbook": [],
		"inventory": {},
		"unlocked": {},
		"research_progress": {},
		"active_research": "",
		"research_ramp": 0,
		"blueprints": {},
		"next_blueprint": 1,
		"production_lines": {},
		"production_today": {},
		"products": {},
		"listings": {},
		"rooms": [],
		"stations": [],
		"sources": [],
		"next_room": 5,
		"next_station": 4,
		"staff": [],
		"applicants": [],
		"next_applicant_refresh_day": 1,
		"dismissed_until": {},
		"rivals": {},
		"active_contracts": {},
		"available_contracts": {},
		"contract_offer_cooldowns": {},
		"completed_contracts": [],
		"insolvency_since": -1,
		"loan_balance": 0.0,
		"victory": "",
		"defeat": false,
		"market_report": {},
		"active_races": {},
	}
	_initialize_unlocks()
	_initialize_inventory()
	_initialize_workshop()
	_initialize_staff()
	_initialize_sources()
	_refresh_applicants(true)
	_initialize_rivals()
	_add_journal("capital", float(state.cash), "Startkapital")
	_emit("GameStarted", {"scenario_id": scenario_id, "seed": seed})
	state_changed.emit()

func execute(command: GameCommand) -> Dictionary:
	if bool(state.get("defeat", false)) or not str(state.get("victory", "")).is_empty():
		return _result(false, "Die Partie ist beendet.")
	var result: Dictionary
	match command.kind:
		GameCommand.Kind.START_RESEARCH:
			result = _start_research(str(command.payload.get("project_id", "")))
		GameCommand.Kind.PAUSE_RESEARCH:
			result = _pause_research()
		GameCommand.Kind.CREATE_BLUEPRINT:
			result = _create_blueprint(command.payload)
		GameCommand.Kind.CONFIGURE_PRODUCTION:
			result = _configure_production(str(command.payload.get("station_id", "")), str(command.payload.get("blueprint_id", "")))
		GameCommand.Kind.SET_PRODUCTION_ENABLED:
			result = _set_production_enabled(str(command.payload.get("station_id", "")), bool(command.payload.get("enabled", false)))
		GameCommand.Kind.PURCHASE_MATERIAL:
			result = _purchase_material(str(command.payload.get("material_id", "")), int(command.payload.get("quantity", 0)))
		GameCommand.Kind.SELL_MATERIAL:
			result = _sell_material(str(command.payload.get("material_id", "")), int(command.payload.get("quantity", 0)))
		GameCommand.Kind.SET_PRICE:
			result = _set_price(str(command.payload.get("blueprint_id", "")), float(command.payload.get("price", 0)))
		GameCommand.Kind.STOP_SALE:
			result = _stop_sale(str(command.payload.get("blueprint_id", "")))
		GameCommand.Kind.PLACE_ROOM:
			result = _place_room(str(command.payload.get("room_type", "")), command.payload.get("rect", []))
		GameCommand.Kind.RESIZE_ROOM:
			result = _resize_room(str(command.payload.get("room_id", "")), command.payload.get("rect", []))
		GameCommand.Kind.PLACE_STATION:
			result = _place_station(str(command.payload.get("station_type", "")), command.payload.get("position", []))
		GameCommand.Kind.ASSIGN_STAFF:
			result = _assign_staff(str(command.payload.get("staff_id", "")), str(command.payload.get("station_id", "")))
		GameCommand.Kind.HIRE_STAFF:
			result = _hire_staff(str(command.payload.get("staff_id", "")))
		GameCommand.Kind.DISMISS_STAFF:
			result = _dismiss_staff(str(command.payload.get("staff_id", "")))
		GameCommand.Kind.TAKE_LOAN:
			result = _take_loan()
		GameCommand.Kind.ACCEPT_CONTRACT:
			result = _accept_contract(str(command.payload.get("contract_id", "")))
		GameCommand.Kind.SUBMIT_CONTRACT:
			result = _submit_contract(str(command.payload.get("contract_id", "")))
		GameCommand.Kind.CHOOSE_PROFESSION:
			result = _choose_profession(str(command.payload.get("profession_id", "")))
		GameCommand.Kind.SET_WAGE_LEVEL:
			result = _set_wage_level(float(command.payload.get("value", 1.0)))
		_:
			result = _result(false, "Unbekannter Befehl.")
	if bool(result.ok):
		state_changed.emit()
	return result

func tick() -> void:
	if bool(state.paused) or bool(state.defeat) or not str(state.victory).is_empty():
		return
	state.hour = int(state.hour) + 1
	_tick_research()
	_tick_production()
	_tick_rivals()
	_update_races()
	if int(state.hour) % HOURS_PER_DAY == 0:
		_tick_day()
	state_changed.emit()

func set_paused(value: bool) -> void:
	state.paused = value
	state_changed.emit()

func set_speed(value: int) -> void:
	state.speed = clampi(value, 1, 4)
	state.paused = false
	state_changed.emit()

func current_day() -> int:
	return int(state.hour) / HOURS_PER_DAY + 1

func wage_performance_multiplier() -> float:
	return clampf(float(state.get("wage_level", 1.0)), MIN_WAGE_LEVEL, MAX_WAGE_LEVEL)

func base_daily_wages() -> float:
	var wages := 0.0
	for staff_entry: Variant in state.staff:
		wages += float(registry.get_def("staff", str((staff_entry as Dictionary).id)).get("salary", 0.0))
	return wages

func daily_wages(level: float = -1.0) -> float:
	var applied_level := wage_performance_multiplier() if level < 0.0 else clampf(level, MIN_WAGE_LEVEL, MAX_WAGE_LEVEL)
	return snappedf(base_daily_wages() * applied_level, 0.01)

func active_research_daily_cost() -> float:
	var project_id := str(state.get("active_research", ""))
	if project_id.is_empty() or research_rate(project_id, false) <= 0.0:
		return 0.0
	return float(registry.get_def("research", project_id).get("hourly_cost", 0.0)) * HOURS_PER_DAY

func expected_daily_operating_result() -> float:
	var last_revenue := float((state.get("market_report", {}) as Dictionary).get("daily_revenue", 0.0))
	var interest := float(state.get("loan_balance", 0.0)) * 0.001
	return last_revenue - daily_wages() - active_research_daily_cost() - interest - float((state.get("market_report", {}) as Dictionary).get("production_cost", 0.0))

func contract_days_remaining(contract: Dictionary) -> int:
	return maxi(0, int(contract.get("deadline_day", current_day())) - current_day())

func contract_delivery_status(contract: Dictionary) -> Dictionary:
	var required := int(contract.get("quantity", 0))
	var available := 0
	for blueprint_id: Variant in (state.products as Dictionary).keys():
		var product: Dictionary = (state.products as Dictionary)[blueprint_id]
		var blueprint: Dictionary = (state.blueprints as Dictionary).get(blueprint_id, {})
		if not _product_matches_contract(blueprint, product, contract):
			continue
		available += int(product.get("quantity", 0))
	return {"ready":available >= required, "available":available, "required":required}

func contract_product_status(blueprint_id: String, contract: Dictionary) -> Dictionary:
	var blueprint: Dictionary = (state.blueprints as Dictionary).get(blueprint_id, {})
	var product: Dictionary = (state.products as Dictionary).get(blueprint_id, {"quantity":0, "average_quality":0.0})
	if blueprint.is_empty():
		return {"matches":false, "reason":"unknown_blueprint", "quantity":0}
	var computed: Dictionary = blueprint.get("computed", {})
	var class_match := _arrays_overlap(computed.get("goods_classes", []), contract.get("accepted_classes", []))
	var coverage_match := _contains_all(computed.get("profession_coverage", []), contract.get("required_coverage", []))
	var quality_match := float(product.get("average_quality", 0.0)) >= float(contract.get("min_quality", 0.0))
	return {"matches":class_match and coverage_match and quality_match, "class_match":class_match, "coverage_match":coverage_match, "quality_match":quality_match, "quantity":int(product.get("quantity", 0)), "quality":float(product.get("average_quality", 0.0))}

func available_goods_classes(profession_id: String = "") -> Array[String]:
	if profession_id.is_empty():
		profession_id = str(state.get("player_profession", ""))
	var result: Array[String] = []
	if profession_id.is_empty():
		return result
	var has_profession_effect := false
	for effect: Dictionary in unlocked_content("effects"):
		if _effect_profession_coverage(effect).has(profession_id):
			has_profession_effect = true
			_add_string_values(result, effect.get("goods_classes", []))
	if not has_profession_effect:
		return result
	for category: String in ["bodies", "modifiers"]:
		for component: Dictionary in unlocked_content(category):
			_add_string_values(result, component.get("goods_classes", []))
	for material: Dictionary in registry.all("materials"):
		_add_string_values(result, material.get("goods_classes", []))
	var matching: Array[String] = []
	for class_id: String in result:
		if str(registry.get_def("goods_classes", class_id).get("profession", "")) == profession_id:
			matching.append(class_id)
	return matching

func available_research() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for project: Dictionary in registry.all("research"):
		if bool((state.unlocked as Dictionary).get(str(project.id), false)):
			continue
		if _research_prerequisites_met(project):
			result.append(project)
	return result

func visible_research() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for project: Dictionary in registry.all("research"):
		if bool((state.unlocked as Dictionary).get(str(project.id), false)):
			result.append(project)
			continue
		if _research_prerequisites_met(project):
			result.append(project)
	return result

func complex_blueprints_unlocked() -> bool:
	return bool((state.unlocked as Dictionary).get(COMPLEX_BLUEPRINT_RESEARCH, false))

func effect_combination_status(primary_effect_id: String, secondary_effect_id: String) -> Dictionary:
	var primary := registry.get_def("effects", primary_effect_id)
	var coverage: Array[String] = _effect_profession_coverage(primary)
	if secondary_effect_id.is_empty():
		return {"ok":true, "message":"", "coverage":coverage, "required_research":""}
	var secondary := registry.get_def("effects", secondary_effect_id)
	if primary.is_empty() or secondary.is_empty():
		return {"ok":false, "message":"Unbekannte Effektkombination.", "coverage":coverage, "required_research":""}
	_add_string_values(coverage, _effect_profession_coverage(secondary))
	if coverage.size() <= 1:
		return {"ok":true, "message":"", "coverage":coverage, "required_research":""}
	var required_research := ""
	if coverage.size() >= 3:
		required_research = "base:convergent_mastery"
	elif coverage.has("base:arcane") and coverage.has("base:witchcraft"):
		required_research = "base:crystal_hex"
	elif coverage.has("base:arcane") and coverage.has("base:runes"):
		required_research = "base:runic_manufactory"
	elif coverage.has("base:witchcraft") and coverage.has("base:runes"):
		required_research = "base:bound_covenant"
	if required_research.is_empty() or not bool((state.unlocked as Dictionary).get(required_research, false)):
		var research_name := str(registry.get_def("research", required_research).get("name_de", required_research))
		return {"ok":false, "message":"Diese Effektmischung benötigt die Forschung %s." % research_name, "coverage":coverage, "required_research":required_research}
	return {"ok":true, "message":"", "coverage":coverage, "required_research":required_research}

func unlocked_content(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition: Dictionary in registry.all(category):
		if bool(definition.get("unlocked", false)) or bool((state.unlocked as Dictionary).get(str(definition.id), false)):
			result.append(definition)
	return result

func preview_blueprint(data: Dictionary) -> Dictionary:
	var body := registry.get_def("bodies", str(data.get("body_id", "")))
	var effect := registry.get_def("effects", str(data.get("effect_id", "")))
	var material := registry.get_def("materials", str(data.get("material_id", "")))
	if body.is_empty() or effect.is_empty() or material.is_empty():
		return {"valid": false, "message": "Grundkörper, Effekt und Material werden benötigt."}
	for definition: Dictionary in [body, effect]:
		if not _is_content_unlocked(definition):
			return {"valid": false, "message": "Nicht erforschter Bestandteil: %s" % definition.id}
	var secondary_effect_id := str(data.get("secondary_effect_id", ""))
	var secondary_material_id := str(data.get("secondary_material_id", ""))
	var secondary_effect := registry.get_def("effects", secondary_effect_id)
	var secondary_material := registry.get_def("materials", secondary_material_id)
	if (not secondary_effect_id.is_empty() or not secondary_material_id.is_empty()) and not complex_blueprints_unlocked():
		return {"valid":false, "message":"Sekundäreffekt und Zusatzmaterial benötigen die Forschung Komplexe Baupläne."}
	if not secondary_effect_id.is_empty():
		if secondary_effect.is_empty() or not _is_content_unlocked(secondary_effect):
			return {"valid":false, "message":"Ungültiger oder gesperrter Sekundäreffekt."}
		if secondary_effect_id == str(effect.id):
			return {"valid":false, "message":"Primär- und Sekundäreffekt müssen verschieden sein."}
	if not secondary_material_id.is_empty():
		if secondary_material.is_empty():
			return {"valid":false, "message":"Unbekanntes Zusatzmaterial."}
		if secondary_material_id == str(material.id):
			return {"valid":false, "message":"Haupt- und Zusatzmaterial müssen verschieden sein."}
	var combination := effect_combination_status(str(effect.id), secondary_effect_id)
	if not bool(combination.ok):
		return {"valid":false, "message":str(combination.message)}
	var modifiers: Array = data.get("modifier_ids", [])
	if modifiers.size() > 2:
		return {"valid": false, "message": "Höchstens zwei Modifikatoren sind erlaubt."}
	var unique_modifiers: Dictionary = {}
	for modifier_id: Variant in modifiers:
		if unique_modifiers.has(str(modifier_id)):
			return {"valid":false, "message":"Ein Modifikator kann nicht doppelt verwendet werden."}
		unique_modifiers[str(modifier_id)] = true
	var stats := {"power": 0.0, "stability": 0.0, "safety": 0.0, "prestige": 0.0}
	var cost := float(body.get("base_cost", 0)) + float(effect.get("base_cost", 0))
	var material_cost := material_buy_price(str(material.id)) * 2.0
	var hours := float(body.get("base_hours", 8)) + float(effect.get("difficulty", 1))
	var difficulty := float(effect.get("difficulty", 1))
	var quality_delta := 0.0
	var tags: Array = []
	var goods_classes: Array[String] = []
	for definition: Dictionary in [body, effect, material]:
		_add_stats(stats, definition.get("stats", {}))
		_add_tags(tags, definition.get("tags", []))
		_add_string_values(goods_classes, definition.get("goods_classes", []))
		hours *= float(definition.get("hours_multiplier", 1.0))
	if not secondary_effect.is_empty():
		_add_scaled_stats(stats, secondary_effect.get("stats", {}), SECONDARY_EFFECT_FACTOR)
		_add_tags(tags, secondary_effect.get("tags", []))
		_add_string_values(goods_classes, secondary_effect.get("goods_classes", []))
		cost += float(secondary_effect.get("base_cost", 0.0)) * SECONDARY_EFFECT_FACTOR
		var secondary_difficulty := float(secondary_effect.get("difficulty", 0.0)) * SECONDARY_EFFECT_FACTOR
		difficulty += secondary_difficulty
		hours += secondary_difficulty
		hours *= _scaled_multiplier(float(secondary_effect.get("hours_multiplier", 1.0)), SECONDARY_EFFECT_FACTOR)
	if not secondary_material.is_empty():
		_add_scaled_stats(stats, secondary_material.get("stats", {}), SECONDARY_MATERIAL_STAT_FACTOR)
		_add_tags(tags, secondary_material.get("tags", []))
		_add_string_values(goods_classes, secondary_material.get("goods_classes", []))
		material_cost += material_buy_price(str(secondary_material.id))
		hours *= _scaled_multiplier(float(secondary_material.get("hours_multiplier", 1.0)), SECONDARY_MATERIAL_STAT_FACTOR)
	var modifier_breakdown: Array[Dictionary] = []
	for modifier_id: Variant in modifiers:
		var modifier := registry.get_def("modifiers", str(modifier_id))
		if modifier.is_empty() or not _is_content_unlocked(modifier):
			return {"valid": false, "message": "Ungültiger oder gesperrter Modifikator."}
		_add_stats(stats, modifier.get("stats", {}))
		_add_tags(tags, modifier.get("tags", []))
		_add_string_values(goods_classes, modifier.get("goods_classes", []))
		cost += float(modifier.get("base_cost", 0))
		hours *= float(modifier.get("hours_multiplier", 1.0))
		quality_delta += float(modifier.get("quality_delta", 0.0))
		modifier_breakdown.append({"id":str(modifier.id), "stats":modifier.get("stats", {}).duplicate(true), "cost_delta":float(modifier.get("base_cost", 0.0)), "hours_multiplier":float(modifier.get("hours_multiplier", 1.0)), "quality_delta":float(modifier.get("quality_delta", 0.0))})
	for key: String in STAT_KEYS:
		stats[key] = maxf(0.0, float(stats[key]))
	var material_quality := float(material.get("quality", 0.5))
	var material_requirements: Array[Dictionary] = [{"material_id":str(material.id), "quantity":2, "quality_weight":2.0}]
	if not secondary_material.is_empty():
		material_quality = (material_quality * 2.0 + float(secondary_material.get("quality", 0.5))) / 3.0
		material_requirements.append({"material_id":str(secondary_material.id), "quantity":1, "quality_weight":1.0})
	return {
		"valid": true,
		"stats": stats,
		"processing_cost": maxf(0.0, snappedf(cost, 0.01)),
		"material_cost": snappedf(material_cost, 0.01),
		"unit_cost": snappedf(maxf(0.0, snappedf(cost, 0.01)) + material_cost, 0.01),
		"hours": maxf(2.0, snappedf(hours, 0.1)),
		"difficulty": difficulty,
		"quality_delta":quality_delta,
		"tags": tags,
		"goods_classes": goods_classes,
		"profession_coverage": combination.coverage,
		"material_id": material.id,
		"material_per_unit": 2,
		"secondary_effect_id":secondary_effect_id,
		"secondary_material_id":secondary_material_id,
		"material_requirements":material_requirements,
		"material_quality_estimate":material_quality,
		"component_breakdown":{"modifiers":modifier_breakdown},
		"quality_estimate": _quality_estimate(difficulty, material_quality, 1.0, quality_delta),
	}

func serialize() -> Dictionary:
	var output := state.duplicate(true)
	output["rng"] = {"quality": rng_quality.state, "market": rng_market.state, "rivals": rng_rivals.state, "staff": rng_staff.state, "contracts":rng_contracts.state}
	output["packages"] = registry.package_snapshot()
	return output

func restore(data: Dictionary) -> Dictionary:
	var version_error := Schema.check(data.get("save_version"), "integer", "save_version")
	if not version_error.is_empty():
		return _result(false, version_error, {"code":"corrupt"})
	var saved_version := int(data.get("save_version", -1))
	if saved_version < 1 or saved_version > SAVE_VERSION:
		return _result(false, "Nicht unterstützte Spielstandsversion.", {"code":"incompatible_version"})
	var shape_error := SaveValidation.shape(data, saved_version)
	if not shape_error.is_empty():
		return _result(false, shape_error, {"code":"corrupt"})
	var saved_packages: Array = data.get("packages", [])
	if JSON.stringify(saved_packages) != JSON.stringify(registry.package_snapshot()):
		return _result(false, "Die aktive Modliste stimmt nicht mit dem Spielstand überein.", {"code":"incompatible_packages"})
	var reference_error := SaveValidation.references(data, registry, saved_version)
	if not reference_error.is_empty():
		return _result(false, reference_error, {"code":"corrupt"})
	var candidate := GameSimulation.new(registry)
	candidate._restore_candidate(data, saved_version)
	var migrated := candidate.serialize()
	shape_error = SaveValidation.shape(migrated, SAVE_VERSION)
	if shape_error.is_empty():
		shape_error = SaveValidation.references(migrated, registry, SAVE_VERSION)
	if not shape_error.is_empty():
		return _result(false, shape_error, {"code":"corrupt"})
	for id: String in candidate.state.blueprints:
		var preview := candidate.preview_blueprint(candidate.state.blueprints[id])
		if not bool(preview.get("valid", false)):
			return _result(false, "blueprints.%s: %s" % [id, preview.get("message", "Ungültiger Bauplan.")], {"code":"corrupt"})
	state = candidate.state
	scenario = candidate.scenario
	property = candidate.property
	rng_quality = candidate.rng_quality
	rng_market = candidate.rng_market
	rng_rivals = candidate.rng_rivals
	rng_staff = candidate.rng_staff
	rng_contracts = candidate.rng_contracts
	recent_events.clear()
	state_changed.emit()
	return _result(true, "Spielstand geladen.", {"code":"ok"})

func _restore_candidate(data: Dictionary, saved_version: int) -> void:
	var scenario_id := str(data.get("scenario_id", ""))
	scenario = registry.get_def("scenarios", scenario_id)
	state = data.duplicate(true)
	state.erase("rng")
	state.erase("packages")
	if saved_version == 1:
		state["property_id"] = "base:outskirts"
	state.save_version = SAVE_VERSION
	property = registry.get_def("properties", str(state.get("property_id", "base:outskirts")))
	if property.is_empty():
		property = registry.get_def("properties", "base:outskirts")
		state.property_id = "base:outskirts"
	_reconcile_unlocks()
	var rng_data: Dictionary = data.get("rng", {})
	rng_quality = DeterministicRng.new(int(rng_data.get("quality", 1)))
	rng_market = DeterministicRng.new(int(rng_data.get("market", 2)))
	rng_rivals = DeterministicRng.new(int(rng_data.get("rivals", 3)))
	rng_staff = DeterministicRng.new(int(rng_data.get("staff", int(state.get("seed", 1)) ^ 0x71aff)))
	rng_contracts = DeterministicRng.new(int(rng_data.get("contracts", int(state.get("seed", 1)) ^ 0xc017ac7)))
	# Zero is a valid state reached by the generator, though not a valid new-game seed.
	for stream: String in rng_data:
		var generator: DeterministicRng = {"quality":rng_quality, "market":rng_market, "rivals":rng_rivals, "staff":rng_staff, "contracts":rng_contracts}.get(stream)
		if generator != null:
			generator.state = int(rng_data[stream])
	if saved_version == 1:
		_migrate_v1_state()
	else:
		state["sources"] = state.get("sources", [])
		state["applicants"] = state.get("applicants", [])
		state["dismissed_until"] = state.get("dismissed_until", {})
		state["next_applicant_refresh_day"] = int(state.get("next_applicant_refresh_day", current_day() + 7))
		state["next_room"] = int(state.get("next_room", _next_runtime_id(state.rooms, "room_")))
		state["next_station"] = int(state.get("next_station", _next_runtime_id(state.stations, "station_")))
	_migrate_production_lines(saved_version)
	_migrate_professions_and_classes(saved_version)
	_migrate_complex_blueprints(saved_version)
	_migrate_contract_market(saved_version)
	_migrate_material_trade()
	_migrate_wage_level()
	state["logbook"] = state.get("logbook", [])

func _initialize_unlocks() -> void:
	for category: String in ["bodies", "effects", "modifiers", "stations"]:
		for definition: Dictionary in registry.all(category):
			if bool(definition.get("unlocked", false)):
				(state.unlocked as Dictionary)[str(definition.id)] = true

func _reconcile_unlocks() -> void:
	_initialize_unlocks()
	for project: Dictionary in registry.all("research"):
		if not bool((state.unlocked as Dictionary).get(str(project.id), false)):
			continue
		for unlock: Variant in project.get("unlocks", []):
			(state.unlocked as Dictionary)[str(unlock)] = true

func _initialize_inventory() -> void:
	var source_materials: PackedStringArray = ["base:spring_water", "base:wild_herbs", "base:spirit_essence"]
	for material: Dictionary in registry.all("materials"):
		var quantity := 0 if source_materials.has(str(material.id)) else 12
		(state.inventory as Dictionary)[str(material.id)] = {"quantity": quantity, "quality": float(material.get("quality", 0.5))}

func _initialize_workshop() -> void:
	state.rooms = (property.get("start_rooms", []) as Array).duplicate(true)
	state.stations = (property.get("start_stations", []) as Array).duplicate(true)

func _initialize_staff() -> void:
	var starters: PackedStringArray = ["base:elara", "base:torben", "base:selin"]
	var station_ids: PackedStringArray = ["station_1", "", "station_2"]
	for index: int in starters.size():
		state.staff.append({"id": starters[index], "station_id": station_ids[index]})

func _initialize_sources() -> void:
	state.sources = []
	var index := 1
	for source_value: Variant in property.get("sources", []):
		var source: Dictionary = (source_value as Dictionary).duplicate(true)
		var definition := registry.get_def("resource_sources", str(source.type))
		source["id"] = "source_%d" % index
		source["reserve"] = float(definition.get("max_reserve", 0))
		source["offsite"] = false
		state.sources.append(source)
		index += 1

func grid_size() -> Vector2i:
	var data: Array = property.get("grid_size", [20, 12])
	return Vector2i(int(data[0]), int(data[1]))

func housing_capacity(rooms_override: Array = []) -> int:
	var rooms_to_count: Array = state.rooms if rooms_override.is_empty() else rooms_override
	var tiles := 0
	for room_value: Variant in rooms_to_count:
		var room: Dictionary = room_value
		var definition := registry.get_def("rooms", str(room.type))
		if bool(definition.get("housing", false)):
			tiles += _array_to_rect(room.rect).get_area()
	return tiles / 4

func material_capacity() -> int:
	var capacity := 0
	for station_value: Variant in state.stations:
		var station: Dictionary = station_value
		var definition := registry.get_def("stations", str(station.get("type", "")))
		if str(definition.get("kind", "")) == "storage":
			capacity += int(definition.get("capacity", 0))
	return capacity

func material_free_capacity(material_id: String) -> int:
	var stock: Dictionary = (state.inventory as Dictionary).get(material_id, {"quantity":0})
	return maxi(0, material_capacity() - int(stock.get("quantity", 0)))

func material_buy_price(material_id: String) -> float:
	var material := registry.get_def("materials", material_id)
	if material.is_empty():
		return 0.0
	return float(material.get("price", 0.0)) * _material_event_multiplier(material_id) * float(property.get("procurement_multiplier", 1.0))

func material_sell_price(material_id: String, quality: float = -1.0) -> float:
	var material := registry.get_def("materials", material_id)
	if material.is_empty():
		return 0.0
	var base_quality := maxf(0.0001, float(material.get("quality", 0.5)))
	if quality < 0.0:
		quality = float(((state.inventory as Dictionary).get(material_id, {"quality":base_quality}) as Dictionary).get("quality", base_quality))
	var quality_factor := clampf(quality / base_quality, 0.5, 1.5)
	return float(material.get("price", 0.0)) * _material_event_multiplier(material_id) * float(property.get("market_multiplier", 1.0)) * 0.75 * quality_factor

func active_material_price_events(material_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var material := registry.get_def("materials", material_id)
	if material.is_empty():
		return result
	var tags: Array = material.get("tags", [])
	var day := current_day()
	for event: Dictionary in registry.all("events"):
		var start := int(event.get("start_day", 99999))
		var duration := int(event.get("duration_days", 0))
		if day < start or day >= start + duration or not event.has("price_multiplier"):
			continue
		var explicit_material := str(event.get("material", ""))
		var material_tag := str(event.get("material_tag", ""))
		if (not explicit_material.is_empty() and explicit_material == material_id) or (not material_tag.is_empty() and tags.has(material_tag)):
			var active := event.duplicate(true)
			active["remaining_days"] = start + duration - day
			result.append(active)
	return result

func _initialize_rivals() -> void:
	for rival: Dictionary in registry.all("rivals"):
		var first_project := _first_project_for(str(rival.focus), 1)
		(state.rivals as Dictionary)[str(rival.id)] = {
			"cash": float(rival.get("starting_cash", 5000)),
			"reputation": 8.0,
			"research_progress": {},
			"unlocked": {},
			"active_research": first_project,
			"market_share": 0.18,
			"last_action": "Forschung begonnen",
		}

func _start_research(project_id: String) -> Dictionary:
	var project := registry.get_def("research", project_id)
	if project.is_empty():
		return _result(false, "Unbekanntes Forschungsprojekt.")
	if bool((state.unlocked as Dictionary).get(project_id, false)):
		return _result(false, "Diese Forschung ist bereits abgeschlossen.")
	if not _research_prerequisites_met(project):
		return _result(false, "Voraussetzungen sind noch nicht erfüllt.")
	var changed := str(state.active_research) != project_id
	state.active_research = project_id
	if changed:
		state.research_ramp = RAMP_HOURS
	_emit("ResearchStarted", {"project_id": project_id})
	return _result(true, "Forschung gestartet.")

func _pause_research() -> Dictionary:
	if str(state.active_research).is_empty():
		return _result(false, "Keine aktive Forschung.")
	state.active_research = ""
	state.research_ramp = 0
	return _result(true, "Forschung pausiert; Fortschritt bleibt erhalten.")

func _tick_research() -> void:
	var project_id := str(state.active_research)
	if project_id.is_empty():
		return
	var project := registry.get_def("research", project_id)
	if project.is_empty():
		return
	var capacity := research_rate(project_id, false)
	if capacity <= 0.0:
		return
	var hourly_cost := float(project.get("hourly_cost", 0))
	state.cash = float(state.cash) - hourly_cost
	state.research_cost_today = float(state.get("research_cost_today", 0.0)) + hourly_cost
	_add_journal("research", -hourly_cost, str(project.get("name_de", project_id)), false)
	if int(state.research_ramp) > 0:
		capacity *= 0.55
		state.research_ramp = int(state.research_ramp) - 1
	var progress: Dictionary = state.research_progress
	progress[project_id] = float(progress.get(project_id, 0.0)) + capacity
	if float(progress[project_id]) >= float(project.get("cost_hours", 1)):
		_complete_research(project)

func _complete_research(project: Dictionary) -> void:
	var project_id := str(project.id)
	(state.unlocked as Dictionary)[project_id] = true
	for unlock: Variant in project.get("unlocks", []):
		(state.unlocked as Dictionary)[str(unlock)] = true
	state.active_research = ""
	state.reputation = float(state.reputation) + 3.0 + float(project.get("tier", 1))
	_emit("ResearchCompleted", {"project_id": project_id, "tier": project.get("tier", 1), "hybrid": project.get("hybrid", false)})
	var profession := _foundation_profession(project)
	if str(state.get("player_profession", "")).is_empty() and not profession.is_empty():
		state.player_profession = profession
		state.profession_choice_required = false
		_emit("ProfessionChosen", {"profession_id":profession})

func _choose_profession(profession_id: String) -> Dictionary:
	if not bool(state.get("profession_choice_required", false)) or not str(state.get("player_profession", "")).is_empty():
		return _result(false, "Die Werkstattprofession ist bereits festgelegt.")
	if not _completed_foundation_professions().has(profession_id):
		return _result(false, "Diese Profession steht im alten Spielstand nicht zur Auswahl.")
	state.player_profession = profession_id
	state.profession_choice_required = false
	_emit("ProfessionChosen", {"profession_id":profession_id})
	return _result(true, "Werkstattprofession festgelegt.")

func _set_wage_level(value: float) -> Dictionary:
	if value < MIN_WAGE_LEVEL - 0.0001 or value > MAX_WAGE_LEVEL + 0.0001:
		return _result(false, "Das Lohnniveau muss zwischen 80 % und 120 % liegen.")
	var steps := roundi((value - MIN_WAGE_LEVEL) / WAGE_LEVEL_STEP)
	var normalized := snappedf(MIN_WAGE_LEVEL + steps * WAGE_LEVEL_STEP, 0.01)
	if not is_equal_approx(value, normalized):
		return _result(false, "Das Lohnniveau kann nur in Schritten von 5 % geändert werden.")
	state.pending_wage_level = normalized
	return _result(true, "Lohnniveau von %d %% für den nächsten Spieltag vorgemerkt." % roundi(normalized * 100.0))

func research_rate(project_id: String = "", include_ramp: bool = true) -> float:
	if project_id.is_empty():
		project_id = str(state.active_research)
	var project := registry.get_def("research", project_id)
	if project.is_empty():
		return 0.0
	var discipline_id := str(project.get("discipline", ""))
	var capacity := 0.0
	for staff_entry: Variant in state.staff:
		var staff_def := registry.get_def("staff", str((staff_entry as Dictionary).id))
		if _staff_station_kind(staff_entry as Dictionary) == "research":
			var station := _station_by_id(str((staff_entry as Dictionary).get("station_id", "")))
			var station_def := registry.get_def("stations", str(station.get("type", "")))
			var contribution := float(staff_def.get("research", 0.0)) * float(station_def.get("capacity", 1.0)) * RESEARCH_WORK_SCALE
			if not bool(project.get("general", false)) and str(staff_def.get("specialty", "")) == discipline_id:
				contribution *= 1.2
			capacity += contribution
	var multipliers: Dictionary = property.get("research_multipliers", {})
	if not bool(project.get("general", false)):
		capacity *= float(multipliers.get(discipline_id, 1.0))
	capacity *= wage_performance_multiplier()
	if include_ramp and int(state.research_ramp) > 0:
		capacity *= 0.55
	return capacity

func research_hours_remaining(project_id: String) -> int:
	var project := registry.get_def("research", project_id)
	var normal_rate := research_rate(project_id, false)
	if project.is_empty() or normal_rate <= 0.0:
		return -1
	var remaining := maxf(0.0, float(project.get("cost_hours", 0)) - float((state.research_progress as Dictionary).get(project_id, 0.0)))
	var ramp_ticks := int(state.research_ramp) if project_id == str(state.active_research) else 0
	var ramp_rate := normal_rate * 0.55
	var ramp_work := ramp_rate * ramp_ticks
	if remaining <= ramp_work:
		return int(ceil(remaining / ramp_rate))
	return ramp_ticks + int(ceil((remaining - ramp_work) / normal_rate))

func _create_blueprint(data: Dictionary) -> Dictionary:
	var preview := preview_blueprint(data)
	if not bool(preview.get("valid", false)):
		return _result(false, str(preview.get("message", "Ungültiger Bauplan.")))
	var blueprint_id := "player:blueprint_%d" % int(state.next_blueprint)
	state.next_blueprint = int(state.next_blueprint) + 1
	var blueprint := data.duplicate(true)
	blueprint["id"] = blueprint_id
	blueprint["name"] = str(data.get("name", "Artefakt %d" % int(state.next_blueprint)))
	blueprint["computed"] = preview
	(state.blueprints as Dictionary)[blueprint_id] = blueprint
	_emit("BlueprintCreated", {"blueprint_id": blueprint_id})
	return _result(true, "Bauplan erstellt.", {"blueprint_id": blueprint_id})

func production_stations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for station_value: Variant in state.stations:
		var station: Dictionary = station_value
		if str(registry.get_def("stations", str(station.type)).get("kind", "")) == "production":
			result.append(station)
	return result

func production_line_status(station_id: String) -> Dictionary:
	var station := _station_by_id(station_id)
	if station.is_empty() or str(registry.get_def("stations", str(station.type)).get("kind", "")) != "production":
		return {"status":"invalid", "rate":0.0, "eta_hours":-1}
	var line: Dictionary = (state.production_lines as Dictionary).get(station_id, {})
	var blueprint_id := str(line.get("blueprint_id", ""))
	var worker := _staff_for_station(station_id)
	var rate := _production_work_rate(station, worker)
	var result := {
		"status":"unconfigured", "rate":rate, "eta_hours":-1,
		"progress":float(line.get("progress", 0.0)), "required":0.0,
		"worker_id":str(worker.get("id", "")), "produced_today":_production_today_for_station(station_id),
	}
	if blueprint_id.is_empty() or not (state.blueprints as Dictionary).has(blueprint_id):
		return result
	var blueprint: Dictionary = (state.blueprints as Dictionary)[blueprint_id]
	var required := float((blueprint.computed as Dictionary).hours)
	result.required = required
	if not bool(line.get("enabled", false)):
		result.status = "paused"
	elif worker.is_empty():
		result.status = "no_worker"
	elif not bool(line.get("material_reserved", false)) and not _can_supply_unit(blueprint):
		var supply := _unit_supply_status(blueprint)
		result.status = str(supply.status)
		result["missing_materials"] = supply.missing_materials
	else:
		result.status = "producing"
	if rate > 0.0:
		result.eta_hours = int(ceil(maxf(0.0, required - float(line.get("progress", 0.0))) / rate))
	return result

func _configure_production(station_id: String, blueprint_id: String) -> Dictionary:
	var station := _station_by_id(station_id)
	if station.is_empty() or str(registry.get_def("stations", str(station.type)).get("kind", "")) != "production":
		return _result(false, "Ungültige Produktionsstation.")
	if not (state.blueprints as Dictionary).has(blueprint_id):
		return _result(false, "Unbekannter Bauplan.")
	var lines: Dictionary = state.production_lines
	var line: Dictionary = lines.get(station_id, {})
	if bool(line.get("enabled", false)):
		return _result(false, "Werkbank vor dem Produktwechsel pausieren.")
	if str(line.get("blueprint_id", "")) != blueprint_id:
		_refund_line_material(line)
		line = _new_production_line(blueprint_id)
	lines[station_id] = line
	return _result(true, "Produktionslinie eingerichtet.")

func _set_production_enabled(station_id: String, enabled: bool) -> Dictionary:
	var line: Dictionary = (state.production_lines as Dictionary).get(station_id, {})
	if line.is_empty() or str(line.get("blueprint_id", "")).is_empty():
		return _result(false, "Zuerst einen Bauplan für diese Werkbank wählen.")
	line.enabled = enabled
	(state.production_lines as Dictionary)[station_id] = line
	return _result(true, "Produktion gestartet." if enabled else "Produktion pausiert.")

func _purchase_material(material_id: String, quantity: int) -> Dictionary:
	var material := registry.get_def("materials", material_id)
	if material.is_empty() or quantity <= 0:
		return _result(false, "Ungültiger Materialkauf.")
	if quantity > material_free_capacity(material_id):
		return _result(false, "Nicht genug Lagerplatz für diesen Materialkauf.")
	var cost := _material_purchase_cost(material_id, quantity)
	if float(state.cash) < cost:
		return _result(false, "Nicht genug Gold für den Materialkauf.")
	state.cash = float(state.cash) - cost
	_add_inventory(material_id, quantity, float(material.get("quality", 0.5)))
	_add_journal("procurement", -cost, "Materialkauf: %s" % material.get("name_de", material_id))
	return _result(true, "%d Einheiten Material gekauft." % quantity)

func _sell_material(material_id: String, quantity: int) -> Dictionary:
	var material := registry.get_def("materials", material_id)
	var stock: Dictionary = (state.inventory as Dictionary).get(material_id, {})
	if material.is_empty() or quantity <= 0:
		return _result(false, "Ungültiger Materialverkauf.")
	if int(stock.get("quantity", 0)) < quantity:
		return _result(false, "Nicht genug Material für diesen Verkauf.")
	var quality := float(stock.get("quality", material.get("quality", 0.5)))
	var revenue := snappedf(material_sell_price(material_id, quality) * quantity, 0.01)
	stock.quantity = int(stock.quantity) - quantity
	(state.inventory as Dictionary)[material_id] = stock
	_record_material_sale(material_id, quantity, quality, revenue, false)
	_add_journal("raw_material_sale", revenue, "Rohstoffverkauf: %s" % material.get("name_de", material_id))
	return _result(true, "%d Einheiten %s für %.2f G verkauft." % [quantity, material.get("name_de", material_id), revenue])

func _tick_production() -> void:
	for station: Dictionary in production_stations():
		var station_id := str(station.id)
		var line: Dictionary = (state.production_lines as Dictionary).get(station_id, {})
		if line.is_empty() or not bool(line.get("enabled", false)):
			continue
		var blueprint_id := str(line.get("blueprint_id", ""))
		var blueprint: Dictionary = (state.blueprints as Dictionary).get(blueprint_id, {})
		var worker := _staff_for_station(station_id)
		if blueprint.is_empty() or worker.is_empty():
			continue
		var work_budget := _production_work_rate(station, worker)
		var required := float((blueprint.computed as Dictionary).hours)
		while work_budget > 0.0001:
			if not bool(line.get("material_reserved", false)) and not _reserve_unit_material(line, blueprint):
				break
			var applied := minf(work_budget, required - float(line.get("progress", 0.0)))
			line.progress = float(line.get("progress", 0.0)) + applied
			line.quality_work = float(line.get("quality_work", 0.0)) + float(worker.get("production_quality", worker.get("craft", 1.0))) * wage_performance_multiplier() * applied
			work_budget -= applied
			if float(line.progress) + 0.0001 < required:
				break
			_complete_production_unit(station_id, line, blueprint, required)
		(state.production_lines as Dictionary)[station_id] = line

func _complete_production_unit(station_id: String, line: Dictionary, blueprint: Dictionary, required: float) -> void:
	var worker_quality := float(line.get("quality_work", required)) / maxf(0.0001, required)
	var quality := _roll_quality(float((blueprint.computed as Dictionary).difficulty), float(line.get("material_quality", 0.5)), worker_quality, float((blueprint.computed as Dictionary).get("quality_delta", 0.0)))
	var products: Dictionary = state.products
	var blueprint_id := str(blueprint.id)
	var current: Dictionary = products.get(blueprint_id, {"quantity":0, "average_quality":0.0, "unit_cost":float((blueprint.computed as Dictionary).unit_cost)})
	var old_quantity := int(current.quantity)
	current.average_quality = (float(current.average_quality) * old_quantity + quality) / float(old_quantity + 1)
	current.quantity = old_quantity + 1
	products[blueprint_id] = current
	var station_today: Dictionary = (state.production_today as Dictionary).get(station_id, {})
	station_today[blueprint_id] = int(station_today.get(blueprint_id, 0)) + 1
	(state.production_today as Dictionary)[station_id] = station_today
	line.progress = 0.0
	line.quality_work = 0.0
	line.material_reserved = false
	line.reserved_processing_cost = 0.0
	line.reserved_materials = []
	line.material_id = ""
	line.material_quantity = 0
	line.material_quality = 0.0

func _new_production_line(blueprint_id: String) -> Dictionary:
	return {"blueprint_id":blueprint_id, "enabled":false, "progress":0.0, "quality_work":0.0, "material_reserved":false, "reserved_processing_cost":0.0, "reserved_materials":[], "material_id":"", "material_quantity":0, "material_quality":0.0}

func _reserve_unit_material(line: Dictionary, blueprint: Dictionary) -> bool:
	var computed: Dictionary = blueprint.computed
	var supply := _unit_supply_status(blueprint)
	if not bool(supply.can_supply):
		return false
	var missing_by_material: Dictionary = supply.missing_by_material
	var processing_cost := float(computed.get("processing_cost", 0.0))
	state.cash = float(state.cash) - processing_cost
	state.production_cost_today = float(state.production_cost_today) + processing_cost
	line.reserved_processing_cost = processing_cost
	_add_journal("production", -processing_cost, str(blueprint.name), false)
	var total_purchase_cost := float(supply.purchase_cost)
	if total_purchase_cost > 0.0:
		state.cash = float(state.cash) - total_purchase_cost
		for material_id: Variant in missing_by_material.keys():
			var missing := int(missing_by_material[material_id])
			if missing <= 0:
				continue
			var material := registry.get_def("materials", str(material_id))
			_add_inventory(str(material_id), missing, float(material.get("quality", 0.5)))
			_add_journal("procurement", -_material_purchase_cost(str(material_id), missing), "Automatische Beschaffung: %s" % material.get("name_de", material_id), false)
	var reserved: Array[Dictionary] = []
	var quality_work := 0.0
	var quality_weight := 0.0
	for requirement: Dictionary in _material_requirements(computed):
		var material_id := str(requirement.material_id)
		var quantity := int(requirement.quantity)
		var stock: Dictionary = (state.inventory as Dictionary).get(material_id, {})
		var quality := float(stock.get("quality", registry.get_def("materials", material_id).get("quality", 0.5)))
		stock.quantity = int(stock.get("quantity", 0)) - quantity
		(state.inventory as Dictionary)[material_id] = stock
		var weight := float(requirement.get("quality_weight", quantity))
		quality_work += quality * weight
		quality_weight += weight
		reserved.append({"material_id":material_id, "quantity":quantity, "quality":quality, "quality_weight":weight})
	line.material_quality = quality_work / maxf(0.0001, quality_weight)
	line.material_reserved = true
	line.reserved_materials = reserved
	line.material_id = str(reserved[0].material_id) if not reserved.is_empty() else ""
	line.material_quantity = int(reserved[0].quantity) if not reserved.is_empty() else 0
	return true

func _refund_line_material(line: Dictionary) -> void:
	if not bool(line.get("material_reserved", false)):
		return
	var reserved: Array = line.get("reserved_materials", [])
	if reserved.is_empty() and not str(line.get("material_id", "")).is_empty():
		reserved = [{"material_id":str(line.get("material_id", "")), "quantity":int(line.get("material_quantity", 0)), "quality":float(line.get("material_quality", 0.5))}]
	for reservation: Dictionary in reserved:
		_add_inventory(str(reservation.get("material_id", "")), int(reservation.get("quantity", 0)), float(reservation.get("quality", 0.5)))
	var refund := float(line.get("reserved_processing_cost", 0.0))
	state.cash = float(state.cash) + refund
	state.production_cost_today = float(state.get("production_cost_today", 0.0)) - refund
	if refund > 0.0:
		_add_journal("production_refund", refund, "", false)
	line.reserved_processing_cost = 0.0
	line.material_reserved = false
	line.reserved_materials = []

func _can_supply_unit(blueprint: Dictionary) -> bool:
	return bool(_unit_supply_status(blueprint).can_supply)

func _unit_supply_status(blueprint: Dictionary) -> Dictionary:
	var missing_by_material: Dictionary = {}
	var missing_materials: PackedStringArray = []
	var purchase_cost := 0.0
	for requirement: Dictionary in _material_requirements(blueprint.computed):
		var material_id := str(requirement.material_id)
		var stock: Dictionary = (state.inventory as Dictionary).get(material_id, {"quantity":0})
		var missing := maxi(0, int(requirement.quantity) - int(stock.get("quantity", 0)))
		if missing > 0:
			missing_by_material[material_id] = missing
			missing_materials.append(material_id)
			purchase_cost += _material_purchase_cost(material_id, missing)
	if not missing_by_material.is_empty() and not _has_storage_worker():
		return {"can_supply":false, "status":"no_material", "missing_by_material":missing_by_material, "missing_materials":missing_materials, "purchase_cost":purchase_cost}
	if float(state.cash) < purchase_cost + float((blueprint.computed as Dictionary).get("processing_cost", 0.0)):
		return {"can_supply":false, "status":"no_cash", "missing_by_material":missing_by_material, "missing_materials":missing_materials, "purchase_cost":purchase_cost}
	return {"can_supply":true, "status":"producing", "missing_by_material":missing_by_material, "missing_materials":missing_materials, "purchase_cost":purchase_cost}

func _material_requirements(computed: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in computed.get("material_requirements", []):
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
	if result.is_empty() and not str(computed.get("material_id", "")).is_empty():
		result.append({"material_id":str(computed.material_id), "quantity":int(computed.get("material_per_unit", 2)), "quality_weight":float(computed.get("material_per_unit", 2))})
	return result

func _material_purchase_cost(material_id: String, quantity: int) -> float:
	return material_buy_price(material_id) * maxi(0, quantity)

func _material_event_multiplier(material_id: String) -> float:
	var multiplier := 1.0
	for event: Dictionary in active_material_price_events(material_id):
		multiplier *= float(event.get("price_multiplier", 1.0))
	return multiplier

func _set_price(blueprint_id: String, price: float) -> Dictionary:
	if not is_finite(price) or not (state.blueprints as Dictionary).has(blueprint_id) or snappedf(price, 0.01) <= 0:
		return _result(false, "Ungültiges Marktangebot.")
	(state.listings as Dictionary)[blueprint_id] = {"price":snappedf(price, 0.01), "enabled":true}
	return _result(true, "Marktpreis gesetzt.")

func _stop_sale(blueprint_id: String) -> Dictionary:
	if not (state.listings as Dictionary).has(blueprint_id):
		return _result(false, "Für diese Ware gibt es kein aktives Marktangebot.")
	(state.listings as Dictionary).erase(blueprint_id)
	return _result(true, "Verkauf gestoppt. Die Ware bleibt im Lager.")

func _tick_day() -> void:
	_flush_production_summary()
	_pay_daily_costs()
	_tick_sources()
	_run_market()
	_update_contracts()
	_update_contract_market()
	_refresh_applicants(false)
	_apply_pending_wage_level()
	_update_insolvency()
	_check_victory()

func _tick_sources() -> void:
	var logistics := 0.0
	for staff_value: Variant in state.staff:
		var staff_entry: Dictionary = staff_value
		if _staff_station_kind(staff_entry) == "storage":
			logistics += float(registry.get_def("staff", str(staff_entry.id)).get("logistics", 0.0)) * wage_performance_multiplier()
	for index: int in (state.sources as Array).size():
		var source: Dictionary = state.sources[index]
		var definition := registry.get_def("resource_sources", str(source.type))
		var maximum := float(definition.get("max_reserve", 0))
		var regeneration := float(definition.get("daily_regen", 0)) * float(source.get("regen_multiplier", 1.0))
		source.reserve = minf(maximum, float(source.get("reserve", maximum)) + regeneration)
		var harvested := 0
		if logistics > 0.0:
			harvested = mini(int(floor(float(source.reserve))), maxi(1, int(round(float(definition.get("base_yield", 1)) * logistics * float(source.get("yield_multiplier", 1.0))))))
		if harvested > 0:
			source.reserve = float(source.reserve) - harvested
			var material_id := str(source.get("material", definition.get("material", "")))
			var material := registry.get_def("materials", material_id)
			var quality := clampf(float(material.get("quality", 0.5)) + float(source.get("quality_bonus", 0.0)), 0.0, 1.0)
			var stored := mini(harvested, material_free_capacity(material_id))
			_add_inventory(material_id, stored, quality)
			var overflow := harvested - stored
			if overflow > 0:
				var revenue := snappedf(material_sell_price(material_id, quality) * overflow, 0.01)
				_record_material_sale(material_id, overflow, quality, revenue, true)
		source["last_harvest"] = harvested
		state.sources[index] = source

func _add_inventory(material_id: String, quantity: int, quality: float) -> void:
	if material_id.is_empty() or quantity <= 0:
		return
	var current: Dictionary = (state.inventory as Dictionary).get(material_id, {"quantity":0, "quality":quality})
	var old_quantity := int(current.get("quantity", 0))
	var total := old_quantity + quantity
	current.quality = (float(current.get("quality", quality)) * old_quantity + quality * quantity) / maxf(1.0, total)
	current.quantity = total
	(state.inventory as Dictionary)[material_id] = current

func _record_material_sale(material_id: String, quantity: int, quality: float, revenue: float, automatic: bool) -> void:
	state.cash = float(state.cash) + revenue
	state.lifetime_revenue = float(state.lifetime_revenue) + revenue
	state.raw_material_revenue = float(state.get("raw_material_revenue", 0.0)) + revenue
	var sales: Dictionary = state.get("raw_material_sales_today", {})
	var entry: Dictionary = sales.get(material_id, {"manual_units":0, "automatic_units":0, "manual_revenue":0.0, "automatic_revenue":0.0, "quality_work":0.0})
	var prefix := "automatic" if automatic else "manual"
	entry[prefix + "_units"] = int(entry.get(prefix + "_units", 0)) + quantity
	entry[prefix + "_revenue"] = float(entry.get(prefix + "_revenue", 0.0)) + revenue
	entry.quality_work = float(entry.get("quality_work", 0.0)) + quality * quantity
	sales[material_id] = entry
	state.raw_material_sales_today = sales
	if automatic:
		_add_journal("raw_material_overflow", revenue, "Automatischer Überlaufverkauf: %s" % registry.get_def("materials", material_id).get("name_de", material_id), false)

func _refresh_applicants(force: bool) -> void:
	if not force and current_day() < int(state.get("next_applicant_refresh_day", 1)):
		return
	var hired: PackedStringArray = []
	for staff_value: Variant in state.staff:
		hired.append(str((staff_value as Dictionary).id))
	var eligible: Array[Dictionary] = []
	var dismissed: Dictionary = state.get("dismissed_until", {})
	for definition: Dictionary in registry.all("staff"):
		var staff_id := str(definition.id)
		if hired.has(staff_id) or int(definition.get("min_reputation", 0)) > int(floor(float(state.reputation))):
			continue
		if int(dismissed.get(staff_id, 0)) > current_day():
			continue
		eligible.append(definition)
	var selected: Array = []
	var wanted := int(property.get("applicant_count", 3))
	while not eligible.is_empty() and selected.size() < wanted:
		var pick := rng_staff.range_int(0, eligible.size() - 1)
		selected.append(str(eligible[pick].id))
		eligible.remove_at(pick)
	state.applicants = selected
	state.next_applicant_refresh_day = current_day() + 7

func _run_market() -> void:
	var report: Dictionary = {}
	var artifact_revenue := 0.0
	var player_sales := 0
	var total_market := 0
	for customer: Dictionary in registry.all("customers"):
		var customer_sales := 0
		var demand_multiplier := _event_demand_multiplier(str(customer.id))
		var faction_value := float((state.get("faction_reputation", {}) as Dictionary).get(str(customer.id), 0.0))
		var faction_multiplier := 1.0 + minf(50.0, faction_value) * 0.005
		var demand := int(round(float(customer.get("base_demand", 10)) * demand_multiplier * faction_multiplier * float(property.get("market_multiplier", 1.0))))
		total_market += demand
		var remaining_demand := demand
		var listing_ids := (state.listings as Dictionary).keys()
		listing_ids.sort()
		for blueprint_id: Variant in listing_ids:
			if remaining_demand <= 0:
				break
			var product: Dictionary = (state.products as Dictionary).get(str(blueprint_id), {})
			if product.is_empty() or int(product.get("quantity", 0)) <= 0:
				continue
			var listing: Dictionary = (state.listings as Dictionary)[blueprint_id]
			if not bool(listing.get("enabled", true)):
				continue
			var blueprint: Dictionary = (state.blueprints as Dictionary)[blueprint_id]
			var score := _customer_score(customer, blueprint, product, float(listing.price))
			if score <= 0.15:
				continue
			var noise := 0.85 + rng_market.randf() * 0.3
			var sold := mini(remaining_demand, mini(int(product.quantity), maxi(0, int(floor(demand * minf(0.65, score / 140.0) * noise)))))
			if sold <= 0:
				continue
			product.quantity = int(product.quantity) - sold
			remaining_demand -= sold
			(state.products as Dictionary)[blueprint_id] = product
			var revenue := sold * float(listing.price)
			state.cash = float(state.cash) + revenue
			state.lifetime_revenue = float(state.lifetime_revenue) + revenue
			state.artifact_revenue = float(state.get("artifact_revenue", 0.0)) + revenue
			artifact_revenue += revenue
			customer_sales += sold
			player_sales += sold
			state.market_units_sold = int(state.get("market_units_sold", 0)) + sold
			_add_journal("sale", revenue, str(blueprint.name), false)
		report[str(customer.id)] = {"demand":demand, "player_sales":customer_sales}
	var raw_sales: Dictionary = state.get("raw_material_sales_today", {})
	var raw_revenue := 0.0
	var manual_raw_revenue := 0.0
	var automatic_raw_revenue := 0.0
	for material_id: Variant in raw_sales.keys():
		var raw_entry: Dictionary = raw_sales[material_id]
		manual_raw_revenue += float(raw_entry.get("manual_revenue", 0.0))
		automatic_raw_revenue += float(raw_entry.get("automatic_revenue", 0.0))
		var automatic_units := int(raw_entry.get("automatic_units", 0))
		if automatic_units > 0:
			_emit("RawMaterialOverflowSold", {"material_id":str(material_id), "quantity":automatic_units, "revenue":float(raw_entry.get("automatic_revenue", 0.0))})
	raw_revenue = manual_raw_revenue + automatic_raw_revenue
	var daily_revenue := artifact_revenue + raw_revenue
	var history: Array = state.revenue_history
	history.append(daily_revenue)
	if history.size() > 30:
		history.pop_front()
	state.market_report = report
	state.market_report["player_share"] = float(player_sales) / maxf(1.0, total_market)
	state.market_report["daily_revenue"] = daily_revenue
	state.market_report["artifact_revenue"] = artifact_revenue
	state.market_report["raw_material_revenue"] = raw_revenue
	state.market_report["manual_raw_material_revenue"] = manual_raw_revenue
	state.market_report["automatic_raw_material_revenue"] = automatic_raw_revenue
	state.market_report["wages"] = float(state.get("last_wages_paid", 0.0))
	state.market_report["research_cost"] = float(state.get("research_cost_today", 0.0))
	state.market_report["production_cost"] = float(state.get("production_cost_today", 0.0))
	state.market_report["interest"] = float(state.get("last_interest_paid", 0.0))
	state.market_report["operating_net"] = daily_revenue - float(state.market_report.wages) - float(state.market_report.research_cost) - float(state.market_report.interest) - float(state.market_report.production_cost)
	state.raw_material_sales_today = {}
	state.research_cost_today = 0.0
	state.production_cost_today = 0.0

func _customer_score(customer: Dictionary, blueprint: Dictionary, product: Dictionary, price: float) -> float:
	var stats: Dictionary = (blueprint.computed as Dictionary).stats
	var preferences: Dictionary = customer.get("preferences", {})
	var score := float(product.get("average_quality", 0)) * 0.45
	for key: String in STAT_KEYS:
		score += float(stats.get(key, 0)) * float(preferences.get(key, 0))
	var classes: Array = (blueprint.computed as Dictionary).get("goods_classes", [])
	var class_matches := 0
	for desired_class: Variant in customer.get("preferred_classes", []):
		if classes.has(desired_class):
			class_matches += 1
	score += mini(2, class_matches) * 12.0
	var affordability := clampf(float(customer.get("budget", 1)) / maxf(1.0, price), 0.0, 1.3)
	return score * affordability * (0.85 + float(state.reputation) / 100.0)

func _pay_daily_costs() -> void:
	var wages := daily_wages()
	var interest := float(state.loan_balance) * 0.001
	state.cash = float(state.cash) - wages - interest
	state["last_wages_paid"] = wages
	state["last_interest_paid"] = interest
	_add_journal("wages", -wages, "Löhne")
	if interest > 0:
		_add_journal("interest", -interest, "Kreditzinsen")

func _apply_pending_wage_level() -> void:
	var old_level := wage_performance_multiplier()
	var new_level := clampf(float(state.get("pending_wage_level", old_level)), MIN_WAGE_LEVEL, MAX_WAGE_LEVEL)
	if is_equal_approx(old_level, new_level):
		return
	state.wage_level = new_level
	_emit("WageLevelChanged", {"old_level":old_level, "new_level":new_level})

func _accept_contract(contract_id: String) -> Dictionary:
	var offers: Dictionary = state.get("available_contracts", {})
	if not offers.has(contract_id):
		return _result(false, "Auftrag ist nicht verfügbar.")
	var runtime: Dictionary = offers[contract_id]
	if contract_days_remaining(runtime) <= 0:
		return _result(false, "Die Angebotsfrist ist bereits abgelaufen.")
	runtime["accepted_day"] = current_day()
	(state.active_contracts as Dictionary)[contract_id] = runtime
	offers.erase(contract_id)
	_emit("ContractAccepted", {"contract_id":contract_id})
	return _result(true, "Auftrag angenommen.")

func _update_contracts() -> void:
	for contract_id: Variant in (state.active_contracts as Dictionary).keys().duplicate():
		var contract: Dictionary = (state.active_contracts as Dictionary)[contract_id]
		if current_day() >= int(contract.deadline_day):
			(state.active_contracts as Dictionary).erase(contract_id)
			state.reputation = maxf(0.0, float(state.reputation) - 5.0)
			(state.contract_offer_cooldowns as Dictionary)[contract_id] = current_day() + CONTRACT_OFFER_COOLDOWN_DAYS
			_emit("ContractExpired", {"contract_id":contract_id})

func _update_contract_market() -> void:
	var offers: Dictionary = state.available_contracts
	var cooldowns: Dictionary = state.contract_offer_cooldowns
	for contract_id: Variant in offers.keys().duplicate():
		var offer: Dictionary = offers[contract_id]
		if current_day() >= int(offer.get("deadline_day", current_day())):
			offers.erase(contract_id)
			cooldowns[contract_id] = current_day() + CONTRACT_OFFER_COOLDOWN_DAYS
			_emit("ContractOfferExpired", {"contract_id":contract_id})
	var player_profession := str(state.get("player_profession", ""))
	if player_profession.is_empty() or bool(state.get("profession_choice_required", false)) or int(state.get("market_units_sold", 0)) < CONTRACT_MARKET_MIN_SALES or float(state.reputation) < CONTRACT_MARKET_MIN_REPUTATION:
		return
	var capacity := _contract_offer_capacity()
	var candidates: Array[Dictionary] = []
	var available_classes := available_goods_classes(player_profession)
	for definition: Dictionary in registry.all("contracts"):
		var contract_id := str(definition.id)
		if offers.has(contract_id) or (state.active_contracts as Dictionary).has(contract_id):
			continue
		if (state.completed_contracts as Array).has(contract_id) and not bool(definition.get("repeatable", true)):
			continue
		if int(cooldowns.get(contract_id, 0)) > current_day():
			continue
		if not (definition.get("eligible_professions", []) as Array).has(player_profession):
			continue
		var customer_id := str(definition.get("customer", ""))
		if float((state.faction_reputation as Dictionary).get(customer_id, 0.0)) < float(definition.get("min_faction_reputation", 0.0)):
			continue
		if not _arrays_overlap(definition.get("accepted_classes", []), available_classes):
			continue
		if not _coverage_is_buildable(definition.get("required_coverage", [])):
			continue
		candidates.append(definition)
	while offers.size() + (state.active_contracts as Dictionary).size() < capacity and not candidates.is_empty():
		var pick := rng_contracts.range_int(0, candidates.size() - 1)
		var definition: Dictionary = candidates[pick]
		candidates.remove_at(pick)
		var contract_id := str(definition.id)
		var runtime := definition.duplicate(true)
		runtime["appeared_day"] = current_day()
		runtime["deadline_day"] = current_day() + int(definition.get("deadline_days", 10))
		offers[contract_id] = runtime
		_emit("ContractOffered", {"contract_id":contract_id})

func _contract_offer_capacity() -> int:
	var reputation := float(state.reputation)
	if reputation >= 30.0:
		return 3
	if reputation >= 15.0:
		return 2
	return 1

func _submit_contract(contract_id: String) -> Dictionary:
	if not (state.active_contracts as Dictionary).has(contract_id):
		return _result(false, "Auftrag ist nicht aktiv.")
	var contract: Dictionary = (state.active_contracts as Dictionary)[contract_id]
	var delivery := contract_delivery_status(contract)
	if not bool(delivery.ready):
		return _result(false, "Noch nicht genug passende Ware: %d von %d Stück verfügbar (mindestens Qualität %.0f)." % [int(delivery.available), int(delivery.required), float(contract.min_quality)])
	var remaining := int(contract.quantity)
	for blueprint_id: Variant in (state.products as Dictionary).keys():
		if remaining <= 0:
			break
		var product: Dictionary = (state.products as Dictionary)[blueprint_id]
		var blueprint: Dictionary = (state.blueprints as Dictionary).get(blueprint_id, {})
		if not _product_matches_contract(blueprint, product, contract):
			continue
		var delivered := mini(remaining, int(product.get("quantity", 0)))
		product.quantity = int(product.get("quantity", 0)) - delivered
		remaining -= delivered
		(state.products as Dictionary)[blueprint_id] = product
	state.cash = float(state.cash) + float(contract.reward)
	state.reputation = float(state.reputation) + float(contract.prestige)
	var customer_id := str(contract.get("customer", ""))
	(state.faction_reputation as Dictionary)[customer_id] = float((state.faction_reputation as Dictionary).get(customer_id, 0.0)) + float(contract.get("faction_reputation_reward", 0.0))
	(state.active_contracts as Dictionary).erase(contract_id)
	if not (state.completed_contracts as Array).has(contract_id):
		state.completed_contracts.append(contract_id)
	(state.contract_offer_cooldowns as Dictionary)[contract_id] = current_day() + CONTRACT_OFFER_COOLDOWN_DAYS
	_add_journal("contract", float(contract.reward), str(contract.get("name_de", contract_id)))
	_emit("ContractCompleted", {"contract_id":contract_id, "reward":contract.reward, "prestige":contract.prestige, "customer":customer_id, "faction_reputation":contract.get("faction_reputation_reward", 0.0)})
	return _result(true, "Auftrag abgeschlossen: %s · +%.0f Gold · +%.0f Ruf · +%.0f Kundenansehen." % [str(contract.get("name_de", contract_id)), float(contract.reward), float(contract.prestige), float(contract.get("faction_reputation_reward", 0.0))])

func _tick_rivals() -> void:
	for rival_id: Variant in (state.rivals as Dictionary).keys():
		var runtime: Dictionary = (state.rivals as Dictionary)[rival_id]
		var project_id := str(runtime.active_research)
		if project_id.is_empty():
			continue
		var project := registry.get_def("research", project_id)
		var profile := registry.get_def("rivals", str(rival_id))
		var progress: Dictionary = runtime.research_progress
		var cost := float(project.get("hourly_cost", 0))
		if float(runtime.cash) < cost:
			runtime.last_action = "Spart für Forschung"
			continue
		runtime.cash = float(runtime.cash) - cost
		progress[project_id] = float(progress.get(project_id, 0)) + 3.0 * float(profile.get("research_efficiency", 1.0))
		if float(progress[project_id]) >= float(project.get("cost_hours", 1)):
			(runtime.unlocked as Dictionary)[project_id] = true
			runtime.reputation = float(runtime.reputation) + 4.0
			runtime.last_action = "Forschung abgeschlossen: %s" % project.get("name_de", project_id)
			var next := _first_project_for(str(profile.focus), int(project.get("tier", 1)) + 1)
			runtime.active_research = next
			_emit("RivalResearchCompleted", {"rival_id":rival_id, "project_id":project_id})
		(state.rivals as Dictionary)[rival_id] = runtime
	if int(state.hour) % HOURS_PER_DAY == 0:
		for rival_id: Variant in (state.rivals as Dictionary).keys():
			var runtime: Dictionary = (state.rivals as Dictionary)[rival_id]
			var profile := registry.get_def("rivals", str(rival_id))
			var income := 420.0 * float(profile.get("market_efficiency", 1.0)) + rng_rivals.range_int(-50, 80)
			runtime.cash = float(runtime.cash) + income
			runtime.market_share = clampf(float(runtime.market_share) + (rng_rivals.randf() - 0.45) * 0.01, 0.1, 0.38)
			(state.rivals as Dictionary)[rival_id] = runtime

func _update_races() -> void:
	var player_project := str(state.active_research)
	if player_project.is_empty():
		return
	for rival_id: Variant in (state.rivals as Dictionary).keys():
		var runtime: Dictionary = (state.rivals as Dictionary)[rival_id]
		if str(runtime.active_research) == player_project:
			var race_id := "%s|%s" % [player_project, rival_id]
			if not (state.active_races as Dictionary).has(race_id):
				(state.active_races as Dictionary)[race_id] = {"project_id":player_project, "rival_id":rival_id, "started_hour":state.hour}
				_emit("RaceStarted", {"project_id":player_project, "rival_id":rival_id})

func _update_insolvency() -> void:
	if float(state.cash) >= 0:
		state.insolvency_since = -1
		return
	if int(state.insolvency_since) < 0:
		state.insolvency_since = current_day()
		_emit("InsolvencyWarning", {"remaining_days":int(scenario.get("rescue_days", 14))})
	var elapsed := current_day() - int(state.insolvency_since)
	if elapsed >= int(scenario.get("rescue_days", 14)):
		state.defeat = true
		_emit("Defeat", {"reason":"insolvency"})

func _take_loan() -> Dictionary:
	if float(state.loan_balance) >= 15000:
		return _result(false, "Das Kreditlimit ist erreicht.")
	state.cash = float(state.cash) + 5000.0
	state.loan_balance = float(state.loan_balance) + 6000.0
	_add_journal("loan", 5000.0, "Gildenkredit")
	return _result(true, "5.000 Gold erhalten; 6.000 Gold Rückzahlung offen.")

func _check_victory() -> void:
	var victory_config: Dictionary = scenario.get("victory", {})
	for project: Dictionary in registry.all("research"):
		if int(project.get("tier", 0)) >= int(victory_config.get("technology_tier", 3)) and bool((state.unlocked as Dictionary).get(str(project.id), false)):
			state.victory = "technology"
	var revenue_30d := 0.0
	for value: Variant in state.revenue_history:
		revenue_30d += float(value)
	if float(state.cash) >= float(victory_config.get("economic_cash", INF)) and revenue_30d >= float(victory_config.get("economic_revenue_30d", INF)) and float((state.market_report as Dictionary).get("player_share", 0)) >= float(victory_config.get("economic_share", 1)):
		state.victory = "economic"
	if (state.completed_contracts as Array).has(str(victory_config.get("hybrid_contract", "impossible"))):
		state.victory = "hybrid"
	if not str(state.victory).is_empty():
		_emit("Victory", {"path":state.victory})

func _place_room(room_type: String, rect_data: Array) -> Dictionary:
	var definition := registry.get_def("rooms", room_type)
	if definition.is_empty() or rect_data.size() != 4:
		return _result(false, "Ungültiger Raum.")
	var rect := Rect2i(int(rect_data[0]), int(rect_data[1]), int(rect_data[2]), int(rect_data[3]))
	var property_size := grid_size()
	if rect.size.x <= 0 or rect.size.y <= 0 or rect.position.x < 0 or rect.position.y < 0 or rect.end.x > property_size.x or rect.end.y > property_size.y:
		return _result(false, "Der Raum liegt außerhalb des Grundstücks.")
	if rect.get_area() < int(definition.get("min_size", 1)):
		return _result(false, "Der Raum ist zu klein.")
	for existing: Variant in state.rooms:
		var other := _array_to_rect((existing as Dictionary).rect)
		if rect.intersects(other):
			return _result(false, "Der Raum überschneidet einen vorhandenen Raum.")
	if _rect_hits_source(rect):
		return _result(false, "Der Raum würde eine Rohstoffquelle überbauen.")
	var cost := rect.get_area() * float(definition.get("cost_per_tile", 0)) * float(property.get("construction_multiplier", 1.0))
	if float(state.cash) < cost:
		return _result(false, "Nicht genug Gold für den Raum.")
	state.cash = float(state.cash) - cost
	var room_id := "room_%d" % int(state.next_room)
	state.next_room = int(state.next_room) + 1
	state.rooms.append({"id":room_id, "type":room_type, "rect":rect_data.duplicate()})
	_add_journal("construction", -cost, str(definition.get("name_de", room_type)))
	return _result(true, "Raum gebaut.", {"room_id":room_id})

func _resize_room(room_id: String, rect_data: Array) -> Dictionary:
	if rect_data.size() != 4:
		return _result(false, "Ungültige Raumgröße.")
	var room_index := -1
	for index: int in (state.rooms as Array).size():
		if str((state.rooms[index] as Dictionary).id) == room_id:
			room_index = index
			break
	if room_index < 0:
		return _result(false, "Raum wurde nicht gefunden.")
	var room: Dictionary = state.rooms[room_index]
	var old_rect := _array_to_rect(room.rect)
	var new_rect := _array_to_rect(rect_data)
	var definition := registry.get_def("rooms", str(room.type))
	var property_size := grid_size()
	if new_rect.position != old_rect.position:
		return _result(false, "Beim Umbau bleibt die obere linke Ecke unverändert.")
	if new_rect.size.x <= 0 or new_rect.size.y <= 0 or new_rect.end.x > property_size.x or new_rect.end.y > property_size.y:
		return _result(false, "Die neue Raumgröße liegt außerhalb des Grundstücks.")
	if new_rect.get_area() < int(definition.get("min_size", 1)):
		return _result(false, "Der Raum wäre zu klein.")
	for index: int in (state.rooms as Array).size():
		if index != room_index and new_rect.intersects(_array_to_rect((state.rooms[index] as Dictionary).rect)):
			return _result(false, "Der geänderte Raum würde einen anderen Raum überlagern.")
	if _rect_hits_source(new_rect):
		return _result(false, "Der geänderte Raum würde eine Rohstoffquelle überbauen.")
	var proposed_rooms: Array = (state.rooms as Array).duplicate(true)
	var proposed_room := room.duplicate(true)
	proposed_room.rect = rect_data.duplicate()
	proposed_rooms[room_index] = proposed_room
	if bool(definition.get("housing", false)) and housing_capacity(proposed_rooms) < (state.staff as Array).size():
		return _result(false, "Das Wohnhaus hätte danach zu wenige Personalplätze.")
	var proposed_stations: Array = (state.stations as Array).duplicate(true)
	var occupied: Dictionary = {}
	var clipped: Array[int] = []
	for index: int in proposed_stations.size():
		var station: Dictionary = proposed_stations[index]
		var position := _array_to_position(station.position)
		if new_rect.has_point(position):
			occupied[position] = true
		elif old_rect.has_point(position):
			clipped.append(index)
	for station_index: int in clipped:
		var replacement := Vector2i(-1, -1)
		for y: int in range(new_rect.position.y, new_rect.end.y):
			for x: int in range(new_rect.position.x, new_rect.end.x):
				var candidate := Vector2i(x, y)
				if not occupied.has(candidate):
					replacement = candidate
					break
			if replacement.x >= 0:
				break
		if replacement.x < 0:
			return _result(false, "Nicht alle Stationen finden im geänderten Raum Platz.")
		(proposed_stations[station_index] as Dictionary).position = [replacement.x, replacement.y]
		occupied[replacement] = true
	var intersection := old_rect.intersection(new_rect)
	var added_tiles := new_rect.get_area() - intersection.get_area()
	var removed_tiles := old_rect.get_area() - intersection.get_area()
	var tile_cost := float(definition.get("cost_per_tile", 0)) * float(property.get("construction_multiplier", 1.0))
	var cost := added_tiles * tile_cost + removed_tiles * tile_cost * 0.5
	if float(state.cash) < cost:
		return _result(false, "Nicht genug Gold für den Umbau.")
	state.cash = float(state.cash) - cost
	state.rooms = proposed_rooms
	state.stations = proposed_stations
	_add_journal("construction", -cost, "Umbau: %s" % definition.get("name_de", room.type))
	return _result(true, "Raumgröße geändert.")

func _place_station(station_type: String, position_data: Array) -> Dictionary:
	var definition := registry.get_def("stations", station_type)
	if definition.is_empty() or position_data.size() != 2:
		return _result(false, "Ungültige Station.")
	if not _is_content_unlocked(definition):
		return _result(false, "Diese Station ist noch nicht freigeschaltet.")
	var position := Vector2i(int(position_data[0]), int(position_data[1]))
	var valid_room := false
	for room: Variant in state.rooms:
		if str((room as Dictionary).type) == str(definition.room_type) and _array_to_rect((room as Dictionary).rect).has_point(position):
			valid_room = true
	for station: Variant in state.stations:
		var existing: Array = (station as Dictionary).position
		if Vector2i(int(existing[0]), int(existing[1])) == position:
			return _result(false, "Dieses Feld ist bereits belegt.")
	if not valid_room:
		return _result(false, "Station benötigt den passenden Raumtyp.")
	var cost := float(definition.get("cost", 0)) * float(property.get("construction_multiplier", 1.0))
	if float(state.cash) < cost:
		return _result(false, "Nicht genug Gold für die Station.")
	state.cash = float(state.cash) - cost
	var station_id := "station_%d" % int(state.next_station)
	state.next_station = int(state.next_station) + 1
	state.stations.append({"id":station_id, "type":station_type, "position":position_data.duplicate()})
	_add_journal("construction", -cost, str(definition.get("name_de", station_type)))
	return _result(true, "Station platziert.", {"station_id":station_id})

func _assign_staff(staff_id: String, station_id: String) -> Dictionary:
	var staff_index := _staff_index(staff_id)
	if staff_index < 0:
		return _result(false, "Unbekannte Schlüsselkraft.")
	if not station_id.is_empty() and _station_by_id(station_id).is_empty():
		return _result(false, "Unbekannte Station.")
	var entry: Dictionary = state.staff[staff_index]
	var old_station := str(entry.get("station_id", ""))
	var occupant_index := -1
	if not station_id.is_empty():
		for index: int in (state.staff as Array).size():
			if index != staff_index and str((state.staff[index] as Dictionary).get("station_id", "")) == station_id:
				occupant_index = index
				break
	entry.station_id = station_id
	state.staff[staff_index] = entry
	if occupant_index >= 0:
		var occupant: Dictionary = state.staff[occupant_index]
		occupant.station_id = old_station
		state.staff[occupant_index] = occupant
	return _result(true, "Personal neu zugewiesen.")

func _hire_staff(staff_id: String) -> Dictionary:
	if not (state.applicants as Array).has(staff_id) or _staff_index(staff_id) >= 0:
		return _result(false, "Diese Bewerbung ist nicht verfügbar.")
	if (state.staff as Array).size() >= housing_capacity():
		return _result(false, "Es fehlt ein freier Platz im Wohnhaus.")
	var definition := registry.get_def("staff", staff_id)
	var fee := float(definition.get("salary", 0)) * 3.0 * float(property.get("hiring_multiplier", 1.0))
	if float(state.cash) < fee:
		return _result(false, "Nicht genug Gold für die Einstellung.")
	state.cash = float(state.cash) - fee
	state.staff.append({"id":staff_id, "station_id":""})
	state.applicants.erase(staff_id)
	_add_journal("staff", -fee, "Einstellung: %s" % definition.get("name_de", staff_id))
	return _result(true, "Personal eingestellt.")

func _dismiss_staff(staff_id: String) -> Dictionary:
	var index := _staff_index(staff_id)
	if index < 0:
		return _result(false, "Diese Person ist nicht beschäftigt.")
	var definition := registry.get_def("staff", staff_id)
	var severance := float(definition.get("salary", 0)) * 2.0
	if float(state.cash) < severance:
		return _result(false, "Nicht genug Gold für die Abfindung.")
	state.cash = float(state.cash) - severance
	state.staff.remove_at(index)
	(state.dismissed_until as Dictionary)[staff_id] = current_day() + 14
	state.applicants.erase(staff_id)
	_add_journal("staff", -severance, "Abfindung: %s" % definition.get("name_de", staff_id))
	return _result(true, "Personal entlassen.")

func _production_work_rate(station: Dictionary, worker: Dictionary) -> float:
	if station.is_empty() or worker.is_empty():
		return 0.0
	var station_def := registry.get_def("stations", str(station.type))
	return float(station_def.get("capacity", 1.0)) * float(worker.get("production_speed", worker.get("craft", 1.0))) * wage_performance_multiplier()

func _quality_estimate(difficulty: float, material_quality: float, worker_quality: float = 1.0, quality_delta: float = 0.0) -> float:
	return clampf(48.0 + material_quality * 36.0 - difficulty * 0.7 + (worker_quality - 1.0) * 18.0 + quality_delta, 15.0, 95.0)

func _roll_quality(difficulty: float, material_quality: float, worker_quality: float = 1.0, quality_delta: float = 0.0) -> float:
	return clampf(_quality_estimate(difficulty, material_quality, worker_quality, quality_delta) + (rng_quality.randf() - 0.5) * 12.0, 1.0, 100.0)

func _staff_for_station(station_id: String) -> Dictionary:
	for staff_value: Variant in state.staff:
		var entry: Dictionary = staff_value
		if str(entry.get("station_id", "")) == station_id:
			return registry.get_def("staff", str(entry.id))
	return {}

func _has_storage_worker() -> bool:
	for staff_value: Variant in state.staff:
		if _staff_station_kind(staff_value as Dictionary) == "storage":
			return true
	return false

func _flush_production_summary() -> void:
	var total := 0
	var by_blueprint: Dictionary = {}
	for station_id: Variant in (state.production_today as Dictionary).keys():
		var station_today: Dictionary = (state.production_today as Dictionary)[station_id]
		for blueprint_id: Variant in station_today.keys():
			var count := int(station_today[blueprint_id])
			total += count
			by_blueprint[blueprint_id] = int(by_blueprint.get(blueprint_id, 0)) + count
	if total > 0:
		_emit("ProductionSummary", {"total":total, "products":by_blueprint})
	state.production_today = {}

func _production_today_for_station(station_id: String) -> int:
	var total := 0
	for count: Variant in ((state.production_today as Dictionary).get(station_id, {}) as Dictionary).values():
		total += int(count)
	return total

func _event_demand_multiplier(customer_id: String) -> float:
	var multiplier := 1.0
	var day := current_day()
	for event: Dictionary in registry.all("events"):
		var start := int(event.get("start_day", 99999))
		if day >= start and day < start + int(event.get("duration_days", 0)):
			if str(event.get("customer", "")) in [customer_id, "all"]:
				multiplier *= float(event.get("demand_multiplier", 1.0))
	return multiplier

func _first_project_for(discipline_id: String, tier: int) -> String:
	for project: Dictionary in registry.all("research"):
		if str(project.get("discipline", "")) == discipline_id and int(project.get("tier", 0)) == tier and not bool(project.get("hybrid", false)):
			return str(project.id)
	return ""

func _is_content_unlocked(definition: Dictionary) -> bool:
	return bool(definition.get("unlocked", false)) or bool((state.unlocked as Dictionary).get(str(definition.get("id", "")), false))

func _staff_index(staff_id: String) -> int:
	for index: int in (state.staff as Array).size():
		if str((state.staff[index] as Dictionary).id) == staff_id:
			return index
	return -1

func _station_by_id(station_id: String) -> Dictionary:
	for station_value: Variant in state.stations:
		var station: Dictionary = station_value
		if str(station.id) == station_id:
			return station
	return {}

func _staff_station_kind(staff_entry: Dictionary) -> String:
	var station := _station_by_id(str(staff_entry.get("station_id", "")))
	if station.is_empty():
		return ""
	return str(registry.get_def("stations", str(station.type)).get("kind", ""))

func _rect_hits_source(rect: Rect2i) -> bool:
	for source_value: Variant in state.get("sources", []):
		var source: Dictionary = source_value
		if bool(source.get("offsite", false)):
			continue
		var position_data: Array = source.get("position", [])
		if position_data.size() == 2 and rect.has_point(_array_to_position(position_data)):
			return true
	return false

func _migrate_v1_state() -> void:
	state["sources"] = []
	state["applicants"] = []
	state["dismissed_until"] = {}
	state["next_applicant_refresh_day"] = current_day()
	state["next_room"] = _next_runtime_id(state.rooms, "room_")
	state["next_station"] = _next_runtime_id(state.stations, "station_")
	for material_id: String in ["base:spring_water", "base:wild_herbs", "base:spirit_essence"]:
		if not (state.inventory as Dictionary).has(material_id):
			var material := registry.get_def("materials", material_id)
			(state.inventory as Dictionary)[material_id] = {"quantity":0, "quality":float(material.get("quality", 0.5))}
	var has_residence := false
	for room_value: Variant in state.rooms:
		if str((room_value as Dictionary).type) == "base:residence":
			has_residence = true
	if not has_residence:
		var residence_rect := _first_free_rect(Vector2i(4, 4))
		if residence_rect.size.x > 0:
			state.rooms.append({"id":"room_%d" % int(state.next_room), "type":"base:residence", "rect":[residence_rect.position.x, residence_rect.position.y, 4, 4]})
			state.next_room = int(state.next_room) + 1
	var occupied_stations: Dictionary = {}
	for index: int in (state.staff as Array).size():
		var entry: Dictionary = state.staff[index]
		var legacy_assignment := str(entry.get("assignment", "available"))
		entry.erase("assignment")
		entry["station_id"] = ""
		if legacy_assignment in ["research", "production"]:
			for station_value: Variant in state.stations:
				var station: Dictionary = station_value
				var station_id := str(station.id)
				if not occupied_stations.has(station_id) and str(registry.get_def("stations", str(station.type)).get("kind", "")) == legacy_assignment:
					entry.station_id = station_id
					occupied_stations[station_id] = true
					break
		state.staff[index] = entry
	_initialize_sources()
	for index: int in (state.sources as Array).size():
		var source: Dictionary = state.sources[index]
		var preferred := _array_to_position(source.position)
		var position := _find_free_source_cell(preferred, str(source.id))
		if position.x < 0:
			source.offsite = true
		else:
			source.position = [position.x, position.y]
		state.sources[index] = source
	_refresh_applicants(true)

func _next_runtime_id(entries: Array, prefix: String) -> int:
	var next := 1
	for entry: Dictionary in entries:
		var id := str(entry.get("id", ""))
		if id.begins_with(prefix):
			next = maxi(next, int(id.trim_prefix(prefix)) + 1)
	return next

func _migrate_production_lines(saved_version: int) -> void:
	state["production_cost_today"] = float(state.get("production_cost_today", 0.0)) if saved_version >= 9 else 0.0
	var legacy_queue: Array = state.get("production_queue", [])
	if saved_version < SAVE_VERSION and not legacy_queue.is_empty():
		for order_value: Variant in legacy_queue:
			var order: Dictionary = order_value
			var blueprint: Dictionary = (state.blueprints as Dictionary).get(str(order.get("blueprint_id", "")), {})
			if blueprint.is_empty():
				continue
			var computed: Dictionary = blueprint.computed
			_add_inventory(str(computed.material_id), int(computed.material_per_unit) * int(order.get("quantity", 0)), float(order.get("material_quality", 0.5)))
		var logbook: Array = state.get("logbook", [])
		logbook.push_front({"type":"ProductionMigrated", "hour":state.get("hour", 0), "payload":{"orders":legacy_queue.size()}})
		state["logbook"] = logbook
	state.erase("production_queue")
	state.erase("production_timing_version")
	state.erase("teams")
	state["production_lines"] = state.get("production_lines", {})
	state["production_today"] = state.get("production_today", {})
	for station_id: Variant in (state.production_lines as Dictionary).keys().duplicate():
		var line: Dictionary = (state.production_lines as Dictionary)[station_id]
		line["reserved_processing_cost"] = float(line.get("reserved_processing_cost", 0.0)) if saved_version >= 9 else 0.0
		var station := _station_by_id(str(station_id))
		if station.is_empty() or str(registry.get_def("stations", str(station.type)).get("kind", "")) != "production" or not (state.blueprints as Dictionary).has(str(line.get("blueprint_id", ""))):
			_refund_line_material(line)
			(state.production_lines as Dictionary).erase(station_id)
			continue
		for defaults_key: String in ["progress", "quality_work", "material_quantity", "material_quality"]:
			line[defaults_key] = float(line.get(defaults_key, 0.0))
		line["enabled"] = bool(line.get("enabled", false))
		line["material_reserved"] = bool(line.get("material_reserved", false))
		line["material_id"] = str(line.get("material_id", ""))
		var reserved_materials: Array = line.get("reserved_materials", [])
		if bool(line.material_reserved) and reserved_materials.is_empty() and not str(line.material_id).is_empty():
			reserved_materials = [{"material_id":str(line.material_id), "quantity":int(line.get("material_quantity", 0)), "quality":float(line.get("material_quality", 0.5)), "quality_weight":float(line.get("material_quantity", 0))}]
		line["reserved_materials"] = reserved_materials
		(state.production_lines as Dictionary)[station_id] = line

func _migrate_professions_and_classes(saved_version: int) -> void:
	var faction_reputation: Dictionary = state.get("faction_reputation", {})
	for customer: Dictionary in registry.all("customers"):
		faction_reputation[str(customer.id)] = float(faction_reputation.get(str(customer.id), 0.0))
	state["faction_reputation"] = faction_reputation
	var profession := str(state.get("player_profession", ""))
	if not profession.is_empty() and not registry.has_def("disciplines", profession):
		profession = ""
	if profession.is_empty():
		var completed := _completed_foundation_professions()
		if completed.size() == 1:
			profession = completed[0]
			state["profession_choice_required"] = false
		elif completed.size() > 1:
			state["profession_choice_required"] = true
		else:
			state["profession_choice_required"] = false
	state["player_profession"] = profession
	for blueprint_id: Variant in (state.blueprints as Dictionary).keys():
		var blueprint: Dictionary = (state.blueprints as Dictionary)[blueprint_id]
		var classification := _blueprint_classification(blueprint)
		var computed: Dictionary = blueprint.get("computed", {})
		computed["goods_classes"] = classification.goods_classes
		computed["profession_coverage"] = classification.profession_coverage
		blueprint["computed"] = computed
		(state.blueprints as Dictionary)[blueprint_id] = blueprint
	if saved_version < 6:
		state["active_contracts"] = {}
		state["available_contracts"] = {}
		state["contract_offer_cooldowns"] = {}

func _migrate_wage_level() -> void:
	state["wage_level"] = clampf(float(state.get("wage_level", 1.0)), MIN_WAGE_LEVEL, MAX_WAGE_LEVEL)
	state["pending_wage_level"] = clampf(float(state.get("pending_wage_level", state.wage_level)), MIN_WAGE_LEVEL, MAX_WAGE_LEVEL)
	state["research_cost_today"] = float(state.get("research_cost_today", 0.0))
	state["last_wages_paid"] = float(state.get("last_wages_paid", 0.0))
	state["last_interest_paid"] = float(state.get("last_interest_paid", 0.0))

func _migrate_complex_blueprints(_saved_version: int) -> void:
	for blueprint_id: Variant in (state.blueprints as Dictionary).keys():
		var blueprint: Dictionary = (state.blueprints as Dictionary)[blueprint_id]
		blueprint["secondary_effect_id"] = str(blueprint.get("secondary_effect_id", ""))
		blueprint["secondary_material_id"] = str(blueprint.get("secondary_material_id", ""))
		var preview := preview_blueprint(blueprint)
		if bool(preview.get("valid", false)):
			blueprint["computed"] = preview
		(state.blueprints as Dictionary)[blueprint_id] = blueprint

func _migrate_contract_market(_saved_version: int) -> void:
	state["market_units_sold"] = int(state.get("market_units_sold", 0))
	state["active_contracts"] = state.get("active_contracts", {})
	state["available_contracts"] = state.get("available_contracts", {})
	state["contract_offer_cooldowns"] = state.get("contract_offer_cooldowns", {})
	for contract_id: Variant in (state.active_contracts as Dictionary).keys():
		var runtime: Dictionary = (state.active_contracts as Dictionary)[contract_id]
		if not runtime.has("appeared_day"):
			runtime["appeared_day"] = int(runtime.get("accepted_day", current_day()))
		if not runtime.has("deadline_day"):
			runtime["deadline_day"] = int(runtime.appeared_day) + int(runtime.get("deadline_days", 10))
		var definition := registry.get_def("contracts", str(contract_id))
		if not definition.is_empty():
			_refresh_contract_requirements(runtime, definition)
		(state.active_contracts as Dictionary)[contract_id] = runtime
	for contract_id: Variant in (state.available_contracts as Dictionary).keys():
		var runtime: Dictionary = (state.available_contracts as Dictionary)[contract_id]
		var definition := registry.get_def("contracts", str(contract_id))
		if not definition.is_empty():
			_refresh_contract_requirements(runtime, definition)
		(state.available_contracts as Dictionary)[contract_id] = runtime

func _migrate_material_trade() -> void:
	state["raw_material_revenue"] = float(state.get("raw_material_revenue", 0.0))
	state["artifact_revenue"] = float(state.get("artifact_revenue", float(state.get("lifetime_revenue", 0.0)) - float(state.raw_material_revenue)))
	state["raw_material_sales_today"] = state.get("raw_material_sales_today", {})

func _first_free_rect(size: Vector2i) -> Rect2i:
	var property_size := grid_size()
	for y: int in range(0, property_size.y - size.y + 1):
		for x: int in range(0, property_size.x - size.x + 1):
			var candidate := Rect2i(x, y, size.x, size.y)
			var blocked := false
			for room_value: Variant in state.rooms:
				if candidate.intersects(_array_to_rect((room_value as Dictionary).rect)):
					blocked = true
					break
			if not blocked:
				return candidate
	return Rect2i()

func _find_free_source_cell(preferred: Vector2i, ignored_source_id: String = "") -> Vector2i:
	var property_size := grid_size()
	var candidates: Array[Vector2i] = []
	if preferred.x >= 0 and preferred.y >= 0:
		candidates.append(preferred)
	for y: int in property_size.y:
		for x: int in property_size.x:
			var candidate := Vector2i(x, y)
			if not candidates.has(candidate):
				candidates.append(candidate)
	for candidate: Vector2i in candidates:
		var blocked := candidate.x < 0 or candidate.y < 0 or candidate.x >= property_size.x or candidate.y >= property_size.y
		for room_value: Variant in state.rooms:
			blocked = blocked or _array_to_rect((room_value as Dictionary).rect).has_point(candidate)
		for source_value: Variant in state.sources:
			var other: Dictionary = source_value
			var data: Array = other.get("position", [])
			if str(other.get("id", "")) != ignored_source_id and data.size() == 2 and _array_to_position(data) == candidate and not bool(other.get("offsite", false)):
				blocked = true
		if not blocked:
			return candidate
	return Vector2i(-1, -1)

func _effect_profession_coverage(effect: Dictionary) -> Array[String]:
	var result: Array[String] = []
	_add_string_values(result, effect.get("profession_coverage", [effect.get("discipline", "")]))
	return result

func _blueprint_classification(blueprint: Dictionary) -> Dictionary:
	var goods_classes: Array[String] = []
	var effect := registry.get_def("effects", str(blueprint.get("effect_id", "")))
	var secondary_effect := registry.get_def("effects", str(blueprint.get("secondary_effect_id", "")))
	for definition: Dictionary in [registry.get_def("bodies", str(blueprint.get("body_id", ""))), effect, secondary_effect, registry.get_def("materials", str(blueprint.get("material_id", ""))), registry.get_def("materials", str(blueprint.get("secondary_material_id", "")))]:
		_add_string_values(goods_classes, definition.get("goods_classes", []))
	for modifier_id: Variant in blueprint.get("modifier_ids", []):
		_add_string_values(goods_classes, registry.get_def("modifiers", str(modifier_id)).get("goods_classes", []))
	var coverage := _effect_profession_coverage(effect)
	if not secondary_effect.is_empty():
		_add_string_values(coverage, _effect_profession_coverage(secondary_effect))
	return {"goods_classes":goods_classes, "profession_coverage":coverage}

func _product_matches_contract(blueprint: Dictionary, product: Dictionary, contract: Dictionary) -> bool:
	if blueprint.is_empty() or int(product.get("quantity", 0)) <= 0 or float(product.get("average_quality", 0.0)) < float(contract.get("min_quality", 0.0)):
		return false
	var computed: Dictionary = blueprint.get("computed", {})
	return _arrays_overlap(computed.get("goods_classes", []), contract.get("accepted_classes", [])) and _contains_all(computed.get("profession_coverage", []), contract.get("required_coverage", []))

func _coverage_is_buildable(required_coverage: Variant) -> bool:
	for effect: Dictionary in unlocked_content("effects"):
		if _contains_all(_effect_profession_coverage(effect), required_coverage):
			return true
	return false

func _arrays_overlap(left: Variant, right: Variant) -> bool:
	if not left is Array or not right is Array:
		return false
	for value: Variant in left:
		if (right as Array).has(value):
			return true
	return false

func _contains_all(container: Variant, required: Variant) -> bool:
	if not container is Array or not required is Array:
		return false
	for value: Variant in required:
		if not (container as Array).has(value):
			return false
	return true

func _add_string_values(target: Array[String], source: Variant) -> void:
	if not source is Array:
		return
	for value: Variant in source:
		var text_value := str(value)
		if not text_value.is_empty() and not target.has(text_value):
			target.append(text_value)

func _foundation_profession(project: Dictionary) -> String:
	if int(project.get("tier", 0)) == 1 and (project.get("requires", []) as Array).is_empty() and not bool(project.get("hybrid", false)):
		return str(project.get("discipline", ""))
	return ""

func _research_prerequisites_met(project: Dictionary) -> bool:
	for requirement: Variant in project.get("requires", []):
		if not bool((state.unlocked as Dictionary).get(str(requirement), false)):
			return false
	var alternatives: Array = project.get("requires_any", [])
	if not alternatives.is_empty():
		var any_met := false
		for requirement: Variant in alternatives:
			if bool((state.unlocked as Dictionary).get(str(requirement), false)):
				any_met = true
				break
		if not any_met:
			return false
	return true

func _completed_foundation_professions() -> Array[String]:
	var result: Array[String] = []
	for project: Dictionary in registry.all("research"):
		var profession := _foundation_profession(project)
		if not profession.is_empty() and bool((state.unlocked as Dictionary).get(str(project.id), false)):
			result.append(profession)
	return result

func _refresh_contract_requirements(runtime: Dictionary, definition: Dictionary) -> void:
	for key: String in ["eligible_professions", "accepted_classes", "required_coverage", "customer", "tier", "min_faction_reputation", "faction_reputation_reward", "repeatable"]:
		if definition.has(key):
			runtime[key] = definition[key]

func _add_stats(target: Dictionary, source: Variant) -> void:
	if not source is Dictionary:
		return
	for key: Variant in (source as Dictionary).keys():
		target[str(key)] = float(target.get(str(key), 0)) + float((source as Dictionary)[key])

func _add_scaled_stats(target: Dictionary, source: Variant, factor: float) -> void:
	if not source is Dictionary:
		return
	for key: Variant in (source as Dictionary).keys():
		target[str(key)] = float(target.get(str(key), 0)) + float((source as Dictionary)[key]) * factor

func _scaled_multiplier(multiplier: float, factor: float) -> float:
	return 1.0 + (multiplier - 1.0) * factor

func _add_tags(target: Array, source: Variant) -> void:
	if not source is Array:
		return
	for tag: Variant in source:
		if not target.has(tag):
			target.append(tag)

func _add_journal(category: String, amount: float, description: String, emit_change: bool = true) -> void:
	var journal: Array = state.journal
	journal.push_front({"hour":state.hour, "category":category, "amount":amount, "description":description})
	if journal.size() > 150:
		journal.pop_back()
	if emit_change:
		state_changed.emit()

func _emit(kind: String, payload: Dictionary = {}) -> void:
	var event := {"type":kind, "hour":state.get("hour", 0), "payload":payload.duplicate(true)}
	recent_events.push_front(event)
	if recent_events.size() > 30:
		recent_events.pop_back()
	var logbook: Array = state.get("logbook", [])
	logbook.push_front(event.duplicate(true))
	if logbook.size() > 200:
		logbook.pop_back()
	state["logbook"] = logbook
	event_emitted.emit(event)

func _array_to_rect(data: Array) -> Rect2i:
	return Rect2i(int(data[0]), int(data[1]), int(data[2]), int(data[3]))

func _array_to_position(data: Array) -> Vector2i:
	return Vector2i(int(data[0]), int(data[1]))

func _result(ok: bool, message: String, extra: Dictionary = {}) -> Dictionary:
	var result := {"ok":ok, "message":message}
	result.merge(extra)
	return result
