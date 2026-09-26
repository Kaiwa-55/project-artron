extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var starting_player: CombatantState = load("res://data/character/player.tres").create_combatant_state()
	var starting_system := CombatSystem.new()
	starting_system.start_combat([starting_player])
	check(starting_system.equipment_system.validate_dual_weapon_setup(starting_player).success, "The default Player should start with two distinct Daggers equipped.", failures)
	check(starting_player.equipped_items.get(EquipmentSystem.WEAPON_SLOT_1) != starting_player.equipped_items.get(EquipmentSystem.WEAPON_SLOT_2), "The two starting Daggers must be separate item resources.", failures)
	var actor: CombatantState = load("res://data/character/player.tres").create_combatant_state()
	var target: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	actor.id = "dual_actor"
	actor.team = 0
	actor.position = Vector2.ZERO
	target.id = "dual_target"
	target.team = 1
	# Exercise the real gridless range calculation instead of overlapping the
	# tokens. With two 2.5 ft radii, 10 ft centre distance is exactly 5 ft reach.
	target.position = Vector2(10.0 * 12.0, 0)
	actor.starting_equipment = [load("res://data/equipment/dagger.tres"), load("res://data/equipment/hand_axe.tres")]
	actor.starting_equipment_slots = {"dagger": EquipmentSystem.WEAPON_SLOT_1, "hand_axe": EquipmentSystem.WEAPON_SLOT_2}
	var system := CombatSystem.new()
	system.start_combat([actor, target])
	system.combat_state.current_actor_id = actor.id
	actor.ap = 4
	actor.attacks_declared_this_turn = 1 # One earlier Attack makes the off-hand strike reach the -4 RAP step.
	check(system.equipment_system.validate_dual_weapon_setup(actor).success, "Two eligible one-handed weapons should enable Dual Strike.", failures)
	var dual_strike = system.ability_system.get_active_abilities(actor).filter(func(ability): return ability.id == "dual_strike").front()
	check(dual_strike != null, "Dual Strike should appear in the active Ability list.", failures)
	check(system.ability_system.get_targeting_range(actor, dual_strike) == 5.0, "Dual Strike targeting should use the shorter equipped weapon range.", failures)
	var before_hp: int = target.hp
	var result := system.use_active_ability(actor.id, target.id, "dual_strike")
	check(result.success, "Dual Strike should execute.", failures)
	check(actor.ap == 4 - dual_strike.ap_cost, "Dual Strike should spend its configured AP cost once.", failures)
	var attack_results := result.events.filter(func(event): return event.type == EventTypes.Type.ATTACK_HIT or event.type == EventTypes.Type.ATTACK_MISS)
	check(attack_results.size() == 2, "Dual Strike should resolve both weapon attacks.", failures)
	var dual_penalties: Array[int] = []
	for attack_result in attack_results:
		dual_penalties.append(int(attack_result.data.get("repeated_attack_penalty", 0)))
	check(dual_penalties == [-2, -4], "Dual Strike counts both weapon attacks for Repeated Attack Penalty.", failures)
	check(int(attack_results[0].data.get("offhand_penalty", 99)) == 0, "Main-hand Attack has no off-hand penalty.", failures)
	check(int(attack_results[1].data.get("offhand_penalty", 99)) == -2, "Non-Light off-hand Attack has its own -2 penalty.", failures)
	check(int(attack_results[1].data.get("repeated_attack_penalty", 99)) + int(attack_results[1].data.get("offhand_penalty", 99)) == -6, "A -4 repeated penalty and -2 off-hand penalty stack to -6.", failures)
	check(actor.attacks_declared_this_turn == 3, "Dual Strike counts as two declared Attacks.", failures)
	var next_attack: AttackData = actor.equipped_items.get(EquipmentSystem.WEAPON_SLOT_1).weapon_attack
	check(system.attack_system.declare_attack_action(actor, next_attack) == -4, "The Attack after Dual Strike receives the -4 Repeated Attack Penalty.", failures)
	check(target.hp <= before_hp, "Dual Strike must never restore target HP.", failures)
	var plain_actor := CombatantState.new()
	plain_actor.id = "plain_attacker"
	plain_actor.team = 1
	plain_actor.max_ap = 10
	plain_actor.ap = 10
	var plain_target := CombatantState.new()
	plain_target.id = "plain_target"
	plain_target.team = 2
	plain_target.max_hp = 100
	plain_target.hp = 100
	var plain_system := CombatSystem.new()
	plain_system.start_combat([plain_actor, plain_target])
	var plain_attack := AttackData.new()
	plain_attack.ap_cost = 0
	var unpenalized := plain_system.attack_system.resolve_attack(plain_actor, plain_target, plain_attack, true)
	var stacked := plain_system.attack_system.resolve_attack(plain_actor, plain_target, plain_attack, true, [], -4, -2)
	check(unpenalized.attack_modifier - stacked.attack_modifier == 6, "Off-hand and repeated penalties both reduce the actual To Hit modifier.", failures)
	var light_actor: CombatantState = load("res://data/character/player.tres").create_combatant_state()
	var light_target: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	light_actor.id = "light_actor"
	light_actor.team = 0
	light_actor.position = Vector2.ZERO
	light_target.id = "light_target"
	light_target.team = 1
	light_target.position = Vector2(120, 0)
	var light_system := CombatSystem.new()
	light_system.start_combat([light_actor, light_target])
	light_system.combat_state.current_actor_id = light_actor.id
	light_actor.ap = 4
	light_actor.attacks_declared_this_turn = 1
	var light_result := light_system.use_active_ability(light_actor.id, light_target.id, "dual_strike")
	var light_rolls := light_result.events.filter(func(event): return event.type == EventTypes.Type.ATTACK_HIT or event.type == EventTypes.Type.ATTACK_MISS)
	check(light_rolls.size() == 2 and int(light_rolls[1].data.get("repeated_attack_penalty", 99)) == -4 and int(light_rolls[1].data.get("offhand_penalty", 99)) == -2, "Light off-hand weapon also stacks -2 with the -4 repeated penalty.", failures)
	var combat_ui := preload("res://scenes/combat/control.gd").new()
	check(combat_ui.format_attack_penalties(light_rolls[1]).contains("Combined Penalty: -6"), "Combat log shows the combined -6 penalty.", failures)
	combat_ui.free()

	var shield_actor: CombatantState = load("res://data/character/player.tres").create_combatant_state()
	shield_actor.equipped_items[EquipmentSystem.WEAPON_SLOT_1] = load("res://data/equipment/dagger.tres")
	shield_actor.equipped_items[EquipmentSystem.WEAPON_SLOT_2] = load("res://data/equipment/buckler.tres")
	check(not system.equipment_system.validate_dual_weapon_setup(shield_actor).success, "A Shield must not count as a second weapon.", failures)

	if failures.is_empty():
		print("DUAL_WEAPON_TEST: PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
