extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var player_data = load("res://data/character/player.tres").duplicate(true)
	player_data.character_class = load("res://data/class/martial_artist.tres")
	player_data.class_attribute_choices.assign([AttributeTypes.Type.STRENGTH])
	var player: CombatantState = player_data.create_combatant_state()
	var enemy: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	player.position = Vector2.ZERO
	enemy.position = Vector2(5.0, 0.0)
	var system := CombatSystem.new()
	system.start_combat([player, enemy])
	system.combat_state.current_actor_id = player.id
	player.ap = 10
	# Keep this test independent from the player's current prototype loadout.
	player.equipped_weapon_attack = load("res://data/attack/iron_sword.tres")

	var devotee_data = load("res://data/character/player.tres").duplicate(true)
	var devotee: CombatantState = devotee_data.create_combatant_state()
	var devotee_enemy: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	var devotee_system := CombatSystem.new()
	devotee_system.start_combat([devotee, devotee_enemy])
	check(not devotee_system.ability_system.get_active_abilities(devotee).any(func(ability): return ability.id == "defensive_stance"), "Weapon Abilities with unmet Traits must not appear in the Action Bar", failures)
	check(not devotee_system.use_weapon_ability(devotee.id, devotee_enemy.id, "defensive_stance").success, "A filtered Weapon Ability cannot be activated directly", failures)

	var result := system.use_weapon_ability(player.id, enemy.id, "defensive_stance")
	check(result.success, "Defensive Stance should execute: %s" % result.failure_reason, failures)
	check(system.ability_system.ability_has_trait(load("res://data/ability/defensive_stance.tres"), "stance"), "Defensive Stance should have the shared Stance Trait", failures)
	check(player.has_status("defensive_stance_reflex"), "Defensive Stance should apply its shared EffectData", failures)
	check(system.effect_system.get_reflex_bonus(player) == 1, "Defensive Stance should grant +1 Reflex", failures)
	check(system.ability_system.get_remaining_cooldown(player, "defensive_stance") == 1, "Defensive Stance should start cooldown", failures)
	check(not system.use_weapon_ability(player.id, enemy.id, "defensive_stance").success, "Ability must be blocked during cooldown", failures)
	system.ability_system.reduce_cooldowns(player)
	check(system.ability_system.get_remaining_cooldown(player, "defensive_stance") == 1, "A new cooldown must not tick down at the end of the turn where it started", failures)
	system.ability_system.reduce_cooldowns(player)
	check(system.ability_system.get_remaining_cooldown(player, "defensive_stance") == 0, "Ability cooldown should be adjustable by the shared system", failures)
	system.ability_system.set_remaining_cooldown(player, "defensive_stance", 3)
	check(system.ability_system.change_remaining_cooldown(player, "defensive_stance", -2) == 1, "Ability cooldown should support shared modifiers", failures)

	var spear = load("res://data/equipment/long_spear.tres")
	player.ap = 10
	system.equipment_system.toggle_equipment(player, spear, EquipmentSystem.WEAPON_SLOT_1)
	system.equipment_system.refresh_equipment(player)
	check(not system.use_weapon_ability(player.id, enemy.id, "defensive_stance").success, "Switching weapons must remove the old Weapon Ability", failures)
	check(player.has_status("defensive_stance_reflex"), "An already-applied Effect must survive a weapon switch", failures)
	check(system.effect_system.expire_start_turn_effects(player).size() == 1 and not player.has_status("defensive_stance_reflex"), "Defensive Stance must expire at the start of the next turn", failures)

	if failures.is_empty():
		print("WEAPON_ACTIVE_ABILITY_TEST: PASS")
		quit(0)
	for failure in failures:
		push_error(failure)
	quit(1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
