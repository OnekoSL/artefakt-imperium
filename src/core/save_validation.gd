extends RefCounted

const Schema = preload("res://src/core/data_schema.gd")

static func shape(data: Dictionary, version: int) -> String:
	var natural := Schema.integer()
	var positive := Schema.number(0.0)
	var strings := Schema.array("string")
	var event_payload := Schema.object({"products":Schema.map(natural), "project_id":"string", "rival_id":"string", "blueprint_id":"string", "material_id":"string", "contract_id":"string", "profession_id":"string", "quantity":natural, "total":natural, "orders":natural, "quality":"number", "revenue":"number", "old_level":"number", "new_level":"number", "path":"string"})
	var requirement := Schema.object({"material_id":"string", "quantity":Schema.integer(1), "quality_weight":Schema.number(0.000001)}, ["material_id", "quantity"])
	var computed := Schema.object({"stats":Schema.map("number"), "hours":Schema.number(0.000001), "difficulty":positive, "unit_cost":positive, "processing_cost":positive, "material_cost":positive, "material_id":"string", "material_per_unit":Schema.integer(1), "material_requirements":Schema.array(requirement), "goods_classes":strings, "profession_coverage":strings, "tags":strings, "quality_delta":"number", "component_breakdown":Schema.object({"modifiers":Schema.array(Schema.object({"id":"string", "stats":Schema.map("number"), "cost_delta":"number", "hours_multiplier":Schema.number(0.000001), "quality_delta":"number"}))})}, ["stats", "hours", "difficulty", "unit_cost", "material_id", "material_per_unit"])
	var blueprint := Schema.object({"id":"string", "name":"string", "body_id":"string", "effect_id":"string", "material_id":"string", "secondary_effect_id":"string", "secondary_material_id":"string", "modifier_ids":strings, "computed":computed}, ["id", "name", "body_id", "effect_id", "material_id", "computed"])
	var reservation := Schema.object({"material_id":"string", "quantity":Schema.integer(1), "quality":Schema.number(0.0, 1.0), "quality_weight":Schema.number(0.000001)}, ["material_id", "quantity", "quality"])
	var line := Schema.object({"blueprint_id":"string", "enabled":"bool", "progress":positive, "quality_work":positive, "material_reserved":"bool", "reserved_processing_cost":positive, "reserved_materials":Schema.array(reservation), "material_id":"string", "material_quantity":natural, "material_quality":Schema.number(0.0, 1.0)}, ["blueprint_id"])
	if version >= 9:
		(line.required as Array).append_array(["enabled", "progress", "quality_work", "material_reserved", "reserved_processing_cost", "reserved_materials"])
	var contract_fields := {"id":"string", "name_de":"string", "name_en":"string", "customer":"string", "quantity":Schema.integer(1), "min_quality":positive, "reward":positive, "prestige":positive, "deadline_days":Schema.integer(1), "deadline_day":Schema.integer(1), "appeared_day":Schema.integer(1), "accepted_day":Schema.integer(1), "tier":Schema.integer(1, 3), "faction_reputation_reward":positive, "min_faction_reputation":positive, "eligible_professions":strings, "accepted_classes":strings, "required_coverage":strings}
	var contract := Schema.object(contract_fields, ["id", "customer", "quantity", "min_quality", "reward", "prestige"])
	if version >= 9:
		(contract.required as Array).append_array(["deadline_day", "appeared_day", "deadline_days"])
	var fields := {
		"save_version":Schema.integer(1), "scenario_id":"string", "property_id":"string", "seed":"integer", "hour":natural, "paused":"bool", "speed":Schema.integer(1, 4), "cash":"number", "reputation":positive,
		"player_profession":"string", "profession_choice_required":"bool", "faction_reputation":Schema.map(positive), "lifetime_revenue":positive, "artifact_revenue":positive, "raw_material_revenue":positive, "market_units_sold":natural, "revenue_history":Schema.array(positive),
		"wage_level":Schema.number(0.8, 1.2), "pending_wage_level":Schema.number(0.8, 1.2), "research_cost_today":positive, "production_cost_today":"number", "last_wages_paid":positive, "last_interest_paid":positive,
		"inventory":Schema.map(Schema.object({"quantity":natural, "quality":Schema.number(0.0, 1.0)}, ["quantity", "quality"])),
		"raw_material_sales_today":Schema.map(Schema.object({"manual_units":natural, "automatic_units":natural, "manual_revenue":positive, "automatic_revenue":positive, "quality_work":positive})),
		"unlocked":Schema.map("bool"), "research_progress":Schema.map(positive), "active_research":"string", "research_ramp":natural,
		"blueprints":Schema.map(blueprint), "next_blueprint":Schema.integer(1), "production_lines":Schema.map(line), "production_today":Schema.map(Schema.map(natural)),
		"products":Schema.map(Schema.object({"quantity":natural, "average_quality":Schema.number(0.0, 100.0), "unit_cost":positive}, ["quantity", "average_quality"])),
		"listings":Schema.map(Schema.object({"price":Schema.number(0.01), "enabled":"bool"}, ["price"])),
		"rooms":Schema.array(Schema.object({"id":"string", "type":"string", "rect":Schema.array(natural, 4)}, ["id", "type", "rect"])),
		"stations":Schema.array(Schema.object({"id":"string", "type":"string", "position":Schema.array(natural, 2)}, ["id", "type", "position"])),
		"sources":Schema.array(Schema.object({"id":"string", "type":"string", "material":"string", "position":Schema.array("integer", 2), "reserve":positive, "offsite":"bool", "quality_bonus":"number", "yield_multiplier":positive, "regen_multiplier":positive, "last_harvest":natural}, ["id", "type", "position"])),
		"next_room":Schema.integer(1), "next_station":Schema.integer(1), "staff":Schema.array(Schema.object({"id":"string", "station_id":"string", "assignment":"string"}, ["id"])), "applicants":strings, "next_applicant_refresh_day":natural, "dismissed_until":Schema.map(natural),
		"rivals":Schema.map(Schema.object({"cash":"number", "reputation":positive, "research_progress":Schema.map(positive), "unlocked":Schema.map("bool"), "active_research":"string", "market_share":Schema.number(0.0, 1.0), "last_action":"string"}, ["cash", "reputation", "research_progress", "unlocked", "active_research", "market_share", "last_action"])),
		"active_contracts":Schema.map(contract), "available_contracts":Schema.map(contract), "contract_offer_cooldowns":Schema.map(natural), "completed_contracts":strings,
		"insolvency_since":Schema.integer(-1), "loan_balance":positive, "victory":{"type":"string", "enum":["", "master", "merchant", "researcher"]}, "defeat":"bool",
		"market_report":Schema.object({"player_share":positive, "daily_revenue":positive, "artifact_revenue":positive, "raw_material_revenue":positive, "manual_raw_material_revenue":positive, "automatic_raw_material_revenue":positive, "wages":positive, "research_cost":positive, "interest":positive, "production_cost":"number", "operating_net":"number"}),
		"active_races":Schema.map(Schema.object({"project_id":"string", "rival_id":"string", "started_hour":natural, "winner":"string", "finished_hour":natural}, ["project_id", "rival_id", "started_hour"])),
		"journal":Schema.array(Schema.object({"hour":natural, "category":"string", "amount":"number", "description":"string"}, ["hour", "category", "amount", "description"])),
		"logbook":Schema.array(Schema.object({"type":"string", "hour":natural, "payload":event_payload}, ["type", "hour", "payload"])),
		"packages":Schema.array(Schema.object({"id":"string", "version":"string"}, ["id", "version"])),
		"rng":Schema.object({"quality":natural, "market":natural, "rivals":natural, "staff":natural, "contracts":natural}, ["quality", "market", "rivals"]),
		"production_queue":Schema.array(Schema.object({"blueprint_id":"string", "quantity":Schema.integer(1), "material_quality":Schema.number(0.0, 1.0)}, ["blueprint_id", "quantity"]))
	}
	var team := Schema.object({"project_id":"string", "ramp":Schema.integer(0, 12)}, ["project_id", "ramp"])
	fields["research_teams"] = Schema.array(team)
	fields["station_teams"] = Schema.map(Schema.integer(0, 1))
	fields["pending_breakthroughs"] = Schema.map("bool")
	fields["focus_branch"] = "string"
	fields["focus_chosen"] = "bool"
	fields["focus_change"] = Schema.object({"branch_id":"string", "team_id":Schema.integer(0, 1), "progress":positive})
	fields["company_level"] = Schema.integer(1, 5)
	fields["regular_contracts_completed"] = natural
	fields["breakthroughs_completed"] = natural
	fields["victories"] = Schema.map(Schema.integer(1))
	fields["master_project"] = Schema.object({"project_id":"string", "family_effect":"string", "sales":natural, "deadline_day":natural, "started_hour":natural})
	fields["researcher_project"] = Schema.object({"project_id":"string", "demonstrated":"bool"})
	fields["merchant_history"] = Schema.array(Schema.object({"day":Schema.integer(1), "revenue":positive, "net":"number", "customers":Schema.map(natural)}, ["day", "revenue", "net", "customers"]))
	var required: Array = ["save_version", "scenario_id", "seed", "hour", "paused", "speed", "cash", "reputation", "lifetime_revenue", "revenue_history", "inventory", "unlocked", "research_progress", "active_research", "research_ramp", "blueprints", "next_blueprint", "products", "listings", "rooms", "stations", "staff", "rivals", "active_contracts", "completed_contracts", "insolvency_since", "loan_balance", "victory", "defeat", "market_report", "active_races", "journal", "packages", "rng"]
	if version >= 9:
		required.append_array(["property_id", "sources", "next_room", "next_station", "production_lines", "production_today", "production_cost_today", "research_cost_today", "wage_level", "pending_wage_level", "player_profession", "profession_choice_required", "faction_reputation", "available_contracts", "contract_offer_cooldowns", "market_units_sold", "applicants", "dismissed_until", "next_applicant_refresh_day", "logbook"])
		(fields.rng.required as Array).append_array(["staff", "contracts"])
	if version >= 10:
		required.append_array(["research_teams", "station_teams", "pending_breakthroughs", "focus_branch", "focus_chosen", "focus_change", "company_level", "regular_contracts_completed", "breakthroughs_completed", "victories", "master_project", "researcher_project", "merchant_history"])
	var error := Schema.check(data, Schema.object(fields, required), "Spielstand")
	if not error.is_empty():
		return error
	if version >= 10:
		for field: String in ["focus_change", "master_project", "researcher_project"]:
			var mandatory: Dictionary = {"focus_change":["branch_id", "team_id", "progress"], "master_project":["project_id", "family_effect", "sales", "deadline_day", "started_hour"], "researcher_project":["project_id", "demonstrated"]}
			if not (data[field] as Dictionary).is_empty():
				for key: String in mandatory[field]:
					if not data[field].has(key):
						return field + "." + key + ": Pflichtfeld fehlt."
	for key: String in data.market_report:
		if key.contains(":"):
			error = Schema.check(data.market_report[key], Schema.object({"demand":natural, "player_sales":natural}, ["demand", "player_sales"]), "market_report." + key)
			if not error.is_empty():
				return error
	return ""

static func references(data: Dictionary, registry: ContentRegistry, version: int) -> String:
	if version >= 10:
		var expansion_error := _expansion_references(data, registry)
		if not expansion_error.is_empty():
			return expansion_error
	var direct := {"scenario_id":"scenarios", "property_id":"properties", "player_profession":"disciplines", "active_research":"research"}
	for field: String in direct:
		var target := str(data.get(field, ""))
		if not target.is_empty() and not registry.has_def(direct[field], target):
			return field + ": Unbekannte ID " + target
	for field: String in ["inventory", "research_progress", "rivals", "active_contracts", "available_contracts", "contract_offer_cooldowns", "faction_reputation", "dismissed_until"]:
		var category: String = {"inventory":"materials", "research_progress":"research", "rivals":"rivals", "active_contracts":"contracts", "available_contracts":"contracts", "contract_offer_cooldowns":"contracts", "faction_reputation":"customers", "dismissed_until":"staff"}[field]
		for id: String in data.get(field, {}):
			if not registry.has_def(category, id):
				return field + "." + id + ": Unbekannte ID."
	for field: String in ["applicants", "completed_contracts"]:
		for id: String in data.get(field, []):
			if not registry.has_def("staff" if field == "applicants" else "contracts", id):
				return field + ": Unbekannte ID " + id
	for id: String in data.unlocked:
		var found := false
		for category: String in ["research", "bodies", "effects", "modifiers", "stations"]:
			found = found or registry.has_def(category, id)
		if not found:
			return "unlocked." + id + ": Unbekannte ID."
	for id: String in data.blueprints:
		var blueprint: Dictionary = data.blueprints[id]
		if str(blueprint.id) != id:
			return "blueprints." + id + ".id: Widersprüchliche ID."
		for field: String in ["body_id", "effect_id", "material_id", "secondary_effect_id", "secondary_material_id"]:
			var target := str(blueprint.get(field, ""))
			var category := "bodies" if field == "body_id" else ("effects" if field.contains("effect") else "materials")
			if (field in ["body_id", "effect_id", "material_id"] or not target.is_empty()) and not registry.has_def(category, target):
				return "blueprints." + id + "." + field + ": Unbekannte ID."
		var base_material := str(registry.get_def("bodies", str(blueprint.body_id)).get("base_material_id", ""))
		if str(blueprint.material_id) != base_material or not str(blueprint.get("secondary_material_id", "")).is_empty():
			return "blueprints." + id + ": Ungültige Basismaterialzuordnung."
		var computed: Dictionary = blueprint.computed
		var requirements: Array = computed.get("material_requirements", [])
		if str(computed.material_id) != base_material or int(computed.material_per_unit) != 2 or requirements.size() != 1:
			return "blueprints." + id + ": Ungültiger Materialbedarf."
		if str(requirements[0].material_id) != base_material or int(requirements[0].quantity) != 2 or not is_equal_approx(float(requirements[0].get("quality_weight", 0)), 2.0):
			return "blueprints." + id + ": Widersprüchlicher Materialbedarf."
		for modifier: String in blueprint.get("modifier_ids", []):
			if not registry.has_def("modifiers", modifier):
				return "blueprints." + id + ".modifier_ids: Unbekannte ID."
	var stations: Dictionary = {}
	var room_rects: Array[Rect2i] = []
	var property_id := str(data.get("property_id", "base:outskirts"))
	var grid: Array = registry.get_def("properties", property_id).get("grid_size", [20, 12])
	var bounds := Rect2i(0, 0, int(grid[0]), int(grid[1]))
	for field: String in ["rooms", "stations", "sources", "staff"]:
		var seen: Dictionary = {}
		for entry: Dictionary in data.get(field, []):
			var id := str(entry.id)
			if id.is_empty() or seen.has(id):
				return field + ": Leere oder doppelte ID " + id
			seen[id] = true
			var category := "resource_sources" if field == "sources" else field
			if not registry.has_def(category, str(entry.id if field == "staff" else entry.type)):
				return field + "." + id + ": Unbekannte Inhaltsreferenz."
			if field == "rooms":
				var r: Array = entry.rect
				var rect := Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
				if rect.size.x <= 0 or rect.size.y <= 0 or not bounds.encloses(rect):
					return "rooms." + id + ".rect: Ungültige Raumgrenzen."
				for other: Rect2i in room_rects:
					if rect.intersects(other):
						return "rooms." + id + ".rect: Überlappende Räume."
				room_rects.append(rect)
			if field == "stations":
				stations[id] = entry
				var position := Vector2i(int(entry.position[0]), int(entry.position[1]))
				var room_type := str(registry.get_def("stations", str(entry.type)).room_type)
				var found := false
				for room: Dictionary in data.rooms:
					var rect := Rect2i(int(room.rect[0]), int(room.rect[1]), int(room.rect[2]), int(room.rect[3]))
					found = found or (str(room.type) == room_type and rect.has_point(position))
				if not found:
					return "stations." + id + ".position: Kein passender Raum."
	var occupied: Dictionary = {}
	var station_cells: Dictionary = {}
	for id: String in stations:
		var cell := str(stations[id].position)
		if station_cells.has(cell):
			return "stations." + id + ".position: Doppelt belegtes Feld."
		station_cells[cell] = true
	for staff: Dictionary in data.staff:
		var station := str(staff.get("station_id", ""))
		if not station.is_empty():
			if not stations.has(station) or occupied.has(station):
				return "staff." + str(staff.id) + ".station_id: Unbekannte oder doppelt besetzte Station."
			occupied[station] = true
	for field: String in ["products", "listings"]:
		for id: String in data[field]:
			if not data.blueprints.has(id):
				return field + "." + id + ": Bauplan fehlt."
	for station_id: String in data.get("production_lines", {}):
		var line: Dictionary = data.production_lines[station_id]
		if not stations.has(station_id) or not data.blueprints.has(str(line.blueprint_id)):
			if version >= 9:
				return "production_lines." + station_id + ": Station oder Bauplan fehlt."
			continue
		if str(registry.get_def("stations", str(stations[station_id].type)).get("kind", "")) != "production":
			return "production_lines." + station_id + ": Keine Produktionsstation."
		var hours := float(data.blueprints[line.blueprint_id].computed.hours)
		if float(line.get("progress", 0.0)) > hours:
			return "production_lines." + station_id + ".progress: Fortschritt überschreitet Stückaufwand."
		if not bool(line.get("material_reserved", false)) and (float(line.get("reserved_processing_cost", 0.0)) != 0.0 or float(line.get("progress", 0.0)) != 0.0):
			return "production_lines." + station_id + ": Fortschritt oder Kosten ohne Reservierung."
		for reservation: Dictionary in line.get("reserved_materials", []):
			if not registry.has_def("materials", str(reservation.material_id)):
				return "production_lines." + station_id + ".reserved_materials: Unbekanntes Material."
		if bool(line.get("material_reserved", false)) and version >= 9 and (line.get("reserved_materials", []) as Array).is_empty():
			return "production_lines." + station_id + ": Reserviertes Material fehlt."
		if bool(line.get("material_reserved", false)):
			var reservations: Array = line.get("reserved_materials", [])
			var material_id := str(data.blueprints[line.blueprint_id].material_id)
			if reservations.size() != 1 or str(reservations[0].material_id) != material_id or int(reservations[0].quantity) != 2 or not is_equal_approx(float(reservations[0].get("quality_weight", 0)), 2.0):
				return "production_lines." + station_id + ": Reservierung widerspricht dem Basismaterial."
			if str(line.get("material_id", "")) != material_id or int(line.get("material_quantity", 0)) != 2:
				return "production_lines." + station_id + ": Widersprüchliche Materialreservierung."
	for source: Dictionary in data.get("sources", []):
		var material := str(source.get("material", registry.get_def("resource_sources", str(source.type)).get("material", "")))
		if not registry.has_def("materials", material):
			return "sources." + str(source.id) + ".material: Unbekannte ID."
	for id: String in data.rivals:
		var rival: Dictionary = data.rivals[id]
		var projects: Array = (rival.research_progress as Dictionary).keys() + (rival.unlocked as Dictionary).keys()
		if not str(rival.active_research).is_empty():
			projects.append(rival.active_research)
		for project: String in projects:
			if not registry.has_def("research", project):
				return "rivals." + id + ": Unbekannte Forschung " + project
	for id: String in data.active_races:
		var race: Dictionary = data.active_races[id]
		if not registry.has_def("research", str(race.project_id)) or not data.rivals.has(str(race.rival_id)):
			return "active_races." + id + ": Unbekannte Forschung oder Rivalenreferenz."
	for field: String in ["active_contracts", "available_contracts"]:
		for id: String in data.get(field, {}):
			var contract: Dictionary = data[field][id]
			if str(contract.id) != id or not registry.has_def("customers", str(contract.customer)):
				return field + "." + id + ": Ungültige Auftragsreferenz."
			for reference: String in ["eligible_professions", "required_coverage", "accepted_classes"]:
				for target: String in contract.get(reference, []):
					if not registry.has_def("goods_classes" if reference == "accepted_classes" else "disciplines", target):
						return field + "." + id + "." + reference + ": Unbekannte ID."
	for station_id: String in data.get("production_today", {}):
		if not stations.has(station_id):
			return "production_today." + station_id + ": Station fehlt."
		for blueprint_id: String in data.production_today[station_id]:
			if not data.blueprints.has(blueprint_id):
				return "production_today." + station_id + ": Bauplan fehlt."
	for entry: Dictionary in data.get("production_queue", []):
		if not data.blueprints.has(str(entry.blueprint_id)):
			return "production_queue: Bauplan fehlt."
	return ""

static func _expansion_references(data: Dictionary, registry: ContentRegistry) -> String:
	var teams: Array = data.research_teams
	if teams.is_empty() or teams.size() > 2 or (teams.size() == 2 and not bool(data.unlocked.get("base:second_team", false))):
		return "research_teams: Ungültige Teamzahl."
	var active: Dictionary = {}
	for team: Dictionary in teams:
		var id := str(team.project_id)
		if id.is_empty():
			continue
		if not registry.has_def("research", id) or active.has(id) or bool(data.unlocked.get(id, false)) or data.pending_breakthroughs.has(id):
			return "research_teams: Ungültiges oder doppelt zugewiesenes Projekt."
		active[id] = true
	if str(data.active_research) != str(teams[0].project_id) or int(data.research_ramp) != int(teams[0].ramp):
		return "research_teams: Widersprüchlicher Hauptteamzustand."
	for station_id: String in data.station_teams:
		var matches: Array = (data.stations as Array).filter(func(station: Dictionary) -> bool: return str(station.id) == station_id)
		if matches.is_empty() or int(data.station_teams[station_id]) >= teams.size() or str(registry.get_def("stations", str(matches[0].type)).get("kind", "")) != "research":
			return "station_teams: Forschertisch oder Team fehlt."
	for id: String in data.pending_breakthroughs:
		var project := registry.get_def("research", id)
		if project.is_empty() or (project.get("proofs", []) as Array).is_empty() or bool(data.unlocked.get(id, false)) or not bool(data.pending_breakthroughs[id]) or float(data.research_progress.get(id, 0)) < float(project.cost_hours):
			return "pending_breakthroughs: Ungültiger wartender Durchbruch."
	var branches: Dictionary = {}
	for project: Dictionary in registry.all("research"):
		if str(project.get("track", "")) == "branch" and int(project.tier) == 2 and bool(data.unlocked.get(str(project.id), false)):
			branches[str(project.branch)] = true
	if not str(data.focus_branch).is_empty() and (not branches.has(str(data.focus_branch)) or not bool(data.focus_chosen)):
		return "focus_branch: Fachrichtung nicht verfügbar."
	if not data.focus_change.is_empty():
		var change: Dictionary = data.focus_change
		var config: Dictionary = registry.get_def("scenarios", str(data.scenario_id)).get("focus", {})
		if not branches.has(str(change.branch_id)) or int(change.team_id) >= teams.size() or not str(teams[int(change.team_id)].project_id).is_empty() or not str(data.focus_branch).is_empty() or not bool(data.focus_chosen) or float(change.progress) >= float(config.get("work", 0)):
			return "focus_change: Ungültige Umstellung."
	for path: String in data.victories:
		if path not in ["master", "merchant", "researcher"]:
			return "victories: Unbekannter Siegpfad."
	if not str(data.victory).is_empty() and (not data.victories.has(str(data.victory)) or not bool(data.paused)):
		return "victory: Ungültiger Sieghinweis."
	for field: String in ["master_project", "researcher_project"]:
		var final: Dictionary = data[field]
		if final.is_empty():
			continue
		var project := registry.get_def("research", str(final.project_id))
		if not bool(data.unlocked.get(str(final.project_id), false)) or not bool(project.get("capstone" if field == "master_project" else "convergence", false)):
			return field + ": Abschlussforschung fehlt."
		if field == "master_project" and str(final.family_effect) != str(project.family_effect):
			return field + ": Falsche Produktfamilie."
		if field == "researcher_project" and not bool(final.demonstrated):
			return field + ": Demonstration fehlt."
	var config: Dictionary = registry.get_def("scenarios", str(data.scenario_id)).get("victory", {})
	if (data.merchant_history as Array).size() > int(config.get("merchant_days", 30)):
		return "merchant_history: Zu viele Tage."
	if not (data.merchant_history as Array).is_empty() and not bool(data.unlocked.get("base:trade_mastery", false)):
		return "merchant_history: Handelsmeisterschaft fehlt."
	var previous := -1
	for day: Dictionary in data.merchant_history:
		if previous >= 0 and int(day.day) != previous + 1:
			return "merchant_history: Tage nicht aufeinanderfolgend."
		if int(day.day) > int(data.hour) / 24 + 1:
			return "merchant_history: Tagesbericht aus der Zukunft."
		previous = int(day.day)
		for id: String in day.customers:
			if not registry.has_def("customers", id):
				return "merchant_history: Kundengruppe fehlt."
	return ""
