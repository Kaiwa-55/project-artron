extends SceneTree

const WorldScene = preload("res://scenes/world3d/DungeonWorld3D.tscn")
const MapRulesScript = preload("res://combat/map/map_rules.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var map := BuildingMapData.new()
	map.source_size = Vector2(100, 100)
	map.pixels_per_foot = 10.0
	var surface := BuildingSurfaceData.new()
	surface.surface_id = &"ground"
	surface.display_name = "Ground"
	surface.walkable_rects = [Rect2(0, 0, 100, 100)]
	var object := BuildingObjectData.new()
	object.object_id = &"crate"
	object.display_name = "Crate"
	object.rect = Rect2(45, 40, 10, 20)
	object.height_feet = 3.0
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 0.0))
	image.set_pixel(0, 0, Color.WHITE)
	object.texture = ImageTexture.create_from_image(image)
	surface.texture = object.texture
	surface.objects = [object]
	map.surfaces = [surface]
	var world: DungeonWorld3D = WorldScene.instantiate()
	root.add_child(world)
	world.build(map)
	await physics_frame
	await physics_frame
	var object_node := world.get_node_or_null("ground/Object0_crate") as StaticBody3D
	var rules = MapRulesScript.new()
	rules.configure_building_map(map)
	var actor := CombatantState.new()
	actor.position = Vector2(-30, 0)
	var movement := rules.validate_movement_path(actor, Vector2(30, 0), {actor.id: actor})
	var passed := object_node != null and object_node.collision_layer == 2
	var collision: CollisionShape3D
	var visual: MeshInstance3D
	if object_node != null:
		for child in object_node.get_children():
			if child is CollisionShape3D:
				collision = child
			elif child is MeshInstance3D:
				visual = child
	var box_shape := collision.shape as BoxShape3D if collision != null else null
	var object_mesh := visual.mesh as ArrayMesh if visual != null else null
	passed = passed and box_shape != null and box_shape.size.is_equal_approx(Vector3(1.0, 3.0, 2.0))
	passed = passed and object_mesh != null and object_mesh.get_surface_count() == 1
	if object_mesh != null and object_mesh.get_surface_count() == 1:
		var top_material := object_mesh.surface_get_material(0) as StandardMaterial3D
		var map_material := (world.get_node("ground/MapImage") as MeshInstance3D).material_override as Material
		passed = passed and top_material != null and top_material.albedo_texture == object.texture
		passed = passed and top_material.albedo_color == Color.WHITE
		passed = passed and top_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA
		passed = passed and top_material.render_priority > map_material.render_priority
	passed = passed and not movement.success
	var los_blocked := not world.has_line_of_sight(Vector3(-3, 1.5, 0), Vector3(3, 1.5, 0))
	passed = passed and los_blocked
	object.image_layer = 0
	world.build(map)
	var behind_visual: MeshInstance3D
	for child in world.get_node("ground/Object0_crate").get_children():
		if child is MeshInstance3D:
			behind_visual = child
	var behind_mesh := behind_visual.mesh as ArrayMesh if behind_visual != null else null
	passed = passed and behind_mesh != null
	if behind_mesh != null:
		var behind_map_material := (world.get_node("ground/MapImage") as MeshInstance3D).material_override as Material
		passed = passed and (behind_mesh.surface_get_material(0) as StandardMaterial3D).render_priority < behind_map_material.render_priority
	world.queue_free()
	await process_frame
	print("MAP_OBJECT_TEST: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
