class_name BattlefieldCameraController
extends Camera2D

signal camera_changed

@export_range(0.1, 4.0, 0.05) var minimum_zoom: float = 0.35
@export_range(0.1, 4.0, 0.05) var maximum_zoom: float = 2.0
@export_range(0.01, 1.0, 0.01) var zoom_step: float = 0.12
@export var keyboard_pan_speed: float = 900.0

var map_bounds: Rect2 = Rect2()
var dragging: bool = false


func configure(bounds: Rect2, focus_position: Vector2 = Vector2.ZERO) -> void:
	map_bounds = bounds
	position = focus_position
	limit_left = floori(bounds.position.x)
	limit_top = floori(bounds.position.y)
	limit_right = ceili(bounds.end.x)
	limit_bottom = ceili(bounds.end.y)
	_set_zoom(zoom.x)
	_clamp_to_map()


func screen_to_world(screen_position: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_position


func world_to_screen(world_position: Vector2) -> Vector2:
	return get_canvas_transform() * world_position


func _process(delta: float) -> void:
	var required_zoom := get_minimum_allowed_zoom()
	if zoom.x < required_zoom:
		zoom = Vector2.ONE * required_zoom
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	).normalized()
	if not direction.is_zero_approx():
		position += direction * keyboard_pan_speed * delta / zoom.x
		_clamp_to_map()
		camera_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			get_viewport().set_input_as_handled()
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(zoom.x + zoom_step)
			get_viewport().set_input_as_handled()
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(zoom.x - zoom_step)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and dragging:
		position -= event.relative / zoom.x
		_clamp_to_map()
		camera_changed.emit()
		get_viewport().set_input_as_handled()


func _set_zoom(value: float) -> void:
	var clamped := clampf(value, get_minimum_allowed_zoom(), maximum_zoom)
	zoom = Vector2.ONE * clamped
	_clamp_to_map()
	camera_changed.emit()


func get_minimum_allowed_zoom() -> float:
	if map_bounds.size.x <= 0.0 or map_bounds.size.y <= 0.0:
		return minimum_zoom
	var viewport_size := get_viewport_rect().size
	return maxf(minimum_zoom, maxf(viewport_size.x / map_bounds.size.x, viewport_size.y / map_bounds.size.y))


func _clamp_to_map() -> void:
	if map_bounds.size.x <= 0.0 or map_bounds.size.y <= 0.0:
		return
	var viewport_size := get_viewport_rect().size
	var half_visible := viewport_size * 0.5 / zoom
	position.x = _clamp_axis(position.x, map_bounds.position.x, map_bounds.end.x, half_visible.x)
	position.y = _clamp_axis(position.y, map_bounds.position.y, map_bounds.end.y, half_visible.y)


func _clamp_axis(value: float, minimum: float, maximum: float, half_visible: float) -> float:
	if maximum - minimum <= half_visible * 2.0:
		return (minimum + maximum) * 0.5
	return clampf(value, minimum + half_visible, maximum - half_visible)
