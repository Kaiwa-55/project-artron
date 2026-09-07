extends SceneTree

const CameraControllerScript = preload("res://scenes/combat/battlefield_camera_controller.gd")

func _init() -> void:
	var camera: Camera2D = CameraControllerScript.new()
	root.add_child(camera)
	await process_frame
	camera.configure(Rect2(Vector2(-1500, -1500), Vector2(3000, 3000)), Vector2.ZERO)
	var minimum_zoom: float = camera.get_minimum_allowed_zoom()
	camera._set_zoom(0.1)
	var zoom_is_safe: bool = camera.zoom.x >= minimum_zoom
	camera.position = Vector2(9999, 9999)
	camera._clamp_to_map()
	var half_visible: Vector2 = camera.get_viewport_rect().size * 0.5 / camera.zoom
	var right_edge: float = camera.position.x + half_visible.x
	var bottom_edge: float = camera.position.y + half_visible.y
	var bounds_are_safe: bool = right_edge <= 1500.01 and bottom_edge <= 1500.01
	var converted: Vector2 = camera.screen_to_world(camera.world_to_screen(Vector2(120, -80)))
	var conversion_is_stable: bool = converted.distance_to(Vector2(120, -80)) < 0.01
	var passed: bool = zoom_is_safe and bounds_are_safe and conversion_is_stable
	print("BATTLEFIELD_CAMERA_TEST: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
