class_name WorkshopGrid
extends Control

signal cell_clicked(cell: Vector2i)
signal room_drawn(rect: Rect2i)
signal room_resize_requested(room_id: String, rect: Rect2i)
signal preview_changed(rect: Rect2i, room_id: String)

const CELL_SIZE := 28

var grid_size := Vector2i(20, 12)
var rooms: Array = []
var stations: Array = []
var staff: Array = []
var sources: Array = []
var registry: ContentRegistry
var language := "de"
var mode := "room"
var hovered := Vector2i(-1, -1)
var selected_room_id := ""
var dragging := false
var resizing := false
var drag_start := Vector2i.ZERO
var drag_rect := Rect2i()

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	_update_size()

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
	for y: int in grid_size.y:
		for x: int in grid_size.x:
			var cell_rect := Rect2(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			draw_rect(cell_rect, Color("18202a"), true)
			draw_rect(cell_rect, Color("2a3543"), false, 1.0)
	for room_value: Variant in rooms:
		var room: Dictionary = room_value
		var room_rect := _pixel_rect(_array_to_rect(room.rect))
		var definition := registry.get_def("rooms", str(room.type)) if registry != null else {}
		var color := Color(str(definition.get("color", "405060")))
		draw_rect(room_rect.grow(-2), color, true)
		draw_rect(room_rect.grow(-2), color.lightened(0.28), false, 2.0)
		if str(room.id) == selected_room_id:
			draw_rect(room_rect.grow(-1), Color("f0c875"), false, 3.0)
			var handle := Rect2(room_rect.end - Vector2(13, 13), Vector2(11, 11))
			draw_rect(handle, Color("f0c875"), true)
		var room_name := str(definition.get("name_" + language, room.type))
		draw_string(ThemeDB.fallback_font, room_rect.position + Vector2(7, 18), "%s · %d×%d" % [room_name, int(room.rect[2]), int(room.rect[3])], HORIZONTAL_ALIGNMENT_LEFT, room_rect.size.x - 12, 12, Color.WHITE)
	for source_value: Variant in sources:
		var source: Dictionary = source_value
		if bool(source.get("offsite", false)):
			continue
		var source_pos := _array_to_position(source.position)
		var source_def := registry.get_def("resource_sources", str(source.type))
		var center := _cell_center(source_pos)
		var color := Color(str(source_def.get("color", "78a86b")))
		var diamond := PackedVector2Array([center + Vector2(0, -10), center + Vector2(10, 0), center + Vector2(0, 10), center + Vector2(-10, 0)])
		draw_colored_polygon(diamond, color)
		draw_polyline(diamond + PackedVector2Array([diamond[0]]), color.lightened(0.35), 2.0)
		draw_string(ThemeDB.fallback_font, center + Vector2(-5, 5), _source_letter(str(source.type)), HORIZONTAL_ALIGNMENT_CENTER, 10, 11, Color.WHITE)
	for station_value: Variant in stations:
		var station: Dictionary = station_value
		var station_def := registry.get_def("stations", str(station.type))
		var center := _cell_center(_array_to_position(station.position))
		var station_rect := Rect2(center - Vector2(9, 9), Vector2(18, 18))
		draw_rect(station_rect, Color("263545"), true)
		draw_rect(station_rect, Color("b9c7d5"), false, 2.0)
		draw_string(ThemeDB.fallback_font, center + Vector2(-6, 5), _station_letter(str(station_def.get("kind", ""))), HORIZONTAL_ALIGNMENT_CENTER, 12, 11, Color("dbe6ef"))
		if _station_has_staff(str(station.id)):
			var person_center := center + Vector2(8, -8)
			draw_circle(person_center, 5.5, Color("e6bd69"))
			draw_circle(person_center, 5.5, Color("fff1bd"), false, 1.5)
	if dragging and drag_rect.get_area() > 0:
		var preview := _pixel_rect(drag_rect)
		draw_rect(preview.grow(-2), Color(0.35, 0.8, 0.55, 0.3), true)
		draw_rect(preview.grow(-2), Color("8ed6a7"), false, 3.0)
	if _inside(hovered):
		draw_rect(Rect2(hovered.x * CELL_SIZE, hovered.y * CELL_SIZE, CELL_SIZE, CELL_SIZE), Color(1, 1, 1, 0.13), true)

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

func _station_letter(kind: String) -> String:
	return {"research":"F", "production":"W", "storage":"L"}.get(kind, "S")

func _source_letter(type_id: String) -> String:
	return {"base:timber_source":"H", "base:water_source":"Q", "base:herb_source":"K", "base:spirit_source":"G"}.get(type_id, "R")
