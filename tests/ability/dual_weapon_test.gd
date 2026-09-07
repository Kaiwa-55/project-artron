extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var actor: CombatantState = load("res://data/character/player.tres").create_combatant_state()
	var target: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	actor.id = "dual_actor"
	actor.team = 0
	actor.position = Vector2.ZERO
	target.id = "dual_target"
	target.team = 1
	target.position = Vector2(5, 0)
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
	check(target.hp < before_hp, "Dual Strike should deal weapon damage.", failures)

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
