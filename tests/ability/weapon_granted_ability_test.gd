extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var player: CombatantState = load("res://data/character/player.tres").create_combatant_state()
	var equipment_system := EquipmentSystem.new()
	equipment_system.initialize_combatant(player)
	equipment_system.refresh_equipment(player)

	var ability_system := AbilitySystem.new()
	var attack: AttackData = load("res://data/attack/long_spear.tres")
	var ability = ability_system.get_available_ability(player, "long_reach")
	if ability != null:
		failures.append("Unequipped weapon Ability must not be available")

	var spear = load("res://data/equipment/long_spear.tres")
	player.ap = 10
	equipment_system.toggle_equipment(player, spear, EquipmentSystem.WEAPON_SLOT_1)
	equipment_system.refresh_equipment(player)
	ability = ability_system.get_available_ability(player, "long_reach")
	if ability == null:
		failures.append("Active weapon must expose its granted Ability")
	if not ability_system.is_ability_active(player, "long_reach"):
		failures.append("Weapon-granted Ability must be active without character equip")
	if ability_system.get_attack_range_bonus(player, attack) != 2.0:
		failures.append("Long Reach must grant +2 feet through the shared effect system")
	if attack.range_feet + ability_system.get_attack_range_bonus(player, attack) != 10.0:
		failures.append("Long Spear effective range must remain 10 feet")
	if ability_system.get_attack_abilities(player, attack).filter(func(entry): return entry.id == "long_reach").size() != 1:
		failures.append("Weapon Ability must not be duplicated")

	if failures.is_empty():
		print("weapon_granted_ability_test: PASS")
		quit(0)
	for failure in failures:
		push_error(failure)
	quit(1)
