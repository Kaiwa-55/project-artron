extends SceneTree

const CameraControllerScript = preload("res://scenes/combat/battlefield_camera_controller.gd")

func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var camera: Camera2D = CameraControllerScript.new()
	viewport.add_child(camera)
	await process_frame
	camera.configure(Rect2(Vector2(-1500, -1500), Vector2(3000, 3000)), Vector2.ZERO)
	var old_resolution_zoom: float = camera.zoom.x
	viewport.size = Vector2i(640, 360)
	await process_frame
	await process_frame
	var minimum_zoom: float = camera.get_minimum_allowed_zoom()
	var zoom_is_safe: bool = camera.zoom.x >= minimum_zoom and is_equal_approx(camera.zoom.x, old_resolution_zoom * 0.5)
	camera.position = Vector2(9999, 9999)
	camera._clamp_to_map()
	var half_visible: Vector2 = viewport.get_visible_rect().size * 0.5 / camera.zoom
	var right_edge: float = camera.position.x + half_visible.x
	var bottom_edge: float = camera.position.y + half_visible.y
	var bounds_are_safe: bool = right_edge <= 1500.01 and bottom_edge <= 1500.01
	var converted: Vector2 = camera.screen_to_world(camera.world_to_screen(Vector2(120, -80)))
	var conversion_is_stable: bool = converted.distance_to(Vector2(120, -80)) < 0.01
	var camera_at_640: Camera2D = CameraControllerScript.new()
	viewport.add_child(camera_at_640)
	await process_frame
	camera_at_640.configure(Rect2(Vector2(-1500, -1500), Vector2(3000, 3000)), Vector2.ZERO)
	var new_resolution_starts_correctly: bool = is_equal_approx(camera_at_640.zoom.x, 0.5)
	if not zoom_is_safe:
		push_error("Camera should recalculate zoom after viewport resize: old %.3f, new %.3f, minimum %.3f, viewport %s" % [old_resolution_zoom, camera.zoom.x, minimum_zoom, camera.get_viewport().get_visible_rect().size])
	if not bounds_are_safe:
		push_error("Camera must clamp to resized viewport bounds")
	if not conversion_is_stable:
		push_error("Camera screen/world conversion must remain stable after resize")
	if not new_resolution_starts_correctly:
		push_error("Camera should initialize at 0.5 zoom for the 640x360 viewport")
	var passed: bool = zoom_is_safe and bounds_are_safe and conversion_is_stable and new_resolution_starts_correctly
	print("BATTLEFIELD_CAMERA_TEST: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
