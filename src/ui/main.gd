extends Control

const TAB_KEYS: PackedStringArray = ["overview", "research", "blueprints", "production", "warehouse", "market", "workshop", "personnel", "rivals", "finance", "logbook"]
const REAL_SECONDS_PER_TICK := 1.25
const UI_TEXT := {
	"de": {
		"overview":"Übersicht", "research":"Forschung", "blueprints":"Baupläne", "production":"Produktion", "warehouse":"Lager",
		"market":"Markt & Aufträge", "workshop":"Werkstatt", "personnel":"Personal", "rivals":"Konkurrenz", "finance":"Finanzen", "logbook":"Logbuch",
		"save":"Speichern", "load":"Laden", "loan":"Kredit", "day":"Tag", "gold":"Gold", "reputation":"Ruf",
		"paused":"Pausiert", "active":"Aktiv", "start":"Starten", "pause":"Pausieren", "locked":"Gesperrt",
		"completed":"Erforscht", "auto_name":"Auto-Name", "create":"Bauplan erstellen", "queue":"Produzieren", "offer":"Anbieten", "stop_sale":"Verkauf stoppen", "accept":"Annehmen", "submit":"Waren abgeben"
	},
	"en": {
		"overview":"Overview", "research":"Research", "blueprints":"Blueprints", "production":"Production", "warehouse":"Warehouse",
		"market":"Market & Contracts", "workshop":"Workshop", "personnel":"Personnel", "rivals":"Competitors", "finance":"Finances", "logbook":"Logbook",
		"save":"Save", "load":"Load", "loan":"Loan", "day":"Day", "gold":"Gold", "reputation":"Reputation",
		"paused":"Paused", "active":"Active", "start":"Start", "pause":"Pause", "locked":"Locked",
		"completed":"Researched", "auto_name":"Auto Name", "create":"Create Blueprint", "queue":"Produce", "offer":"List", "stop_sale":"Stop Sale", "accept":"Accept", "submit":"Deliver goods"
	}
}

var registry := ContentRegistry.new()
var simulation: GameSimulation
var language := "de"
var accumulator := 0.0
var last_day := 0
var status_label: Label
var day_label: Label
var cash_label: Label
var reputation_label: Label
var pause_button: Button
var tabs: TabContainer
var tab_roots: Dictionary = {}
var debug_panel: PanelContainer
var debug_label: Label
var selected_room_type := "base:workshop"
var selected_station_type := "base:arcane_bench"
var placement_mode := "room"
var start_overlay: ColorRect
var start_content: VBoxContainer
var live_research_bars: Dictionary = {}
var live_research_details: Dictionary = {}
var live_production_widgets: Dictionary = {}

func _ready() -> void:
	_build_theme()
	_build_shell()
	if not registry.load_all(true):
		_show_fatal_content_errors()
		return
	_build_start_overlay()
	_show_start_menu()

func _process(delta: float) -> void:
	if simulation == null:
		return
	var ticked := false
	if not bool(simulation.state.paused):
		accumulator += delta * int(simulation.state.speed)
		while accumulator >= REAL_SECONDS_PER_TICK:
			accumulator -= REAL_SECONDS_PER_TICK
			simulation.tick()
			ticked = true
	if ticked:
		_refresh_live_values()
	_refresh_header()
	_update_debug()
	if simulation.current_day() != last_day:
		last_day = simulation.current_day()
		var autosave_result := SaveSystem.save_game(simulation, "autosave")
		if not bool(autosave_result.ok):
			_show_result(autosave_result)
		if TAB_KEYS[tabs.current_tab] not in ["blueprints", "production"]:
			_refresh_current_tab()

func _build_theme() -> void:
	var game_theme := Theme.new()
	game_theme.default_font_size = 15
	game_theme.set_color("font_color", "Label", Color("e8edf2"))
	game_theme.set_color("font_color", "Button", Color("f4f7fa"))
	game_theme.set_color("font_color", "TabBar", Color("dbe5ed"))
	game_theme.set_constant("separation", "VBoxContainer", 8)
	game_theme.set_constant("separation", "HBoxContainer", 8)
	theme = game_theme

func _build_shell() -> void:
	var background := ColorRect.new()
	background.color = Color("10161e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	var title_bar := HBoxContainer.new()
	title_bar.custom_minimum_size.y = 64
	title_bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	title_bar.add_theme_constant_override("separation", 10)
	root.add_child(title_bar)
	var title := Label.new()
	title.text = "  ARTEFAKT IMPERIUM"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("f0c875"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_bar.add_child(title)
	day_label = _top_label(title_bar)
	cash_label = _top_label(title_bar)
	reputation_label = _top_label(title_bar)
	pause_button = _button(title_bar, "Ⅱ", _toggle_pause)
	_button(title_bar, "1×", func() -> void: simulation.set_speed(1))
	_button(title_bar, "2×", func() -> void: simulation.set_speed(2))
	_button(title_bar, "4×", func() -> void: simulation.set_speed(4))
	_button(title_bar, "DE/EN", _toggle_language)
	_button(title_bar, "⚙", _toggle_debug)

	var action_bar := HBoxContainer.new()
	action_bar.custom_minimum_size.y = 42
	action_bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(action_bar)
	status_label = Label.new()
	status_label.text = "Bereit."
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_bar.add_child(status_label)
	_button(action_bar, _t("save"), func() -> void: _show_result(SaveSystem.save_game(simulation, "manual")))
	_button(action_bar, _t("load"), func() -> void: _load_slot("manual"))
	_button(action_bar, "Quick", func() -> void: _show_result(SaveSystem.save_game(simulation, "quick")))
	_button(action_bar, _t("loan"), func() -> void: _run(GameCommand.take_loan()))

	tabs = TabContainer.new()
	tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tabs.tab_changed.connect(func(_index: int) -> void: _refresh_current_tab())
	var tabs_host := Control.new()
	tabs_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs_host.clip_contents = true
	root.add_child(tabs_host)
	tabs_host.add_child(tabs)
	for key: String in TAB_KEYS:
		var scroll := ScrollContainer.new()
		scroll.name = _t(key)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 20)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_bottom", 20)
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(margin)
		var content := VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin.add_child(content)
		tabs.add_child(scroll)
		tab_roots[key] = content

	debug_panel = PanelContainer.new()
	debug_panel.visible = false
	debug_panel.position = Vector2(820, 108)
	debug_panel.size = Vector2(440, 280)
	debug_panel.z_index = 20
	add_child(debug_panel)
	debug_label = Label.new()
	debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debug_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	debug_panel.add_child(debug_label)

func _build_start_overlay() -> void:
	start_overlay = ColorRect.new()
	start_overlay.color = Color("0c1219")
	start_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_overlay.z_index = 100
	add_child(start_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 620)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	start_content = VBoxContainer.new()
	start_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(start_content)

func _show_start_menu() -> void:
	_clear(start_content)
	var title := Label.new()
	title.text = "ARTEFAKT IMPERIUM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("f0c875"))
	start_content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Magische Werkstatt-Tycoon-Simulation" if language == "de" else "Magical workshop tycoon simulation"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("8fb5d6"))
	start_content.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 48
	start_content.add_child(spacer)
	var new_button := _button(start_content, "Neues Spiel" if language == "de" else "New Game", _show_property_choices)
	new_button.custom_minimum_size.y = 54
	var load_title := Label.new()
	load_title.text = "Spielstand laden" if language == "de" else "Load game"
	load_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_title.add_theme_font_size_override("font_size", 19)
	start_content.add_child(load_title)
	for slot: String in ["manual", "quick", "autosave"]:
		var slot_name: String = str({"manual":"Manuell", "quick":"Quick", "autosave":"Autosave"}.get(slot, slot))
		var captured_slot := slot
		var button := _button(start_content, str(slot_name), func() -> void: _load_from_start(captured_slot))
		button.custom_minimum_size.y = 42

func _show_property_choices() -> void:
	_clear(start_content)
	var title := Label.new()
	title.text = "Grundstück wählen" if language == "de" else "Choose a property"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("f0c875"))
	start_content.add_child(title)
	for property_id_value: String in ["base:outskirts", "base:cemetery", "base:deep_forest"]:
		var property_def := registry.get_def("properties", property_id_value)
		var card := _card(start_content)
		var row := HBoxContainer.new()
		card.add_child(row)
		var description := VBoxContainer.new()
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(description)
		var grid_data: Array = property_def.get("grid_size", [20, 12])
		var name_label := Label.new()
		name_label.text = "%s · %d×%d" % [_name(property_def), int(grid_data[0]), int(grid_data[1])]
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", Color("8fb5d6"))
		description.add_child(name_label)
		var detail := Label.new()
		detail.text = str(property_def.get("description_" + language, "")) + "\n" + _property_modifier_text(property_def)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_child(detail)
		var property_id := str(property_def.id)
		var choose := _button(row, "Wählen" if language == "de" else "Choose", func() -> void: _start_new_game(property_id))
		choose.custom_minimum_size = Vector2(112, 54)
	var back := _button(start_content, "Zurück" if language == "de" else "Back", _show_start_menu)
	back.custom_minimum_size.y = 38

func _property_modifier_text(definition: Dictionary) -> String:
	var market := (float(definition.get("market_multiplier", 1.0)) - 1.0) * 100.0
	var procurement := (float(definition.get("procurement_multiplier", 1.0)) - 1.0) * 100.0
	var construction := (float(definition.get("construction_multiplier", 1.0)) - 1.0) * 100.0
	var applicants := int(definition.get("applicant_count", 3))
	var hiring := (float(definition.get("hiring_multiplier", 1.0)) - 1.0) * 100.0
	var parts: PackedStringArray = []
	if language == "de":
		parts = ["Marktnachfrage %+.0f%%" % market, "Beschaffung %+.0f%%" % procurement, "Baukosten %+.0f%%" % construction, "%d Bewerber/Zyklus" % applicants]
		if not is_zero_approx(hiring):
			parts.append("Einstellung %+.0f%%" % hiring)
	else:
		parts = ["Market demand %+.0f%%" % market, "Procurement %+.0f%%" % procurement, "Construction %+.0f%%" % construction, "%d applicants/cycle" % applicants]
		if not is_zero_approx(hiring):
			parts.append("Hiring %+.0f%%" % hiring)
	for discipline_id: Variant in (definition.get("research_multipliers", {}) as Dictionary).keys():
		var bonus := (float((definition.research_multipliers as Dictionary)[discipline_id]) - 1.0) * 100.0
		parts.append("%s-Forschung %+.0f%%" % [_name(registry.get_def("disciplines", str(discipline_id))), bonus] if language == "de" else "%s research %+.0f%%" % [_name(registry.get_def("disciplines", str(discipline_id))), bonus])
	var enhanced_sources := 0
	for source_value: Variant in definition.get("sources", []):
		var source: Dictionary = source_value
		if float(source.get("yield_multiplier", 1.0)) > 1.0 or float(source.get("regen_multiplier", 1.0)) > 1.0 or float(source.get("quality_bonus", 0.0)) > 0.0:
			enhanced_sources += 1
	if enhanced_sources > 0:
		parts.append("%d verstärkte Quellen" % enhanced_sources if language == "de" else "%d enhanced sources" % enhanced_sources)
	return " · ".join(parts)

func _start_new_game(property_id: String) -> void:
	simulation = GameSimulation.new(registry)
	simulation.event_emitted.connect(_on_game_event)
	simulation.new_game("base:first_sparks", 0, property_id)
	last_day = simulation.current_day()
	accumulator = 0.0
	start_overlay.visible = false
	_refresh_header()
	_refresh_all_tabs()

func _load_from_start(slot: String) -> void:
	var candidate := GameSimulation.new(registry)
	var result := SaveSystem.load_game(candidate, slot)
	if not bool(result.get("ok", false)):
		var message := Label.new()
		message.text = str(result.get("message", ""))
		message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		message.add_theme_color_override("font_color", Color("e98b82"))
		start_content.add_child(message)
		return
	simulation = candidate
	_show_result(result)
	simulation.event_emitted.connect(_on_game_event)
	last_day = simulation.current_day()
	accumulator = 0.0
	start_overlay.visible = false
	_refresh_header()
	_refresh_all_tabs()
	if bool(simulation.state.get("profession_choice_required", false)):
		_show_legacy_profession_choice()

func _show_legacy_profession_choice() -> void:
	start_overlay.visible = true
	_clear(start_content)
	var title := Label.new()
	title.text = "Werkstattprofession festlegen" if language == "de" else "Choose Workshop Profession"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("f0c875"))
	start_content.add_child(title)
	_info(start_content, "Dieser ältere Spielstand enthält mehrere abgeschlossene Grundlagenforschungen. Wähle einmalig die Profession, unter der deine Werkstatt künftig Aufträge erhält." if language == "de" else "This older save has multiple completed foundations. Choose the profession under which your workshop will receive future contracts.")
	for project: Dictionary in registry.all("research"):
		if int(project.get("tier", 0)) != 1 or not (project.get("requires", []) as Array).is_empty() or not bool((simulation.state.unlocked as Dictionary).get(str(project.id), false)):
			continue
		var profession_id := str(project.get("discipline", ""))
		var captured_profession := profession_id
		var choose := _button(start_content, _name(registry.get_def("disciplines", profession_id)), func() -> void:
			var result := simulation.execute(GameCommand.choose_profession(captured_profession))
			_show_result(result)
			if bool(result.get("ok", false)):
				start_overlay.visible = false
				_refresh_all_tabs()
		)
		choose.custom_minimum_size.y = 48

func _refresh_header() -> void:
	if simulation == null:
		return
	day_label.text = "%s %d · %02d:00" % [_t("day"), simulation.current_day(), int(simulation.state.hour) % 24]
	cash_label.text = "%s: %s" % [_t("gold"), _money(float(simulation.state.cash))]
	reputation_label.text = "%s: %.0f" % [_t("reputation"), float(simulation.state.reputation)]
	pause_button.text = "▶" if bool(simulation.state.paused) else "Ⅱ"
	if bool(simulation.state.defeat):
		status_label.text = "INSOLVENZ – Partie verloren" if language == "de" else "INSOLVENT – Game lost"
	elif not str(simulation.state.victory).is_empty():
		status_label.text = ("SIEG: " if language == "de" else "VICTORY: ") + str(simulation.state.victory).to_upper()

func _refresh_all_tabs() -> void:
	for index: int in TAB_KEYS.size():
		_refresh_tab(index)

func _refresh_current_tab() -> void:
	_refresh_tab(tabs.current_tab)

func _refresh_tab(index: int) -> void:
	if simulation == null or index < 0 or index >= TAB_KEYS.size():
		return
	var key := TAB_KEYS[index]
	var root: VBoxContainer = tab_roots[key]
	_clear(root)
	match key:
		"overview": _build_overview(root)
		"research": _build_research(root)
		"blueprints": _build_blueprints(root)
		"production": _build_production(root)
		"warehouse": _build_warehouse(root)
		"market": _build_market(root)
		"workshop": _build_workshop(root)
		"personnel": _build_personnel(root)
		"rivals": _build_rivals(root)
		"finance": _build_finance(root)
		"logbook": _build_logbook(root)

func _refresh_live_values() -> void:
	if simulation == null:
		return
	for project_id: Variant in live_research_bars.keys():
		var bar: ProgressBar = live_research_bars[project_id]
		if not is_instance_valid(bar):
			continue
		var project := registry.get_def("research", str(project_id))
		var completed := bool((simulation.state.unlocked as Dictionary).get(str(project_id), false))
		bar.value = bar.max_value if completed else float((simulation.state.research_progress as Dictionary).get(str(project_id), 0.0))
		bar.tooltip_text = "%.1f / %.0f" % [bar.value, float(project.get("cost_hours", 0))]
	for project_id: Variant in live_research_details.keys():
		var label: Label = live_research_details[project_id]
		if not is_instance_valid(label):
			continue
		var rate := simulation.research_rate(str(project_id), true)
		var eta := simulation.research_hours_remaining(str(project_id))
		if rate <= 0.0:
			label.text = "Wartet auf Forscher" if language == "de" else "Waiting for researcher"
		else:
			var ramp := int(simulation.state.research_ramp)
			label.text = (("%.2f/Tick · Anlauf noch %d h · ca. %d h" if language == "de" else "%.2f/tick · ramp %d h · about %d h") % [rate, ramp, eta])
	for station_id: Variant in live_production_widgets.keys():
		var widgets: Dictionary = live_production_widgets[station_id]
		var progress: ProgressBar = widgets.progress
		var details: Label = widgets.details
		if not is_instance_valid(progress) or not is_instance_valid(details):
			continue
		var status := simulation.production_line_status(str(station_id))
		progress.max_value = maxf(1.0, float(status.get("required", 1.0)))
		progress.value = float(status.get("progress", 0.0))
		var eta := int(status.get("eta_hours", -1))
		var eta_text := (" · noch %d h" % eta if language == "de" else " · %d h left" % eta) if eta >= 0 else ""
		var status_text := _production_status_text(str(status.get("status", "")))
		var missing_names: PackedStringArray = []
		for material_id: Variant in status.get("missing_materials", []):
			missing_names.append(_name(registry.get_def("materials", str(material_id))))
		if not missing_names.is_empty():
			status_text += ": " + ", ".join(missing_names)
		details.text = "%s · %.2f Arbeit/Tick%s · heute %d Stk." % [status_text, float(status.get("rate", 0.0)), eta_text, int(status.get("produced_today", 0))] if language == "de" else "%s · %.2f work/tick%s · %d today" % [status_text, float(status.get("rate", 0.0)), eta_text, int(status.get("produced_today", 0))]

func _production_status_text(status: String) -> String:
	var translations := {
		"de":{"unconfigured":"Kein Produkt gewählt", "paused":"Pausiert", "no_worker":"Wartet: kein Arbeiter", "no_material":"Wartet: kein Material", "no_cash":"Wartet: zu wenig Gold", "producing":"Produziert", "invalid":"Ungültige Station"},
		"en":{"unconfigured":"No product selected", "paused":"Paused", "no_worker":"Waiting: no worker", "no_material":"Waiting: no material", "no_cash":"Waiting: insufficient gold", "producing":"Producing", "invalid":"Invalid station"},
	}
	return str((translations[language] as Dictionary).get(status, status))

func _build_overview(root: VBoxContainer) -> void:
	_heading(root, "Unternehmensleitung" if language == "de" else "Company Management")
	var columns := HBoxContainer.new()
	root.add_child(columns)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	_section(left, "Aktuelle Lage" if language == "de" else "Current Situation")
	_info(left, "%s: %s" % [_t("gold"), _money(float(simulation.state.cash))])
	_info(left, "%s: %.0f" % [_t("reputation"), float(simulation.state.reputation)])
	var profession_id := str(simulation.state.get("player_profession", ""))
	_info(left, ("Werkstattprofession: " if language == "de" else "Workshop profession: ") + (_name(registry.get_def("disciplines", profession_id)) if not profession_id.is_empty() else ("noch nicht festgelegt" if language == "de" else "not established yet")))
	_info(left, "Lebenszeitumsatz: %s" % _money(float(simulation.state.lifetime_revenue)) if language == "de" else "Lifetime revenue: %s" % _money(float(simulation.state.lifetime_revenue)))
	var active_id := str(simulation.state.active_research)
	_info(left, ("Forschung: " if language == "de" else "Research: ") + (_name(registry.get_def("research", active_id)) if not active_id.is_empty() else "—"))
	_info(left, "Aktive Produktionslinien: %d" % (simulation.state.production_lines as Dictionary).values().filter(func(line: Dictionary) -> bool: return bool(line.get("enabled", false))).size() if language == "de" else "Active production lines: %d" % (simulation.state.production_lines as Dictionary).values().filter(func(line: Dictionary) -> bool: return bool(line.get("enabled", false))).size())
	_section(left, "Kundenansehen" if language == "de" else "Customer Standing")
	for customer: Dictionary in registry.all("customers"):
		_info(left, "%s: %.0f" % [_name(customer), float((simulation.state.faction_reputation as Dictionary).get(str(customer.id), 0.0))])

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	_section(right, "Siegpfade" if language == "de" else "Victory Paths")
	var tech_tier := 0
	for project: Dictionary in registry.all("research"):
		if bool((simulation.state.unlocked as Dictionary).get(str(project.id), false)):
			tech_tier = maxi(tech_tier, int(project.get("tier", 0)))
	_progress_row(right, "Technologieführung" if language == "de" else "Technology Leadership", tech_tier, 3)
	_progress_row(right, "Wirtschaft: Kapital" if language == "de" else "Economy: Cash", float(simulation.state.cash), 22000.0)
	var hybrid_done := (simulation.state.completed_contracts as Array).has("base:hybrid_showcase")
	_progress_row(right, "Hybrid-Meisterwerk" if language == "de" else "Hybrid Masterpiece", 1 if hybrid_done else 0, 1)
	_section(root, "Letzte Ereignisse" if language == "de" else "Recent Events")
	if simulation.recent_events.is_empty():
		_info(root, "Noch keine Ereignisse." if language == "de" else "No events yet.")
	for event: Dictionary in simulation.recent_events.slice(0, 8):
		_info(root, "Tag %d · %s" % [int(event.hour) / 24 + 1, str(event.type)])

func _build_research(root: VBoxContainer) -> void:
	live_research_bars.clear()
	live_research_details.clear()
	_heading(root, _t("research"))
	_info(root, "Nur besetzte Forschertische leisten Arbeit. Ein Projektwechsel verursacht 12 Arbeitsstunden Anlaufzeit." if language == "de" else "Only staffed research desks generate progress. Switching projects causes a 12-work-hour ramp-up period.")
	if str(simulation.state.get("player_profession", "")).is_empty():
		_info(root, "Der erste Abschluss einer Grundlagenforschung legt deine Werkstattprofession dauerhaft fest. Erst danach erscheinen Fachaufträge." if language == "de" else "The first completed foundation permanently establishes your workshop profession. Professional contracts appear afterwards.")
	if not str(simulation.state.active_research).is_empty():
		var actions := HBoxContainer.new()
		actions.alignment = BoxContainer.ALIGNMENT_END
		root.add_child(actions)
		var pause_research_button := _button(actions, _t("pause"), func() -> void: _run(GameCommand.pause_research()))
		pause_research_button.custom_minimum_size = Vector2(132, 36)
	var visible_projects := simulation.visible_research()
	for discipline: Dictionary in registry.all("disciplines"):
		var discipline_projects: Array[Dictionary] = []
		for project: Dictionary in visible_projects:
			if str(project.get("discipline", "")) == str(discipline.id):
				discipline_projects.append(project)
		if discipline_projects.is_empty():
			continue
		_section(root, _name(discipline))
		for project: Dictionary in discipline_projects:
			var row := _list_row(root)
			var completed := bool((simulation.state.unlocked as Dictionary).get(str(project.id), false))
			var progress := float((simulation.state.research_progress as Dictionary).get(str(project.id), 0.0))
			var prefix := "◆ " if bool(project.get("hybrid", false)) else ""
			var project_title := "%s%s · T%d" % [prefix, _name(project), int(project.get("tier", 1))]
			if str(simulation.state.get("player_profession", "")).is_empty() and int(project.get("tier", 0)) == 1 and (project.get("requires", []) as Array).is_empty():
				project_title += " · " + ("legt Profession fest" if language == "de" else "establishes profession")
			_list_label(row, project_title, 260, true)
			var bar := ProgressBar.new()
			bar.min_value = 0
			bar.max_value = float(project.get("cost_hours", 1))
			bar.value = bar.max_value if completed else progress
			bar.custom_minimum_size = Vector2(260, 28)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.show_percentage = true
			bar.tooltip_text = "%.0f / %.0f h" % [bar.value, bar.max_value]
			row.add_child(bar)
			live_research_bars[str(project.id)] = bar
			if completed:
				_list_status(row, "✓  " + _t("completed"), Color("73d69c"))
			elif str(simulation.state.active_research) == str(project.id):
				var detail := _list_status(row, "", Color("f0c875"))
				live_research_details[str(project.id)] = detail
			else:
				var project_id := str(project.id)
				var start_button := _button(row, _t("start"), func() -> void: _run(GameCommand.start_research(project_id)))
				start_button.custom_minimum_size = Vector2(132, 36)
	_refresh_live_values()

func _build_blueprints(root: VBoxContainer) -> void:
	_heading(root, _t("blueprints"))
	if simulation.unlocked_content("bodies").is_empty() or simulation.unlocked_content("effects").is_empty():
		_info(root, "Erforsche zunächst Bestandteile." if language == "de" else "Research components first.")
		return
	var editor_margin := _card(root)
	var form := GridContainer.new()
	form.columns = 2
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_margin.add_child(form)
	_form_label(form, "Name")
	var name_controls := HBoxContainer.new()
	name_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(name_controls)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Name des Bauplans" if language == "de" else "Blueprint name"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.custom_minimum_size = Vector2(320, 36)
	name_controls.add_child(name_edit)
	var auto_name_button := Button.new()
	auto_name_button.text = _t("auto_name")
	auto_name_button.custom_minimum_size = Vector2(124, 36)
	name_controls.add_child(auto_name_button)
	var body_option := _definition_option(form, "Grundkörper" if language == "de" else "Body", simulation.unlocked_content("bodies"))
	var effect_option := _definition_option(form, "Primäreffekt" if language == "de" else "Primary Effect", simulation.unlocked_content("effects"))
	var secondary_effect_option := _definition_option(form, "Sekundäreffekt" if language == "de" else "Secondary Effect", simulation.unlocked_content("effects"), true)
	var modifier_defs := simulation.unlocked_content("modifiers")
	var modifier_one := _definition_option(form, "Modifikator 1" if language == "de" else "Modifier 1", modifier_defs, true)
	var modifier_two := _definition_option(form, "Modifikator 2" if language == "de" else "Modifier 2", modifier_defs, true)
	var material_option := _definition_option(form, "Material", registry.all("materials"))
	var secondary_material_option := _definition_option(form, "Zusatzmaterial" if language == "de" else "Additional Material", registry.all("materials"), true)
	var complex_unlocked := simulation.complex_blueprints_unlocked()
	secondary_effect_option.disabled = not complex_unlocked
	secondary_material_option.disabled = not complex_unlocked
	if not complex_unlocked:
		secondary_effect_option.tooltip_text = "Erfordert die Forschung Komplexe Baupläne." if language == "de" else "Requires Complex Blueprints research."
		secondary_material_option.tooltip_text = secondary_effect_option.tooltip_text
	var preview_label := Label.new()
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.add_theme_color_override("font_color", Color("b9c8d6"))
	root.add_child(preview_label)
	var breakdown_box := VBoxContainer.new()
	root.add_child(breakdown_box)
	var collect := func() -> Dictionary:
		var modifiers: Array = []
		for option: OptionButton in [modifier_one, modifier_two]:
			var value := _option_id(option)
			if not value.is_empty():
				modifiers.append(value)
		return {"name":name_edit.text, "body_id":_option_id(body_option), "effect_id":_option_id(effect_option), "secondary_effect_id":_option_id(secondary_effect_option) if complex_unlocked else "", "modifier_ids":modifiers, "material_id":_option_id(material_option), "secondary_material_id":_option_id(secondary_material_option) if complex_unlocked else ""}
	var update_preview := func() -> void:
		_clear(breakdown_box)
		var preview: Dictionary = simulation.preview_blueprint(collect.call() as Dictionary)
		if not bool(preview.get("valid", false)):
			preview_label.text = str(preview.get("message", ""))
			return
		var stats: Dictionary = preview.stats
		preview_label.text = (("Leistung %.0f · Stabilität %.0f · Sicherheit %.0f · Prestige %.0f · Kosten %s · Basisaufwand %.1f h · Qualität ~%.0f" if language == "de" else "Power %.0f · Stability %.0f · Safety %.0f · Prestige %.0f · Cost %s · Base effort %.1f h · Quality ~%.0f") % [stats.power, stats.stability, stats.safety, stats.prestige, _money(preview.unit_cost), preview.hours, preview.quality_estimate]) + "\n" + (("Warenklassen: " if language == "de" else "Goods classes: ") + _goods_class_names(preview.get("goods_classes", [])) + " · " + ("Abdeckung: " if language == "de" else "Coverage: ") + _profession_names(preview.get("profession_coverage", [])))
		_info(breakdown_box, _blueprint_cost_text(preview))
		_info(breakdown_box, ("Materialmix: " if language == "de" else "Material mix: ") + _material_requirements_text(preview.get("material_requirements", [])) + (" · gewichtete Qualität %.0f%%" if language == "de" else " · weighted quality %.0f%%") % (float(preview.get("material_quality_estimate", 0.0)) * 100.0))
		for modifier_value: Variant in ((preview.get("component_breakdown", {}) as Dictionary).get("modifiers", []) as Array):
			var modifier_data: Dictionary = modifier_value
			var modifier_def := registry.get_def("modifiers", str(modifier_data.get("id", "")))
			var tradeoff := _modifier_tradeoff_parts(modifier_data)
			var title := _info(breakdown_box, _name(modifier_def))
			title.add_theme_color_override("font_color", Color("d8e0e8"))
			if not (tradeoff.advantages as PackedStringArray).is_empty():
				var advantage := _info(breakdown_box, ("  Vorteil: " if language == "de" else "  Benefit: ") + ", ".join(tradeoff.advantages))
				advantage.add_theme_color_override("font_color", Color("73d69c"))
			if not (tradeoff.disadvantages as PackedStringArray).is_empty():
				var disadvantage := _info(breakdown_box, ("  Nachteil: " if language == "de" else "  Tradeoff: ") + ", ".join(tradeoff.disadvantages))
				disadvantage.add_theme_color_override("font_color", Color("e2a36f"))
	var name_mode := {"automatic":true, "updating":false}
	var set_auto_name := func() -> void:
		name_mode.automatic = true
		name_mode.updating = true
		name_edit.text = _auto_blueprint_name(body_option, effect_option, secondary_effect_option, [modifier_one, modifier_two], material_option, secondary_material_option)
		name_edit.caret_column = name_edit.text.length()
		name_mode.updating = false
	name_edit.text_changed.connect(func(_text: String) -> void:
		if not bool(name_mode.updating):
			name_mode.automatic = false
	)
	auto_name_button.tooltip_text = "Automatischen Namen wieder aktivieren" if language == "de" else "Re-enable automatic naming"
	auto_name_button.pressed.connect(func() -> void:
		set_auto_name.call()
		update_preview.call()
	)
	for option: OptionButton in [body_option, effect_option, secondary_effect_option, modifier_one, modifier_two, material_option, secondary_material_option]:
		option.item_selected.connect(func(_index: int) -> void:
			if bool(name_mode.automatic):
				set_auto_name.call()
			update_preview.call()
		)
	set_auto_name.call()
	update_preview.call()
	var create_actions := HBoxContainer.new()
	create_actions.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(create_actions)
	var create_button := _button(create_actions, _t("create"), func() -> void: _run(GameCommand.create_blueprint(collect.call())))
	create_button.custom_minimum_size = Vector2(190, 38)
	_section(root, "Gespeicherte Baupläne" if language == "de" else "Saved Blueprints")
	for blueprint_value: Variant in (simulation.state.blueprints as Dictionary).values():
		var blueprint: Dictionary = blueprint_value
		var computed: Dictionary = simulation.preview_blueprint(blueprint)
		var blueprint_card := _card(root)
		var blueprint_box := VBoxContainer.new()
		blueprint_card.add_child(blueprint_box)
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 38
		blueprint_box.add_child(row)
		_list_label(row, str(blueprint.name), 280, true)
		_list_status(row, "%s · %.1f h" % [_money(computed.unit_cost), computed.hours])
		var details := VBoxContainer.new()
		details.visible = false
		blueprint_box.add_child(details)
		_info(details, _blueprint_cost_text(computed))
		var body := registry.get_def("bodies", str(blueprint.get("body_id", "")))
		var effect := registry.get_def("effects", str(blueprint.get("effect_id", "")))
		var secondary_effect := registry.get_def("effects", str(blueprint.get("secondary_effect_id", "")))
		var material := registry.get_def("materials", str(blueprint.get("material_id", "")))
		var secondary_material := registry.get_def("materials", str(blueprint.get("secondary_material_id", "")))
		var modifier_names: PackedStringArray = []
		for modifier_id: Variant in blueprint.get("modifier_ids", []):
			modifier_names.append(_name(registry.get_def("modifiers", str(modifier_id))))
		_info(details, ("Grundkörper: %s · Primäreffekt: %s · Sekundäreffekt: %s · Modifikatoren: %s" if language == "de" else "Body: %s · Primary effect: %s · Secondary effect: %s · Modifiers: %s") % [_name(body), _name(effect), _name(secondary_effect) if not secondary_effect.is_empty() else "—", ", ".join(modifier_names) if not modifier_names.is_empty() else "—"])
		_info(details, ("Materialmix: " if language == "de" else "Material mix: ") + _material_requirements_text(computed.get("material_requirements", [])) + ((" · Hauptmaterial %s · Zusatzmaterial %s" if language == "de" else " · Primary %s · additional %s") % [_name(material), _name(secondary_material) if not secondary_material.is_empty() else "—"]))
		var stats: Dictionary = computed.get("stats", {})
		_info(details, ("Leistung %.0f · Stabilität %.0f · Sicherheit %.0f · Prestige %.0f · Aufwand %.1f h · Qualitätsprognose ~%.0f (Modifikatoren %+.0f)" if language == "de" else "Power %.0f · Stability %.0f · Safety %.0f · Prestige %.0f · Effort %.1f h · Expected quality ~%.0f (modifiers %+.0f)") % [float(stats.get("power", 0)), float(stats.get("stability", 0)), float(stats.get("safety", 0)), float(stats.get("prestige", 0)), float(computed.get("hours", 0)), float(computed.get("quality_estimate", 0)), float(computed.get("quality_delta", 0))])
		_info(details, ("Warenklassen: " if language == "de" else "Goods classes: ") + _goods_class_names(computed.get("goods_classes", [])))
		_info(details, ("Professionsabdeckung: " if language == "de" else "Profession coverage: ") + _profession_names(computed.get("profession_coverage", [])))
		var product: Dictionary = (simulation.state.products as Dictionary).get(str(blueprint.id), {})
		_info(details, ("Lagerbestand: %d · tatsächliche Durchschnittsqualität %.0f" if language == "de" else "Stock: %d · actual average quality %.0f") % [int(product.get("quantity", 0)), float(product.get("average_quality", 0))])
		var details_button := _button(row, "Ansehen" if language == "de" else "View", func() -> void:
			details.visible = not details.visible
		)
		details_button.tooltip_text = "Bauplanbestandteile und Werte anzeigen" if language == "de" else "Show blueprint components and values"

func _build_production(root: VBoxContainer) -> void:
	live_production_widgets.clear()
	_heading(root, _t("production"))
	_info(root, "Jede besetzte Werkbank fertigt ihr gewähltes Produkt fortlaufend. Material und Herstellungskosten werden pro Stück reserviert und bei einem Produktwechsel für das unfertige Stück erstattet." if language == "de" else "Each staffed workbench continuously crafts its selected product. Materials and processing costs are reserved per unit and refunded for unfinished work when switching products.")
	if simulation.production_stations().is_empty():
		_info(root, "Keine Produktionsstation vorhanden." if language == "de" else "No production station available.")
	for station: Dictionary in simulation.production_stations():
		var station_id := str(station.id)
		var station_def := registry.get_def("stations", str(station.type))
		var line: Dictionary = (simulation.state.production_lines as Dictionary).get(station_id, {})
		var card := _card(root)
		var body := VBoxContainer.new()
		card.add_child(body)
		var header := HBoxContainer.new()
		body.add_child(header)
		_list_label(header, _name(station_def), 260, true)
		var worker_id := str(simulation.production_line_status(station_id).get("worker_id", ""))
		_list_status(header, (_name(registry.get_def("staff", worker_id)) if not worker_id.is_empty() else ("Kein Arbeiter" if language == "de" else "No worker")), Color("a9bdd6") if not worker_id.is_empty() else Color("e2a36f"))
		var controls := HBoxContainer.new()
		body.add_child(controls)
		var blueprint_option := OptionButton.new()
		blueprint_option.custom_minimum_size = Vector2(360, 36)
		blueprint_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		blueprint_option.add_item("Produkt wählen" if language == "de" else "Choose product")
		blueprint_option.set_item_metadata(0, "")
		for blueprint_value: Variant in (simulation.state.blueprints as Dictionary).values():
			var blueprint: Dictionary = blueprint_value
			blueprint_option.add_item(str(blueprint.name))
			blueprint_option.set_item_metadata(blueprint_option.item_count - 1, blueprint.id)
			if str(line.get("blueprint_id", "")) == str(blueprint.id):
				blueprint_option.select(blueprint_option.item_count - 1)
		blueprint_option.disabled = bool(line.get("enabled", false))
		blueprint_option.item_selected.connect(func(_index: int) -> void:
			var selected_id := _option_id(blueprint_option)
			if not selected_id.is_empty():
				_run(GameCommand.configure_production(station_id, selected_id))
		)
		controls.add_child(blueprint_option)
		var enabled := bool(line.get("enabled", false))
		var toggle := _button(controls, ("Pausieren" if language == "de" else "Pause") if enabled else ("Starten" if language == "de" else "Start"), func() -> void: _run(GameCommand.set_production_enabled(station_id, not enabled)))
		toggle.disabled = str(line.get("blueprint_id", "")).is_empty()
		toggle.custom_minimum_size = Vector2(132, 36)
		var progress := ProgressBar.new()
		progress.custom_minimum_size = Vector2(400, 26)
		progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		progress.show_percentage = true
		body.add_child(progress)
		var details := Label.new()
		details.add_theme_color_override("font_color", Color("b9c8d6"))
		body.add_child(details)
		live_production_widgets[station_id] = {"progress":progress, "details":details}
	_refresh_live_values()

func _build_warehouse(root: VBoxContainer) -> void:
	_heading(root, _t("warehouse"))
	_info(root, "Hier siehst du Rohstoffe, Fertigwaren und ihren aktuellen Verkaufsstatus." if language == "de" else "Review raw materials, finished goods, and their current sales status here.")
	_section(root, "Fertigwaren" if language == "de" else "Finished Goods")
	if (simulation.state.blueprints as Dictionary).is_empty():
		_info(root, "Noch keine Waren vorhanden." if language == "de" else "No goods available yet.")
	for blueprint_id: Variant in (simulation.state.blueprints as Dictionary).keys():
		var blueprint: Dictionary = (simulation.state.blueprints as Dictionary)[blueprint_id]
		var product: Dictionary = (simulation.state.products as Dictionary).get(str(blueprint_id), {"quantity":0, "average_quality":0.0, "unit_cost":float((blueprint.computed as Dictionary).unit_cost)})
		var row := _list_row(root)
		_list_label(row, str(blueprint.name), 260, true)
		_list_status(row, "%d Stk. · Q %.0f" % [int(product.quantity), float(product.average_quality)])
		var listing: Dictionary = (simulation.state.listings as Dictionary).get(str(blueprint_id), {})
		if listing.is_empty():
			_list_status(row, "Nicht angeboten" if language == "de" else "Not listed", Color("8fa0b2"))
		else:
			_list_status(row, ("Im Verkauf · %s" if language == "de" else "Listed · %s") % _money(float(listing.price)), Color("73d69c"))

	_section(root, "Rohstoffe" if language == "de" else "Raw Materials")
	var shelf_count := 0
	for station_value: Variant in simulation.state.stations:
		var station: Dictionary = station_value
		if str(registry.get_def("stations", str(station.get("type", ""))).get("kind", "")) == "storage":
			shelf_count += 1
	_info(root, ("%d Materialregal(e) · %d Plätze je Rohstoff" if language == "de" else "%d material shelf/shelves · %d spaces per raw material") % [shelf_count, simulation.material_capacity()])
	for material: Dictionary in registry.all("materials"):
		var material_id := str(material.id)
		var stock: Dictionary = (simulation.state.inventory as Dictionary).get(material_id, {"quantity":0, "quality":float(material.get("quality", 0.0))})
		var capacity := simulation.material_capacity()
		var free_capacity := simulation.material_free_capacity(material_id)
		var row := _list_row(root)
		_list_label(row, _name(material), 180, true)
		_list_status(row, ("%d/%d · %d frei" if language == "de" else "%d/%d · %d free") % [int(stock.quantity), capacity, free_capacity], Color("e2a36f") if free_capacity == 0 else Color("b9c8d6"))
		_list_status(row, "Q %.0f" % (float(stock.quality) * 100.0))
		_list_status(row, ("Kauf %s · Verkauf %s" if language == "de" else "Buy %s · Sell %s") % [_money(simulation.material_buy_price(material_id)), _money(simulation.material_sell_price(material_id, float(stock.quality)))])
		var price_events := simulation.active_material_price_events(material_id)
		if not price_events.is_empty():
			var event_parts: PackedStringArray = []
			for event: Dictionary in price_events:
				event_parts.append("%s ×%.2f · %s" % [_name(event), float(event.price_multiplier), ("noch %d Tage" if language == "de" else "%d days left") % int(event.remaining_days)])
			_list_status(row, ", ".join(event_parts), Color("f0c875"))
		var quantity := SpinBox.new()
		quantity.min_value = 1
		quantity.max_value = maxi(1, maxi(capacity, int(stock.quantity)))
		quantity.value = mini(10, maxi(1, int(quantity.max_value)))
		quantity.custom_minimum_size = Vector2(92, 36)
		row.add_child(quantity)
		var buy := _button(row, "Kaufen" if language == "de" else "Buy", func() -> void: _run(GameCommand.purchase_material(material_id, int(quantity.value))))
		buy.tooltip_text = ("Material manuell beschaffen" if language == "de" else "Purchase material manually")
		buy.disabled = free_capacity <= 0 or float(simulation.state.cash) < simulation.material_buy_price(material_id)
		var sell := _button(row, "Verkaufen" if language == "de" else "Sell", func() -> void: _run(GameCommand.sell_material(material_id, int(quantity.value))))
		sell.tooltip_text = ("Rohstoff manuell verkaufen" if language == "de" else "Sell raw material manually")
		sell.disabled = int(stock.quantity) <= 0

func _build_market(root: VBoxContainer) -> void:
	_heading(root, _t("market"))
	_section(root, "Serienmarkt" if language == "de" else "Open Market")
	for blueprint_id: Variant in (simulation.state.blueprints as Dictionary).keys():
		var blueprint: Dictionary = (simulation.state.blueprints as Dictionary)[blueprint_id]
		var row := _list_row(root)
		_list_label(row, "%s · Bestand %d" % [blueprint.name, int((simulation.state.products as Dictionary).get(blueprint_id, {"quantity":0}).quantity)], 280, true)
		var price := SpinBox.new()
		price.min_value = 1
		price.max_value = 9999
		price.value = float((simulation.state.listings as Dictionary).get(blueprint_id, {"price":float((blueprint.computed as Dictionary).unit_cost) * 2.2}).price)
		price.suffix = " G"
		price.custom_minimum_size = Vector2(130, 36)
		row.add_child(price)
		var captured_id := str(blueprint_id)
		var listing_active := (simulation.state.listings as Dictionary).has(str(blueprint_id))
		var offer_button := _button(row, "Preis ändern" if language == "de" and listing_active else ("Update Price" if listing_active else _t("offer")), func() -> void: _run(GameCommand.set_price(captured_id, price.value)))
		offer_button.custom_minimum_size = Vector2(125, 36)
		if listing_active:
			var stop_button := _button(row, _t("stop_sale"), func() -> void: _run(GameCommand.stop_sale(captured_id)))
			stop_button.custom_minimum_size = Vector2(155, 36)
			stop_button.add_theme_color_override("font_color", Color("ef9a91"))
	var report: Dictionary = simulation.state.market_report
	_info(root, ("Tagesumsatz: %s · Artefakte: %s · Rohstoffe: %s · Marktanteil: %.1f%%" if language == "de" else "Daily revenue: %s · Artifacts: %s · Raw materials: %s · Market share: %.1f%%") % [_money(float(report.get("daily_revenue", 0))), _money(float(report.get("artifact_revenue", 0))), _money(float(report.get("raw_material_revenue", 0))), float(report.get("player_share", 0)) * 100.0])
	var faction_parts: PackedStringArray = []
	for customer: Dictionary in registry.all("customers"):
		faction_parts.append("%s %.0f" % [_name(customer), float((simulation.state.faction_reputation as Dictionary).get(str(customer.id), 0.0))])
	_info(root, ("Kundenansehen: " if language == "de" else "Customer standing: ") + " · ".join(faction_parts))
	_section(root, "Aufträge" if language == "de" else "Contracts")
	var active_contracts: Dictionary = simulation.state.active_contracts
	var available_contracts: Dictionary = simulation.state.available_contracts
	if active_contracts.is_empty() and available_contracts.is_empty():
		var no_profession := str(simulation.state.get("player_profession", "")).is_empty()
		var hint := ("Schließe zuerst eine Grundlagenforschung ab, um deine Werkstattprofession festzulegen." if language == "de" else "Complete a foundation first to establish your workshop profession.") if no_profession else ("Noch keine passenden Aufträge. Verkaufe Waren und erschließe weitere Warenklassen durch Forschung." if language == "de" else "No suitable contracts yet. Sell goods and unlock more goods classes through research.")
		_info(root, hint)
	for contract_value: Variant in active_contracts.values():
		var contract: Dictionary = contract_value
		var row := _list_row(root)
		_list_label(row, "%s · %d Stk. · Q %.0f · %s" % [_name(contract), int(contract.quantity), float(contract.min_quality), _money(float(contract.reward))], 360, true)
		var requirement_label := _list_status(row, _contract_requirement_text(contract), Color("a9bdd6"))
		requirement_label.custom_minimum_size.x = 360
		requirement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		requirement_label.tooltip_text = _contract_requirement_details(contract)
		_list_status(row, ("Aktiv · " if language == "de" else "Active · ") + _contract_time_left(contract), Color("f0c875"))
		var delivery := simulation.contract_delivery_status(contract)
		var delivery_label := _list_status(row, ("Passend %d/%d" if language == "de" else "Eligible %d/%d") % [int(delivery.available), int(delivery.required)], Color("73d69c") if bool(delivery.ready) else Color("e2a36f"))
		delivery_label.tooltip_text = _contract_mismatch_summary(contract)
		var active_contract_id := str(contract.id)
		var submit_button := _button(row, _t("submit"), func() -> void: _run(GameCommand.submit_contract(active_contract_id)))
		submit_button.disabled = not bool(delivery.ready)
		submit_button.tooltip_text = ("Genügend passende Ware im Lager." if language == "de" else "Enough eligible goods in storage.") if bool(delivery.ready) else (("Benötigt %d Stück mit Qualität %.0f und passender Art." if language == "de" else "Requires %d goods of quality %.0f with the matching type.") % [int(contract.quantity), float(contract.min_quality)])
	for contract_value: Variant in available_contracts.values():
		var contract: Dictionary = contract_value
		var row := _list_row(root)
		_list_label(row, "%s · %d Stk. · Q %.0f · %s" % [_name(contract), int(contract.quantity), float(contract.min_quality), _money(float(contract.reward))], 360, true)
		var requirement_label := _list_status(row, _contract_requirement_text(contract), Color("a9bdd6"))
		requirement_label.custom_minimum_size.x = 360
		requirement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		requirement_label.tooltip_text = _contract_requirement_details(contract)
		_list_status(row, _contract_time_left(contract), Color("a9bdd6"))
		var contract_id := str(contract.id)
		var accept_button := _button(row, _t("accept"), func() -> void: _run(GameCommand.accept_contract(contract_id)))
		accept_button.custom_minimum_size = Vector2(132, 36)

func _contract_time_left(contract: Dictionary) -> String:
	var days := simulation.contract_days_remaining(contract)
	if days <= 0:
		return "nur noch heute" if language == "de" else "due today"
	if language == "de":
		return "noch 1 Tag" if days == 1 else "noch %d Tage" % days
	return "1 day left" if days == 1 else "%d days left" % days

func _build_workshop_legacy(root: VBoxContainer) -> void:
	_heading(root, _t("workshop"))
	var toolbar_margin := _card(root)
	var toolbar := HFlowContainer.new()
	toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar_margin.add_child(toolbar)
	_list_label(toolbar, "Raumtyp" if language == "de" else "Room type", 78)
	var room_option := OptionButton.new()
	room_option.custom_minimum_size = Vector2(175, 36)
	for room_def: Dictionary in registry.all("rooms"):
		room_option.add_item(_name(room_def))
		room_option.set_item_metadata(room_option.item_count - 1, room_def.id)
		if str(room_def.id) == selected_room_type:
			room_option.select(room_option.item_count - 1)
	room_option.item_selected.connect(func(_i: int) -> void: selected_room_type = _option_id(room_option); placement_mode = "room")
	toolbar.add_child(room_option)
	var room_button := _button(toolbar, "Raum 3×3 bauen" if language == "de" else "Build 3×3 Room", func() -> void: placement_mode = "room")
	room_button.custom_minimum_size = Vector2(150, 36)
	var separator := VSeparator.new()
	separator.custom_minimum_size.x = 12
	toolbar.add_child(separator)
	_list_label(toolbar, "Stationstyp" if language == "de" else "Station type", 90)
	var station_option := OptionButton.new()
	station_option.custom_minimum_size = Vector2(190, 36)
	station_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var available_stations := simulation.unlocked_content("stations")
	var selected_station_found := false
	for station_def: Dictionary in available_stations:
		station_option.add_item(_name(station_def))
		station_option.set_item_metadata(station_option.item_count - 1, station_def.id)
		if str(station_def.id) == selected_station_type:
			station_option.select(station_option.item_count - 1)
			selected_station_found = true
	if available_stations.is_empty():
		station_option.add_item("Keine verfügbar" if language == "de" else "None available")
		station_option.disabled = true
		selected_station_type = ""
	elif not selected_station_found:
		selected_station_type = str(available_stations[0].id)
		station_option.select(0)
	station_option.item_selected.connect(func(_i: int) -> void: selected_station_type = _option_id(station_option); placement_mode = "station")
	toolbar.add_child(station_option)
	var station_button := _button(toolbar, "Station platzieren" if language == "de" else "Place Station", func() -> void: placement_mode = "station")
	station_button.custom_minimum_size = Vector2(150, 36)
	station_button.disabled = available_stations.is_empty()
	var mode_name := ("Raum bauen" if language == "de" else "Build room") if placement_mode == "room" else ("Station platzieren" if language == "de" else "Place station")
	_info(root, ("Modus: %s · Klicke ein Rasterfeld." if language == "de" else "Mode: %s · Click a grid cell.") % mode_name)
	var grid := WorkshopGrid.new()
	grid.set_world(simulation.state.rooms, simulation.state.stations, simulation.state.staff, simulation.state.sources, registry, simulation.grid_size(), placement_mode, language)
	grid.cell_clicked.connect(_on_grid_clicked)
	root.add_child(grid)
	_section(root, "Schlüsselkräfte" if language == "de" else "Key Staff")
	for staff_value: Variant in simulation.state.staff:
		var entry: Dictionary = staff_value
		var staff_def := registry.get_def("staff", str(entry.id))
		var staff_row := _list_row(root)
		var wage_factor := simulation.wage_performance_multiplier()
		_list_label(staff_row, "%s · F %.2f / T %.2f / Q %.2f" % [_name(staff_def), float(staff_def.research) * wage_factor, float(staff_def.get("production_speed", staff_def.get("craft", 1.0))) * wage_factor, float(staff_def.get("production_quality", staff_def.get("craft", 1.0))) * wage_factor], 360, true)
		var assignment := OptionButton.new()
		assignment.custom_minimum_size = Vector2(170, 36)
		var assignments := ["available", "research", "production"]
		var assignment_labels := (["Verfügbar", "Forschung", "Produktion"] if language == "de" else ["Available", "Research", "Production"])
		for index: int in assignments.size():
			assignment.add_item(assignment_labels[index])
			assignment.set_item_metadata(index, assignments[index])
			if str(entry.assignment) == assignments[index]:
				assignment.select(index)
		var staff_id := str(entry.id)
		assignment.item_selected.connect(func(_index: int) -> void: _run(GameCommand.assign_staff(staff_id, _option_id(assignment))))
		staff_row.add_child(assignment)

func _build_workshop(root: VBoxContainer) -> void:
	_heading(root, _t("workshop"))
	var property_def := registry.get_def("properties", str(simulation.state.property_id))
	var property_size := simulation.grid_size()
	_info(root, "%s · %d×%d · %s" % [_name(property_def), property_size.x, property_size.y, _property_modifier_text(property_def)])
	var grid := WorkshopGrid.new()
	var toolbar_margin := _card(root)
	var toolbar := HFlowContainer.new()
	toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar_margin.add_child(toolbar)
	_list_label(toolbar, "Raumtyp" if language == "de" else "Room type", 78)
	var room_option := OptionButton.new()
	room_option.custom_minimum_size = Vector2(175, 36)
	for room_def: Dictionary in registry.all("rooms"):
		room_option.add_item(_name(room_def))
		room_option.set_item_metadata(room_option.item_count - 1, room_def.id)
		if str(room_def.id) == selected_room_type:
			room_option.select(room_option.item_count - 1)
	room_option.item_selected.connect(func(_i: int) -> void: selected_room_type = _option_id(room_option); placement_mode = "room"; grid.set_mode("room"))
	toolbar.add_child(room_option)
	var room_button := _button(toolbar, "Raum aufziehen" if language == "de" else "Draw Room", func() -> void: placement_mode = "room"; grid.set_mode("room"))
	room_button.custom_minimum_size = Vector2(145, 36)
	var station_option := OptionButton.new()
	station_option.custom_minimum_size = Vector2(190, 36)
	var available_stations := simulation.unlocked_content("stations")
	var selected_station_found := false
	for station_def: Dictionary in available_stations:
		station_option.add_item(_name(station_def))
		station_option.set_item_metadata(station_option.item_count - 1, station_def.id)
		if str(station_def.id) == selected_station_type:
			station_option.select(station_option.item_count - 1)
			selected_station_found = true
	if available_stations.is_empty():
		station_option.add_item("Keine verfügbar" if language == "de" else "None available")
		station_option.disabled = true
		selected_station_type = ""
	elif not selected_station_found:
		selected_station_type = str(available_stations[0].id)
		station_option.select(0)
	station_option.item_selected.connect(func(_i: int) -> void: selected_station_type = _option_id(station_option); placement_mode = "station"; grid.set_mode("station"))
	toolbar.add_child(station_option)
	var station_button := _button(toolbar, "Station platzieren" if language == "de" else "Place Station", func() -> void: placement_mode = "station"; grid.set_mode("station"))
	station_button.disabled = available_stations.is_empty()
	var resize_button := _button(toolbar, "Räume ändern" if language == "de" else "Resize Rooms", func() -> void: placement_mode = "resize"; grid.set_mode("resize"))
	resize_button.custom_minimum_size.x = 135
	var instruction := _info(root, _workshop_mode_text())
	instruction.add_theme_color_override("font_color", Color("a9c6dd"))
	var preview_label := _info(root, "")
	preview_label.add_theme_color_override("font_color", Color("8ed6a7"))
	grid.set_world(simulation.state.rooms, simulation.state.stations, simulation.state.staff, simulation.state.sources, registry, simulation.grid_size(), placement_mode, language)
	grid.cell_clicked.connect(_on_grid_clicked)
	grid.room_drawn.connect(_on_room_drawn)
	grid.room_resize_requested.connect(_on_room_resize_requested)
	grid.preview_changed.connect(func(rect: Rect2i, room_id: String) -> void: preview_label.text = _room_preview_text(rect, room_id))
	root.add_child(grid)
	_section(root, "Rohstoffquellen" if language == "de" else "Resource Sources")
	for source_value: Variant in simulation.state.sources:
		var source: Dictionary = source_value
		var source_def := registry.get_def("resource_sources", str(source.type))
		var material_id := str(source.get("material", source_def.get("material", "")))
		var material := registry.get_def("materials", material_id)
		var location := "Offsite" if bool(source.get("offsite", false)) else "%d/%d" % [int(source.position[0]), int(source.position[1])]
		_info(root, "%s → %s · %.1f/%.0f · +%.1f/Tag · Q %.0f%% · %s" % [_name(source_def), _name(material), float(source.reserve), float(source_def.get("max_reserve", 0)), float(source_def.get("daily_regen", 0)) * float(source.get("regen_multiplier", 1.0)), (float(material.get("quality", 0.5)) + float(source.get("quality_bonus", 0.0))) * 100.0, location])

func _build_personnel(root: VBoxContainer) -> void:
	_heading(root, _t("personnel"))
	var wage_level := simulation.wage_performance_multiplier()
	var pending_level := float(simulation.state.get("pending_wage_level", wage_level))
	_section(root, "Lohnniveau" if language == "de" else "Wage level")
	var wage_card := _card(root)
	var wage_body := VBoxContainer.new()
	wage_card.add_child(wage_body)
	_info(wage_body, (("Aktiv %d %% · Tageslohn %s · Leistungsfaktor %.2f" if language == "de" else "Active %d%% · Daily wages %s · Performance factor %.2f") % [roundi(wage_level * 100.0), _money(simulation.daily_wages()), wage_level]))
	if not is_equal_approx(wage_level, pending_level):
		var pending_info := _info(wage_body, (("Ab nächstem Spieltag vorgemerkt: %d %% · %s/Tag" if language == "de" else "Scheduled for next game day: %d%% · %s/day") % [roundi(pending_level * 100.0), _money(simulation.daily_wages(pending_level))]))
		pending_info.add_theme_color_override("font_color", Color("f0c875"))
	var wage_controls := HBoxContainer.new()
	wage_body.add_child(wage_controls)
	var wage_slider := HSlider.new()
	wage_slider.min_value = 80
	wage_slider.max_value = 120
	wage_slider.step = 5
	wage_slider.value = pending_level * 100.0
	wage_slider.custom_minimum_size = Vector2(360, 36)
	wage_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wage_controls.add_child(wage_slider)
	var wage_preview := _list_status(wage_controls, "%d %%" % roundi(wage_slider.value), Color("a9bdd6"))
	wage_preview.custom_minimum_size.x = 90
	wage_slider.value_changed.connect(func(value: float) -> void: wage_preview.text = "%d %%" % roundi(value))
	var apply_wage := _button(wage_controls, "Für morgen vormerken" if language == "de" else "Schedule for tomorrow", func() -> void: _run(GameCommand.set_wage_level(wage_slider.value / 100.0)))
	apply_wage.custom_minimum_size = Vector2(205, 36)
	_info(root, ("Personal %d/%d · Grundlöhne %s · aktuell %s · Nächste Bewerbungen an Tag %d" if language == "de" else "Staff %d/%d · Base wages %s · currently %s · Next applicants on day %d") % [(simulation.state.staff as Array).size(), simulation.housing_capacity(), _money(simulation.base_daily_wages()), _money(simulation.daily_wages()), int(simulation.state.next_applicant_refresh_day)])
	_section(root, "Beschäftigte" if language == "de" else "Employees")
	for staff_value: Variant in simulation.state.staff:
		var entry: Dictionary = staff_value
		var staff_def := registry.get_def("staff", str(entry.id))
		var specialty := registry.get_def("disciplines", str(staff_def.get("specialty", "")))
		var card := _card(root)
		var body := VBoxContainer.new()
		card.add_child(body)
		var top := HBoxContainer.new()
		body.add_child(top)
		_list_label(top, "%s · %s" % [_name(staff_def), _name(specialty)], 260, true)
		_list_status(top, ("Basis %s · aktuell %s/Tag" if language == "de" else "Base %s · currently %s/day") % [_money(float(staff_def.get("salary", 0))), _money(float(staff_def.get("salary", 0)) * wage_level)])
		_info(body, ("Effektiv: Forschung %.2f · Tempo %.2f · Qualität %.2f · Logistik %.2f" if language == "de" else "Effective: Research %.2f · Speed %.2f · Quality %.2f · Logistics %.2f") % [float(staff_def.get("research", 0)) * wage_level, float(staff_def.get("production_speed", staff_def.get("craft", 1.0))) * wage_level, float(staff_def.get("production_quality", staff_def.get("craft", 1.0))) * wage_level, float(staff_def.get("logistics", 0)) * wage_level])
		var controls := HBoxContainer.new()
		body.add_child(controls)
		var assignment := OptionButton.new()
		assignment.custom_minimum_size = Vector2(430, 36)
		assignment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		assignment.add_item("Verfügbar" if language == "de" else "Available")
		assignment.set_item_metadata(0, "")
		var current_station := str(entry.get("station_id", ""))
		for station_value: Variant in simulation.state.stations:
			var station: Dictionary = station_value
			var station_def := registry.get_def("stations", str(station.type))
			var occupant := _station_occupant(str(station.id), str(entry.id))
			var station_status := ""
			if str(station.id) == current_station:
				station_status = " — aktuell zugewiesen" if language == "de" else " — currently assigned"
			elif not occupant.is_empty():
				station_status = (" — tauschen mit " if language == "de" else " — swap with ") + occupant
			else:
				station_status = " — frei" if language == "de" else " — free"
			assignment.add_item(_name(station_def) + station_status)
			assignment.set_item_metadata(assignment.item_count - 1, station.id)
			if str(station.id) == current_station:
				assignment.select(assignment.item_count - 1)
		var staff_id := str(entry.id)
		assignment.item_selected.connect(func(_index: int) -> void: _run(GameCommand.assign_staff(staff_id, _option_id(assignment))))
		controls.add_child(assignment)
		var dismiss := _button(controls, "Entlassen" if language == "de" else "Dismiss", func() -> void: _run(GameCommand.dismiss_staff(staff_id)))
		dismiss.add_theme_color_override("font_color", Color("ef9a91"))
	_section(root, "Bewerbungen" if language == "de" else "Applicants")
	if (simulation.state.applicants as Array).is_empty():
		_info(root, "Derzeit keine Bewerbungen." if language == "de" else "No applications at present.")
	for applicant_value: Variant in simulation.state.applicants:
		var applicant_id := str(applicant_value)
		var applicant := registry.get_def("staff", applicant_id)
		var specialty := registry.get_def("disciplines", str(applicant.get("specialty", "")))
		var fee := float(applicant.get("salary", 0)) * 3.0 * float(simulation.property.get("hiring_multiplier", 1.0))
		var row := _list_row(root)
		_list_label(row, "%s · %s · F %.2f / T %.2f / Q %.2f / L %.2f · Basis %s/Tag" % [_name(applicant), _name(specialty), float(applicant.get("research", 0)) * wage_level, float(applicant.get("production_speed", applicant.get("craft", 1.0))) * wage_level, float(applicant.get("production_quality", applicant.get("craft", 1.0))) * wage_level, float(applicant.get("logistics", 0)) * wage_level, _money(float(applicant.get("salary", 0)))], 520, true)
		var hire := _button(row, ("Einstellen · " if language == "de" else "Hire · ") + _money(fee), func() -> void: _run(GameCommand.hire_staff(applicant_id)))
		hire.disabled = (simulation.state.staff as Array).size() >= simulation.housing_capacity() or float(simulation.state.cash) < fee

func _station_occupant(station_id: String, except_staff_id: String = "") -> String:
	for value: Variant in simulation.state.staff:
		var entry: Dictionary = value
		if str(entry.id) != except_staff_id and str(entry.get("station_id", "")) == station_id:
			return _name(registry.get_def("staff", str(entry.id)))
	return ""

func _workshop_mode_text() -> String:
	match placement_mode:
		"room": return "Modus Raum: vom ersten bis zum gegenüberliegenden Eckfeld ziehen." if language == "de" else "Room mode: drag from the first to the opposite corner."
		"station": return "Modus Station: auf ein freies Feld im passenden Raum klicken." if language == "de" else "Station mode: click a free tile in the matching room."
		_: return "Modus Umbau: Raum wählen, dann den goldenen Griff unten rechts ziehen." if language == "de" else "Resize mode: select a room, then drag its golden bottom-right handle."

func _room_preview_text(rect: Rect2i, room_id: String) -> String:
	if rect.get_area() <= 0:
		return ""
	var definition := registry.get_def("rooms", selected_room_type)
	var cost := 0.0
	var action := "Neuer Raum" if language == "de" else "New room"
	if not room_id.is_empty():
		for room_value: Variant in simulation.state.rooms:
			var room: Dictionary = room_value
			if str(room.id) == room_id:
				definition = registry.get_def("rooms", str(room.type))
				var old := Rect2i(int(room.rect[0]), int(room.rect[1]), int(room.rect[2]), int(room.rect[3]))
				var overlap := old.intersection(rect).get_area()
				cost = (rect.get_area() - overlap + (old.get_area() - overlap) * 0.5) * float(definition.get("cost_per_tile", 0))
				action = "Umbau" if language == "de" else "Resize"
				break
	else:
		cost = rect.get_area() * float(definition.get("cost_per_tile", 0))
	cost *= float(simulation.property.get("construction_multiplier", 1.0))
	var valid := rect.get_area() >= int(definition.get("min_size", 1)) and rect.end.x <= simulation.grid_size().x and rect.end.y <= simulation.grid_size().y
	var validity := ("gültig" if language == "de" else "valid") if valid else ("ungültig" if language == "de" else "invalid")
	return "%s · %s · %d×%d · %s · %s" % [action, _name(definition), rect.size.x, rect.size.y, validity, _money(cost)]

func _build_rivals(root: VBoxContainer) -> void:
	_heading(root, _t("rivals"))
	for rival_id: Variant in (simulation.state.rivals as Dictionary).keys():
		var profile := registry.get_def("rivals", str(rival_id))
		var runtime: Dictionary = (simulation.state.rivals as Dictionary)[rival_id]
		_section(root, _name(profile))
		var project := registry.get_def("research", str(runtime.active_research))
		var progress := float((runtime.research_progress as Dictionary).get(str(runtime.active_research), 0))
		var total := float(project.get("cost_hours", 1))
		_info(root, ("Fokus: %s · Geschätzte Forschung: %s (%.0f%%)" if language == "de" else "Focus: %s · Estimated research: %s (%.0f%%)") % [_name(registry.get_def("disciplines", str(profile.focus))), _name(project), clampf(progress / total * 100.0 + 5.0, 0, 99)])
		_info(root, ("Bekannte Aktivität: " if language == "de" else "Known activity: ") + str(runtime.last_action))
		_info(root, ("Marktanteil etwa %.0f%%" if language == "de" else "Market share around %.0f%%") % (float(runtime.market_share) * 100.0))
	_section(root, "Aktive Technologierennen" if language == "de" else "Active Technology Races")
	if (simulation.state.active_races as Dictionary).is_empty():
		_info(root, "Keine." if language == "de" else "None.")
	for race_value: Variant in (simulation.state.active_races as Dictionary).values():
		var race: Dictionary = race_value
		_info(root, "%s ↔ %s" % [_name(registry.get_def("research", str(race.project_id))), _name(registry.get_def("rivals", str(race.rival_id)))])

func _build_finance(root: VBoxContainer) -> void:
	_heading(root, _t("finance"))
	_info(root, "%s: %s · Kredit: %s" % [_t("gold"), _money(float(simulation.state.cash)), _money(float(simulation.state.loan_balance))])
	_info(root, ("Lebenszeitumsatz %s · Artefakte %s · Rohstoffe %s" if language == "de" else "Lifetime revenue %s · Artifacts %s · Raw materials %s") % [_money(float(simulation.state.lifetime_revenue)), _money(float(simulation.state.get("artifact_revenue", 0.0))), _money(float(simulation.state.get("raw_material_revenue", 0.0)))])
	var report: Dictionary = simulation.state.get("market_report", {})
	var last_revenue := float(report.get("daily_revenue", 0.0))
	var last_wages := float(report.get("wages", 0.0))
	var last_research := float(report.get("research_cost", 0.0))
	var last_interest := float(report.get("interest", 0.0))
	var last_production := float(report.get("production_cost", 0.0))
	var last_net := float(report.get("operating_net", last_revenue - last_wages - last_research - last_interest - last_production))
	_section(root, "Tageswirtschaft" if language == "de" else "Daily economy")
	_info(root, ("Letzter Abschluss: Umsatz %s · Löhne %s · Forschung %s · Herstellung %s · Zinsen %s · Ergebnis %s" if language == "de" else "Last close: Revenue %s · Wages %s · Research %s · Processing %s · Interest %s · Result %s") % [_money(last_revenue), _money(last_wages), _money(last_research), _money(last_production), _money(last_interest), _signed_money(last_net)])
	var projected_interest := float(simulation.state.loan_balance) * 0.001
	_info(root, ("Laufende Prognose: Umsatz %s · Löhne %s · Forschung %s · Herstellung %s · Zinsen %s · Ergebnis %s" if language == "de" else "Current forecast: Revenue %s · Wages %s · Research %s · Processing %s · Interest %s · Result %s") % [_money(last_revenue), _money(simulation.daily_wages()), _money(simulation.active_research_daily_cost()), _money(last_production), _money(projected_interest), _signed_money(simulation.expected_daily_operating_result())])
	_info(root, "Herstellung in der Prognose ist eine Schätzung anhand des letzten Tages (abzüglich Erstattungen). Materialkäufe sowie einmalige Bau-, Einstellungs- und Abfindungskosten sind in der Prognose nicht enthalten." if language == "de" else "Projected processing costs use the last day, net of refunds. Material purchases and one-off construction, hiring, and severance costs are excluded from the forecast.")
	if int(simulation.state.insolvency_since) >= 0:
		var remaining := int(simulation.scenario.get("rescue_days", 14)) - (simulation.current_day() - int(simulation.state.insolvency_since))
		_info(root, "Insolvenzfrist: noch %d Tage" % remaining if language == "de" else "Insolvency grace: %d days left" % remaining)
	_button(root, _t("loan") + " +5.000 G", func() -> void: _run(GameCommand.take_loan()))
	_section(root, "Journal")
	for entry_value: Variant in (simulation.state.journal as Array).slice(0, 40):
		var entry: Dictionary = entry_value
		var row := _list_row(root)
		var description := str(entry.description)
		if str(entry.category) == "production":
			description = ("Herstellung: " if language == "de" else "Processing: ") + description
		elif str(entry.category) == "production_refund":
			description = "Herstellungserstattung" if language == "de" else "Processing refund"
		_list_label(row, "T%d · %s" % [int(entry.hour) / 24 + 1, description], 320, true)
		_list_status(row, ("+" if float(entry.amount) >= 0 else "") + _money(float(entry.amount)), Color("73d69c") if float(entry.amount) >= 0 else Color("e27d76"))

func _build_logbook(root: VBoxContainer) -> void:
	_heading(root, _t("logbook"))
	_info(root, "Chronik wichtiger Ereignisse deines Unternehmens." if language == "de" else "Chronicle of important events in your company.")
	var entries: Array = simulation.state.get("logbook", [])
	if entries.is_empty():
		_info(root, "Noch keine Einträge." if language == "de" else "No entries yet.")
		return
	for event_value: Variant in entries.slice(0, 100):
		var event: Dictionary = event_value
		var row := _list_row(root)
		var hour := int(event.get("hour", 0))
		_list_status(row, ("Tag %d · %02d:00" if language == "de" else "Day %d · %02d:00") % [hour / 24 + 1, hour % 24], Color("8fb5d6"))
		_list_label(row, _event_text(str(event.get("type", "")), event.get("payload", {})), 620, true)

func _on_grid_clicked(cell: Vector2i) -> void:
	if placement_mode == "station" and not selected_station_type.is_empty():
		_run(GameCommand.place_station(selected_station_type, cell))

func _on_room_drawn(rect: Rect2i) -> void:
	if placement_mode == "room":
		_run(GameCommand.place_room(selected_room_type, rect))

func _on_room_resize_requested(room_id: String, rect: Rect2i) -> void:
	if placement_mode == "resize" and not room_id.is_empty():
		_run(GameCommand.resize_room(room_id, rect))

func _on_game_event(event: Dictionary) -> void:
	var event_name := str(event.type)
	status_label.text = _event_text(event_name, event.payload)
	status_label.add_theme_color_override("font_color", Color("a9c6dd"))
	if event_name == "ProductionSummary":
		_refresh_live_values()
	else:
		_refresh_current_tab()

func _event_text(kind: String, payload: Dictionary) -> String:
	match kind:
		"GameStarted": return "Unternehmen gegründet." if language == "de" else "Company founded."
		"ResearchStarted": return ("Forschung begonnen: " if language == "de" else "Research started: ") + _name(registry.get_def("research", str(payload.get("project_id", ""))))
		"ResearchCompleted": return ("Forschung abgeschlossen: " if language == "de" else "Research completed: ") + _name(registry.get_def("research", str(payload.get("project_id", ""))))
		"ProfessionChosen": return ("Werkstattprofession festgelegt: " if language == "de" else "Workshop profession established: ") + _name(registry.get_def("disciplines", str(payload.get("profession_id", ""))))
		"WageLevelChanged": return (("Lohnniveau aktiviert: %d %%" if language == "de" else "Wage level activated: %d%%") % roundi(float(payload.get("new_level", 1.0)) * 100.0))
		"BlueprintCreated":
			var blueprint: Dictionary = (simulation.state.blueprints as Dictionary).get(str(payload.get("blueprint_id", "")), {})
			return ("Bauplan erstellt: " if language == "de" else "Blueprint created: ") + str(blueprint.get("name", "—"))
		"BatchProduced": return ("Charge fertiggestellt: " if language == "de" else "Batch completed: ") + "%d · Q %.0f" % [payload.get("quantity", 0), payload.get("quality", 0)]
		"ProductionSummary": return _production_summary_text(payload)
		"ProductionMigrated": return ("Alte Produktionsaufträge zurückerstattet: %d" if language == "de" else "Legacy production orders refunded: %d") % int(payload.get("orders", 0))
		"RawMaterialOverflowSold":
			var material_name := _name(registry.get_def("materials", str(payload.get("material_id", ""))))
			return ("Lagerüberlauf verkauft: %d× %s für %s" if language == "de" else "Storage overflow sold: %d× %s for %s") % [int(payload.get("quantity", 0)), material_name, _money(float(payload.get("revenue", 0.0)))]
		"ContractOffered": return ("Neuer Auftrag verfügbar: " if language == "de" else "New contract available: ") + _name(registry.get_def("contracts", str(payload.get("contract_id", ""))))
		"ContractAccepted": return ("Auftrag angenommen: " if language == "de" else "Contract accepted: ") + _name(registry.get_def("contracts", str(payload.get("contract_id", ""))))
		"ContractOfferExpired": return ("Auftragsangebot verstrichen: " if language == "de" else "Contract offer expired: ") + _name(registry.get_def("contracts", str(payload.get("contract_id", ""))))
		"ContractCompleted": return ("Auftrag abgeschlossen: " if language == "de" else "Contract completed: ") + _name(registry.get_def("contracts", str(payload.get("contract_id", ""))))
		"ContractExpired": return ("Auftrag abgelaufen: " if language == "de" else "Contract expired: ") + _name(registry.get_def("contracts", str(payload.get("contract_id", ""))))
		"RivalResearchCompleted":
			var rival_name := _name(registry.get_def("rivals", str(payload.get("rival_id", ""))))
			var project_name := _name(registry.get_def("research", str(payload.get("project_id", ""))))
			return ("%s hat %s erforscht." if language == "de" else "%s researched %s.") % [rival_name, project_name]
		"RaceStarted": return "Technologierennen begonnen!" if language == "de" else "Technology race started!"
		"InsolvencyWarning": return "Warnung: Insolvenzfrist läuft!" if language == "de" else "Warning: insolvency grace period started!"
		"Defeat": return "Insolvenz – Partie verloren." if language == "de" else "Insolvent – game lost."
		"Victory": return ("Sieg durch " if language == "de" else "Victory by ") + str(payload.get("path", ""))
		_: return "Ereignis: " + kind if language == "de" else "Event: " + kind

func _production_summary_text(payload: Dictionary) -> String:
	var parts: PackedStringArray = []
	for blueprint_id: Variant in (payload.get("products", {}) as Dictionary).keys():
		var blueprint: Dictionary = (simulation.state.blueprints as Dictionary).get(blueprint_id, {})
		parts.append("%d× %s" % [int((payload.products as Dictionary)[blueprint_id]), str(blueprint.get("name", blueprint_id))])
	var prefix := "Tagesproduktion: " if language == "de" else "Daily production: "
	return prefix + (", ".join(parts) if not parts.is_empty() else ("%d Stück" if language == "de" else "%d units") % int(payload.get("total", 0)))

func _run(command: GameCommand) -> void:
	_show_result(simulation.execute(command))
	_refresh_all_tabs()

func _show_result(result: Dictionary) -> void:
	status_label.text = str(result.get("message", ""))
	status_label.add_theme_color_override("font_color", Color("8ed6a7") if bool(result.get("ok", false)) else Color("e98b82"))

func _load_slot(slot: String) -> void:
	var result := SaveSystem.load_game(simulation, slot)
	_show_result(result)
	if bool(result.ok):
		last_day = simulation.current_day()
		accumulator = 0.0
	_refresh_all_tabs()
	if bool(simulation.state.get("profession_choice_required", false)):
		_show_legacy_profession_choice()

func _toggle_pause() -> void:
	simulation.set_paused(not bool(simulation.state.paused))

func _toggle_language() -> void:
	language = "en" if language == "de" else "de"
	for index: int in TAB_KEYS.size():
		tabs.set_tab_title(index, _t(TAB_KEYS[index]))
	_refresh_all_tabs()
	_refresh_header()

func _toggle_debug() -> void:
	debug_panel.visible = not debug_panel.visible
	_update_debug()

func _update_debug() -> void:
	if simulation == null or not debug_panel.visible:
		return
	debug_label.text = "DEBUG\nTick: %d · RNG Q/M/R: %d / %d / %d\nActive research: %s\nQueue: %d\nPackages: %s\nContent warnings: %s\nLast market: %s" % [
		simulation.state.hour, simulation.rng_quality.state, simulation.rng_market.state, simulation.rng_rivals.state,
		simulation.state.active_research, (simulation.state.production_lines as Dictionary).size(),
		JSON.stringify(registry.package_snapshot()), " | ".join(registry.warnings), JSON.stringify(simulation.state.market_report)
	]

func _show_fatal_content_errors() -> void:
	status_label.text = "CONTENT ERROR"
	var label := Label.new()
	label.text = "\n".join(registry.errors)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(tab_roots["overview"] as VBoxContainer).add_child(label)

func _definition_option(parent: GridContainer, label_text: String, definitions: Array[Dictionary], allow_none: bool = false) -> OptionButton:
	_form_label(parent, label_text)
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(320, 36)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if allow_none:
		option.add_item("—")
		option.set_item_metadata(0, "")
	for definition: Dictionary in definitions:
		option.add_item(_name(definition))
		option.set_item_metadata(option.item_count - 1, definition.id)
	parent.add_child(option)
	return option

func _auto_blueprint_name(body_option: OptionButton, effect_option: OptionButton, secondary_effect_option: OptionButton, modifier_options: Array, material_option: OptionButton, secondary_material_option: OptionButton) -> String:
	var body_name := _name(registry.get_def("bodies", _option_id(body_option)))
	var effect_name := _name(registry.get_def("effects", _option_id(effect_option)))
	var material_name := _name(registry.get_def("materials", _option_id(material_option)))
	var secondary_effect_id := _option_id(secondary_effect_option)
	var secondary_material_id := _option_id(secondary_material_option)
	if not secondary_effect_id.is_empty():
		effect_name += " + " + _name(registry.get_def("effects", secondary_effect_id))
	if not secondary_material_id.is_empty():
		material_name += " + " + _name(registry.get_def("materials", secondary_material_id))
	var result := "%s – %s (%s)" % [body_name, effect_name, material_name]
	var modifier_names: PackedStringArray = []
	for option_value: Variant in modifier_options:
		var modifier_id := _option_id(option_value as OptionButton)
		if not modifier_id.is_empty():
			modifier_names.append(_name(registry.get_def("modifiers", modifier_id)))
	if not modifier_names.is_empty():
		result += " · " + ", ".join(modifier_names)
	return result

func _option_id(option: OptionButton) -> String:
	if option.item_count == 0 or option.selected < 0:
		return ""
	return str(option.get_item_metadata(option.selected))

func _form_label(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(170, 36)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)

func _heading(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color("f0c875"))
	parent.add_child(label)

func _section(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color("8fb5d6"))
	parent.add_child(label)

func _info(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _card(parent: Control) -> MarginContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("171e27")
	style.border_color = Color("293544")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)
	return margin

func _list_row(parent: Control) -> HBoxContainer:
	var margin := _card(parent)
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 38
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)
	return row

func _list_label(parent: Control, text: String, minimum_width: float = 0.0, expand: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = minimum_width
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = text
	if expand:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _list_status(parent: Control, text: String, color: Color = Color("cbd5df")) -> Label:
	var label := _list_label(parent, text, 132.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_color_override("font_color", color)
	return label

func _progress_row(parent: Control, title: String, value: float, maximum: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 180
	row.add_child(label)
	var progress := ProgressBar.new()
	progress.max_value = maximum
	progress.value = value
	progress.custom_minimum_size = Vector2(280, 24)
	row.add_child(progress)

func _top_label(parent: Control) -> Label:
	var label := Label.new()
	label.custom_minimum_size.x = 145
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label

func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		child.queue_free()

func _name(definition: Dictionary) -> String:
	if definition.is_empty():
		return "—"
	return str(definition.get("name_" + language, definition.get("id", "?")))

func _localized_tags(tags: Variant) -> String:
	var names: PackedStringArray = []
	if tags is Array:
		for tag: Variant in tags:
			names.append(_localized_tag(str(tag)))
	return ", ".join(names) if not names.is_empty() else "—"

func _localized_tag(tag: String) -> String:
	var translations := {
		"de":{"wearable":"Talisman", "mage":"Magierware", "witch":"Hexenware", "citizen":"Bürgerware", "utility":"Gebrauchsware", "hybrid":"Hybridware", "common":"Gewöhnlich", "natural":"Natürlich", "refined":"Veredelt", "crystal":"Kristall", "rare":"Selten", "ritual":"Ritual", "runic":"Runisch", "pure":"Rein", "spirit":"Geisterhaft", "risky":"Riskant"},
		"en":{"wearable":"Talisman", "mage":"Mage goods", "witch":"Witch goods", "citizen":"Citizen goods", "utility":"Utility", "hybrid":"Hybrid", "common":"Common", "natural":"Natural", "refined":"Refined", "crystal":"Crystal", "rare":"Rare", "ritual":"Ritual", "runic":"Runic", "pure":"Pure", "spirit":"Spirit", "risky":"Risky"},
	}
	return str((translations[language] as Dictionary).get(tag, tag.capitalize()))

func _goods_class_names(class_ids: Variant) -> String:
	var names: PackedStringArray = []
	if class_ids is Array:
		for class_id: Variant in class_ids:
			names.append(_name(registry.get_def("goods_classes", str(class_id))))
	return ", ".join(names) if not names.is_empty() else "—"

func _profession_names(profession_ids: Variant) -> String:
	var names: PackedStringArray = []
	if profession_ids is Array:
		for profession_id: Variant in profession_ids:
			names.append(_name(registry.get_def("disciplines", str(profession_id))))
	return " + ".join(names) if not names.is_empty() else "—"

func _material_requirements_text(requirements: Variant) -> String:
	var parts: PackedStringArray = []
	if requirements is Array:
		for value: Variant in requirements:
			if value is Dictionary:
				var requirement: Dictionary = value
				parts.append("%d× %s" % [int(requirement.get("quantity", 0)), _name(registry.get_def("materials", str(requirement.get("material_id", ""))))])
	return " + ".join(parts) if not parts.is_empty() else "—"

func _modifier_tradeoff_parts(data: Dictionary) -> Dictionary:
	var advantages: PackedStringArray = []
	var disadvantages: PackedStringArray = []
	var stat_names := {"power":"Leistung" if language == "de" else "Power", "stability":"Stabilität" if language == "de" else "Stability", "safety":"Sicherheit" if language == "de" else "Safety", "prestige":"Prestige"}
	for key: Variant in (data.get("stats", {}) as Dictionary).keys():
		var value := float((data.stats as Dictionary)[key])
		var text := "%s %+.0f" % [str(stat_names.get(str(key), str(key))), value]
		(advantages if value >= 0.0 else disadvantages).append(text)
	var cost_delta := float(data.get("cost_delta", 0.0))
	if not is_zero_approx(cost_delta):
		(disadvantages if cost_delta > 0.0 else advantages).append(("Kosten %+.0f G" if language == "de" else "Cost %+.0f G") % cost_delta)
	var hours_change := (float(data.get("hours_multiplier", 1.0)) - 1.0) * 100.0
	if not is_zero_approx(hours_change):
		(disadvantages if hours_change > 0.0 else advantages).append(("Aufwand %+.0f %%" if language == "de" else "Effort %+.0f%%") % hours_change)
	var quality_delta := float(data.get("quality_delta", 0.0))
	if not is_zero_approx(quality_delta):
		(advantages if quality_delta > 0.0 else disadvantages).append(("Qualität %+.0f" if language == "de" else "Quality %+.0f") % quality_delta)
	return {"advantages":advantages, "disadvantages":disadvantages}

func _contract_requirement_text(contract: Dictionary) -> String:
	var classes: Array = contract.get("accepted_classes", [])
	var class_names: PackedStringArray = []
	for class_id: Variant in classes:
		class_names.append(_name(registry.get_def("goods_classes", str(class_id))))
	var prefix := ("Klasse: " if language == "de" else "Class: ") if class_names.size() == 1 else ("Klassen: " if language == "de" else "Classes: ")
	return prefix + (" / ".join(class_names) if not class_names.is_empty() else "—")

func _contract_requirement_details(contract: Dictionary) -> String:
	var customer_name := _name(registry.get_def("customers", str(contract.get("customer", ""))))
	return (("Kunde: %s\nAkzeptiert alternativ: %s\nNötige Abdeckung: %s\nKundenansehen: +%.0f" if language == "de" else "Customer: %s\nAccepted alternatives: %s\nRequired coverage: %s\nCustomer standing: +%.0f") % [customer_name, _goods_class_names(contract.get("accepted_classes", [])), _profession_names(contract.get("required_coverage", [])), float(contract.get("faction_reputation_reward", 0.0))])

func _contract_mismatch_summary(contract: Dictionary) -> String:
	var lines: PackedStringArray = []
	for blueprint_id: Variant in (simulation.state.products as Dictionary).keys():
		var product: Dictionary = (simulation.state.products as Dictionary)[blueprint_id]
		if int(product.get("quantity", 0)) <= 0:
			continue
		var blueprint: Dictionary = (simulation.state.blueprints as Dictionary).get(blueprint_id, {})
		var status := simulation.contract_product_status(str(blueprint_id), contract)
		var reasons: PackedStringArray = []
		if not bool(status.get("class_match", false)):
			reasons.append("falsche Warenklasse" if language == "de" else "wrong goods class")
		if not bool(status.get("coverage_match", false)):
			reasons.append("falsche Professionsabdeckung" if language == "de" else "wrong profession coverage")
		if not bool(status.get("quality_match", false)):
			reasons.append(("Qualität %.0f < %.0f" if language == "de" else "quality %.0f < %.0f") % [float(status.get("quality", 0.0)), float(contract.get("min_quality", 0.0))])
		lines.append("%s: %d · %s" % [str(blueprint.get("name", blueprint_id)), int(product.get("quantity", 0)), ("passend" if language == "de" else "eligible") if bool(status.get("matches", false)) else ", ".join(reasons)])
	return "\n".join(lines) if not lines.is_empty() else ("Keine fertigen Waren im Lager." if language == "de" else "No finished goods in storage.")

func _t(key: String) -> String:
	var localized: Dictionary = UI_TEXT.get(language, {})
	return str(localized.get(key, key))

func _blueprint_cost_text(computed: Dictionary) -> String:
	return ("Herstellung %.2f G + Materialwert ca. %.2f G = Stückkosten ca. %.2f G\nMaterialwert zu aktuellen Einkaufspreisen; vorhandenes Material wird nicht erneut bezahlt." if language == "de" else "Processing %.2f G + estimated materials %.2f G = estimated unit cost %.2f G\nMaterials valued at current purchase prices; existing stock is not charged again.") % [float(computed.get("processing_cost", 0.0)), float(computed.get("material_cost", 0.0)), float(computed.get("unit_cost", 0.0))]

func _money(value: float) -> String:
	return "%s G" % String.num(value, 0)

func _signed_money(value: float) -> String:
	return ("+" if value >= 0.0 else "−") + _money(absf(value))
