@tool
class_name MapAuthoringCanvas
extends Control

signal shape_added
signal zoom_changed(value: float)

const MIN_ZOOM := 0.5
const MAX_ZOOM := 8.0
const ZOOM_STEP := 1.25

const COLORS := {
	"walkable": Color(0.20, 0.85, 0.35, 0.28),
	"wall": Color(0.95, 0.25, 0.20, 0.55),
	"opening": Color(0.20, 0.75, 1.0, 0.55),
	"railing": Color(1.0, 0.75, 0.15, 0.65),
	"invisible_wall": Color(1.0, 1.0, 1.0, 0.45),
	"object": Color(0.55, 0.32, 0.14, 0.8),
	"door": Color(1.0, 0.64, 0.12, 0.85),
	"stairs": Color(0.75, 0.35, 1.0, 0.85),
}

var source_size := Vector2(1600, 1600)
var pixels_per_foot: float = 12.0
var stair_start_feet: float = 0.0
var stair_end_feet: float = 10.0
var texture: Texture2D
var layer_id: StringName = &"ground"
var tool_id: StringName = &"walkable"
var snap_pixels: float = 10.0
var wall_height_feet: float = 9.0
var wall_width_pixels: float = 20.0
var shapes: Dictionary = {
	&"ground": {"walkable": [], "wall": [], "opening": [], "railing": [], "invisible_wall": [], "object": [], "door": []},
	&"level_1": {"walkable": [], "wall": [], "opening": [], "railing": [], "invisible_wall": [], "object": [], "door": []},
}
var stairs: Array[Dictionary] = []
var light_points: Array[Dictionary] = []
var light_level := 1
var light_radius_feet := 15.0
var drag_start := Vector2.INF
var drag_current := Vector2.INF
var pending_stair_bounds := Rect2()
var pending_stair_start := Vector2.INF
var object_preset: Dictionary = {"preset_id": &"crate", "display_name": "Crate", "height_feet": 3.0, "collision_enabled": true, "blocks_movement": true, "blocks_line_of_sight": true, "color": Color("8a6544")}
var door_starts_open := false
var zoom_factor := 1.0
var pan_offset := Vector2.ZERO
var panning := false

func _ready() -> void:
	custom_minimum_size = Vector2(600, 500)
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	clip_contents = true
	resized.connect(_clamp_view)

func reset_view() -> void:
	zoom_factor = 1.0
	pan_offset = Vector2.ZERO
	zoom_changed.emit(zoom_factor)
	queue_redraw()

func zoom_at_screen_position(factor: float, screen_point: Vector2) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var before := _screen_to_map_unclamped(screen_point)
	var next_zoom := clampf(zoom_factor * factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(next_zoom, zoom_factor):
		return
	zoom_factor = next_zoom
	var rect := _content_rect()
	pan_offset += screen_point - (rect.position + before / source_size * rect.size)
	_clamp_view()
	zoom_changed.emit(zoom_factor)
	queue_redraw()

func _clamp_view() -> void:
	var fit_scale := minf(size.x / source_size.x, size.y / source_size.y)
	var drawn := source_size * fit_scale * zoom_factor
	var limit := Vector2(maxf(0.0, (drawn.x - size.x) * 0.5), maxf(0.0, (drawn.y - size.y) * 0.5))
	pan_offset = pan_offset.clamp(-limit, limit)
	queue_redraw()

func set_layer(value: StringName, layer_texture: Texture2D) -> void:
	ensure_layer(value)
	layer_id = value
	texture = layer_texture
	queue_redraw()

func ensure_layer(value: StringName) -> void:
	if not shapes.has(value):
		shapes[value] = {"walkable": [], "wall": [], "opening": [], "railing": [], "invisible_wall": [], "object": [], "door": []}
	elif not shapes[value].has("door"):
		shapes[value]["door"] = []

func set_tool(value: StringName) -> void:
	tool_id = value
	pending_stair_bounds = Rect2()
	pending_stair_start = Vector2.INF
	drag_start = Vector2.INF
	drag_current = Vector2.INF
	queue_redraw()

func set_snap_pixels(value: float) -> void:
	snap_pixels = maxf(1.0, value)
	queue_redraw()

func undo_last() -> void:
	if tool_id == &"stairs":
		if not stairs.is_empty(): stairs.pop_back()
	elif tool_id == &"light_point":
		for index in range(light_points.size() - 1, -1, -1):
			if light_points[index].get("surface_id", &"ground") == layer_id:
				light_points.remove_at(index)
				break
	else:
		var entries: Array = shapes[layer_id][String(tool_id)]
		if not entries.is_empty(): entries.pop_back()
	queue_redraw()

func clear_all() -> void:
	for id in shapes:
		for kind in shapes[id]: shapes[id][kind].clear()
	stairs.clear()
	light_points.clear()
	queue_redraw()

func object_layer_order(floor_id: StringName) -> Array[int]:
	ensure_layer(floor_id)
	var objects: Array = shapes[floor_id].object
	var order: Array[int] = []
	for index in range(objects.size()):
		if objects[index] is Dictionary and int(objects[index].get("image_layer", 1)) == 0:
			order.append(index)
	order.append(-1) # The floor image stays between the two object groups.
	for index in range(objects.size()):
		if not (objects[index] is Dictionary) or int(objects[index].get("image_layer", 1)) != 0:
			order.append(index)
	return order

func move_object_layer(floor_id: StringName, object_index: int, direction: int) -> int:
	var objects: Array = shapes[floor_id].object
	if object_index < 0 or object_index >= objects.size() or abs(direction) != 1:
		return object_index
	var order := object_layer_order(floor_id)
	var position := order.find(object_index)
	var destination := position + direction
	if destination < 0 or destination >= order.size():
		return object_index
	if order[destination] == -1:
		var entry: Dictionary = objects[object_index]
		entry.image_layer = 1 if direction > 0 else 0
		objects[object_index] = entry
	order[position] = order[destination]
	order[destination] = object_index
	var reordered: Array = []
	for index in order:
		if index >= 0:
			reordered.append(objects[index])
	shapes[floor_id].object = reordered
	queue_redraw()
	return destination if destination < order.find(-1) else destination - 1

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_at_screen_position(ZOOM_STEP, event.position)
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_at_screen_position(1.0 / ZOOM_STEP, event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		panning = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and panning:
		pan_offset += event.relative
		_clamp_view()
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if tool_id == &"stairs" and pending_stair_bounds.has_area():
			if event.pressed:
				_commit_stair_point(_screen_to_map(event.position))
			return
		if event.pressed:
			drag_start = _screen_to_map(event.position)
			drag_current = drag_start
		else:
			_commit_drag(_screen_to_map(event.position))
	elif event is InputEventMouseMotion and drag_start != Vector2.INF:
		drag_current = _screen_to_map(event.position)
		queue_redraw()

func _commit_drag(end: Vector2) -> void:
	if drag_start == Vector2.INF:
		return
	if tool_id == &"light_point":
		var light_rect := Rect2(drag_start, end - drag_start).abs()
		if light_rect.size.x >= snap_pixels and light_rect.size.y >= snap_pixels:
			light_points.append({"surface_id": layer_id, "rect": light_rect, "level": light_level})
		else:
			light_points.append({"surface_id": layer_id, "position": end, "radius_feet": light_radius_feet, "level": light_level})
	elif tool_id == &"stairs":
		var rect := Rect2(drag_start, end - drag_start).abs()
		if rect.size.x >= snap_pixels and rect.size.y >= snap_pixels:
			pending_stair_bounds = rect
			pending_stair_start = Vector2.INF
	else:
		var rect := Rect2(drag_start, end - drag_start).abs()
		if tool_id == &"wall" and drag_start.distance_to(end) >= snap_pixels:
			shapes[layer_id].wall.append({"from": drag_start, "to": end, "width_feet": wall_width_pixels / pixels_per_foot, "height_feet": wall_height_feet})
		elif rect.size.x >= 2.0 and rect.size.y >= 2.0:
			if tool_id == &"object":
				var entry := object_preset.duplicate()
				entry["rect"] = rect
				shapes[layer_id][String(tool_id)].append(entry)
			elif tool_id == &"door":
				shapes[layer_id].door.append({"rect": rect, "starts_open": door_starts_open})
			else:
				shapes[layer_id][String(tool_id)].append(rect)
	drag_start = Vector2.INF
	drag_current = Vector2.INF
	shape_added.emit()
	queue_redraw()

func _commit_stair_point(point: Vector2) -> void:
	if not pending_stair_bounds.has_point(point):
		return
	if pending_stair_start == Vector2.INF:
		pending_stair_start = point
		queue_redraw()
		return
	if pending_stair_start.distance_to(point) < snap_pixels:
		return
	var direction := (point - pending_stair_start).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var width_pixels := minf(pending_stair_bounds.size.x / maxf(absf(perpendicular.x), 0.001), pending_stair_bounds.size.y / maxf(absf(perpendicular.y), 0.001))
	stairs.append({"from": pending_stair_start, "to": point, "from_elevation_feet": stair_start_feet, "to_elevation_feet": stair_end_feet, "width_feet": width_pixels / pixels_per_foot, "bounds": pending_stair_bounds})
	pending_stair_bounds = Rect2()
	pending_stair_start = Vector2.INF
	shape_added.emit()
	queue_redraw()

func _content_rect() -> Rect2:
	var scale_factor := minf(size.x / source_size.x, size.y / source_size.y) * zoom_factor
	var drawn := source_size * scale_factor
	return Rect2((size - drawn) * 0.5 + pan_offset, drawn)

func _screen_to_map_unclamped(point: Vector2) -> Vector2:
	var rect := _content_rect()
	return (point - rect.position) / rect.size * source_size

func _screen_to_map(point: Vector2) -> Vector2:
	var map_point := _screen_to_map_unclamped(point).clamp(Vector2.ZERO, source_size)
	return Vector2(
		roundf(map_point.x / snap_pixels) * snap_pixels,
		roundf(map_point.y / snap_pixels) * snap_pixels
	).clamp(Vector2.ZERO, source_size)

func _map_to_screen(point: Vector2) -> Vector2:
	var rect := _content_rect()
	return rect.position + point / source_size * rect.size

func _draw() -> void:
	var content := _content_rect()
	draw_rect(content, Color(0.04, 0.05, 0.06), true)
	for entry in shapes[layer_id].object:
		if entry is Dictionary and int(entry.get("image_layer", 1)) == 0:
			_draw_shape("object", entry, content)
	if texture != null:
		draw_texture_rect(texture, content, false)
	var grid_color := Color(0.75, 0.85, 1.0, 0.13)
	var x := snap_pixels
	while x < source_size.x:
		var screen_x := _map_to_screen(Vector2(x, 0)).x
		draw_line(Vector2(screen_x, content.position.y), Vector2(screen_x, content.end.y), grid_color)
		x += snap_pixels
	var y := snap_pixels
	while y < source_size.y:
		var screen_y := _map_to_screen(Vector2(0, y)).y
		draw_line(Vector2(content.position.x, screen_y), Vector2(content.end.x, screen_y), grid_color)
		y += snap_pixels
	for kind in shapes[layer_id]:
		for entry in shapes[layer_id][kind]:
			if kind == "object" and entry is Dictionary and int(entry.get("image_layer", 1)) == 0:
				continue
			_draw_shape(String(kind), entry, content)
	for stair in stairs:
		if stair.has("bounds"):
			var bounds: Rect2 = stair.bounds
			draw_rect(Rect2(_map_to_screen(bounds.position), bounds.size / source_size * content.size), Color(COLORS.stairs, 0.22), true)
		var first := _map_to_screen(stair.from)
		var last := _map_to_screen(stair.to)
		draw_line(first, last, COLORS.stairs, 6.0)
		draw_circle(first, 5.0, Color.WHITE)
		draw_circle(last, 5.0, COLORS.stairs)
	for point in light_points:
		if point.get("surface_id", &"ground") != layer_id:
			continue
		var color: Color = [Color("ffe08a"), Color("a8d9ff"), Color("7175c9"), Color("35364e")][clampi(int(point.get("level", 1)), 0, 3)]
		if point.has("rect"):
			var area: Rect2 = point.rect
			var screen_rect := Rect2(_map_to_screen(area.position), area.size / source_size * content.size)
			draw_rect(screen_rect, Color(color, 0.14), true)
			draw_rect(screen_rect, color, false, 2.0)
		else:
			var center := _map_to_screen(point.get("position", Vector2.ZERO))
			var radius := float(point.get("radius_feet", 15.0)) * pixels_per_foot * content.size.x / source_size.x
			draw_circle(center, radius, Color(color, 0.14))
			draw_arc(center, radius, 0.0, TAU, 48, color, 2.0)
			draw_circle(center, 5.0, color)
	if drag_start != Vector2.INF:
		if tool_id == &"light_point":
			var preview := Rect2(drag_start, drag_current - drag_start).abs()
			if preview.size.x >= snap_pixels and preview.size.y >= snap_pixels:
				draw_rect(Rect2(_map_to_screen(preview.position), preview.size / source_size * content.size), Color("ffe08a", 0.25), true)
			else:
				draw_circle(_map_to_screen(drag_current), 5.0, Color("ffe08a"))
		elif tool_id == &"stairs":
			var preview := Rect2(drag_start, drag_current - drag_start).abs()
			draw_rect(Rect2(_map_to_screen(preview.position), preview.size / source_size * content.size), Color(COLORS.stairs, 0.25), true)
		elif tool_id == &"wall":
			draw_line(_map_to_screen(drag_start), _map_to_screen(drag_current), COLORS.wall, maxf(2.0, wall_width_pixels * content.size.x / source_size.x))
		else:
			var preview := Rect2(drag_start, drag_current - drag_start).abs()
			draw_rect(Rect2(_map_to_screen(preview.position), preview.size / source_size * content.size), COLORS[String(tool_id)], true)
	if pending_stair_bounds.has_area():
		var pending_screen := Rect2(_map_to_screen(pending_stair_bounds.position), pending_stair_bounds.size / source_size * content.size)
		draw_rect(pending_screen, Color(COLORS.stairs, 0.25), true)
		draw_rect(pending_screen, COLORS.stairs, false, 2.0)
		if pending_stair_start != Vector2.INF:
			draw_circle(_map_to_screen(pending_stair_start), 6.0, Color.WHITE)

func _draw_shape(kind: String, entry: Variant, content: Rect2) -> void:
	if kind == "wall" and entry is Dictionary and entry.has("from"):
		var width := float(entry.get("width_feet", 1.5)) * pixels_per_foot * content.size.x / source_size.x
		draw_line(_map_to_screen(entry.from), _map_to_screen(entry.to), COLORS.wall, maxf(2.0, width))
		return
	var map_rect: Rect2 = entry.get("rect", Rect2()) if entry is Dictionary else Rect2(entry)
	var screen_rect := Rect2(_map_to_screen(map_rect.position), map_rect.size / source_size * content.size)
	var entry_color: Color = entry.get("color", COLORS[kind]) if entry is Dictionary else COLORS[kind]
	var has_texture := entry is Dictionary and entry.get("texture") is Texture2D
	if has_texture:
		draw_texture_rect(entry.get("texture"), screen_rect, false)
	else:
		draw_rect(screen_rect, entry_color, true)
	draw_rect(screen_rect, COLORS[kind].lightened(0.25), false, 2.0)
	if kind == "door":
		draw_string(ThemeDB.fallback_font, screen_rect.position + Vector2(2, -3), "OPEN" if entry.get("starts_open", false) else "CLOSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("82f4c8") if entry.get("starts_open", false) else Color("ffce80"))
