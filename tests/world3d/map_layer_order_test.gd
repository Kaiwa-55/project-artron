extends SceneTree

const CanvasScript = preload("res://addons/building_map_editor/map_authoring_canvas.gd")
const BlockEditorScript = preload("res://addons/building_map_editor/block_editor_3d.gd")
const WorldScene = preload("res://scenes/world3d/DungeonWorld3D.tscn")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var canvas: MapAuthoringCanvas = CanvasScript.new()
	canvas.shapes[&"ground"].object = [
		{"display_name": "Behind", "image_layer": 0},
		{"display_name": "First", "image_layer": 1},
		{"display_name": "Second", "image_layer": 1},
	]
	var passed := canvas.object_layer_order(&"ground") == [0, -1, 1, 2]
	var moved := canvas.move_object_layer(&"ground", 1, -1)
	passed = passed and moved == 1 and canvas.object_layer_order(&"ground") == [0, 1, -1, 2]
	passed = passed and canvas.shapes[&"ground"].object[1].display_name == "First"
	passed = passed and canvas.shapes[&"ground"].object[1].image_layer == 0
	moved = canvas.move_object_layer(&"ground", 0, 1)
	passed = passed and moved == 1 and canvas.shapes[&"ground"].object[1].display_name == "Behind"
	var editor: BuildingBlockEditor3D = BlockEditorScript.new()
	editor.authoring_canvas = canvas
	var map_priority := editor._visual_floor_priority(&"ground")
	passed = passed and editor._object_visual_priority(&"ground", 0) < editor._object_visual_priority(&"ground", 1)
	passed = passed and editor._object_visual_priority(&"ground", 1) < map_priority
	passed = passed and map_priority < editor._object_visual_priority(&"ground", 2)
	var map := BuildingMapData.new()
	map.source_size = Vector2(100, 100)
	map.pixels_per_foot = 10.0
	var surface := BuildingSurfaceData.new()
	surface.surface_id = &"ground"
	surface.walkable_rects = [Rect2(0, 0, 100, 100)]
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var object_texture := ImageTexture.create_from_image(image)
	surface.texture = object_texture
	for index in range(canvas.shapes[&"ground"].object.size()):
		var entry: Dictionary = canvas.shapes[&"ground"].object[index]
		var map_object := BuildingObjectData.new()
		map_object.object_id = StringName("layer_%d" % index)
		map_object.rect = Rect2(10 + index * 20, 10, 10, 10)
		map_object.texture = object_texture
		map_object.image_layer = int(entry.image_layer)
		surface.objects.append(map_object)
	map.surfaces = [surface]
	var world: DungeonWorld3D = WorldScene.instantiate()
	root.add_child(world)
	world.build(map)
	var runtime_map_priority := (world.get_node("ground/MapImage") as MeshInstance3D).material_override.render_priority
	var priorities: Array[int] = []
	for index in range(surface.objects.size()):
		var body := world.get_node("ground/Object%d_layer_%d" % [index, index])
		for child in body.get_children():
			if child is MeshInstance3D:
				priorities.append((child.mesh as ArrayMesh).surface_get_material(0).render_priority)
	passed = passed and priorities.size() == 3
	if priorities.size() == 3:
		passed = passed and priorities[0] < priorities[1] and priorities[1] < runtime_map_priority and runtime_map_priority < priorities[2]
	var upper := BuildingSurfaceData.new()
	upper.surface_id = &"level_1"
	upper.elevation_feet = 10.0
	upper.texture = object_texture
	upper.walkable_rects = [Rect2(0, 0, 100, 100)]
	var upper_object := BuildingObjectData.new()
	upper_object.object_id = &"upper"
	upper_object.rect = Rect2(10, 10, 10, 10)
	upper_object.texture = object_texture
	upper.objects = [upper_object]
	map.surfaces.append(upper)
	world.build(map)
	var ground_last: int = world._object_visual_priority(surface, 2)
	var upper_map: int = (world.get_node("level_1/MapImage") as MeshInstance3D).material_override.render_priority
	var upper_first: int = world._object_visual_priority(upper, 0)
	passed = passed and ground_last < upper_map and upper_map < upper_first
	world.queue_free()
	editor.free()
	canvas.free()
	await process_frame
	print("MAP_LAYER_ORDER_TEST: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
