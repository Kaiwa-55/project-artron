class_name TokenDragEditor
extends Control

signal customization_finished

const TOKEN_SIZE := 256.0
const HANDLE_SIZE := 14.0
const MIN_ZOOM := 0.75
const MAX_ZOOM := 2.5

var draft
var preview: TextureRect
var _moving := false
var _resizing := false


func setup(source_draft, target_preview: TextureRect) -> void:
	draft = source_draft
	preview = target_preview
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	tooltip_text = "Drag the image to reposition it. Drag the gold corner to resize it."
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if draft == null or draft.custom_portrait == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_resizing = _resize_handle_rect().has_point(event.position)
			_moving = not _resizing
			mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE if _resizing else Control.CURSOR_MOVE
		else:
			var changed := _moving or _resizing
			_moving = false
			_resizing = false
			mouse_default_cursor_shape = Control.CURSOR_MOVE
			if changed:
				customization_finished.emit()
		accept_event()
	elif event is InputEventMouseMotion and (_moving or _resizing):
		if _resizing:
			var zoom_delta: float = (event.relative.x - event.relative.y) * 0.0125
			draft.token_zoom = clampf(draft.token_zoom + zoom_delta, MIN_ZOOM, MAX_ZOOM)
		else:
			var preview_span := maxf(1.0, minf(size.x, size.y))
			draft.token_offset += event.relative * TOKEN_SIZE / preview_span
			draft.token_offset.x = clampf(draft.token_offset.x, -128.0, 128.0)
			draft.token_offset.y = clampf(draft.token_offset.y, -128.0, 128.0)
		_refresh_preview()
		accept_event()


func _refresh_preview() -> void:
	if preview != null:
		preview.texture = draft.get_token_texture()
	queue_redraw()


func _resize_handle_rect() -> Rect2:
	return Rect2(size - Vector2(HANDLE_SIZE, HANDLE_SIZE), Vector2(HANDLE_SIZE, HANDLE_SIZE))


func _draw() -> void:
	if draft == null or draft.custom_portrait == null:
		return
	var side := minf(size.x, size.y)
	var origin := Vector2((size.x - side) * 0.5, (size.y - side) * 0.5)
	draw_arc(origin + Vector2.ONE * side * 0.5, side * 0.5 - 1.0, 0.0, TAU, 48, Color("e1b64f"), 1.0)
	var handle := _resize_handle_rect()
	draw_rect(handle, Color("e1b64f"), true)
	draw_line(handle.position + Vector2(3, HANDLE_SIZE - 3), handle.end - Vector2(3, HANDLE_SIZE - 3), Color("101820"), 1.0)
