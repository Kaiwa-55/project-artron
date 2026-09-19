extends SceneTree

const PlayerTemplate := preload("res://data/character/player.tres")
const Devotee := preload("res://data/class/devotee.tres")
const UnwaveringFaith := preload("res://data/ability/unwavering_faith.tres")
const Catalog := preload("res://data/creation/default_creation_catalog.tres")


func _init() -> void:
	var failures: Array[String] = []
	check_max_faith_at_level(1, 10, failures)
	check_max_faith_at_level(2, 11, failures)
	check_max_faith_at_level(3, 11, failures)
	check_max_faith_at_level(4, 12, failures)
	check_max_faith_at_level(6, 13, failures)
	check_max_faith_at_level(10, 15, failures)

	var devotee := create_devotee(2)
	var system := CombatSystem.new()
	system.start_combat([devotee])
	check(devotee.base_max_faith == 10 and devotee.max_faith == 11 and devotee.faith == 11, "Combat initializes base and current Faith from the central Stat formula", failures)
	devotee.faith = 7
	devotee.level = 4
	system.stat_system.refresh_combatant(devotee)
	check(devotee.max_faith == 12 and devotee.faith == 7, "Level refresh raises Max Faith without refilling spent Faith", failures)

	check(UnwaveringFaith.required_level == 2 and UnwaveringFaith.is_passive, "Unwavering Faith is a Level 2 Passive", failures)
	check(["devotee", "passive"].all(func(id): return UnwaveringFaith.traits.any(func(trait_data): return trait_data != null and trait_data.id == id)), "Unwavering Faith has Devotee and Passive traits", failures)
	check(Catalog.abilities.has(UnwaveringFaith) and Devotee.get_progression_entry(2).granted_abilities.has(UnwaveringFaith), "Unwavering Faith is registered in Character Creation and Level 2 progression", failures)

	for failure in failures:
		push_error(failure)
	print("UNWAVERING_FAITH_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func create_devotee(level: int) -> CombatantState:
	var character = PlayerTemplate.duplicate(true)
	character.character_class = Devotee
	character.level = level
	character.class_attribute_choices.assign([AttributeTypes.Type.CONSTITUTION])
	return character.create_combatant_state()


func check_max_faith_at_level(level: int, expected: int, failures: Array[String]) -> void:
	var devotee := create_devotee(level)
	var system := CombatSystem.new()
	system.start_combat([devotee])
	check(devotee.max_faith == expected, "Level %d Devotee has %d Max Faith" % [level, expected], failures)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
