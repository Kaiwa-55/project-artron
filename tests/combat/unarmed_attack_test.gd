extends SceneTree

const PlayerData = preload("res://data/character/player.tres")
const EnemyData = preload("res://data/character/enemy.tres")
const SpiderData = preload("res://data/character/spider.tres")
const GiantSpiderData = preload("res://data/character/giant_spider.tres")
const VelkariaData = preload("res://data/character/velkaria.tres")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	for character_data in [PlayerData, EnemyData, SpiderData, GiantSpiderData, VelkariaData]:
		var state: CombatantState = character_data.create_combatant_state()
		check(state.unarmed_attack != null and state.unarmed_attack.id == "unarmed_attack", "%s receives Unarmed Attack" % state.display_name)

	var system := CombatSystem.new()
	var player: CombatantState = PlayerData.create_combatant_state()
	var target: CombatantState = EnemyData.create_combatant_state()
	player.position = Vector2.ZERO
	target.position = Vector2(100, 0)
	system.start_combat([player, target])
	system.combat_state.current_actor_id = player.id
	system.start_current_turn()
	var attack: AttackData = player.unarmed_attack.duplicate(true)
	attack.requires_to_hit = false
	check(system.trait_system.attack_has_trait(attack, "melee") and system.trait_system.attack_has_trait(attack, "unarmed"), "Unarmed Attack has Melee and Unarmed traits")
	check(system.equipment_system.has_free_hand(player), "One empty hand enables Unarmed Attack")
	var request := ActionRequest.new(player.id, ActionTypes.Type.ATTACK)
	request.target_id = target.id
	request.attack_data = attack
	check(system.execute_action(request).success, "Unarmed Attack can execute with a free hand")

	player.ap = player.effective_max_ap
	player.equipped_items[0] = RefCounted.new()
	player.equipped_items[3] = RefCounted.new()
	check(not system.equipment_system.has_free_hand(player), "Two occupied hands disable Unarmed Attack")
	var blocked: ActionResult = system.execute_action(request)
	check(not blocked.success and blocked.failure_reason.contains("free hand"), "Combat validation rejects Unarmed Attack with no free hand")

	for failure in failures:
		push_error(failure)
	print("UNARMED_ATTACK_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
