extends SceneTree

const PlayerTemplate = preload("res://data/character/player.tres")
const EnemyTemplate = preload("res://data/character/enemy.tres")
const AssassinData = preload("res://data/class/assassin.tres")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _init() -> void:
	var character = PlayerTemplate.duplicate(true)
	character.character_class = AssassinData
	character.level = 3
	character.set_meta("selected_class_attribute_choices", [AttributeTypes.Type.INTELLIGENCE])
	character.available_abilities.append(load("res://data/ability/pursuit.tres"))
	character.selected_ability_ids.append("pursuit")
	character.equipped_abilities.append("pursuit")
	var player: CombatantState = character.create_combatant_state()
	var enemy: CombatantState = EnemyTemplate.create_combatant_state()
	var system := CombatSystem.new()
	system.start_combat([player, enemy])
	var pursuit = null
	for reaction in player.active_reactions:
		if reaction != null and reaction.id == "pursuit":
			pursuit = reaction
	player.active_reactions = [pursuit]
	check(pursuit != null and pursuit.ap_cost == 1, "Assassin gains Pursuit at 1 AP")
	check(system.ability_system.ability_has_trait(pursuit, "reactive"), "Pursuit is Reactive")
	var combined: float = system.map_rules.get_combatant_radius_world_units(player) + system.map_rules.get_combatant_radius_world_units(enemy)
	player.position = Vector2.ZERO
	enemy.position = Vector2(combined + 4.0 * 12.0, 0)
	var enemy_destination := Vector2(combined + 12.0 * 12.0, 0)
	system.combat_state.current_actor_id = enemy.id
	player.ap = 2
	enemy.ap = 2
	var movement := MovementData.new()
	movement.ap_cost = 1
	movement.world_units_per_foot = 12.0
	var request := ActionRequest.new(enemy.id, ActionTypes.Type.MOVE)
	request.movement_data = movement
	request.target_position = enemy_destination
	var opened := system.execute_action(request)
	check(opened.requires_reaction_choice and opened.reaction_prompt.reaction.id == "pursuit", "Leaving Reach offers Pursuit")
	check(enemy.position != enemy_destination and player.ap == 2, "Original Move waits for choice")
	var accepted := system.resolve_pending_reaction(0)
	check(accepted.success and system.has_pending_step_back_move() and player.ap == 1, "Accepting spends 1 AP and requests destination")
	var pursuit_origin := player.position
	var completed := system.execute_step_back_move(player.position + Vector2(0, 9999))
	check(completed.success and is_equal_approx(player.position.distance_to(pursuit_origin) / 12.0, 5.0), "Pursuit clamps to 5 ft")
	check(enemy.position == enemy_destination, "Original Move resumes after Pursuit")
	check(not system.has_pending_reaction() and not system.has_pending_step_back_move(), "Reaction queue completes")
	# Starting outside Reach does not trigger Pursuit.
	system.turn_system.start_turn(system.combat_state)
	system.combat_state.current_actor_id = enemy.id
	player.position = Vector2.ZERO
	enemy.position = Vector2(combined + 6.0 * 12.0, 0)
	request.target_position = Vector2(combined + 15.0 * 12.0, 0)
	enemy.ap = 2
	check(not system.execute_action(request).requires_reaction_choice, "Leaving while already outside Reach does not trigger")
	for failure in failures:
		push_error(failure)
	print("PURSUIT_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
