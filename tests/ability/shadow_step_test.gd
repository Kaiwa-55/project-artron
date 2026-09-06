extends SceneTree

const PlayerData = preload("res://data/character/player.tres")
const EnemyData = preload("res://data/character/enemy.tres")
const AssassinData = preload("res://data/class/assassin.tres")

var failures: Array[String] = []


func _init() -> void:
	var player: CombatantState = PlayerData.create_combatant_state()
	var enemy: CombatantState = EnemyData.create_combatant_state()
	player.level = 3
	player.set_meta("class_data", AssassinData)
	var learned_shadow_step = load("res://data/ability/shadow_step.tres")
	player.available_abilities.append(learned_shadow_step)
	player.equipped_abilities.append("shadow_step")
	player.position = Vector2(100, 100)
	enemy.position = Vector2(700, 500)
	var system := CombatSystem.new()
	system.start_combat([player, enemy])
	system.combat_state.current_actor_id = player.id
	system.turn_system.start_turn(system.combat_state)
	system.turn_system.activate_turn(system.combat_state, player.max_ap)

	var ability = system.ability_system.get_available_ability(player, "shadow_step")
	check(ability != null and player.equipped_abilities.has("shadow_step"), "Learned Shadow Step should be equipped")
	check(ability.ap_cost == 1 and ability.uses_per_turn == 1, "Shadow Step should cost 1 AP and have one use per turn")
	var effect = system.ability_system.get_movement_effect(ability)
	check(effect != null and is_equal_approx(effect.movement_distance_feet, 15.0), "Shadow Step range should be 15 feet")
	check(effect != null and not effect.movement_triggers_reactions, "Shadow Step should not trigger Reactions")

	var starting_ap := player.ap
	check(system.begin_ability_movement(player.id, ability.id).success, "Shadow Step should enter destination mode")
	var origin := player.position
	var move_result := system.execute_pending_ability_movement(origin + Vector2.RIGHT * 9999.0)
	var moved_feet: float = origin.distance_to(player.position) / system.map_rules.world_units_per_foot
	check(move_result.success and is_equal_approx(moved_feet, 15.0), "Over-range Shadow Step should clamp to 15 feet")
	check(player.ap == starting_ap - 1, "Successful Shadow Step should spend 1 AP")
	check(not system.has_pending_reaction(), "Shadow Step movement should not create a Reaction prompt")
	check(not system.begin_ability_movement(player.id, ability.id).success, "Shadow Step should not be usable twice in one turn")

	# A new turn clears the per-turn use. Invalid paths neither spend AP nor consume the use.
	system.turn_system.start_turn(system.combat_state)
	system.turn_system.activate_turn(system.combat_state, player.max_ap)
	var blocked_origin := player.position
	system.map_rules.add_circular_obstacle(blocked_origin + Vector2.RIGHT * 60.0, 20.0, "Test Wall")
	check(system.begin_ability_movement(player.id, ability.id).success, "Shadow Step should refresh next turn")
	var blocked_ap := player.ap
	var blocked_result := system.execute_pending_ability_movement(blocked_origin + Vector2.RIGHT * 120.0)
	check(not blocked_result.success and player.position == blocked_origin, "Shadow Step cannot pass through obstacles")
	check(player.ap == blocked_ap and int(player.ability_uses_this_turn.get(ability.id, 0)) == 0, "Invalid Shadow Step should not spend AP or its use")
	system.map_rules.clear_obstacles()
	enemy.position = blocked_origin + Vector2.RIGHT * 90.0
	var creature_blocked_result := system.execute_pending_ability_movement(blocked_origin + Vector2.RIGHT * 150.0)
	check(not creature_blocked_result.success and player.position == blocked_origin, "Shadow Step cannot pass through creatures")
	check(player.ap == blocked_ap and system.has_pending_ability_movement(), "A blocked creature path should keep destination mode without spending AP")

	if failures.is_empty():
		print("SHADOW_STEP_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("SHADOW_STEP_TEST: FAIL (%d)" % failures.size())
		quit(1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
