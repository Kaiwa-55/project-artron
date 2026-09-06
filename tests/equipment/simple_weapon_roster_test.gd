extends SceneTree

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _init() -> void:
	var catalog = load("res://data/creation/default_creation_catalog.tres")
	var trait_system := TraitSystem.new()
	var player = load("res://data/character/player.tres").create_combatant_state()
	var enemy = load("res://data/character/enemy.tres").create_combatant_state()
	var system := CombatSystem.new()
	system.start_combat([player, enemy])
	system.combat_state.current_actor_id = player.id
	var roster := {"dagger": [3, 5.0, 1, 0], "club": [5, 5.0, 0, 1], "iron_sword": [5, 5.0, 0, 0], "hand_axe": [5, 5.0, 0, 0], "short_spear": [4, 5.0, 0, 0], "shortbow": [4, 30.0, 1, 0]}
	for id in roster:
		var item = load("res://data/equipment/%s.tres" % id)
		var attack: AttackData = item.weapon_attack
		check(catalog.equipment.has(item) and player.equipment_inventory.has(item), id + " available in creation and inventory")
		check(attack.base_damage == roster[id][0] and attack.range_feet == roster[id][1], id + " damage/range")
		check(attack.attack_attribute == roster[id][2] and attack.defense_type == roster[id][3] and attack.ap_cost == 1, id + " attribute/defense/AP")
		check(trait_system.attack_has_trait(attack, "simple") and not trait_system.attack_has_trait(attack, "advanced"), id + " category")
		check(trait_system.attack_has_trait(attack, attack.damage_type), id + " damage trait")
		player.ap = player.max_ap
		if player.equipped_items.values().has(item):
			check(system.toggle_equipment(player.id, item, 0).success, id + " unequip")
		check(system.toggle_equipment(player.id, item, 0).success, id + " equip")
		check(player.equipped_weapon_attack == attack, id + " active attack")
		if id == "shortbow":
			check(player.equipped_items.get(0) == item and player.equipped_items.get(3) == item, "Shortbow uses both hands")
			check(not trait_system.attack_has_trait(attack, "melee"), "Shortbow cannot supply melee Opportunity")
		player.ap = player.max_ap
		enemy.position = player.position + Vector2((player.collision_radius_feet + enemy.collision_radius_feet + attack.range_feet) * 12.0, 0)
		check(system.attack_system.validate_attack(player, enemy, attack).success, id + " exact reach")
		enemy.position.x += 1.0
		check(not system.attack_system.validate_attack(player, enemy, attack).success, id + " beyond reach")
	var dagger = load("res://data/attack/dagger.tres")
	check(dagger.to_hit_bonus == 1 and dagger.critical_chance == 15 and dagger.can_critical, "Dagger accuracy and critical")
	check(not load("res://data/attack/club.tres").can_critical, "Club cannot critical")
	for id in ["simple", "advanced", "melee", "ranged", "thrown", "reach", "two_handed", "shield_compatible", "heavy", "light", "finesse", "reload", "dual_weapon", "slash", "pierce", "blunt"]:
		var trait_data = load("res://data/trait/%s.tres" % id)
		check(trait_data != null and trait_data.id == id and not trait_data.description.is_empty(), id + " trait exists")
	for failure in failures:
		push_error(failure)
	print("SIMPLE_WEAPON_ROSTER_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
