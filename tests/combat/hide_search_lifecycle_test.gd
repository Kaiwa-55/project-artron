extends SceneTree

const PlayerData = preload("res://data/character/player.tres")
const EnemyData = preload("res://data/character/enemy.tres")

var failures: Array[String] = []


func _init() -> void:
	var actor: CombatantState = PlayerData.create_combatant_state()
	var enemy: CombatantState = EnemyData.create_combatant_state()
	actor.skill_ranks["stealth"] = 100
	enemy.skill_ranks["perception"] = 0
	var system := CombatSystem.new()
	system.start_combat([actor, enemy])
	system.combat_state.turn_order = [actor.id, enemy.id]
	system.combat_state.current_actor_id = actor.id
	actor.ap = actor.max_ap
	check(system.use_hide(actor.id).success and system.use_hide(actor.id).success, "Hide can be attempted twice")
	check(actor.get_concealment_bonus_against(enemy.id) == 1, "Repeated Hide cannot stack Concealment")
	system.advance_turn()
	check(system.combat_state.current_actor_id == enemy.id and actor.get_concealment_bonus_against(enemy.id) == 1, "Hide lasts through the enemy's turn")
	enemy.skill_ranks["perception"] = 200
	enemy.ap = enemy.max_ap
	var first_search: ActionResult = system.use_search(enemy.id, actor.id)
	var second_search: ActionResult = system.use_search(enemy.id, actor.id)
	check(first_search.success and second_search.success, "Search can be attempted twice")
	check(first_search.events[0].data.concealment_reduced and not second_search.events[0].data.concealment_reduced and second_search.events.size() == 1, "Only the first Search removes Hide concealment")
	check(actor.get_concealment_reduction_against(enemy.id) == 1, "Repeated Search cannot stack a future concealment penalty")
	system.advance_turn()
	check(system.combat_state.current_actor_id == actor.id and actor.get_concealment_bonus_against(enemy.id) == 0 and actor.get_concealment_reduction_against(enemy.id) == 0, "Hide and Search expire at the hider's next turn")
	actor.grant_concealment_against(enemy.id, 1)
	actor.reveal_concealment_against(enemy.id, 1)
	var attack := AttackData.new()
	attack.id = "stealth_lifecycle_attack"
	attack.requires_to_hit = false
	attack.ap_cost = 0
	attack.base_damage = 0
	attack.range_feet = 100.0
	var request := ActionRequest.new(actor.id, ActionTypes.Type.ATTACK)
	request.target_id = enemy.id
	request.attack_data = attack
	actor.ap = actor.max_ap
	check(system.execute_action(request).success, "An attack can be declared after hiding")
	check(actor.get_concealment_bonus_against(enemy.id) == 0 and actor.get_concealment_reduction_against(enemy.id) == 0, "Declaring an attack reveals the hider")
	actor.grant_concealment_against(enemy.id, 1)
	actor.reveal_concealment_against(enemy.id, 1)
	actor.apply_damage(1)
	check(actor.get_concealment_bonus_against(enemy.id) == 0 and actor.get_concealment_reduction_against(enemy.id) == 0, "Taking damage reveals the hider")
	for failure in failures:
		push_error(failure)
	print("HIDE_SEARCH_LIFECYCLE_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
