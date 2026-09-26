extends SceneTree

const Query = preload("res://combat/vision/visibility_query_3d.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var observer := CombatantState.new()
	var target := CombatantState.new()
	var passed: bool = is_equal_approx(observer.body_height_feet, observer.collision_radius_feet * 2.0)
	passed = passed and is_equal_approx(observer.eye_offset.y, observer.body_height_feet * (5.0 / 6.0))
	observer.collision_radius_feet = 5.0
	passed = passed and is_equal_approx(observer.body_height_feet, 10.0)
	passed = passed and is_equal_approx(observer.eye_offset.y, 10.0 * (5.0 / 6.0))
	observer.collision_radius_feet = 2.5
	target.world_position = Vector3(10, 0, 0)
	var query = Query.new()
	await physics_frame
	passed = passed and query.query(world, observer, target).clear_samples == 3
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.position = Vector3(5, 3, 0)
	body.set_meta("occluder_type", "WALL")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 10, 10)
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	await physics_frame
	await physics_frame
	passed = passed and query.query(world, observer, target).state == "HIDDEN"
	# Changing floor IDs must never allow sight through the same wall.
	target.surface_id = &"another_floor"
	passed = passed and query.query(world, observer, target).state == "HIDDEN"
	body.collision_layer = 8
	await physics_frame
	await physics_frame
	passed = passed and query.query(world, observer, target).clear_samples == 3
	# An overhead floor permits horizontal sight below, but blocks sight up.
	body.collision_layer = 1
	body.set_meta("occluder_type", "FLOOR")
	body.position = Vector3(5, 8, 0)
	box.size = Vector3(40, 0.4, 40)
	await physics_frame
	await physics_frame
	passed = passed and query.query(world, observer, target).clear_samples == 3
	target.world_position.y = 10
	passed = passed and query.query(world, observer, target).state == "HIDDEN"
	observer.world_position.y = 10
	target.world_position.y = 0
	passed = passed and query.query(world, observer, target).state == "HIDDEN"
	observer.world_position.y = 0
	target.world_position.y = 10
	# A genuine opening is absent geometry; surface identity is irrelevant.
	body.position.x = 100
	await physics_frame
	await physics_frame
	passed = passed and query.query(world, observer, target).clear_samples == 3
	world.free()
	print("VISIBILITY_QUERY_TEST: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
