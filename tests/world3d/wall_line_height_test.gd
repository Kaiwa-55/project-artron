extends SceneTree

const WallData = preload("res://data/world/building_wall_data.gd")
const CanvasData = preload("res://addons/building_map_editor/map_authoring_canvas.gd")
const BuilderPlugin = preload("res://addons/building_map_editor/building_map_editor_plugin.gd")
const BlockEditor = preload("res://addons/building_map_editor/block_editor_3d.gd")
const WorldScene = preload("res://scenes/world3d/DungeonWorld3D.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var canvas = CanvasData.new()
	canvas.source_size = Vector2(240, 240)
	canvas.pixels_per_foot = 10.0
	canvas.wall_height_feet = 12.0
	canvas.wall_width_pixels = 20.0
	canvas.set_tool(&"wall")
	canvas.drag_start = Vector2(40, 40)
	canvas._commit_drag(Vector2(200, 200))
	check(canvas.shapes[&"ground"].wall.size() == 1, "Dragging a diagonal line should add one wall.")
	var authored: Dictionary = canvas.shapes[&"ground"].wall[0]
	check(authored.from == Vector2(40, 40) and authored.to == Vector2(200, 200), "Wall endpoints should follow the drag.")
	check(is_equal_approx(float(authored.height_feet), 12.0) and is_equal_approx(float(authored.width_feet), 2.0), "Wall height and thickness should use the editor controls.")
	var wall = WallData.new()
	wall.from_position = authored.from
	wall.to_position = authored.to
	wall.height_feet = authored.height_feet
	wall.width_feet = authored.width_feet
	var surface := BuildingSurfaceData.new()
	surface.surface_id = &"ground"
	surface.walkable_rects = [Rect2(0, 0, 240, 240)]
	surface.wall_rects = [Rect2(100, 0, 10, 30)]
	surface.wall_rect_heights_feet = [4.0]
	surface.wall_segments.append(wall)
	var map := BuildingMapData.new()
	map.source_size = Vector2(240, 240)
	map.pixels_per_foot = 10.0
	map.surfaces.append(surface)
	var save_path := "res://work/wall_line_height_test_map.tres"
	check(ResourceSaver.save(map, save_path) == OK, "Line wall map should save.")
	var loaded_map := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as BuildingMapData
	check(loaded_map != null, "Line wall map should reload.")
	if loaded_map != null:
		var loaded_surface := loaded_map.get_surface(&"ground")
		check(loaded_surface.wall_segments.size() == 1 and is_equal_approx(loaded_surface.wall_segments[0].height_feet, 12.0), "Line wall height should survive a save and load.")
		check(loaded_surface.wall_rect_heights_feet == [4.0], "Rectangle wall height should survive a save and load.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var rules := MapRules.new()
	rules.configure_building_map(map)
	check(rules.obstacles.size() == 2, "Both rectangle and line walls should enter combat rules.")
	check(is_equal_approx(float(rules.obstacles[0].height_feet), 4.0) and is_equal_approx(float(rules.obstacles[1].height_feet), 12.0), "Combat rules should preserve each wall's height.")
	var left := CombatantState.new()
	var right := CombatantState.new()
	left.position = Vector2(-30, -105)
	right.position = Vector2(-5, -105)
	check(rules.has_line_of_sight_between(left, right), "A 4 ft wall should not block a 5 ft sight ray.")
	surface.wall_rect_heights_feet[0] = 8.0
	rules.configure_building_map(map)
	check(not rules.has_line_of_sight_between(left, right), "Raising that wall to 8 ft should block sight.")
	surface.wall_rect_heights_feet[0] = 4.0
	rules.configure_building_map(map)
	left.position = Vector2(-80, 80)
	right.position = Vector2(80, -80)
	check(not rules.has_line_of_sight_between(left, right), "A tall diagonal wall should block sight.")
	var blocked_path := rules.validate_movement_path(left, right.position, {})
	check(not blocked_path.success and blocked_path.failure_reason.contains("wall"), "A diagonal wall should block movement.")
	var world: DungeonWorld3D = WorldScene.instantiate()
	root.add_child(world)
	world.build(map)
	await physics_frame
	await physics_frame
	check(not world.has_line_of_sight(Vector3(-8, 5, 8), Vector3(8, 5, -8)), "A tall diagonal wall should block 3D sight.")
	check(world.has_line_of_sight(Vector3(-3, 5, -10.5), Vector3(-0.5, 5, -10.5)), "A short rectangle wall should allow 3D sight above it.")
	var line_body := world.get_node_or_null("ground/WallSegment0") as StaticBody3D
	var short_body := world.get_node_or_null("ground/Wall0") as StaticBody3D
	check(line_body != null and short_body != null, "World should create both wall types.")
	if line_body != null and short_body != null:
		check(is_equal_approx(((line_body.get_child(0) as CollisionShape3D).shape as BoxShape3D).size.y, 12.0), "Line wall collision should match its height.")
		check(not is_zero_approx(line_body.rotation.y), "Diagonal line wall should be rotated.")
		check(is_equal_approx(((short_body.get_child(0) as CollisionShape3D).shape as BoxShape3D).size.y, 4.0), "Rectangle wall collision should match its height.")
	var door := BuildingDoorData.new()
	door.rect = Rect2(80, 80, 80, 80)
	door.starts_open = true
	surface.doors.append(door)
	check(surface.wall_solid_segments(map.pixels_per_foot).size() == 2, "An open door should split a drawn wall into two solid sections.")
	rules.configure_building_map(map)
	left.position = Vector2(-30, 30)
	right.position = Vector2(30, -30)
	check(rules.has_line_of_sight_between(left, right), "An open door in a drawn wall should allow sight through the gap.")
	check(rules.validate_movement_path(left, right.position, {}).success, "An open door in a drawn wall should allow movement through the gap.")
	root.add_child(canvas)
	var editor = BlockEditor.new()
	root.add_child(editor)
	editor.configure(canvas, map.source_size, map.pixels_per_foot, 10.0, {&"ground": null}, {&"ground": 0.0})
	editor.set_tool(&"wall")
	canvas.wall_height_feet = 6.0
	canvas.wall_width_pixels = 10.0
	editor.wall_drag_start = Vector2(30, 190)
	var end_screen: Vector2 = editor.camera.unproject_position(editor._map_to_world(Vector2(190, 190), 0.0))
	editor._commit_wall_drag(end_screen)
	check(canvas.shapes[&"ground"].wall.size() == 2, "Dragging in the 3D editor should add a wall line.")
	var second: Dictionary = canvas.shapes[&"ground"].wall[1]
	check(is_equal_approx(float(second.height_feet), 6.0) and is_equal_approx(float(second.width_feet), 1.0), "The 3D line should keep its authored height and thickness.")
	editor.set_tool(&"select")
	var center_screen: Vector2 = editor.camera.unproject_position(editor._map_to_world(Vector2(100, 190), 0.0))
	editor._begin_selection(center_screen)
	check(editor.selected_kind == "wall" and editor.selected_index == 1, "A drawn wall should be selectable.")
	editor.update_selected_wall(8.0, 30.0)
	second = canvas.shapes[&"ground"].wall[1]
	check(is_equal_approx(float(second.height_feet), 8.0) and is_equal_approx(float(second.width_feet), 3.0), "Selected wall properties should update.")
	editor.delete_selected()
	check(canvas.shapes[&"ground"].wall.size() == 1, "A selected wall should be removable.")
	for failure in failures:
		push_error(failure)
	editor.queue_free()
	canvas.queue_free()
	print("WALL_LINE_HEIGHT_TEST: PASS" if failures.is_empty() else "WALL_LINE_HEIGHT_TEST: FAIL")
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
