extends SceneTree

const PlayerData = preload("res://data/character/player.tres")
const GoblinSlingerData = preload("res://data/character/goblin_slinger.tres")

var failures: Array[String] = []


func _init() -> void:
	var player: CombatantState = PlayerData.create_combatant_state()
	var slinger: CombatantState = GoblinSlingerData.create_combatant_state()
	player.position = Vector2(300, 100)
	slinger.position = Vector2(100, 100)
	var system := CombatSystem.new()
	system.start_combat([player, slinger])
	system.combat_state.turn_order = [player.id, slinger.id]
	system.combat_state.current_actor_id = player.id
	player.ap = player.max_ap
	slinger.ap = slinger.max_ap

	var movement := MovementData.new()
	movement.ap_cost = 1
	movement.world_units_per_foot = system.map_rules.world_units_per_foot
	var request := ActionRequest.new(player.id, ActionTypes.Type.MOVE)
	request.target_position = Vector2(200, 100)
	request.movement_data = movement
	var slinger_origin := slinger.position
	var slinger_ap_before := slinger.ap
	var result := system.execute_action(request)

	check(result.success, "Movement should resume after the enemy Reaction resolves.")
	check(not system.has_pending_reaction() and not system.reaction_resolver.has_pending_move(), "Enemy movement Reaction should resolve automatically without waiting for player input.")
	check(slinger.position != slinger_origin, "Scramble Away should move the Goblin Slinger when an enemy enters its reach.")
	check(slinger.ap == slinger_ap_before - 1, "Scramble Away should spend 1 AP.")
	check(int(slinger.reaction_last_used_round.get("goblin_scramble_away", 0)) == system.combat_state.current_round, "Scramble Away should record its once-per-round use.")
	check(result.events.any(func(event): return event.type == EventTypes.Type.REACTION_TRIGGERED and event.source_id == slinger.id), "Scramble Away should emit a visible Reaction event.")

	if failures.is_empty():
		print("ENEMY_ENTERS_REACH_REACTION_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("ENEMY_ENTERS_REACH_REACTION_TEST: FAIL (%d)" % failures.size())
		quit(1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
