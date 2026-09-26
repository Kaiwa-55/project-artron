extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	var catalog = load("res://data/creation/default_creation_catalog.tres")
	var player: CombatantState = load("res://data/character/player.tres").create_combatant_state()
	var equipment := EquipmentSystem.new()
	var traits := TraitSystem.new()
	for spec in [["greatsword", 6, 7.0, "slash", true], ["warhammer", 6, 7.0, "blunt", true], ["crossbow", 5, 30.0, "pierce", false]]:
		var item: EquipmentData = load("res://data/equipment/%s.tres" % spec[0])
		var attack: AttackData = item.weapon_attack
		check(catalog.equipment.has(item) and player.equipment_inventory.has(item), "%s is available" % spec[0])
		check(attack.base_damage == spec[1] and attack.range_feet == spec[2] and attack.damage_type == spec[3], "%s combat values" % spec[0])
		check(traits.attack_has_trait(attack, "advanced") and traits.attack_has_trait(attack, "two_handed") and traits.attack_has_trait(attack, spec[3]), "%s category, hands and damage trait" % spec[0])
		check(traits.attack_has_trait(attack, "melee") == spec[4] and traits.attack_has_trait(attack, "ranged") != spec[4], "%s attack mode" % spec[0])
		check(equipment.toggle_equipment_without_cost(player, item, 0).success, "%s equips" % spec[0])
		check(player.equipped_items.get(0) == item and player.equipped_items.get(3) == item, "%s occupies both hands" % spec[0])
	var crossbow: AttackData = load("res://data/attack/crossbow.tres")
	var bolt: ItemData = load("res://data/item/crossbow_bolt.tres")
	var shot: AttackData = equipment.create_ammunition_attack(crossbow, bolt)
	check(shot != null and shot.base_damage == 5, "Crossbow bolt creates a five-damage shot")
	check(equipment.uses_ammunition(crossbow) and crossbow.ammunition_capacity == 1, "Crossbow requires reloading after one shot")
	var bolts: ItemStack = equipment.find_ammunition_stack(player, bolt.id)
	check(bolts != null, "Player has crossbow bolts")
	if bolts != null:
		var bolt_count: int = bolts.quantity
		equipment.initialize_ammunition(player)
		check(equipment.validate_ammunition(player, shot).success, "Loaded crossbow can fire")
		equipment.consume_ammunition(player, shot)
		check(bolts.quantity == bolt_count - 1 and not equipment.validate_ammunition(player, shot).success, "Shot consumes a bolt and empties crossbow")
		player.ap = player.max_ap
		var ap_before: int = player.ap
		check(equipment.reload_weapon(player).success, "Crossbow reload succeeds")
		check(player.ap == ap_before - crossbow.reload_ap_cost and equipment.validate_ammunition(player, shot).success, "Reload spends AP and restores one shot")
	for failure in failures:
		push_error(failure)
	print("ADVANCED_WEAPON_ROSTER_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
