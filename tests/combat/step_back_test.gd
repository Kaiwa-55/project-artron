extends SceneTree

const PlayerData = preload("res://data/character/player.tres")
const EnemyData = preload("res://data/character/enemy.tres")

var failures: Array[String] = []


func _init() -> void:
	var player: CombatantState = PlayerData.create_combatant_state()
	var enemy: CombatantState = EnemyData.create_combatant_state()
	player.equipped_abilities.append("step_back")
	player.active_reactions.clear()
	var system := CombatSystem.new()
	system.start_combat([player, enemy])
	system.combat_state.current_actor_id = enemy.id
	enemy.ap = enemy.max_ap
	player.ap = player.max_ap

	var step_back = system.ability_system.get_available_ability(player, "step_back")
	check(step_back != null, "Step Back should be available independently of Class")
	check(has_ability_trait(step_back, "basic") and has_ability_trait(step_back, "move"), "Step Back should have Basic and Move traits")
	var safe_attack := AttackData.new()
	safe_attack.id = "step_back_test_attack"
	safe_attack.display_name = "Step Back Test Attack"
	safe_attack.requires_to_hit = false
	safe_attack.ap_cost = 0
	safe_attack.base_damage = 0
	safe_attack.range_feet = 100.0

	var request := ActionRequest.new(enemy.id, ActionTypes.Type.ATTACK)
	request.target_id = player.id
	request.attack_data = safe_attack
	var attack_result := system.execute_action(request)
	check(attack_result.success and attack_result.requires_reaction_choice, "Step Back should be offered after the attack resolves")
	check(attack_result.reaction_prompt.get("step_back", false), "post-attack prompt should be Step Back")
	var ap_before := player.ap
	var reaction_result := system.resolve_pending_reaction(0)
	check(reaction_result.success and player.ap == ap_before - 1, "using Step Back should cost 1 AP")
	check(system.has_pending_step_back_move(), "using Step Back should wait for a destination")

	var origin := player.position
	var move_result := system.execute_step_back_move(origin + Vector2.LEFT * 9999.0)
	var moved_feet: float = origin.distance_to(player.position) / system.map_rules.world_units_per_foot
	check(move_result.success, "Step Back destination should resolve")
	check(is_equal_approx(moved_feet, player.speed * 0.5), "an over-range destination should clamp to half Speed")
	check(not system.has_pending_step_back_move(), "Step Back should end after one movement")
	check(player.last_step_back_round == system.combat_state.current_round, "Step Back use should be recorded for the current round")

	enemy.ap = enemy.max_ap
	var second_request := ActionRequest.new(enemy.id, ActionTypes.Type.ATTACK)
	second_request.target_id = player.id
	second_request.attack_data = safe_attack
	var second_attack := system.execute_action(second_request)
	check(not second_attack.requires_reaction_choice, "Step Back should not be offered a second time in the same round")
	system.combat_state.current_round += 1
	enemy.ap = enemy.max_ap
	var next_round_request := ActionRequest.new(enemy.id, ActionTypes.Type.ATTACK)
	next_round_request.target_id = player.id
	next_round_request.attack_data = safe_attack
	var next_round_attack := system.execute_action(next_round_request)
	check(next_round_attack.requires_reaction_choice and next_round_attack.reaction_prompt.get("step_back", false), "Step Back should be available again in a new round")

	if failures.is_empty():
		print("STEP_BACK_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("STEP_BACK_TEST: FAIL (%d)" % failures.size())
		quit(1)


func has_ability_trait(ability, trait_id: String) -> bool:
	for trait_data in ability.traits:
		if trait_data != null and trait_data.id == trait_id:
			return true
	return false


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
