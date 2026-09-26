extends SceneTree

const PlayerData = preload("res://data/character/player.tres")
const EnemyData = preload("res://data/character/enemy.tres")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var actor: CombatantState = PlayerData.create_combatant_state()
	var enemy: CombatantState = EnemyData.create_combatant_state()
	actor.position = Vector2.ZERO
	enemy.position = Vector2(120, 0)
	var system := CombatSystem.new()
	system.start_combat([actor, enemy])
	system.combat_state.current_actor_id = actor.id
	system.map_rules.spatial_world = world
	var wall := StaticBody3D.new()
	wall.collision_layer = 2
	wall.position = Vector3(5, 3, 0)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 10, 10)
	collision.shape = box
	wall.add_child(collision)
	world.add_child(wall)
	await physics_frame
	await physics_frame
	check(system.map_rules.has_line_of_sight(enemy.position, actor.position), "The flat 2D path has no obstacle")
	check(not system.map_rules.has_line_of_sight_between(enemy, actor), "The 3D wall blocks sight")
	actor.ap = actor.max_ap
	var blocked_result: ActionResult = system.use_hide(actor.id)
	var blocked_check: Dictionary = blocked_result.events[0].data.checks[0]
	check(blocked_result.success and not blocked_check.has_line_of_sight and blocked_check.dc == 10 + enemy.get_skill_rank("perception"), "Hide uses the 3D blocked sight result")
	wall.queue_free()
	await physics_frame
	await physics_frame
	actor.ap = actor.max_ap
	var clear_result: ActionResult = system.use_hide(actor.id)
	var clear_check: Dictionary = clear_result.events[0].data.checks[0]
	check(clear_result.success and clear_check.has_line_of_sight and clear_check.dc == 14 + enemy.get_skill_rank("perception"), "Hide adds the sight DC when the 3D route is clear")
	world.queue_free()
	for failure in failures:
		push_error(failure)
	print("HIDE_LINE_OF_SIGHT_3D_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
