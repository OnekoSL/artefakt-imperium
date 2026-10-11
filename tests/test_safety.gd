extends RefCounted

const RECIPE := {"name":"Regression", "body_id":"base:simple_charm", "effect_id":"base:minor_light", "modifier_ids":[], "material_id":"base:copper"}

static func run(registry: ContentRegistry, check: Callable) -> void:
	_test_restore(registry, check)
	_test_market(registry, check)
	_test_production(registry, check)
	_test_files(registry, check)
	_test_mods(check)

static func _new_sim(registry: ContentRegistry) -> GameSimulation:
	var simulation := GameSimulation.new(registry)
	simulation.new_game("base:first_sparks", 6060)
	return simulation

static func _test_restore(registry: ContentRegistry, check: Callable) -> void:
	var simulation := _new_sim(registry)
	var saved := simulation.serialize()
	var before := JSON.stringify(saved)
	var changes := [0]
	simulation.state_changed.connect(func() -> void: changes[0] += 1)
	var missing_cash := saved.duplicate(true)
	missing_cash.erase("cash")
	var invalid_cases: Array[Dictionary] = [missing_cash]
	for replacement: Dictionary in [{"inventory":{"base:copper":[]}}, {"inventory":{"base:copper":{"quantity":-1, "quality":0.5}}}, {"cash":NAN}, {"hour":1.5}, {"rooms":[{"id":"x", "type":"base:workshop", "rect":[0, 0]}]}, {"staff":[{"id":"base:elara", "station_id":"missing"}]}, {"raw_material_sales_today":[]}, {"logbook":[{"type":"ProductionSummary", "hour":0, "payload":{"products":[]}}]}, {"rng":[]}, {"scenario_id":"missing"}, {"rivals":{"missing":{}}}]:
		var invalid := saved.duplicate(true)
		invalid.merge(replacement, true)
		invalid_cases.append(invalid)
	for index: int in invalid_cases.size():
		var result := simulation.restore(invalid_cases[index])
		check.call(not bool(result.ok) and str(result.get("code", "")) == "corrupt" and not str(result.message).is_empty() and JSON.stringify(simulation.serialize()) == before and changes[0] == 0, "malformed save %d is rejected with no state or RNG changes" % index)
	var incompatible := saved.duplicate(true)
	incompatible.packages = []
	check.call(str(simulation.restore(incompatible).get("code", "")) == "incompatible_packages", "save package mismatch has a distinct error code")
	incompatible = saved.duplicate(true)
	incompatible.save_version = GameSimulation.SAVE_VERSION + 1
	check.call(str(simulation.restore(incompatible).get("code", "")) == "incompatible_version", "future save version has a distinct error code")
	var negative_cash := saved.duplicate(true)
	negative_cash.cash = -42.0
	negative_cash.rng.market = 0
	var result := simulation.restore(negative_cash)
	check.call(bool(result.ok) and changes[0] == 1 and simulation.state.cash == -42.0 and simulation.rng_market.state == 0, "valid restore commits once and preserves debt and zero RNG state")

static func _test_market(registry: ContentRegistry, check: Callable) -> void:
	var simulation := _new_sim(registry)
	var id := str(simulation.execute(GameCommand.create_blueprint(RECIPE)).blueprint_id)
	simulation.execute(GameCommand.configure_production("station_2", id))
	simulation.execute(GameCommand.set_production_enabled("station_2", true))
	simulation.execute(GameCommand.set_price(id, 9999.0))
	for hour: int in 24:
		simulation.tick()
	check.call(simulation.state.market_units_sold == 0 and simulation.state.products.has(id), "starter production finds no buyers at 9999 gold")
	var before := JSON.stringify(simulation.state.listings)
	for price: float in [NAN, INF, -INF, 0.001, -1.0]:
		check.call(not bool(simulation.execute(GameCommand.set_price(id, price)).ok) and JSON.stringify(simulation.state.listings) == before, "invalid or rounded-zero price is rejected without mutation: %s" % price)
	var customer := registry.get_def("customers", "base:citizens")
	var blueprint: Dictionary = simulation.state.blueprints[id]
	var product := {"quantity":100, "average_quality":60.0}
	check.call(simulation._customer_score(customer, blueprint, product, 1000.0) > simulation._customer_score(customer, blueprint, product, 9999.0), "affordability keeps declining beyond the former minimum")
	var market := _new_sim(registry)
	for index: int in 5:
		var blueprint_id := str(market.execute(GameCommand.create_blueprint(RECIPE)).blueprint_id)
		market.state.products[blueprint_id] = product.duplicate(true)
		market.execute(GameCommand.set_price(blueprint_id, 1.0))
	var reordered := _new_sim(registry)
	check.call(bool(reordered.restore(market.serialize()).ok), "market fixture restores")
	var ids: Array = reordered.state.listings.keys()
	ids.reverse()
	var listings: Dictionary = {}
	for key: String in ids:
		listings[key] = reordered.state.listings[key]
	reordered.state.listings = listings
	market._run_market()
	reordered._run_market()
	var capped := true
	for definition: Dictionary in registry.all("customers"):
		var report: Dictionary = market.state.market_report[definition.id]
		capped = capped and int(report.player_sales) <= int(report.demand)
	check.call(capped and float(market.state.market_report.player_share) <= 1.0, "duplicate offers share finite segment demand and cannot exceed 100 percent market share")
	check.call(JSON.stringify(market.state.products) == JSON.stringify(reordered.state.products) and market.rng_market.state == reordered.rng_market.state, "market allocation is independent of listing insertion order")

static func _test_production(registry: ContentRegistry, check: Callable) -> void:
	var costs: Array[float] = []
	for modifiers: Array in [[], ["base:economical"]]:
		var simulation := _new_sim(registry)
		var recipe := RECIPE.duplicate(true)
		recipe.modifier_ids = modifiers
		var id := str(simulation.execute(GameCommand.create_blueprint(recipe)).blueprint_id)
		simulation.execute(GameCommand.configure_production("station_2", id))
		simulation.execute(GameCommand.set_production_enabled("station_2", true))
		var cash_before := float(simulation.state.cash)
		simulation.tick()
		costs.append(cash_before - float(simulation.state.cash))
		check.call(int(simulation.state.inventory["base:copper"].quantity) == 10, "processing consumes two stocked materials without charging their purchase price")
	check.call(is_equal_approx(costs[0], 26.0) and is_equal_approx(costs[1], 16.0), "Economical lowers real reserved processing costs by ten gold")
	var simulation := _new_sim(registry)
	var id := str(simulation.execute(GameCommand.create_blueprint(RECIPE)).blueprint_id)
	var alternate := str(simulation.execute(GameCommand.create_blueprint(RECIPE)).blueprint_id)
	simulation.execute(GameCommand.configure_production("station_2", id))
	simulation.execute(GameCommand.set_production_enabled("station_2", true))
	simulation.state.cash = 25.0
	simulation.tick()
	check.call(simulation.state.cash == 25.0 and simulation.state.inventory["base:copper"].quantity == 12 and simulation.production_line_status("station_2").status == "no_cash", "stocked materials remain untouched when processing gold is missing")
	simulation.state.cash = 100.0
	simulation.tick()
	simulation.execute(GameCommand.set_production_enabled("station_2", false))
	var reserved := simulation.serialize()
	simulation.tick()
	check.call(simulation.state.cash == 74.0 and simulation.state.production_lines["station_2"].reserved_processing_cost == 26.0, "pause retains the processing reservation without another charge")
	var restored := _new_sim(registry)
	check.call(bool(restored.restore(reserved).ok), "reserved processing costs survive save restore")
	restored.execute(GameCommand.configure_production("station_2", alternate))
	restored.execute(GameCommand.configure_production("station_2", id))
	check.call(restored.state.cash == 100.0 and restored.state.inventory["base:copper"].quantity == 12 and is_zero_approx(float(restored.state.production_cost_today)), "switch refunds gold and materials exactly once")
	var legacy := reserved.duplicate(true)
	legacy.save_version = 8
	var rejected := _new_sim(registry)
	var before_rejection := JSON.stringify(rejected.serialize())
	check.call(not bool(rejected.restore(legacy).ok) and JSON.stringify(rejected.serialize()) == before_rejection, "pre-expansion reservation is rejected without changes")
	var finished := _new_sim(registry)
	finished.restore(reserved)
	var line: Dictionary = finished.state.production_lines["station_2"]
	var required := float(finished.state.blueprints[id].computed.hours)
	line.progress = required - finished._production_work_rate(finished._station_by_id("station_2"), finished._staff_for_station("station_2"))
	finished.execute(GameCommand.set_production_enabled("station_2", true))
	finished.tick()
	finished.execute(GameCommand.set_production_enabled("station_2", false))
	finished.execute(GameCommand.configure_production("station_2", alternate))
	check.call(finished.state.cash == 74.0 and finished.state.products[id].quantity == 1, "finished piece consumes the reservation and cannot refund it")
	finished._run_market()
	check.call(finished.state.market_report.production_cost == 26.0 and finished.state.market_report.operating_net == -26.0, "daily operating result includes actual processing cash flow")
	check.call(finished.expected_daily_operating_result() == -156.0, "forecast includes the previous day's processing estimate")
	var continuous := _new_sim(registry)
	continuous.restore(reserved)
	var roundtrip := _new_sim(registry)
	roundtrip.restore(JSON.parse_string(JSON.stringify(reserved)))
	continuous.execute(GameCommand.set_production_enabled("station_2", true))
	roundtrip.execute(GameCommand.set_production_enabled("station_2", true))
	for hour: int in 48:
		continuous.tick()
		roundtrip.tick()
	# JSON parses all numbers as floats; compare canonical JSON values, not Variant storage types.
	check.call(JSON.stringify(JSON.parse_string(JSON.stringify(continuous.serialize()))) == JSON.stringify(JSON.parse_string(JSON.stringify(roundtrip.serialize()))), "production and all RNG streams remain deterministic after disk-shaped roundtrip")

static func _write(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()

static func _test_files(registry: ContentRegistry, check: Callable) -> void:
	# A fresh directory avoids touching user slots even when this test runs repeatedly.
	var folder := "regression_%d" % Time.get_ticks_usec()
	var root := SaveSystem.SAVE_DIRECTORY.path_join(folder)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	# The public slot sanitizer disallows directories, so use unique flat slot names.
	var slot := folder + "_save"
	var path := SaveSystem.SAVE_DIRECTORY.path_join(slot + ".json")
	var simulation := _new_sim(registry)
	check.call(bool(SaveSystem.save_game(simulation, slot).ok), "first save is verified and loadable")
	simulation.state.cash = 1234.0
	check.call(bool(SaveSystem.save_game(simulation, slot).ok), "overwrite creates a verified previous generation")
	var loaded := _new_sim(registry)
	var result := SaveSystem.load_game(loaded, slot)
	check.call(bool(result.ok) and not bool(result.recovered_from_backup) and loaded.state.cash == 1234.0, "normal load prefers current save over backup")
	var good_backup := FileAccess.get_file_as_string(path + ".bak")
	var good_primary := FileAccess.get_file_as_string(path)
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path + ".bak.tmp"))
	check.call(not bool(SaveSystem.save_game(simulation, slot).ok) and FileAccess.get_file_as_string(path) == good_primary, "backup write failure preserves the current primary")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak.tmp"))
	_write(path, "{broken")
	result = SaveSystem.load_game(loaded, slot)
	check.call(bool(result.ok) and bool(result.get("recovered_from_backup", false)) and loaded.state.cash == 6500.0, "damaged JSON recovers the previous generation visibly")
	check.call(bool(SaveSystem.save_game(simulation, slot).ok) and FileAccess.get_file_as_string(path + ".bak") == good_backup, "saving over corrupt primary preserves the useful backup")
	var malformed := simulation.serialize()
	malformed.erase("cash")
	_write(path, JSON.stringify(malformed))
	result = SaveSystem.load_game(loaded, slot)
	check.call(bool(result.ok) and bool(result.get("recovered_from_backup", false)), "structurally damaged primary also recovers from backup")
	var incompatible := simulation.serialize()
	incompatible.packages = []
	_write(path, JSON.stringify(incompatible))
	var before := JSON.stringify(loaded.serialize())
	result = SaveSystem.load_game(loaded, slot)
	check.call(not bool(result.ok) and str(result.code) == "incompatible_packages" and JSON.stringify(loaded.serialize()) == before, "incompatible primary never silently falls back to older save")
	incompatible = simulation.serialize()
	incompatible.save_version = 999
	_write(path, JSON.stringify(incompatible))
	check.call(str(SaveSystem.load_game(loaded, slot).get("code", "")) == "incompatible_version", "unsupported primary version does not trigger backup fallback")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_write(path + ".tmp", "partial")
	result = SaveSystem.load_game(loaded, slot)
	check.call(bool(result.ok) and bool(result.get("recovered_from_backup", false)), "interrupted replacement with missing primary recovers backup and ignores temporary data")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	check.call(not bool(SaveSystem.save_game(simulation, slot).ok) and FileAccess.get_file_as_string(path + ".bak") == good_backup, "temporary write failure preserves the last valid save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path))
	check.call(not bool(SaveSystem.save_game(simulation, slot).ok), "blocked final destination reports replacement failure")
	result = SaveSystem.load_game(loaded, slot)
	check.call(bool(result.ok) and bool(result.get("recovered_from_backup", false)), "backup remains loadable after failed replacement")
	for suffix: String in ["", ".tmp", ".bak", ".bak.tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(root))

static func _test_mods(check: Callable) -> void:
	var root := "user://mods/regression_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	var manifest := {"id":"regression", "version":"1.0.0", "game_version":ContentRegistry.SUPPORTED_GAME_VERSION, "dependencies":["base"]}
	_write(root.path_join("manifest.json"), JSON.stringify(manifest))
	var entry := {"id":"regression:metal", "name_de":"Testmetall", "name_en":"Test metal", "price":5.0, "quality":0.5}
	var bad_stats := entry.duplicate(true)
	bad_stats.stats = []
	var bad_tags := entry.duplicate(true)
	bad_tags.tags = 1
	for malformed: Dictionary in [{"materials":{}}, {"materials":[bad_stats]}, {"materials":[bad_tags]}, {"properties":[{"id":"regression:lot", "name_de":"Test", "name_en":"Test", "grid_size":[1]}]}, {"materials":[{"id":"regression:missing_names"}]}]:
		_write(root.path_join("data.json"), JSON.stringify(malformed))
		var registry := ContentRegistry.new()
		check.call(not registry.load_all(true) and not registry.errors.is_empty() and str(registry.errors[0]).contains("data.json"), "malformed mod content returns file and field diagnostics without a script error")
	for material: Variant in [null, "", 42, "regression:missing"]:
		var body := {"id":"regression:body", "name_de":"Test", "name_en":"Test"}
		if material != null:
			body["base_material_id"] = material
		_write(root.path_join("data.json"), JSON.stringify({"bodies":[body]}))
		var body_registry := ContentRegistry.new()
		check.call(not body_registry.load_all(true) and not body_registry.errors.is_empty(), "body content requires a nonempty valid base material reference: %s" % str(material))
	_write(root.path_join("data.json"), JSON.stringify({"materials":[entry]}))
	for field: String in ["dependencies", "overrides", "priority"]:
		var malformed := manifest.duplicate(true)
		malformed[field] = {}
		_write(root.path_join("manifest.json"), JSON.stringify(malformed))
		var registry := ContentRegistry.new()
		check.call(not registry.load_all(true) and str(registry.errors[0]).contains(field), "malformed manifest %s is rejected before loading" % field)
	_write(root.path_join("manifest.json"), JSON.stringify(manifest))
	var valid_registry := ContentRegistry.new()
	check.call(valid_registry.load_all(true) and valid_registry.has_def("materials", "regression:metal"), "valid optional mod fields retain defaults")
	for filename: String in ["data.json", "manifest.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(root.path_join(filename)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(root))
