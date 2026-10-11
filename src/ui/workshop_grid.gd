class_name WorkshopGrid
extends Control

signal cell_clicked(cell: Vector2i)
signal room_drawn(rect: Rect2i)
signal room_resize_requested(room_id: String, rect: Rect2i)
signal preview_changed(rect: Rect2i, room_id: String)

const CELL_SIZE := 36

var grid_size := Vector2i(20, 12)
var rooms: Array = []
var stations: Array = []
var staff: Array = []
var sources: Array = []
var registry: ContentRegistry
var language := "de"
var mode := "room"
var show_grid := false
var hovered := Vector2i(-1, -1)
var selected_room_id := ""
var dragging := false
var resizing := false
var drag_start := Vector2i.ZERO
var drag_rect := Rect2i()

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_update_size()
	clip_contents = true
	mouse_exited.connect(func() -> void: hovered = Vector2i(-1, -1); queue_redraw())

func set_world(new_rooms: Array, new_stations: Array, new_staff: Array, new_sources: Array, content_registry: ContentRegistry, new_grid_size: Vector2i, new_mode: String, new_language: String) -> void:
	rooms = new_rooms
	stations = new_stations
	staff = new_staff
	sources = new_sources
	registry = content_registry
	grid_size = new_grid_size
	mode = new_mode
	language = new_language
	if not selected_room_id.is_empty() and _room_by_id(selected_room_id).is_empty():
		selected_room_id = ""
	_update_size()
	queue_redraw()

func set_mode(new_mode: String) -> void:
	mode = new_mode
	dragging = false
	resizing = false
	drag_rect = Rect2i()
	preview_changed.emit(drag_rect, "")
	queue_redraw()

func _update_size() -> void:
	custom_minimum_size = Vector2(grid_size.x * CELL_SIZE, grid_size.y * CELL_SIZE)
	size = custom_minimum_size

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hovered = _cell_at(event.position)
		if dragging:
			if resizing:
				var room := _room_by_id(selected_room_id)
				if not room.is_empty():
					var old_rect := _array_to_rect(room.rect)
					var end_cell := _clamp_cell(hovered)
					drag_rect = Rect2i(old_rect.position, end_cell - old_rect.position + Vector2i.ONE)
			else:
				drag_rect = _rect_between(drag_start, _clamp_cell(hovered))
			preview_changed.emit(drag_rect, selected_room_id if resizing else "")
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _cell_at(event.position)
		if event.pressed:
			if not _inside(cell):
				return
			if mode == "room":
				dragging = true
				resizing = false
				drag_start = cell
				drag_rect = Rect2i(cell, Vector2i.ONE)
				preview_changed.emit(drag_rect, "")
			elif mode == "resize":
				var selected := _room_by_id(selected_room_id)
				if not selected.is_empty() and cell == _array_to_rect(selected.rect).end - Vector2i.ONE:
					dragging = true
					resizing = true
					drag_rect = _array_to_rect(selected.rect)
					preview_changed.emit(drag_rect, selected_room_id)
				else:
					selected_room_id = _room_id_at(cell)
					preview_changed.emit(Rect2i(), selected_room_id)
					queue_redraw()
			else:
				cell_clicked.emit(cell)
		elif dragging:
			dragging = false
			if resizing:
				room_resize_requested.emit(selected_room_id, drag_rect)
			else:
				room_drawn.emit(drag_rect)
			resizing = false
			drag_rect = Rect2i()
			preview_changed.emit(drag_rect, "")
			queue_redraw()

func _draw() -> void:
	_draw_terrain()
	for room_value: Variant in rooms:
		_draw_building(room_value as Dictionary)
	for source_value: Variant in sources:
		var source: Dictionary = source_value
		if not bool(source.get("offsite", false)):
			_draw_source(source)
	for station_value: Variant in stations:
		_draw_station(station_value as Dictionary)
	if show_grid or dragging:
		for x: int in range(grid_size.x + 1):
			draw_line(Vector2(x * CELL_SIZE, 0), Vector2(x * CELL_SIZE, grid_size.y * CELL_SIZE), Color(0.8, 0.87, 0.72, 0.17))
		for y: int in range(grid_size.y + 1):
			draw_line(Vector2(0, y * CELL_SIZE), Vector2(grid_size.x * CELL_SIZE, y * CELL_SIZE), Color(0.8, 0.87, 0.72, 0.17))
	if dragging and drag_rect.get_area() > 0:
		var preview := _pixel_rect(drag_rect)
		draw_rect(preview.grow(-2), Color(0.35, 0.8, 0.55, 0.3), true)
		draw_rect(preview.grow(-2), Color("8ed6a7"), false, 2.0)
	if _inside(hovered):
		var hover_rect := Rect2(Vector2(hovered * CELL_SIZE), Vector2.ONE * CELL_SIZE).grow(-1)
		draw_rect(hover_rect, Color(1, 0.91, 0.65, 0.12), true)
		draw_rect(hover_rect, Color("efd498"), false, 1.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(grid_size * CELL_SIZE)), Color("77816a"), false, 2.0)

func _draw_terrain() -> void:
	# Coordinate-based decoration stays stable and never uses simulation RNG.
	for y: int in grid_size.y:
		for x: int in grid_size.x:
			var origin := Vector2(x, y) * CELL_SIZE
			var cell := Vector2i(x, y)
			var seed_value := posmod(x * 73 + y * 137 + x * y * 17, 101)
			var near_room := false
			for room_value: Variant in rooms:
				if _array_to_rect((room_value as Dictionary).rect).grow(1).has_point(cell):
					near_room = true
					break
			var shade := float(seed_value) / 100.0
			var ground := Color("344738").lerp(Color("40513b"), shade * 0.5)
			if near_room:
				ground = Color("575441").lerp(Color("635e4a"), shade * 0.4)
			draw_rect(Rect2(origin, Vector2.ONE * CELL_SIZE), ground)
			for detail: int in 3:
				var point := origin + Vector2(4 + posmod(seed_value + detail * 13, CELL_SIZE - 8), 4 + posmod(seed_value * 3 + detail * 19, CELL_SIZE - 8))
				if near_room:
					draw_line(point, point + Vector2(3, 0), Color("77705a"), 1.0)
				else:
					draw_line(point, point + Vector2(-2, -3), Color("546b46"), 1.0)
					draw_line(point, point + Vector2(1, -4), Color("64764e"), 1.0)

func _draw_building(room: Dictionary) -> void:
	var tiles := _array_to_rect(room.rect)
	var bounds := _pixel_rect(tiles).grow(-2)
	var definition := registry.get_def("rooms", str(room.type)) if registry != null else {}
	var accent := Color(str(definition.get("color", "405060"))).lightened(0.18)
	var laboratory := str(room.type) == "base:laboratory"
	var residence := bool(definition.get("housing", false))
	draw_rect(Rect2(bounds.position + Vector2(3, 5), bounds.size), Color(0.05, 0.08, 0.06, 0.45))
	draw_rect(bounds, Color("242c2a"))
	var floor_bounds := bounds.grow(-5)
	var floor_color := Color("454f60") if laboratory else Color("80654a")
	if str(room.type) == "base:storage":
		floor_color = Color("606859")
	draw_rect(floor_bounds, floor_color)
	for y: int in range(int(floor_bounds.position.y), int(floor_bounds.end.y), 12):
		var row_index := (y - int(floor_bounds.position.y)) / 12
		var plank_color := floor_color.lightened(0.025) if row_index % 2 == 0 else floor_color.darkened(0.045)
		var height := minf(12, floor_bounds.end.y - y)
		draw_rect(Rect2(floor_bounds.position.x, y, floor_bounds.size.x, height), plank_color)
		draw_line(Vector2(floor_bounds.position.x, y), Vector2(floor_bounds.end.x, y), floor_color.darkened(0.17))
		for x: int in range(int(floor_bounds.position.x) + (18 if row_index % 2 == 0 else 36), int(floor_bounds.end.x), 42):
			draw_line(Vector2(x, y), Vector2(x, y + height), floor_color.darkened(0.12))
	if laboratory and floor_bounds.size.x > 80 and floor_bounds.size.y > 80:
		var seal_center := floor_bounds.get_center() + Vector2(12, 12)
		draw_arc(seal_center, 26, 0, TAU, 40, Color("74839c"), 1.0, true)
		draw_arc(seal_center, 21, 0, TAU, 40, Color("64768e"), 1.0, true)
		for index: int in 6:
			var start := seal_center + Vector2.from_angle(index * TAU / 6.0) * 21
			var end := seal_center + Vector2.from_angle((index + 2) * TAU / 6.0) * 21
			draw_line(start, end, Color("64768e"), 1.0, true)
	if residence and tiles.size.x >= 3 and tiles.size.y >= 3:
		var bed := Rect2(bounds.end - Vector2(38, 55), Vector2(25, 39))
		draw_rect(bed.grow(3), Color("4f392e"))
		draw_rect(bed, Color("927152"))
		draw_rect(Rect2(bed.position + Vector2(2, 10), Vector2(21, 25)), Color("567d72"))
		draw_rect(Rect2(bed.position + Vector2(3, 2), Vector2(19, 8)), Color("dbc9a1"))
		draw_line(bed.position + Vector2(3, 14), bed.position + Vector2(22, 14), Color("8bac95"), 2)
	# Raised wall caps and corner posts give the cutaway rooms a visible footprint.
	draw_rect(bounds, Color("b1a082"), false, 3.0)
	draw_line(bounds.position + Vector2(2, 3), Vector2(bounds.end.x - 2, bounds.position.y + 3), accent.lightened(0.22), 4)
	draw_line(Vector2(bounds.position.x + 3, bounds.end.y - 3), bounds.end - Vector2(3, 3), Color("4b4136"), 4)
	for corner: Vector2 in [bounds.position, Vector2(bounds.end.x - 5, bounds.position.y), bounds.end - Vector2(5, 5), Vector2(bounds.position.x, bounds.end.y - 5)]:
		draw_rect(Rect2(corner, Vector2(5, 5)), Color("d0ba8e"))
	var door_x := bounds.get_center().x
	draw_line(Vector2(door_x - 9, bounds.end.y - 2), Vector2(door_x + 9, bounds.end.y - 2), Color("bf995f"), 5)
	_draw_room_label(room, definition, bounds)
	if str(room.id) == selected_room_id:
		draw_rect(bounds.grow(1), Color("f0c875"), false, 2.0)
		draw_rect(Rect2(bounds.end - Vector2(12, 12), Vector2(10, 10)), Color("f0c875"))

func _draw_room_label(room: Dictionary, definition: Dictionary, bounds: Rect2) -> void:
	var tiles := _array_to_rect(room.rect)
	var label_y := bounds.position.y + 7
	# Prefer an empty edge row so labels never hide placed workstations.
	var top_free := true
	var bottom_free := true
	for station_value: Variant in stations:
		var cell := _array_to_position((station_value as Dictionary).position)
		if tiles.has_point(cell):
			top_free = top_free and cell.y != tiles.position.y
			bottom_free = bottom_free and cell.y != tiles.end.y - 1
	if not top_free:
		if not bottom_free:
			return
		label_y = bounds.end.y - 25
	var title := str(definition.get("name_" + language, room.type))
	var font := ThemeDB.fallback_font
	var available_width := bounds.size.x - 18
	var font_size := 12
	while font_size > 10 and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available_width:
		font_size -= 1
	while title.length() > 1 and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available_width:
		title = title.left(title.length() - 2) + "…"
	var badge := Rect2(Vector2(bounds.position.x + 7, label_y), Vector2(minf(available_width + 4, font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 8), 18))
	draw_rect(badge, Color(0.08, 0.11, 0.12, 0.87))
	draw_string(font, badge.position + Vector2(4, 13), title, HORIZONTAL_ALIGNMENT_LEFT, available_width, font_size, Color("eee0bc"))

func _draw_station(station: Dictionary) -> void:
	var definition := registry.get_def("stations", str(station.type))
	var center := _cell_center(_array_to_position(station.position))
	draw_set_transform(center)
	_draw_ellipse_shape(Vector2(1, 7), Vector2(14, 6), Color(0, 0, 0, 0.3))
	match str(definition.get("kind", "")):
		"research":
			draw_rect(Rect2(-13, -10, 26, 19), Color("403f59"))
			draw_rect(Rect2(-12, -11, 24, 16), Color("876641"))
			draw_rect(Rect2(-10, -9, 17, 12), Color("dbc89d"))
			draw_line(Vector2(-2, -8), Vector2(-2, 2), Color("8e775b"))
			for y: int in [-6, -3, 0]:
				draw_line(Vector2(-8, y), Vector2(-4, y), Color("847258"))
				draw_line(Vector2(0, y), Vector2(4, y), Color("847258"))
			draw_circle(Vector2(9, -8), 6, Color(0.4, 0.7, 1.0, 0.18))
			draw_circle(Vector2(9, -8), 3, Color("9dd9f2"))
			draw_line(Vector2(-10, 7), Vector2(-10, 10), Color("4d3727"), 3)
			draw_line(Vector2(10, 7), Vector2(10, 10), Color("4d3727"), 3)
		"storage":
			draw_rect(Rect2(-13, -13, 26, 26), Color("47382c"))
			for y: int in [-9, 2]:
				for x: int in [-10, 2]:
					draw_rect(Rect2(x, y, 8, 8), Color("b48b56"))
					draw_line(Vector2(x + 1, y + 1), Vector2(x + 7, y + 7), Color("735633"))
				draw_line(Vector2(-12, y + 9), Vector2(12, y + 9), Color("d2ab72"), 2)
		"production":
			draw_rect(Rect2(-13, -9, 26, 20), Color("48392d"))
			draw_rect(Rect2(-13, -12, 26, 17), Color("a57b4b"))
			draw_line(Vector2(-12, -10), Vector2(11, -10), Color("d1a26a"))
			var anvil := PackedVector2Array([Vector2(-9, -6), Vector2(6, -6), Vector2(9, -3), Vector2(2, -2), Vector2(2, 1), Vector2(-6, 1), Vector2(-5, -2), Vector2(-9, -3)])
			draw_colored_polygon(anvil, Color("bcc3c1"))
			draw_line(Vector2(7, 2), Vector2(10, -5), Color("503626"), 2)
			draw_line(Vector2(7, -6), Vector2(12, -4), Color("d1d2ba"), 3)
		_:
			draw_rect(Rect2(-10, -10, 20, 20), Color("948568"))
			draw_circle(Vector2.ZERO, 6, Color("d0d6bf"), false, 2)
	if _station_has_staff(str(station.id)):
		# A small worker silhouette indicates assignment, not simulated movement.
		draw_circle(Vector2(10, 9), 6, Color("21302e"))
		_draw_ellipse_shape(Vector2(10, 11), Vector2(5, 4), Color("739f9d"))
		draw_circle(Vector2(10, 6), 3, Color("edc28a"))
	draw_set_transform(Vector2.ZERO)

func _draw_source(source: Dictionary) -> void:
	var definition := registry.get_def("resource_sources", str(source.type))
	var center := _cell_center(_array_to_position(source.position))
	var accent := Color(str(definition.get("color", "78a86b")))
	draw_set_transform(center)
	_draw_ellipse_shape(Vector2(1, 9), Vector2(16, 6), Color(0.05, 0.08, 0.06, 0.35))
	match str(source.type):
		"base:timber_source":
			draw_rect(Rect2(-3, -2, 6, 16), Color("8e6840"))
			draw_line(Vector2(-1, 1), Vector2(-1, 12), Color("c19b60"), 2)
			for crown: Vector3 in [Vector3(-7, -4, 8), Vector3(6, -5, 10), Vector3(-1, -10, 9)]:
				draw_circle(Vector2(crown.x + 1, crown.y + 2), crown.z, Color("263f32"))
				draw_circle(Vector2(crown.x, crown.y), crown.z - 1, accent.darkened(0.1))
				draw_arc(Vector2(crown.x - 1, crown.y - 1), crown.z - 3, PI, TAU, 12, accent.lightened(0.2), 2, true)
		"base:water_source":
			_draw_ellipse_shape(Vector2.ZERO, Vector2(16, 12), Color("9a967b"))
			_draw_ellipse_shape(Vector2(0, -1), Vector2(12, 9), Color("285568"))
			_draw_ellipse_shape(Vector2(1, -1), Vector2(9, 6), accent)
			draw_arc(Vector2(1, -2), 5, 0, PI, 14, Color("b0dfdd"), 1.5, true)
			for index: int in 6:
				var stone := Vector2(cos(index * TAU / 6.0) * 14, sin(index * TAU / 6.0) * 10)
				draw_circle(stone, 3, Color("b0a789"))
		"base:herb_source":
			_draw_ellipse_shape(Vector2(0, 4), Vector2(15, 10), Color("584b36"))
			for x: int in [-9, 0, 9]:
				draw_line(Vector2(x, 8), Vector2(x, -7), Color("9aad60"), 2)
				for side: int in [-1, 1]:
					var leaf := PackedVector2Array([Vector2(x, 3), Vector2(x + side * 7, -3), Vector2(x + side * 6, 3)])
					draw_colored_polygon(leaf, accent)
				draw_circle(Vector2(x, -7), 2.5, Color("e5c68a"))
		"base:spirit_source":
			draw_circle(Vector2.ZERO, 17, Color(0.62, 0.43, 0.82, 0.10))
			_draw_ellipse_shape(Vector2(0, 7), Vector2(13, 7), Color("666178"))
			draw_arc(Vector2(0, 3), 13, 0, TAU, 24, accent.lightened(0.1), 1, true)
			_draw_crystal(Vector2(-6, 1), 0.7, accent.darkened(0.1))
			_draw_crystal(Vector2(5, 0), 0.9, accent)
			_draw_crystal(Vector2(0, -4), 1.0, accent.lightened(0.2))
		_:
			_draw_crystal(Vector2.ZERO, 1.0, accent)
	draw_set_transform(Vector2.ZERO)

func _draw_crystal(center: Vector2, scale_factor: float, color: Color) -> void:
	var points := PackedVector2Array([Vector2(0, -13), Vector2(5, -6), Vector2(4, 6), Vector2(0, 9), Vector2(-4, 6), Vector2(-5, -6)])
	for index: int in points.size():
		points[index] = center + points[index] * scale_factor
	draw_colored_polygon(points, color)
	draw_colored_polygon(PackedVector2Array([points[0], points[1], points[2], points[3]]), color.lightened(0.25))
	draw_line(points[0], points[3], Color("eadff5"), 1, true)

func _draw_ellipse_shape(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index: int in 24:
		points.append(center + Vector2(cos(index * TAU / 24.0), sin(index * TAU / 24.0)) * radii)
	draw_colored_polygon(points, color)

func _get_tooltip(at_position: Vector2) -> String:
	var cell := _cell_at(at_position)
	for station_value: Variant in stations:
		var station: Dictionary = station_value
		if _array_to_position(station.position) == cell:
			var definition := registry.get_def("stations", str(station.type))
			var people: PackedStringArray = []
			for entry_value: Variant in staff:
				var entry: Dictionary = entry_value
				if str(entry.get("station_id", "")) == str(station.id):
					var person := registry.get_def("staff", str(entry.id))
					people.append(str(person.get("name_" + language, entry.id)))
			return "%s\n%s" % [str(definition.get("name_" + language, station.type)), ("Unbesetzt" if language == "de" else "Unassigned") if people.is_empty() else ", ".join(people)]
	for source_value: Variant in sources:
		var source: Dictionary = source_value
		if not bool(source.get("offsite", false)) and _array_to_position(source.position) == cell:
			var definition := registry.get_def("resource_sources", str(source.type))
			return "%s\n%s: %.1f / %.0f" % [str(definition.get("name_" + language, source.type)), "Vorrat" if language == "de" else "Reserve", float(source.get("reserve", 0)), float(definition.get("max_reserve", 0))]
	var room := _room_by_id(_room_id_at(cell))
	if not room.is_empty():
		var definition := registry.get_def("rooms", str(room.type))
		return "%s · %d × %d" % [str(definition.get("name_" + language, room.type)), int(room.rect[2]), int(room.rect[3])]
	return ""

func _station_has_staff(station_id: String) -> bool:
	for entry_value: Variant in staff:
		if str((entry_value as Dictionary).get("station_id", "")) == station_id:
			return true
	return false

func _room_by_id(room_id: String) -> Dictionary:
	for value: Variant in rooms:
		if str((value as Dictionary).id) == room_id:
			return value as Dictionary
	return {}

func _room_id_at(cell: Vector2i) -> String:
	for value: Variant in rooms:
		var room: Dictionary = value
		if _array_to_rect(room.rect).has_point(cell):
			return str(room.id)
	return ""

func _rect_between(first: Vector2i, second: Vector2i) -> Rect2i:
	var top_left := Vector2i(mini(first.x, second.x), mini(first.y, second.y))
	var bottom_right := Vector2i(maxi(first.x, second.x), maxi(first.y, second.y))
	return Rect2i(top_left, bottom_right - top_left + Vector2i.ONE)

func _cell_at(pixel: Vector2) -> Vector2i:
	return Vector2i(floori(pixel.x / CELL_SIZE), floori(pixel.y / CELL_SIZE))

func _clamp_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(clampi(cell.x, 0, grid_size.x - 1), clampi(cell.y, 0, grid_size.y - 1))

func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y

func _array_to_rect(data: Array) -> Rect2i:
	return Rect2i(int(data[0]), int(data[1]), int(data[2]), int(data[3]))

func _array_to_position(data: Array) -> Vector2i:
	return Vector2i(int(data[0]), int(data[1]))

func _pixel_rect(rect: Rect2i) -> Rect2:
	return Rect2(Vector2(rect.position * CELL_SIZE), Vector2(rect.size * CELL_SIZE))

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * CELL_SIZE, (cell.y + 0.5) * CELL_SIZE)
