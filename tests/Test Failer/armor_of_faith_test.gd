extends SceneTree

const PlayerTemplate := preload("res://data/character/player.tres")
const Devotee := preload("res://data/class/devotee.tres")
const ArmorOfFaith := preload("res://data/ability/armor_of_faith.tres")
const Catalog := preload("res://data/creation/default_creation_catalog.tres")


func _init() -> void:
	var failures: Array[String] = []
	var character = PlayerTemplate.duplicate(true)
	character.character_class = Devotee
	character.level = 1
	character.class_attribute_choices.assign([AttributeTypes.Type.CONSTITUTION])
	var devotee: CombatantState = character.create_combatant_state()
	var system := CombatSystem.new()
	system.start_combat([devotee])
	check(devotee.granted_ability_ids.has("armor_of_faith") and devotee.equipped_abilities.has("armor_of_faith"), "Level 1 Devotee receives Armor of Faith as an active Passive", failures)

	devotee.faith = 0
	devotee.temporary_faith = 0
	var base_reflex := system.defense_system.get_defense(devotee, DefenseTypes.Type.REFLEX)
	var base_fortitude := system.defense_system.get_defense(devotee, DefenseTypes.Type.FORTITUDE)
	var base_will := system.defense_system.get_defense(devotee, DefenseTypes.Type.WILL)
	devotee.faith = 4
	check(system.defense_system.get_defense(devotee, DefenseTypes.Type.REFLEX) == base_reflex, "Faith below 5 grants no Defense", failures)
	devotee.faith = 5
	check(system.defense_system.get_defense(devotee, DefenseTypes.Type.REFLEX) == base_reflex + 1, "5 Faith grants +1 Reflex", failures)
	check(system.defense_system.get_defense(devotee, DefenseTypes.Type.FORTITUDE) == base_fortitude + 1, "5 Faith grants +1 Fortitude", failures)
	check(system.defense_system.get_defense(devotee, DefenseTypes.Type.WILL) == base_will + 1, "5 Faith grants +1 Will", failures)
	devotee.faith = 9
	check(system.defense_system.get_defense(devotee, DefenseTypes.Type.WILL) == base_will + 1, "Armor of Faith rounds Faith divided by 5 down", failures)
	devotee.faith = 5
	devotee.temporary_faith = 5
	check(system.defense_system.get_defense(devotee, DefenseTypes.Type.REFLEX) == base_reflex + 2, "Temporary Faith contributes to total Faith dynamically", failures)
	devotee.faith = 0
	devotee.temporary_faith = 0
	check(system.defense_system.get_defense(devotee, DefenseTypes.Type.REFLEX) == base_reflex, "Defense decreases immediately when Faith is spent", failures)

	check(ArmorOfFaith.required_level == 1 and ArmorOfFaith.is_passive, "Armor of Faith is a Level 1 Passive", failures)
	check(ArmorOfFaith.required_trait_ids.has("devotee") and ArmorOfFaith.traits.any(func(trait_data): return trait_data != null and trait_data.id == "passive"), "Armor of Faith has Devotee and Passive traits", failures)
	check(Catalog.abilities.has(ArmorOfFaith) and Devotee.get_progression_entry(1).granted_abilities.has(ArmorOfFaith), "Armor of Faith is registered in Character Creation and Level 1 progression", failures)

	for failure in failures:
		push_error(failure)
	print("ARMOR_OF_FAITH_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
