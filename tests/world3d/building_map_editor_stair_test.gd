extends SceneTree

const CanvasScript = preload("res://addons/building_map_editor/map_authoring_canvas.gd")
const BlockEditorScript = preload("res://addons/building_map_editor/block_editor_3d.gd")
const TransitionScript = preload("res://data/world/building_transition_data.gd")

func _init() -> void:
	var canvas = CanvasScript.new()
	canvas.tool_id = &"stairs"
	canvas.snap_pixels = 10.0
	canvas.pixels_per_foot = 10.0
	canvas.stair_start_feet = 3.0
	canvas.stair_end_feet = 14.0
	canvas.ensure_layer(&"level_2")
	canvas.ensure_layer(&"level_3")
	canvas.drag_start = Vector2(100, 100)
	canvas._commit_drag(Vector2(300, 200))
	var passed: bool = canvas.stairs.is_empty() and canvas.pending_stair_bounds == Rect2(100, 100, 200, 100)
	canvas._commit_stair_point(Vector2(50, 50))
	passed = passed and canvas.pending_stair_start == Vector2.INF
	canvas._commit_stair_point(Vector2(120, 150))
	canvas._commit_stair_point(Vector2(280, 150))
	passed = passed and canvas.stairs.size() == 1
	if not canvas.stairs.is_empty():
		var stair: Dictionary = canvas.stairs[0]
		passed = passed and stair.from == Vector2(120, 150) and stair.to == Vector2(280, 150)
		passed = passed and Rect2(stair.bounds) == Rect2(100, 100, 200, 100)
		passed = passed and is_equal_approx(float(stair.width_feet), 10.0)
		passed = passed and is_equal_approx(float(stair.from_elevation_feet), 3.0)
		passed = passed and is_equal_approx(float(stair.to_elevation_feet), 14.0)
	var transition = TransitionScript.new()
	transition.use_custom_elevations = true
	transition.from_elevation_feet = 3.0
	transition.to_elevation_feet = 14.0
	passed = passed and is_equal_approx(transition.get_from_elevation(0.0), 3.0)
	passed = passed and is_equal_approx(transition.get_to_elevation(10.0), 14.0)
	passed = passed and canvas.shapes.has(&"level_2") and canvas.shapes.has(&"level_3")
	var table: BuildingObjectPresetData = load("res://data/world/object_presets/table.tres")
	canvas.set_tool(&"object")
	canvas.object_preset = {"preset_id": table.preset_id, "display_name": table.display_name, "height_feet": table.height_feet, "blocks_movement": table.blocks_movement, "blocks_line_of_sight": table.blocks_line_of_sight, "color": table.color}
	canvas.drag_start = Vector2(20, 20)
	canvas._commit_drag(Vector2(100, 60))
	var authored_object: Dictionary = canvas.shapes[canvas.layer_id].object[0]
	passed = passed and authored_object.preset_id == &"table" and not authored_object.blocks_line_of_sight
	passed = passed and Rect2(authored_object.rect) == Rect2(20, 20, 80, 40)
	var editor = BlockEditorScript.new()
	editor.configure_stair_surfaces(&"level_2", &"level_3")
	passed = passed and editor.stair_from_surface == &"level_2" and editor.stair_to_surface == &"level_3"
	editor.authoring_canvas = canvas
	editor.selected_layer = canvas.layer_id
	editor.selected_kind = "object"
	editor.selected_index = 0
	var object_texture := GradientTexture2D.new()
	var front_priority: int = editor._object_visual_priority(canvas.layer_id, 0)
	var preview_mesh: ArrayMesh = editor._create_object_preview_mesh(Vector3(2.0, 4.0, 1.0), Color("8a6544"), object_texture, front_priority)
	passed = passed and preview_mesh.get_surface_count() == 1
	passed = passed and (preview_mesh.surface_get_material(0) as StandardMaterial3D).render_priority > editor._visual_floor_priority(canvas.layer_id)
	editor.update_selected_object({"display_name": "Dining Table", "collision_enabled": false, "height_feet": 4.0, "texture": object_texture, "image_layer": 0})
	var behind_priority: int = editor._object_visual_priority(canvas.layer_id, 0)
	var behind_mesh: ArrayMesh = editor._create_object_preview_mesh(Vector3(2.0, 4.0, 1.0), Color("8a6544"), object_texture, behind_priority)
	passed = passed and (behind_mesh.surface_get_material(0) as StandardMaterial3D).render_priority < editor._visual_floor_priority(canvas.layer_id)
	authored_object = canvas.shapes[canvas.layer_id].object[0]
	passed = passed and authored_object.display_name == "Dining Table" and not authored_object.collision_enabled
	passed = passed and is_equal_approx(float(authored_object.height_feet), 4.0)
	passed = passed and authored_object.texture == object_texture
	passed = passed and authored_object.image_layer == 0
	editor.free()
	canvas.free()
	print("BUILDING_MAP_EDITOR_STAIR_TEST: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
