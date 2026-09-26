extends SceneTree

const Apprentice = preload("res://data/equipment/apprentice_staff.tres")
const Focus = preload("res://data/equipment/focus_staff.tres")
const Ember = preload("res://data/equipment/ember_staff.tres")
const Frost = preload("res://data/equipment/frost_staff.tres")
const EmberBolt = preload("res://data/skill/ember_bolt.tres")
const FrostShard = preload("res://data/skill/frost_shard.tres")
const ArcaneBolt = preload("res://data/skill/arcane_bolt.tres")

var failures: Array[String] = []


func _init() -> void:
	var actor := CombatantState.new()
	actor.base_max_hp = 10
	actor.base_max_mana = 5
	actor.equipment_inventory = [Apprentice, Focus, Ember, Frost]
	StatSystem.new().initialize_combatant(actor)
	var equipment := EquipmentSystem.new()
	var skills := SkillSystem.new()
	for staff in [Apprentice, Focus, Ember, Frost]:
		check(equipment.toggle_equipment_without_cost(actor, staff, 0).success, "%s equips" % staff.display_name)
		check(actor.equipped_items.get(0) == staff and actor.equipped_items.get(3) == staff, "%s occupies both hands" % staff.display_name)
		check(actor.max_mana == 6, "%s gives exactly +1 Max Mana" % staff.display_name)
		check(equipment.is_two_handed(staff), "%s has the two-handed trait" % staff.display_name)
		if staff == Apprentice:
			check(skills.get_attack_data(ArcaneBolt, actor).to_hit_bonus == ArcaneBolt.attack_data.to_hit_bonus, "Apprentice Staff does not grant an extra Skill bonus")
		elif staff == Focus:
			check(skills.get_attack_data(ArcaneBolt, actor).to_hit_bonus == ArcaneBolt.attack_data.to_hit_bonus + 1, "Focus Staff adds +1 accuracy to a Mana Skill once")
		elif staff == Ember:
			check(skills.get_attack_data(EmberBolt, actor).base_damage == EmberBolt.attack_data.base_damage + 1, "Ember Staff adds +1 fire Skill damage")
			check(skills.get_attack_data(FrostShard, actor).base_damage == FrostShard.attack_data.base_damage, "Ember Staff does not boost cold Skills")
		else:
			check(skills.get_attack_data(FrostShard, actor).base_damage == FrostShard.attack_data.base_damage + 1, "Frost Staff adds +1 cold Skill damage")
			check(skills.get_attack_data(EmberBolt, actor).base_damage == EmberBolt.attack_data.base_damage, "Frost Staff does not boost fire Skills")
	check(equipment.toggle_equipment_without_cost(actor, Frost, 0).success and actor.max_mana == 5, "Removing a Staff removes its Mana bonus")
	var outfitter = load("res://data/shop/outfitter_shop.tres")
	for staff in [Apprentice, Focus, Ember, Frost]:
		check(outfitter.offers.any(func(offer): return offer.product == staff), "%s is sold at the outfitter" % staff.display_name)
	for failure in failures:
		push_error(failure)
	print("MAGE_STAFF_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
