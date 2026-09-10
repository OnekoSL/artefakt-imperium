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
	ui._start_new_game("base:outskirts")
	ui.simulation.set_paused(true)
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
		for tab_index: int in [2, 3, 9]:
			ui.tabs.current_tab = tab_index
			ui._refresh_current_tab()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var path := screenshot_root.path_join("%s_%d.png" % [language, tab_index])
			root.get_texture().get_image().save_png(path)
			print("UI_SCREENSHOT ", ProjectSettings.globalize_path(path))
	_check(str(ui._blueprint_cost_text(ui.simulation.preview_blueprint(ui.simulation.state.blueprints[blueprint_id]))).contains("Processing"), "English cost breakdown is localized")
	ui.queue_free()
	await process_frame
	print("UI_SMOKE failures=", failures)
	quit(failures)

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
