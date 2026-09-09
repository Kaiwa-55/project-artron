extends SceneTree

const IronSkin := preload("res://data/ability/iron_skin.tres")
const Catalog := preload("res://data/creation/default_creation_catalog.tres")


func _init() -> void:
	var failures: Array[String] = []
	var actor := CombatantState.new()
	actor.level = 2
	actor.available_abilities = [IronSkin]
	actor.equipped_abilities = [IronSkin.id]

	check(IronSkin.is_passive and IronSkin.required_level == 2, "Iron Skin is a Level 2 Passive", failures)
	check(IronSkin.required_trait_ids.has("martial_artist"), "Iron Skin requires Martial Artist", failures)
	check(actor.get_damage_resistance("slash") == 1, "Iron Skin resists Slash", failures)
	check(actor.get_damage_resistance("slashing") == 1, "Iron Skin resists Slashing alias", failures)
	check(actor.get_damage_resistance("pierce") == 1, "Iron Skin resists Pierce", failures)
	check(actor.get_damage_resistance("blunt") == 1, "Iron Skin resists Blunt", failures)
	check(actor.get_damage_resistance("bludgeoning") == 1, "Iron Skin resists Bludgeoning alias", failures)
	check(actor.get_damage_resistance("fire") == 0, "Iron Skin does not resist unrelated damage", failures)
	actor.level = 4
	check(actor.get_damage_resistance("slash") == 2, "Iron Skin scales to 2 Resistance at Level 4", failures)
	actor.level = 10
	check(actor.get_damage_resistance("slash") == 5, "Iron Skin scales to 5 Resistance at Level 10", failures)
	actor.level = 2
	actor.damage_resistances["pierce"] = 2
	actor.equipment_damage_resistances["pierce"] = 3
	check(actor.get_damage_resistance("pierce") == 6, "Iron Skin stacks with innate and equipment Resistance", failures)
	actor.equipped_abilities.clear()
	check(actor.get_damage_resistance("slash") == 0, "Unequipped Iron Skin grants no Resistance", failures)
	check(Catalog.abilities.any(func(ability): return ability != null and ability.id == IronSkin.id), "Character Creation contains Iron Skin", failures)

	if failures.is_empty():
		print("IRON_SKIN_TEST: PASS")
		quit(0)
	for failure in failures:
		push_error(failure)
	quit(1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
