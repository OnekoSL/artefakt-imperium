class_name ContentRegistry
extends RefCounted

const Schema = preload("res://src/core/data_schema.gd")

const SUPPORTED_GAME_VERSION := "0.1.0"
const CONTENT_KEYS: PackedStringArray = [
	"disciplines", "goods_classes", "research", "bodies", "effects", "modifiers", "materials",
	"customers", "rivals", "rooms", "stations", "staff", "contracts",
	"resource_sources", "properties", "events", "scenarios"
]

var definitions: Dictionary = {}
var packages: Array[Dictionary] = []
var errors: PackedStringArray = []
var warnings: PackedStringArray = []

func load_all(include_user_mods: bool = true) -> bool:
	definitions.clear()
	packages.clear()
	errors.clear()
	warnings.clear()
	for key: String in CONTENT_KEYS:
		definitions[key] = {}
	var candidates: Array[Dictionary] = []
	_load_package_candidate("res://content/base", candidates)
	_scan_package_root("res://mods", candidates)
	if include_user_mods:
		_scan_package_root("user://mods", candidates)
	var ordered := _sort_packages(candidates)
	for package: Dictionary in ordered:
		_load_package_content(package)
	if errors.is_empty():
		_validate_references()
	return errors.is_empty()

func all(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var bucket: Dictionary = definitions.get(category, {})
	for value: Variant in bucket.values():
		result.append(value as Dictionary)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("id", "")) < str(b.get("id", "")))
	return result

func get_def(category: String, content_id: String) -> Dictionary:
	return (definitions.get(category, {}) as Dictionary).get(content_id, {})

func has_def(category: String, content_id: String) -> bool:
	return (definitions.get(category, {}) as Dictionary).has(content_id)

func package_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for package: Dictionary in packages:
		result.append({"id": package.id, "version": package.version})
	return result

func _scan_package_root(root: String, candidates: Array[Dictionary]) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	var folder := dir.get_next()
	while not folder.is_empty():
		if dir.current_is_dir() and not folder.begins_with("."):
			_load_package_candidate(root.path_join(folder), candidates)
		folder = dir.get_next()
	dir.list_dir_end()

func _load_package_candidate(path: String, candidates: Array[Dictionary]) -> void:
	var manifest_path := path.path_join("manifest.json")
	if not FileAccess.file_exists(manifest_path):
		return
	var parsed: Variant = _read_json(manifest_path)
	if not parsed is Dictionary:
		errors.append("Manifest ist kein Objekt: %s" % manifest_path)
		return
	var manifest: Dictionary = parsed
	var manifest_error := Schema.check(manifest, Schema.object({
		"id":"string", "version":"string", "game_version":"string", "priority":"integer",
		"dependencies":Schema.array("string"), "overrides":Schema.array("string")
	}, ["id", "version", "game_version"]), manifest_path)
	if not manifest_error.is_empty():
		errors.append(manifest_error)
		return
	for required: String in ["id", "version", "game_version"]:
		if str(manifest.get(required, "")).is_empty():
			errors.append("Manifest %s benötigt '%s'." % [manifest_path, required])
			return
	if str(manifest.game_version) != SUPPORTED_GAME_VERSION:
		errors.append("Paket %s ist für Spielversion %s statt %s." % [manifest.id, manifest.game_version, SUPPORTED_GAME_VERSION])
		return
	manifest["path"] = path
	manifest["priority"] = int(manifest.get("priority", 0))
	manifest["dependencies"] = manifest.get("dependencies", [])
	manifest["overrides"] = manifest.get("overrides", [])
	candidates.append(manifest)

func _sort_packages(candidates: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var remaining := candidates.duplicate(true)
	while not remaining.is_empty():
		var progressed := false
		remaining.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.priority) < int(b.priority))
		for package: Dictionary in remaining.duplicate():
			var ready := true
			for dependency: Variant in package.dependencies:
				var dep_id := str(dependency)
				if not result.any(func(item: Dictionary) -> bool: return str(item.id) == dep_id):
					if not candidates.any(func(item: Dictionary) -> bool: return str(item.id) == dep_id):
						errors.append("Paket %s: Abhängigkeit %s fehlt." % [package.id, dep_id])
					ready = false
					break
			if ready:
				result.append(package)
				remaining.erase(package)
				progressed = true
		if not progressed:
			if not remaining.is_empty():
				errors.append("Zyklische oder unerfüllbare Paketabhängigkeit: %s" % str(remaining.map(func(item: Dictionary) -> Variant: return item.id)))
			break
	return result

func _load_package_content(package: Dictionary) -> void:
	var data_path: String = str(package.path).path_join("data.json")
	if not FileAccess.file_exists(data_path):
		errors.append("Paket %s enthält keine data.json." % package.id)
		return
	var parsed: Variant = _read_json(data_path)
	if not parsed is Dictionary:
		errors.append("Ungültige data.json in Paket %s." % package.id)
		return
	var package_data: Dictionary = parsed
	for category: String in CONTENT_KEYS:
		var shape_error := Schema.check(package_data.get(category, []), Schema.array(_entry_schema(category)), "%s (%s).%s" % [data_path, package.id, category])
		if not shape_error.is_empty():
			errors.append(shape_error)
			return
	var declared_overrides: Array = package.overrides
	for category: String in CONTENT_KEYS:
		var entries: Array = package_data.get(category, [])
		for raw_entry: Variant in entries:
			if not raw_entry is Dictionary:
				errors.append("Paket %s/%s enthält einen ungültigen Eintrag." % [package.id, category])
				continue
			var entry: Dictionary = raw_entry.duplicate(true)
			var content_id := str(entry.get("id", ""))
			if content_id.is_empty() or not content_id.contains(":"):
				errors.append("Paket %s/%s: ID '%s' ist nicht namensräumig." % [package.id, category, content_id])
				continue
			var bucket: Dictionary = definitions[category]
			if bucket.has(content_id) and not declared_overrides.has(content_id):
				errors.append("ID-Kollision ohne override: %s" % content_id)
				continue
			entry["package_id"] = package.id
			bucket[content_id] = entry
	packages.append(package)

func _validate_references() -> void:
	for category: String in CONTENT_KEYS:
		for definition: Dictionary in all(category):
			for language_key: String in ["name_de", "name_en"]:
				if str(definition.get(language_key, "")).is_empty():
					errors.append("%s benötigt %s." % [definition.get("id", "?"), language_key])
	for project: Dictionary in all("research"):
		if not bool(project.get("general", false)):
			_validate_id(project, "discipline", "disciplines")
		for requirement: Variant in project.get("requires", []):
			if not has_def("research", str(requirement)):
				errors.append("%s referenziert fehlende Forschung %s." % [project.id, requirement])
		for requirement: Variant in project.get("requires_any", []):
			if not has_def("research", str(requirement)):
				errors.append("%s referenziert fehlende alternative Forschung %s." % [project.id, requirement])
		for unlock: Variant in project.get("unlocks", []):
			var found := false
			for category: String in ["bodies", "effects", "modifiers", "stations"]:
				found = found or has_def(category, str(unlock))
			if not found:
				errors.append("%s schaltet unbekannte ID %s frei." % [project.id, unlock])
	for effect: Dictionary in all("effects"):
		_validate_id(effect, "discipline", "disciplines")
		for profession: Variant in effect.get("profession_coverage", [effect.get("discipline", "")]):
			if not has_def("disciplines", str(profession)):
				errors.append("%s references unknown profession %s." % [effect.id, profession])
	for goods_class: Dictionary in all("goods_classes"):
		_validate_id(goods_class, "profession", "disciplines")
	for component_category: String in ["bodies", "effects", "modifiers", "materials"]:
		for component: Dictionary in all(component_category):
			for class_id: Variant in component.get("goods_classes", []):
				if not has_def("goods_classes", str(class_id)):
					errors.append("%s references unknown goods class %s." % [component.id, class_id])
	for modifier: Dictionary in all("modifiers"):
		if float(modifier.get("hours_multiplier", 1.0)) <= 0.0 or absf(float(modifier.get("quality_delta", 0.0))) > 100.0:
			errors.append("%s has invalid modifier effort or quality values." % modifier.get("id", "?"))
	for rival: Dictionary in all("rivals"):
		_validate_id(rival, "focus", "disciplines")
	for station: Dictionary in all("stations"):
		_validate_id(station, "room_type", "rooms")
		if str(station.get("kind", "")) == "storage" and int(station.get("capacity", 0)) <= 0:
			errors.append("%s requires a positive storage capacity." % station.get("id", "?"))
	for source: Dictionary in all("resource_sources"):
		_validate_id(source, "material", "materials")
		if float(source.get("max_reserve", 0)) <= 0 or float(source.get("daily_regen", 0)) < 0 or float(source.get("base_yield", 0)) <= 0:
			errors.append("%s requires positive source values." % source.get("id", "?"))
	for property: Dictionary in all("properties"):
		var grid: Array = property.get("grid_size", [])
		for multiplier_key: String in ["market_multiplier", "procurement_multiplier", "construction_multiplier", "hiring_multiplier"]:
			if float(property.get(multiplier_key, 0)) <= 0:
				errors.append("%s requires a positive %s." % [property.get("id", "?"), multiplier_key])
		for discipline_id: Variant in (property.get("research_multipliers", {}) as Dictionary).keys():
			if not has_def("disciplines", str(discipline_id)):
				errors.append("%s references unknown research discipline %s." % [property.get("id", "?"), discipline_id])
		if grid.size() != 2 or int(grid[0]) <= 0 or int(grid[1]) <= 0:
			errors.append("%s benötigt eine gültige grid_size." % property.get("id", "?"))
		for room_value: Variant in property.get("start_rooms", []):
			if room_value is Dictionary:
				_validate_id(room_value as Dictionary, "type", "rooms")
		for station_value: Variant in property.get("start_stations", []):
			if station_value is Dictionary:
				_validate_id(station_value as Dictionary, "type", "stations")
		for source_value: Variant in property.get("sources", []):
			if source_value is Dictionary:
				_validate_id(source_value as Dictionary, "type", "resource_sources")
				var material_id := str((source_value as Dictionary).get("material", ""))
				if not material_id.is_empty() and not has_def("materials", material_id):
					errors.append("%s enthält unbekanntes Quellenmaterial %s." % [property.get("id", "?"), material_id])
	for customer: Dictionary in all("customers"):
		for class_id: Variant in customer.get("preferred_classes", []):
			if not has_def("goods_classes", str(class_id)):
				errors.append("%s references unknown preferred goods class %s." % [customer.id, class_id])
	var requested_classes_by_profession: Dictionary = {}
	for profession: Dictionary in all("disciplines"):
		requested_classes_by_profession[str(profession.id)] = {}
	for contract: Dictionary in all("contracts"):
		_validate_id(contract, "customer", "customers")
		var eligible: Array = contract.get("eligible_professions", [])
		var accepted: Array = contract.get("accepted_classes", [])
		var coverage: Array = contract.get("required_coverage", [])
		if eligible.is_empty() or accepted.is_empty() or coverage.is_empty():
			errors.append("%s requires professions, accepted classes, and coverage." % contract.id)
		for profession_id: Variant in eligible + coverage:
			if not has_def("disciplines", str(profession_id)):
				errors.append("%s references unknown profession %s." % [contract.id, profession_id])
		for class_id: Variant in accepted:
			if not has_def("goods_classes", str(class_id)):
				errors.append("%s references unknown accepted goods class %s." % [contract.id, class_id])
				continue
			var owner_profession := str(get_def("goods_classes", str(class_id)).get("profession", ""))
			if eligible.has(owner_profession):
				(requested_classes_by_profession[owner_profession] as Dictionary)[str(class_id)] = true
		if int(contract.get("tier", 0)) not in [1, 2, 3] or int(contract.get("min_faction_reputation", -1)) < 0 or int(contract.get("faction_reputation_reward", 0)) <= 0:
			errors.append("%s requires valid contract tier and faction reputation values." % contract.id)
	for profession: Dictionary in all("disciplines"):
		var profession_id := str(profession.id)
		var defined_count := all("goods_classes").filter(func(item: Dictionary) -> bool: return str(item.get("profession", "")) == profession_id).size()
		var requested_count := (requested_classes_by_profession[profession_id] as Dictionary).size()
		if defined_count < 5 or defined_count > 8 or requested_count != defined_count:
			errors.append("%s requires 5-8 goods classes and every class must be requestable (%d defined, %d requested)." % [profession_id, defined_count, requested_count])
	var material_tags: Array = []
	for material: Dictionary in all("materials"):
		for tag: Variant in material.get("tags", []):
			if not material_tags.has(str(tag)):
				material_tags.append(str(tag))
	for event: Dictionary in all("events"):
		if not event.has("price_multiplier"):
			continue
		if float(event.get("price_multiplier", 0.0)) <= 0.0 or int(event.get("duration_days", 0)) <= 0 or int(event.get("start_day", 0)) <= 0:
			errors.append("%s requires positive material price event values." % event.get("id", "?"))
		var event_material := str(event.get("material", ""))
		var event_tag := str(event.get("material_tag", ""))
		if event_material.is_empty() and event_tag.is_empty():
			errors.append("%s requires a material or material_tag." % event.get("id", "?"))
		if not event_material.is_empty() and not has_def("materials", event_material):
			errors.append("%s references unknown material %s." % [event.get("id", "?"), event_material])
		if not event_tag.is_empty() and not material_tags.has(event_tag):
			errors.append("%s references unknown material tag %s." % [event.get("id", "?"), event_tag])
	for scenario: Dictionary in all("scenarios"):
		var victory: Dictionary = scenario.get("victory", {})
		var hybrid_contract := str(victory.get("hybrid_contract", ""))
		if not hybrid_contract.is_empty() and not has_def("contracts", hybrid_contract):
			errors.append("%s referenziert fehlenden Siegauftrag %s." % [scenario.id, hybrid_contract])

func _validate_id(owner: Dictionary, field: String, category: String) -> void:
	var target := str(owner.get(field, ""))
	if not target.is_empty() and not has_def(category, target):
		errors.append("%s.%s referenziert fehlende ID %s." % [owner.get("id", "?"), field, target])

func _entry_schema(category: String) -> Dictionary:
	var fields: Dictionary = {}
	for key: String in ["id", "name_de", "name_en", "color", "discipline", "profession", "focus", "room_type", "material", "customer", "specialty", "material_tag", "hint_de", "hint_en", "description_de", "description_en"]:
		fields[key] = "string"
	for key: String in ["general", "hybrid", "housing", "unlocked", "repeatable", "victory_contract"]:
		fields[key] = "bool"
	for key: String in ["requires", "requires_any", "unlocks", "profession_coverage", "goods_classes", "tags", "preferred_classes", "eligible_professions", "accepted_classes", "required_coverage"]:
		fields[key] = Schema.array("string")
	for key: String in ["base_cost", "quality_delta", "starting_cash"]:
		fields[key] = "number"
	for key: String in ["hourly_cost", "difficulty", "price", "cost_per_tile", "cost", "daily_regen", "research", "production_speed", "production_quality", "logistics", "salary", "min_reputation", "min_quality", "prestige", "reward", "min_faction_reputation", "faction_reputation_reward"]:
		fields[key] = Schema.number(0.0)
	for key: String in ["base_hours", "cost_hours", "hours_multiplier", "budget", "research_efficiency", "market_efficiency", "capacity", "base_yield", "max_reserve", "construction_multiplier", "hiring_multiplier", "market_multiplier", "procurement_multiplier", "price_multiplier", "demand_multiplier", "safety_multiplier"]:
		fields[key] = Schema.number(0.000001)
	for key: String in ["tier", "min_size", "quantity", "deadline_days", "duration_days", "start_day", "rescue_days"]:
		fields[key] = Schema.integer(1)
	for key: String in ["base_demand", "applicant_count", "seed"]:
		fields[key] = Schema.integer()
	fields["quality"] = Schema.number(0.0, 1.0)
	fields["kind"] = {"type":"string", "enum":["research", "production", "storage"]}
	fields["stats"] = Schema.map("number")
	fields["preferences"] = Schema.map("number")
	fields["research_multipliers"] = Schema.map(Schema.number(0.000001))
	fields["grid_size"] = Schema.array(Schema.integer(1), 2)
	fields["start_rooms"] = Schema.array(Schema.object({"id":"string", "type":"string", "rect":Schema.array(Schema.integer(), 4)}, ["id", "type", "rect"]))
	fields["start_stations"] = Schema.array(Schema.object({"id":"string", "type":"string", "position":Schema.array(Schema.integer(), 2)}, ["id", "type", "position"]))
	fields["sources"] = Schema.array(Schema.object({"id":"string", "type":"string", "material":"string", "position":Schema.array(Schema.integer(), 2), "quality_bonus":"number", "yield_multiplier":Schema.number(0.000001), "regen_multiplier":Schema.number(0.0)}, ["type", "position"]))
	fields["victory"] = Schema.object({"technology_tier":Schema.integer(1), "economic_cash":Schema.number(0.0), "economic_revenue_30d":Schema.number(0.0), "economic_share":Schema.number(0.0, 1.0), "hybrid_contract":"string"})
	var required: Array = ["id", "name_de", "name_en"]
	var category_required := {
		"goods_classes":["profession"], "effects":["discipline"], "rivals":["focus"],
		"stations":["room_type", "kind"], "resource_sources":["material", "max_reserve", "daily_regen", "base_yield"],
		"properties":["grid_size", "construction_multiplier", "hiring_multiplier", "market_multiplier", "procurement_multiplier"],
		"contracts":["customer", "quantity", "min_quality", "reward", "prestige", "deadline_days", "eligible_professions", "accepted_classes", "required_coverage", "tier", "min_faction_reputation", "faction_reputation_reward"]
	}
	required.append_array(category_required.get(category, []))
	for key: String in required:
		if fields.get(key) is String and fields[key] == "string":
			fields[key] = {"type":"string", "min_length":1}
	return Schema.object(fields, required)

func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("Datei kann nicht gelesen werden: %s" % path)
		return null
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK:
		errors.append("JSON-Fehler in %s, Zeile %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
