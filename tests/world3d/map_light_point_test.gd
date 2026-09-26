extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run_test() -> void:
	var canvas := MapAuthoringCanvas.new()
	root.add_child(canvas)
	canvas.set_layer(&"ground", null)
	canvas.set_tool(&"light_point")
	canvas.light_level = 0
	canvas.light_radius_feet = 10.0
	canvas.drag_start = Vector2(400, 400)
	canvas._commit_drag(Vector2(400, 400))
	check(canvas.light_points.size() == 1 and canvas.light_points[0].level == 0, "Editor places a point with its chosen level")
	canvas.undo_last()
	check(canvas.light_points.is_empty(), "Editor undo removes its last light point")
	canvas.drag_start = Vector2(400, 400)
	canvas._commit_drag(Vector2(400, 400))
	canvas.light_level = 2
	canvas.drag_start = Vector2(500, 300)
	canvas._commit_drag(Vector2(700, 500))
	check(canvas.light_points.size() == 2 and canvas.light_points[1].rect == Rect2(500, 300, 200, 200), "Dragging the light tool creates a rectangle")
	var map := BuildingMapData.new()
	map.source_size = Vector2(800, 800)
	map.pixels_per_foot = 10.0
	map.light_points.assign(canvas.light_points)
	map.light_points.append({"surface_id": &"level_1", "position": Vector2(400, 400), "radius_feet": 10.0, "level": 3})
	var path := "user://map_light_point_test.tres"
	check(ResourceSaver.save(map, path) == OK, "Map light points can be saved")
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as BuildingMapData
	check(loaded != null and loaded.light_points.size() == 3 and loaded.light_points[1].has("rect"), "Circular and rectangular lights reload on both floors")
	if loaded != null:
		var light_visual := preload("res://data/world/map_light_visual.gd")
		check(light_visual.level_at(Vector2(400, 400), loaded.light_points, &"ground", 10.0) == 0, "Visual light mask uses the authored bright point")
		check(light_visual.level_at(Vector2(600, 400), loaded.light_points, &"ground", 10.0) == 2, "Visual light mask uses the authored rectangular area")
		check(light_visual.level_at(Vector2(400, 400), loaded.light_points, &"level_1", 10.0) == 3, "Visual light mask keeps floors separate")
		var sample_image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		sample_image.fill(Color.WHITE)
		var material: ShaderMaterial = light_visual.create_material(ImageTexture.create_from_image(sample_image), map.source_size, loaded.light_points, &"ground", 10.0)
		var mask: Image = (material.get_shader_parameter("light_mask") as ImageTexture).get_image()
		check(mask.get_pixel(128, 128).r < mask.get_pixel(200, 128).r, "Rendered map mask makes the bright point lighter than its surroundings")
		var rules := MapRules.new()
		rules.configure_building_map(loaded)
		check(rules.get_light_level_at(Vector2.ZERO, &"ground") == 0, "Ground uses its bright point")
		check(rules.get_light_level_at(Vector2.ZERO, &"level_1") == 3, "Upper floor uses its dark point")
		check(rules.get_light_level_at(Vector2(150, 0), &"ground") == 2, "Inside rectangle uses its authored light level")
		check(rules.get_light_level_at(Vector2(150, 0), &"level_1") == 1, "Rectangle does not light another floor")
		check(rules.get_light_level_at(Vector2(350, 0), &"ground") == 1, "Outside light areas uses default light")
		rules.configure_building_map(null)
		check(rules.light_points.is_empty(), "Loading a different map clears old points")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var editor := BuildingBlockEditor3D.new()
	root.add_child(editor)
	editor.configure(canvas, map.source_size, map.pixels_per_foot, 10.0, {&"ground": null}, {&"ground": 0.0})
	editor.selected_layer = &"ground"
	editor.selected_kind = "light_point"
	editor.selected_index = 0
	editor.update_selected_light(2, 12.0)
	check(canvas.light_points[0].level == 2 and is_equal_approx(canvas.light_points[0].radius_feet, 12.0), "Selected light level and radius can be edited")
	editor.delete_selected()
	check(canvas.light_points.size() == 1 and canvas.light_points[0].has("rect"), "Selected light point can be deleted without removing the rectangle")
	editor.selected_layer = &"ground"
	editor.selected_kind = "light_point"
	editor.selected_index = 0
	editor.update_selected_light(3, 12.0)
	check(canvas.light_points[0].level == 3 and not canvas.light_points[0].has("radius_feet"), "Rectangle level can be edited without gaining a circle radius")
	editor.delete_selected()
	check(canvas.light_points.is_empty(), "Selected light rectangle can be deleted")
	editor.set_tool(&"light_point")
	editor.light_drag_start = Vector2(100, 100)
	var end_screen := editor.camera.unproject_position(editor._map_to_world(Vector2(200, 200), 0.0))
	editor._commit_light_drag(end_screen)
	check(canvas.light_points.size() == 1 and canvas.light_points[0].has("rect"), "3D map editor drag places a rectangular light area")
	editor.set_tool(&"select")
	var select_screen := editor.camera.unproject_position(editor._map_to_world(Vector2(150, 150), 0.0))
	editor._begin_selection(select_screen)
	check(editor.selected_kind == "light_point", "Rectangular light area can be selected")
	var move_screen := editor.camera.unproject_position(editor._map_to_world(Vector2(250, 250), 0.0))
	editor._drag_selection(move_screen)
	check(canvas.light_points[0].rect.position == Vector2(200, 200), "Selected light rectangle can be moved")
	editor.queue_free()
	canvas.queue_free()
	for failure in failures:
		push_error(failure)
	print("MAP_LIGHT_POINT_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
