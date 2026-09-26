extends SceneTree

const WeaponEnhancements = preload("res://data/equipment/weapon_enhancement_catalog.gd")

var failures: Array[String] = []


func _init() -> void:
	var outfitter: ShopData = load("res://data/shop/outfitter_shop.tres")
	var offers := outfitter.get_offers()
	check(offers.size() == outfitter.offers.size() + WeaponEnhancements.WEAPON_PATHS.size() * 2, "Outfitter stocks both tiers of every player weapon")
	check(outfitter.get_offers()[-1].product == offers[-1].product, "Enhanced offers keep stable product identity")
	for path in WeaponEnhancements.WEAPON_PATHS:
		var original: EquipmentData = load(path)
		var original_damage := original.weapon_attack.base_damage
		var original_to_hit := original.weapon_attack.to_hit_bonus
		for level in [1, 2]:
			var enhanced := original.create_enhanced(level)
			check(enhanced != null and enhanced != original and enhanced.weapon_attack != original.weapon_attack, "%s +%d has independent equipment and attack data" % [original.id, level])
			check(enhanced.id == "%s_plus_%d" % [original.id, level] and enhanced.display_name == "%s +%d" % [original.display_name, level], "%s +%d has a distinct ID and name" % [original.id, level])
			check(enhanced.weapon_attack.base_damage == original_damage + level and enhanced.weapon_attack.to_hit_bonus == original_to_hit + level, "%s +%d boosts Base Damage and To Hit" % [original.id, level])
			check(enhanced.weapon_attack.traits == original.weapon_attack.traits and enhanced.weapon_attack.granted_abilities == original.weapon_attack.granted_abilities, "%s +%d keeps traits and abilities" % [original.id, level])
			check(offers.any(func(offer): return offer.product.id == enhanced.id and offer.price == enhanced.purchase_price), "%s +%d can be bought" % [original.id, level])
		check(original.weapon_attack.base_damage == original_damage and original.weapon_attack.to_hit_bonus == original_to_hit, "%s base weapon stays unchanged" % original.id)
	var player: CombatantState = load("res://data/character/player.tres").create_combatant_state()
	var sword: EquipmentData = load("res://data/equipment/sword.tres").create_enhanced(2)
	player.equipment_inventory.append(sword)
	var equipment := EquipmentSystem.new()
	check(equipment.toggle_equipment_without_cost(player, sword, 0).success and player.equipped_weapon_attack == sword.weapon_attack, "Equipping Sword +2 uses its enhanced attack")
	var crossbow: EquipmentData = load("res://data/equipment/crossbow.tres").create_enhanced(1)
	var bolt: ItemData = load("res://data/item/crossbow_bolt.tres")
	var shot := equipment.create_ammunition_attack(crossbow.weapon_attack, bolt)
	check(shot != null and shot.base_damage == crossbow.weapon_attack.base_damage + bolt.ammunition_damage_bonus and shot.to_hit_bonus == crossbow.weapon_attack.to_hit_bonus + bolt.ammunition_to_hit_bonus, "Ammunition keeps the weapon enhancement")
	check(load("res://data/equipment/sword.tres").create_enhanced(0) == null and load("res://data/equipment/sword.tres").create_enhanced(3) == null, "Only +1 and +2 are valid")
	for failure in failures:
		push_error(failure)
	print("WEAPON_ENHANCEMENT_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
