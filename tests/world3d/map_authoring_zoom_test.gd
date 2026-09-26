extends SceneTree

const CanvasScript = preload("res://addons/building_map_editor/map_authoring_canvas.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var canvas: MapAuthoringCanvas = CanvasScript.new()
	root.add_child(canvas)
	canvas.size = Vector2(600, 500)
	canvas.source_size = Vector2(1600, 1600)
	canvas.set_snap_pixels(10.0)
	var cursor := Vector2(350, 260)
	var point_before := canvas._screen_to_map_unclamped(cursor)
	canvas.zoom_at_screen_position(2.0, cursor)
	var passed := is_equal_approx(canvas.zoom_factor, 2.0)
	passed = passed and canvas._screen_to_map_unclamped(cursor).is_equal_approx(point_before)
	var map_point := Vector2(800, 720)
	passed = passed and canvas._screen_to_map(canvas._map_to_screen(map_point)) == map_point
	canvas.pan_offset += Vector2(50, -30)
	canvas._clamp_view()
	passed = passed and canvas._screen_to_map(canvas._map_to_screen(map_point)) == map_point
	canvas.reset_view()
	passed = passed and is_equal_approx(canvas.zoom_factor, 1.0) and canvas.pan_offset == Vector2.ZERO
	canvas.queue_free()
	await process_frame
	print("MAP_AUTHORING_ZOOM_TEST: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
