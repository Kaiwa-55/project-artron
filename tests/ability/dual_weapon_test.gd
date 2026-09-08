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
	check(target.hp <= before_hp, "Dual Strike must never restore target HP.", failures)

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
