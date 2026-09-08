extends SceneTree

const PlayerTemplate = preload("res://data/character/player.tres")
const EnemyTemplate = preload("res://data/character/enemy.tres")

var failures: Array[String] = []


func _init() -> void:
	var actor: CombatantState = PlayerTemplate.create_combatant_state()
	var enemy: CombatantState = EnemyTemplate.create_combatant_state()
	var system := CombatSystem.new()
	system.start_combat([actor, enemy])
	system.combat_state.current_actor_id = actor.id
	actor.position = Vector2.ZERO
	enemy.position = Vector2(5000.0, 5000.0)
	actor.ap = actor.max_ap
	var movement := MovementData.new()
	movement.ap_cost = 1
	movement.world_units_per_foot = system.map_rules.world_units_per_foot
	var speed := actor.get_effective_speed()
	var starting_ap := actor.ap

	var first_destination := Vector2(speed * movement.world_units_per_foot, 0.0)
	check(system.movement_system.execute_move(actor, first_destination, movement, system.combat_state).success, "First full-Speed Move succeeds")
	check(actor.ap == starting_ap - 1 and not actor.movement_in_progress, "First Move spends 1 AP and completes its allowance")
	check(system.movement_system.can_begin_or_continue_move(actor, 1), "Move remains available when AP remains")

	var second_destination := actor.position + Vector2(5.0 * movement.world_units_per_foot, 0.0)
	check(system.movement_system.execute_move(actor, second_destination, movement, system.combat_state).success, "Second Move action succeeds in the same Turn")
	check(actor.ap == starting_ap - 2 and actor.movement_in_progress, "Second Move spends 1 AP and retains unused Speed")
	var continuation_ap := actor.ap
	var final_destination := actor.position + Vector2((speed - 5.0) * movement.world_units_per_foot, 0.0)
	check(system.movement_system.execute_move(actor, final_destination, movement, system.combat_state).success, "Unfinished Move can be continued")
	check(actor.ap == continuation_ap, "Continuing the same Move does not spend AP again")

	for failure in failures:
		push_error(failure)
	print("REPEATED_MOVE_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
