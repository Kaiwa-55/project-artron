extends SceneTree

const Scene = preload("res://scenes/exploration/DungeonExploration.tscn")
const Layout = preload("res://scenes/exploration/dungeon_layout.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func run_test() -> void:
	var dungeon = Scene.instantiate()
	root.add_child(dungeon)
	await physics_frame
	await physics_frame
	dungeon.player.set_physics_process(false)
	check(dungeon.floor_id == 0 and not dungeon.upper.visible, "Start on ground; upper floor hidden")
	check(dungeon.roof_should_show(), "Roof visible outside")
	dungeon.use_stairs()
	check(dungeon.floor_id == 0, "Cannot switch floors away from stairs")
	dungeon.player.position = Vector2(760,1458)
	check(not dungeon.player.test_move(dungeon.player.global_transform, Vector2(0,-70)), "Ground entrance must be passable")
	dungeon.player.position = Vector2(700,1400)
	check(dungeon.player.test_move(dungeon.player.global_transform,Vector2(0,70)), "Exterior wall must block movement")
	dungeon.player.position = Vector2(480,440)
	check(not dungeon.player.test_move(dungeon.player.global_transform,Vector2(0,-80)), "Ground door must stay open despite wall upstairs")
	dungeon.player.position = Vector2(760,1300)
	check(not dungeon.roof_should_show(), "Roof hidden indoors")
	dungeon.player.position = Layout.STAIR_LANDING
	dungeon.use_stairs()
	await physics_frame
	check(dungeon.floor_id == 1 and dungeon.upper.visible and dungeon.player.collision_mask == 4, "Stairs switch image and collision floor")
	dungeon.player.position = Vector2(480,440)
	check(dungeon.player.test_move(dungeon.player.global_transform,Vector2(0,-80)), "Upper wall blocks ground-floor doorway")
	dungeon.player.position = Vector2(440,440)
	check(not dungeon.player.test_move(dungeon.player.global_transform,Vector2(0,-80)), "Upper doorway stays open despite ground wall")
	dungeon.player.position = Vector2(760,1400)
	check(dungeon.player.test_move(dungeon.player.global_transform,Vector2(0,80)), "Upper floor cannot exit into empty space")
	check(not dungeon.set_floor(1,Vector2(160,160)), "Reject destination inside wall")
	check(not dungeon.set_floor(1,Vector2(760,1500)), "Reject destination outside upper floor")
	check(not dungeon.set_floor(7,Layout.STAIR_LANDING), "Reject unknown floor")
	dungeon.player.position = Layout.STAIR_LANDING
	dungeon.inspect_roof = true
	dungeon.use_stairs()
	check(dungeon.floor_id == 1, "Roof inspection disables stair input")
	dungeon.inspect_roof = false
	dungeon.use_stairs()
	check(dungeon.floor_id == 0, "Stairs return downstairs")
	check(Layout.can_stand(Layout.STAIR_LANDING,0) and Layout.can_stand(Layout.STAIR_LANDING,1), "Both landings are valid")
	dungeon.queue_free()
	await process_frame
	print("DUNGEON_LAYERS_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
