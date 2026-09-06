extends SceneTree

const PlayerData = preload("res://data/character/player.tres")
const EnemyData = preload("res://data/character/enemy.tres")
const HiddenData = preload("res://data/status/hidden.tres")
const HasteData = preload("res://data/status/haste.tres")

var failures: Array[String] = []

func _init() -> void:
	var player: CombatantState = PlayerData.create_combatant_state()
	var enemy: CombatantState = EnemyData.create_combatant_state()
	player.position = Vector2(100, 100)
	enemy.position = Vector2(140, 100)
	var system := CombatSystem.new()
	system.start_combat([player, enemy])

	player.add_effect(HiddenData)
	check(system.effect_system.get_attack_bonus(player) == 2, "Hidden should grant +2 To Hit")
	var enemy_attack := AttackData.new()
	enemy_attack.id = "hidden_target_test"
	enemy_attack.display_name = "Hidden Target Test"
	enemy_attack.ap_cost = 0
	enemy_attack.range_feet = 20.0
	check(not system.attack_system.validate_attack(enemy, player, enemy_attack).success, "An enemy cannot directly target a Hidden character")
	player.apply_damage(1)
	check(not player.has_status("hidden"), "Taking damage should remove Hidden")

	player.add_effect(HiddenData)
	system.combat_state.current_actor_id = player.id
	player.ap = player.max_ap
	var safe_attack := AttackData.new()
	safe_attack.id = "reveal_attack"
	safe_attack.display_name = "Reveal Attack"
	safe_attack.requires_to_hit = false
	safe_attack.ap_cost = 0
	safe_attack.base_damage = 0
	safe_attack.range_feet = 20.0
	var request := ActionRequest.new(player.id, ActionTypes.Type.ATTACK)
	request.target_id = enemy.id
	request.attack_data = safe_attack
	check(system.execute_action(request).success and not player.has_status("hidden"), "Declaring an Attack should remove Hidden")

	player.add_effect(HasteData)
	check(is_equal_approx(player.get_effective_speed(), player.speed + 5.0), "Haste should add 5 feet Speed")
	system.combat_state.current_actor_id = player.id
	system.start_current_turn()
	check(player.effective_max_ap == player.max_ap + 1, "Haste should add 1 Maximum AP at turn start")
	var stronger_haste: EffectData = HasteData.duplicate(true)
	stronger_haste.potency = 2
	stronger_haste.speed_bonus_per_stack = 10.0
	stronger_haste.max_ap_bonus_per_stack = 2
	player.add_effect(stronger_haste)
	check(is_equal_approx(player.get_effective_speed(), player.speed + 10.0), "A stronger Haste should replace the weaker Haste")
	check(player.effects.filter(func(instance): return instance.data.id == "haste").size() == 1, "Haste should not stack")

	if failures.is_empty():
		print("HIDDEN_HASTE_TEST: PASS")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		print("HIDDEN_HASTE_TEST: FAIL (%d)" % failures.size())
		quit(1)

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
