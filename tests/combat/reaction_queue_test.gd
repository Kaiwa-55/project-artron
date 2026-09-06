extends SceneTree

const PlayerData = preload("res://data/character/player.tres")
const EnemyData = preload("res://data/character/enemy.tres")
const ParryData = preload("res://data/reaction/parry.tres")

var failures: Array[String] = []

func _init() -> void:
	var player: CombatantState = PlayerData.create_combatant_state()
	var enemy_a: CombatantState = EnemyData.create_combatant_state()
	var enemy_b: CombatantState = EnemyData.create_combatant_state()
	enemy_b.id = "enemy_b"
	enemy_b.display_name = "Enemy B"
	player.position = Vector2(200, 100)
	enemy_a.position = Vector2(105, 75)
	enemy_b.position = Vector2(105, 125)
	player.active_reactions.clear()
	var system := CombatSystem.new()
	system.start_combat([player, enemy_a, enemy_b])
	# Force a known Initiative order for deterministic queue verification.
	system.combat_state.turn_order = [enemy_b.id, enemy_a.id, player.id]
	system.combat_state.current_actor_id = player.id
	player.ap = player.max_ap
	enemy_a.ap = enemy_a.max_ap
	enemy_b.ap = enemy_b.max_ap
	var movement := MovementData.new()
	movement.ap_cost = 1
	movement.world_units_per_foot = system.map_rules.world_units_per_foot
	var move := ActionRequest.new(player.id, ActionTypes.Type.MOVE)
	move.target_position = Vector2(500, 100)
	move.movement_data = movement
	var ap_a := enemy_a.ap
	var ap_b := enemy_b.ap
	var move_result := system.execute_action(move)
	check(move_result.success and not move_result.requires_reaction_choice, "Enemy AI should resolve its queued Reactions and resume Move")
	check(enemy_a.ap < ap_a and enemy_b.ap < ap_b, "Every eligible Enemy Opportunity Attack should resolve from the Queue")
	var trigger_order: Array[String] = []
	for event in system.event_system.get_history():
		if event.type == EventTypes.Type.REACTION_TRIGGERED and event.data.get("reaction_name") == "Opportunity Attack":
			trigger_order.append(event.source_id)
	check(trigger_order.size() >= 2 and trigger_order[0] == enemy_b.id and trigger_order[1] == enemy_a.id, "Queued Reactions should resolve in Initiative order")

	# Enemy defensive Reactions are selected by AI and do not open player UI.
	var attacker: CombatantState = PlayerData.create_combatant_state()
	var defender: CombatantState = EnemyData.create_combatant_state()
	defender.active_reactions.append(ParryData)
	attacker.position = Vector2(100, 100)
	defender.position = Vector2(160, 100)
	system = CombatSystem.new()
	system.start_combat([attacker, defender])
	system.combat_state.current_actor_id = attacker.id
	attacker.ap = attacker.max_ap
	defender.ap = defender.max_ap
	var guaranteed := AttackData.new()
	guaranteed.id = "queue_defense_test"
	guaranteed.display_name = "Queue Defense Test"
	guaranteed.requires_to_hit = false
	guaranteed.ap_cost = 0
	guaranteed.base_damage = 0
	guaranteed.range_feet = 20.0
	var attack := ActionRequest.new(attacker.id, ActionTypes.Type.ATTACK)
	attack.target_id = defender.id
	attack.attack_data = guaranteed
	var defender_ap := defender.ap
	var attack_result := system.execute_action(attack)
	check(attack_result.success and not attack_result.requires_reaction_choice, "Enemy AI should choose its own Defensive Reaction")
	check(defender.ap == defender_ap - ParryData.ap_cost, "Enemy AI Defensive Reaction should spend its AP")

	if failures.is_empty():
		print("REACTION_QUEUE_TEST: PASS")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		print("REACTION_QUEUE_TEST: FAIL (%d)" % failures.size())
		quit(1)

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
