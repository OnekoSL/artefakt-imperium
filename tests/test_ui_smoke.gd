extends SceneTree
## Rendered UI smoke test; run with a graphical renderer and isolated APPDATA.

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://ui_smoke"))
	root.get_texture().get_image().save_png("user://ui_smoke/de_start_slots.png")
	var start_buttons: Array[Node] = ui.start_content.find_children("*", "Button", true, false)
	_check(start_buttons.size() == 10 and start_buttons.all(func(node: Node) -> bool: return (node as Control).get_global_rect().end.y <= 720), "all current and legacy save slots fit the start menu at 1280x720")
	ui._start_new_game("base:outskirts")
	ui.simulation.set_paused(true)
	await process_frame
	var legacy: Dictionary = ui.simulation.serialize()
	legacy.save_version = 10
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves"))
	var legacy_text := JSON.stringify(legacy)
	var legacy_file := FileAccess.open("user://saves/manual_0_3.json", FileAccess.WRITE)
	legacy_file.store_string(legacy_text)
	legacy_file.close()
	_press(ui, ui._t("save"))
	_press(ui, "Quick")
	_check(FileAccess.file_exists("user://saves/manual_0_3_1.json") and FileAccess.file_exists("user://saves/quick_0_3_1.json"), "save controls use the new 0.3.1 slots")
	_check(FileAccess.get_file_as_string("user://saves/manual_0_3.json") == legacy_text, "saving leaves the legacy slot unchanged")
	var before_load := JSON.stringify(ui.simulation.serialize())
	_check(str(SaveSystem.load_game(ui.simulation, "manual_0_3").get("code", "")) == "incompatible_version" and JSON.stringify(ui.simulation.serialize()) == before_load, "legacy disk save is rejected without changing the running game")
	await process_frame
	await _test_fixed_material_controls(ui)
	ui.tabs.current_tab = 2
	ui._refresh_current_tab()
	await process_frame
	_press(ui, ui._t("create"))
	_check(ui.simulation.state.blueprints.size() == 1, "blueprint button creates a recipe")
	if ui.simulation.state.blueprints.is_empty():
		quit(1)
		return
	var blueprint_id := str(ui.simulation.state.blueprints.keys()[0])
	ui.tabs.current_tab = 3
	ui._refresh_current_tab()
	await process_frame
	# The production card's controls route actions through GameCommand.
	var selectors: Array[Node] = ui.tab_roots["production"].find_children("*", "OptionButton", true, false)
	if not selectors.is_empty():
		var selector: OptionButton = selectors[0]
		for index: int in selector.item_count:
			if str(selector.get_item_metadata(index)) == blueprint_id:
				selector.select(index)
				selector.item_selected.emit(index)
				break
	await process_frame
	_press(ui, "Starten")
	ui.simulation.set_paused(false)
	for hour: int in 24:
		ui.simulation.tick()
	ui.simulation.set_paused(true)
	_check(not ui.simulation.state.production_lines.is_empty(), "production selector configures a station")
	_check(float(ui.simulation.state.market_report.get("production_cost", 0.0)) > 0.0, "production start reserves processing costs")
	_check(bool(SaveSystem.save_game(ui.simulation, "ui_smoke").ok), "UI fixture saves")
	var cash := float(ui.simulation.state.cash)
	ui._load_slot("ui_smoke")
	_check(float(ui.simulation.state.cash) == cash, "UI load preserves cash and refreshes tabs")
	var screenshot_root := "user://ui_smoke"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(screenshot_root))
	for language: String in ["de", "en"]:
		if ui.language != language:
			ui._toggle_language()
		for tab_index: int in [0, 1, 2, 3, 6, 9]:
			ui.tabs.current_tab = tab_index
			ui._refresh_current_tab()
			await process_frame
			await process_frame
			if tab_index == 1:
				var focus_label: Label = ui.tab_roots["research"].find_child("FocusLabel", true, false)
				_check(focus_label.size.y < 65, "focus label remains a readable horizontal line")
			await RenderingServer.frame_post_draw
			var path := screenshot_root.path_join("%s_%d.png" % [language, tab_index])
			root.get_texture().get_image().save_png(path)
			print("UI_SCREENSHOT ", ProjectSettings.globalize_path(path))
	# Keep trading columns aligned even when a material has a market event.
	var previous_hour := int(ui.simulation.state.hour)
	ui.simulation.state.hour = 17 * 24
	for language: String in ["de", "en"]:
		if ui.language != language:
			ui._toggle_language()
		ui.tabs.current_tab = 4
		ui._refresh_current_tab()
		await process_frame
		await process_frame
		var warehouse: Control = ui.tab_roots["warehouse"]
		_check(warehouse.find_children("*", "SpinBox", true, false).is_empty(), "warehouse has no manual raw material quantity controls")
		_check(not warehouse.find_children("*", "Button", true, false).any(func(node: Node) -> bool: return (node as Button).text in ["Kaufen", "Verkaufen", "Buy", "Sell"]), "warehouse has no manual trading buttons")
		var price_columns := warehouse.find_children("MaterialPrices", "VBoxContainer", true, false)
		var event_labels := warehouse.find_children("MaterialEvent", "Label", true, false)
		_check(price_columns.size() == ui.registry.all("materials").size(), "every raw material has a dedicated price column")
		_check(not event_labels.is_empty(), "warehouse fixture displays active price events")
		var aligned := true
		var readable := true
		for column: Control in price_columns:
			aligned = aligned and is_equal_approx(column.global_position.x, (price_columns[0] as Control).global_position.x)
			for price_label: Label in column.get_children():
				readable = readable and price_label.get_line_count() == 1 and price_label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING
		_check(aligned and readable, "buy and sell prices stay complete and aligned in " + language)
		for event_label: Label in event_labels:
			_check(event_label.size.x > 600 and event_label.get_line_count() == 1, "market event has a full readable line")
		var scroll: ScrollContainer = ui.tabs.get_child(4)
		if not event_labels.is_empty():
			scroll.ensure_control_visible(event_labels.back())
		await process_frame
		await RenderingServer.frame_post_draw
		var warehouse_path := screenshot_root.path_join(language + "_warehouse.png")
		root.get_texture().get_image().save_png(warehouse_path)
		print("UI_SCREENSHOT ", ProjectSettings.globalize_path(warehouse_path))
	ui.simulation.state.hour = previous_hour
	_check(str(ui._blueprint_cost_text(ui.simulation.preview_blueprint(ui.simulation.state.blueprints[blueprint_id]))).contains("Processing"), "English cost breakdown is localized")
	# Exercise new controls through the actual rendered UI.
	ui.tabs.current_tab = 1
	ui.research_group = "base:arcane"
	ui.selected_research = "base:arcane_foundations"
	ui.research_filter = "all"
	ui._refresh_current_tab()
	await process_frame
	_press(ui, "Start: Team 1")
	_check(str(ui.simulation.state.research_teams[0].project_id) == "base:arcane_foundations", "research detail starts a team through its button")
	ui.simulation.state.research_progress["base:arcane_foundations"] = 287.9
	ui.simulation.set_paused(false)
	ui.simulation.tick()
	ui.simulation.set_paused(true)
	ui.simulation.state.company_level = 3
	for id: String in ["base:arcane_resonance", "base:arcane_mastery", "base:arcane_storage_2", "base:second_team"]:
		ui.simulation.state.unlocked[id] = true
	ui.simulation._reconcile_unlocks()
	ui.simulation.state.research_teams.append({"project_id":"", "ramp":0})
	ui.simulation.execute(GameCommand.place_station("base:research_desk", Vector2i(7, 1)))
	ui.simulation.execute(GameCommand.assign_staff("base:torben", "station_4"))
	ui.simulation.execute(GameCommand.assign_research_team("station_4", 1))
	ui.simulation.execute(GameCommand.change_focus("base:arcane_storage"))
	ui.simulation.execute(GameCommand.start_research("base:arcane_core_4"))
	ui.simulation.state.research_progress["base:arcane_core_4"] = 2879.9
	ui.simulation.set_paused(false)
	ui.simulation.tick()
	ui.simulation.set_paused(true)
	ui.simulation.state.products[blueprint_id].quantity = 2
	ui.simulation.state.products[blueprint_id].average_quality = 70.0
	# The universal quality-testing project accepts this starter product.
	ui.simulation.state.pending_breakthroughs["base:prototype_testing"] = true
	ui.simulation.state.research_progress["base:prototype_testing"] = float(ui.registry.get_def("research", "base:prototype_testing").cost_hours)
	for language: String in ["de", "en"]:
		if ui.language != language:
			ui._toggle_language()
		ui.research_group = "general"
		ui.selected_research = "base:prototype_testing"
		ui._refresh_current_tab()
		await process_frame
		await RenderingServer.frame_post_draw
		var team_path := screenshot_root.path_join("%s_teams.png" % language)
		root.get_texture().get_image().save_png(team_path)
		print("UI_SCREENSHOT ", ProjectSettings.globalize_path(team_path))
		_press(ui, "Prototypen auswählen" if language == "de" else "Select prototypes")
		await process_frame
		var windows: Array[Node] = ui.find_children("*", "Window", true, false)
		_check(not windows.is_empty(), "prototype button opens a stock selection window")
		if not windows.is_empty():
			var window: Window = windows.back()
			await RenderingServer.frame_post_draw
			var path := screenshot_root.path_join("%s_prototype.png" % language)
			window.get_texture().get_image().save_png(path)
			print("UI_SCREENSHOT ", ProjectSettings.globalize_path(path))
			if language == "en":
				var amounts := window.find_children("*", "SpinBox", true, false)
				_check(not amounts.is_empty(), "prototype dialog offers actual matching stock")
				if not amounts.is_empty():
					(amounts[0] as SpinBox).value = 2
					_press(ui, "Deliver goods")
					_check(bool(ui.simulation.state.unlocked.get("base:prototype_testing", false)), "prototype submission button completes breakthrough")
			else:
				window.queue_free()
		await process_frame
	ui.simulation._award_victory("master")
	await process_frame
	await process_frame
	_check(ui.has_node("VictoryDialog"), "victory opens a continue dialog")
	if ui.has_node("VictoryDialog"):
		(ui.get_node("VictoryDialog") as AcceptDialog).confirmed.emit()
	_check(str(ui.simulation.state.victory).is_empty(), "continue dialog resumes the game")
	await _check_workshop(ui, screenshot_root)
	ui.queue_free()
	await process_frame
	print("UI_SMOKE failures=", failures)
	quit(failures)

func _check_workshop(ui: Control, screenshot_root: String) -> void:
	for property_id: String in ["base:outskirts", "base:cemetery", "base:deep_forest"]:
		ui._start_new_game(property_id)
		ui.simulation.set_paused(true)
		ui.tabs.current_tab = 6
		for language: String in ["de", "en"]:
			if ui.language != language:
				ui._toggle_language()
			ui._refresh_current_tab()
			await process_frame
			await process_frame
			var grid: WorkshopGrid = _workshop_grid(ui)
			_check(grid.size.x <= 1200, "workshop fits viewport width: " + property_id)
			var toggle: CheckButton = ui.tab_roots["workshop"].find_children("*", "CheckButton", true, false)[0]
			toggle.button_pressed = true
			_check(grid.show_grid, "build grid toggle enables overlay")
			toggle.button_pressed = false
			var source: Dictionary = ui.simulation.state.sources[0]
			_check(grid._get_tooltip(grid._cell_center(Vector2i(source.position[0], source.position[1]))).contains("Vorrat" if language == "de" else "Reserve"), "source tooltip shows localized reserves")
			var station: Dictionary = ui.simulation.state.stations[0]
			_check(grid._get_tooltip(grid._cell_center(Vector2i(station.position[0], station.position[1]))).contains("Elara"), "workstation tooltip identifies assigned staff")
			# Render the entire map too, including areas below the UI scroll viewport.
			var viewport := SubViewport.new()
			viewport.size = Vector2i(grid.custom_minimum_size)
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var map := WorkshopGrid.new()
			viewport.add_child(map)
			map.set_world(grid.rooms, grid.stations, grid.staff, grid.sources, grid.registry, grid.grid_size, "room", language)
			await process_frame
			await RenderingServer.frame_post_draw
			var path := screenshot_root.path_join("%s_%s_map.png" % [language, property_id.get_slice(":", 1)])
			viewport.get_texture().get_image().save_png(path)
			print("UI_SCREENSHOT ", ProjectSettings.globalize_path(path))
			viewport.queue_free()
		# Check actual placement coordinates after the change in cell size.
		var grid: WorkshopGrid = _workshop_grid(ui)
		ui.selected_room_type = "base:laboratory"
		_press(ui, "Draw Room")
		var room_count: int = ui.simulation.state.rooms.size()
		_drag_grid(grid, Vector2i(13, 4), Vector2i(15, 6))
		await process_frame
		_check(ui.simulation.state.rooms.size() == room_count + 1, "drawing builds a room on the clicked cells: " + property_id)
		grid = _workshop_grid(ui)
		ui.selected_station_type = "base:research_desk"
		_press(ui, "Place Station")
		var station_count: int = ui.simulation.state.stations.size()
		_click_grid(grid, Vector2i(14, 5), true)
		await process_frame
		_check(ui.simulation.state.stations.size() == station_count + 1, "station placement matches the illustrated cell")
		grid = _workshop_grid(ui)
		_press(ui, "Resize Rooms")
		_click_grid(grid, Vector2i(13, 4), true)
		_click_grid(grid, Vector2i(13, 4), false)
		_drag_grid(grid, Vector2i(15, 6), Vector2i(16, 6))
		await process_frame
		var last_room: Dictionary = ui.simulation.state.rooms.back()
		_check(int(last_room.rect[2]) == 4 and int(last_room.rect[3]) == 3, "resize handle preserves room geometry")

func _workshop_grid(ui: Control) -> WorkshopGrid:
	for child: Node in ui.tab_roots["workshop"].get_children():
		if child is WorkshopGrid and not child.is_queued_for_deletion():
			return child as WorkshopGrid
	return null

func _click_grid(grid: WorkshopGrid, cell: Vector2i, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = grid._cell_center(cell)
	grid._gui_input(event)

func _drag_grid(grid: WorkshopGrid, first: Vector2i, last: Vector2i) -> void:
	_click_grid(grid, first, true)
	var motion := InputEventMouseMotion.new()
	motion.position = grid._cell_center(last)
	grid._gui_input(motion)
	_click_grid(grid, last, false)

func _press(ui: Node, caption: String) -> void:
	for button: Node in ui.find_children("*", "Button", true, false):
		if button is Button and (button as Button).text == caption and (button as Button).is_visible_in_tree():
			(button as Button).pressed.emit()
			return

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		printerr("UI_FAIL ", description)
	else:
		print("UI_PASS ", description)

func _test_fixed_material_controls(ui: Control) -> void:
	var folder := "user://ui_smoke"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	_check(ui.simulation.has_storage_worker(), "new game has storage staff assigned")
	ui.simulation.state.unlocked["base:focus_rod"] = true
	for language: String in ["de", "en"]:
		if ui.language != language:
			ui._toggle_language()
		ui.tabs.current_tab = 2
		ui._refresh_current_tab()
		await process_frame
		var editor: Control = ui.tab_roots["blueprints"]
		var options := editor.find_children("*", "OptionButton", true, false)
		_check(options.size() == 5, "blueprint editor contains no material selectors")
		var body_option: OptionButton = options[0]
		var material: Label = editor.find_child("BaseMaterial", true, false)
		for body_id: String in ["base:focus_rod", "base:simple_charm"]:
			for index: int in body_option.item_count:
				if str(body_option.get_item_metadata(index)) == body_id:
					body_option.select(index)
					body_option.item_selected.emit(index)
			await process_frame
			var material_id := str(ui.registry.get_def("bodies", body_id).base_material_id)
			_check(material.text.contains(ui._name(ui.registry.get_def("materials", material_id))) and material.text.contains("2"), "body selection updates fixed material and consumption in " + language)
			var labels := editor.find_children("*", "Label", true, false)
			var preview: Dictionary = ui.simulation.preview_blueprint({"body_id":body_id, "effect_id":"base:minor_light"})
			_check(labels.any(func(node: Node) -> bool: return (node as Label).text.contains(ui._money(preview.unit_cost))), "body selection updates cost preview")
		await RenderingServer.frame_post_draw
		var path := folder.path_join(language + "_fixed_material.png")
		root.get_texture().get_image().save_png(path)
		print("UI_SCREENSHOT ", ProjectSettings.globalize_path(path))
		for staffed: bool in [true, false]:
			ui.simulation.execute(GameCommand.assign_staff("base:torben", "station_3" if staffed else ""))
			ui.tabs.current_tab = 4
			ui._refresh_current_tab()
			await process_frame
			await process_frame
			var warehouse: Control = ui.tab_roots["warehouse"]
			var status: Label = warehouse.find_child("StorageStatus", true, false)
			_check(status.text.contains(("Lagerist zugeordnet:" if staffed else "Kein Lagerist") if language == "de" else ("Storage staff assigned:" if staffed else "No storage staff")), "storage status explains active and missing staff in " + language)
			await RenderingServer.frame_post_draw
			path = folder.path_join("%s_storage_%s.png" % [language, "active" if staffed else "inactive"])
			root.get_texture().get_image().save_png(path)
			print("UI_SCREENSHOT ", ProjectSettings.globalize_path(path))
	ui.simulation.execute(GameCommand.assign_staff("base:torben", "station_3"))
	ui.simulation.state.unlocked.erase("base:focus_rod")
	if ui.language != "de":
		ui._toggle_language()
	# Exercise the daily overflow sale and its rendered report.
	ui.simulation.state.inventory["base:spring_water"].quantity = ui.simulation.material_capacity()
	ui.simulation._tick_sources()
	ui.simulation._run_market()
	_check(float(ui.simulation.state.market_report.get("automatic_raw_material_revenue", 0)) > 0, "storage staff sell new surplus automatically")
	ui.tabs.current_tab = 5
	ui._refresh_current_tab()
	await process_frame
	await RenderingServer.frame_post_draw
	var path := folder.path_join("de_automatic_surplus.png")
	root.get_texture().get_image().save_png(path)
	print("UI_SCREENSHOT ", ProjectSettings.globalize_path(path))
