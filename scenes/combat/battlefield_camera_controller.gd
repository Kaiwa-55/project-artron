class_name BattlefieldCameraController
extends Camera2D

signal camera_changed

@export_range(0.1, 4.0, 0.05) var minimum_zoom: float = 0.35
@export_range(0.1, 4.0, 0.05) var maximum_zoom: float = 2.0
@export_range(0.01, 1.0, 0.01) var zoom_step: float = 0.12
@export var keyboard_pan_speed: float = 900.0
@export var reference_viewport_size: Vector2 = Vector2(1280.0, 720.0)

var map_bounds: Rect2 = Rect2()
var dragging: bool = false
var requested_zoom: float = 1.0
var resize_update_queued: bool = false
var last_viewport_size: Vector2 = Vector2.ZERO
var pan_tween: Tween


func _ready() -> void:
	last_viewport_size = _get_current_viewport_size()
	if not get_viewport().size_changed.is_connected(_queue_viewport_update):
		get_viewport().size_changed.connect(_queue_viewport_update)


func configure(bounds: Rect2, focus_position: Vector2 = Vector2.ZERO) -> void:
	map_bounds = bounds
	position = focus_position
	limit_left = floori(bounds.position.x)
	limit_top = floori(bounds.position.y)
	limit_right = ceili(bounds.end.x)
	limit_bottom = ceili(bounds.end.y)
	requested_zoom = zoom.x * _get_resolution_scale()
	_apply_requested_zoom()
	_clamp_to_map()


func screen_to_world(screen_position: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_position


func world_to_screen(world_position: Vector2) -> Vector2:
	return get_canvas_transform() * world_position


func pan_to(target_position: Vector2, duration: float = 0.35) -> void:
	_cancel_pan()
	var viewport_size := _get_current_viewport_size()
	var half_visible := viewport_size * 0.5 / zoom
	var clamped_target := Vector2(
		_clamp_axis(target_position.x, map_bounds.position.x, map_bounds.end.x, half_visible.x),
		_clamp_axis(target_position.y, map_bounds.position.y, map_bounds.end.y, half_visible.y)
	) if map_bounds.size.x > 0.0 and map_bounds.size.y > 0.0 else target_position
	if duration <= 0.0:
		position = clamped_target
		camera_changed.emit()
		return
	pan_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	pan_tween.tween_property(self, "position", clamped_target, duration)
	pan_tween.finished.connect(func():
		pan_tween = null
		camera_changed.emit()
	)


func _cancel_pan() -> void:
	if pan_tween != null and pan_tween.is_valid():
		pan_tween.kill()
	pan_tween = null


func _process(delta: float) -> void:
	var required_zoom := get_minimum_allowed_zoom()
	if zoom.x < required_zoom:
		zoom = Vector2.ONE * required_zoom
		_clamp_to_map()
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	).normalized()
	if not direction.is_zero_approx():
		_cancel_pan()
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
			_set_zoom(zoom.x + zoom_step * _get_resolution_scale())
			get_viewport().set_input_as_handled()
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(zoom.x - zoom_step * _get_resolution_scale())
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and dragging:
		_cancel_pan()
		position -= event.relative / zoom.x
		_clamp_to_map()
		camera_changed.emit()
		get_viewport().set_input_as_handled()


func _set_zoom(value: float) -> void:
	requested_zoom = clampf(value, get_minimum_allowed_zoom(), _get_maximum_allowed_zoom())
	_apply_requested_zoom()
	_clamp_to_map()
	camera_changed.emit()


func _apply_requested_zoom() -> void:
	var clamped := clampf(requested_zoom, get_minimum_allowed_zoom(), _get_maximum_allowed_zoom())
	zoom = Vector2.ONE * clamped


func _queue_viewport_update() -> void:
	if resize_update_queued:
		return
	resize_update_queued = true
	call_deferred("_update_for_viewport_size")


func _update_for_viewport_size() -> void:
	resize_update_queued = false
	var viewport_size := _get_current_viewport_size()
	if last_viewport_size.x > 0.0 and last_viewport_size.y > 0.0:
		var resize_scale := minf(viewport_size.x / last_viewport_size.x, viewport_size.y / last_viewport_size.y)
		requested_zoom *= resize_scale
	last_viewport_size = viewport_size
	_apply_requested_zoom()
	_clamp_to_map()
	camera_changed.emit()


func get_minimum_allowed_zoom() -> float:
	if map_bounds.size.x <= 0.0 or map_bounds.size.y <= 0.0:
		return minimum_zoom
	var viewport_size := _get_current_viewport_size()
	return maxf(minimum_zoom * _get_resolution_scale(), maxf(viewport_size.x / map_bounds.size.x, viewport_size.y / map_bounds.size.y))


func _get_maximum_allowed_zoom() -> float:
	return maxf(get_minimum_allowed_zoom(), maximum_zoom * _get_resolution_scale())


func _clamp_to_map() -> void:
	if map_bounds.size.x <= 0.0 or map_bounds.size.y <= 0.0:
		return
	var viewport_size := _get_current_viewport_size()
	var half_visible := viewport_size * 0.5 / zoom
	position.x = _clamp_axis(position.x, map_bounds.position.x, map_bounds.end.x, half_visible.x)
	position.y = _clamp_axis(position.y, map_bounds.position.y, map_bounds.end.y, half_visible.y)


func _clamp_axis(value: float, minimum: float, maximum: float, half_visible: float) -> float:
	if maximum - minimum <= half_visible * 2.0:
		return (minimum + maximum) * 0.5
	return clampf(value, minimum + half_visible, maximum - half_visible)


func _get_current_viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _get_resolution_scale() -> float:
	var viewport_size := _get_current_viewport_size()
	if reference_viewport_size.x <= 0.0 or reference_viewport_size.y <= 0.0:
		return 1.0
	return minf(viewport_size.x / reference_viewport_size.x, viewport_size.y / reference_viewport_size.y)
