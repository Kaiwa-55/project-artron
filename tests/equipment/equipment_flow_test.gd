extends SceneTree

const PlayerData = preload("res://data/character/player.tres")
const EnemyData = preload("res://data/character/enemy.tres")

var failures: Array[String] = []


func _init() -> void:
	var system := CombatSystem.new()
	var player: CombatantState = PlayerData.create_combatant_state()
	var enemy: CombatantState = EnemyData.create_combatant_state()
	system.start_combat([player, enemy])
	system.combat_state.current_actor_id = player.id
	player.ap = player.max_ap

	var sword = find_item(player, "iron_sword")
	var spear = find_item(player, "long_spear")
	var armor = find_item(player, "leather_armor")
	var shield = find_item(player, "buckler")
	check(player.equipped_items.get(0) == sword, "starting Weapon should occupy Weapon slot 1")
	check(not player.equipped_items.has(3), "Weapon slot 2 should start empty")

	var armor_result := system.toggle_equipment(player.id, armor)
	check(not armor_result.success and player.ap == player.max_ap, "Armor changes must fail without spending AP")

	var shield_result := system.toggle_equipment(player.id, shield, 3)
	check(shield_result.success and player.ap == player.max_ap - 1, "Shield change should cost 1 AP")
	check(player.equipped_items.get(3) == shield, "Shield should occupy Hand slot 2")

	var spear_result := system.toggle_equipment(player.id, spear, 3)
	check(spear_result.success and player.ap == player.max_ap - 2, "Weapon change should cost 1 AP")
	check(player.equipped_items.get(0) == spear and player.equipped_items.get(3) == spear, "Two-Handed weapon should occupy both Weapon slots")
	check(not player.equipped_items.values().has(shield), "Two-Handed weapon should remove the Shield from shared Hand slots")
	check(player.equipped_weapon_attack == spear.weapon_attack, "Two-Handed weapon should become the active attack")

	player.movement_in_progress = true
	player.movement_remaining_feet = 5.0
	var unequip_result := system.toggle_equipment(player.id, spear, 0)
	check(unequip_result.success, "Two-Handed weapon should unequip")
	check(not player.movement_in_progress and is_zero_approx(player.movement_remaining_feet), "equipment changes should forfeit remaining Move")
	check(not player.equipped_items.has(0) and not player.equipped_items.has(3), "unequipping Two-Handed weapon should free both slots")

	system.pending_action = ActionRequest.new("enemy", ActionTypes.Type.ATTACK)
	system.pending_reaction = {"reactions": ["test"]}
	var ap_before_pending := player.ap
	var pending_result := system.toggle_equipment(player.id, sword, 0)
	check(not pending_result.success and player.ap == ap_before_pending, "pending Reaction should block equipment changes without spending AP")

	if failures.is_empty():
		print("EQUIPMENT_FLOW_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("EQUIPMENT_FLOW_TEST: FAIL (%d)" % failures.size())
		quit(1)


func find_item(combatant: CombatantState, item_id: String):
	for item in combatant.equipment_inventory:
		if item != null and item.id == item_id:
			return item
	return null


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
