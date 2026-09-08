extends SceneTree

const AssassinData = preload("res://data/class/assassin.tres")
const MartialArtistData = preload("res://data/class/martial_artist.tres")
const DevoteeData = preload("res://data/class/devotee.tres")


func _init() -> void:
	var failures: Array[String] = []
	check(AssassinData.has_valid_progression(10), "Assassin progression entries should be valid and unique.", failures)
	check(MartialArtistData.has_valid_progression(10), "Martial Artist progression entries should be valid and unique.", failures)
	check(DevoteeData.has_valid_progression(10), "Devotee progression entries should be valid and unique.", failures)
	check(AssassinData.progression_entries.size() == 10, "Assassin should define rewards for Levels 1-10.", failures)
	check(MartialArtistData.progression_entries.size() == 10, "Martial Artist should define rewards for Levels 1-10.", failures)

	var system := ProgressionSystem.new()
	var assassin := CombatantState.new()
	assassin.set_meta("class_data", AssassinData)
	var initial := system.initialize_character(assassin)
	check(initial.success and assassin.base_max_hp == 5, "Assassin Level 1 should add 4 HP to the default base value.", failures)
	check(assassin.available_abilities.any(func(ability): return ability.id == "killer_instinct"), "Assassin Level 1 should gain Killer Instinct.", failures)
	check(assassin.equipped_abilities.has("killer_instinct"), "Killer Instinct should auto-equip.", failures)

	var level_three := system.add_experience(assassin, 300)
	check(assassin.level == 3, "Assassin should reach Level 3.", failures)
	check(level_three.max_hp_gained == 10 and assassin.base_max_hp == 15, "Assassin Levels 2-3 should add 10 HP.", failures)
	check(level_three.max_mana_gained == 2 and assassin.base_max_mana == 2, "Assassin Levels 2-3 should add 2 Mana.", failures)
	check(not level_three.granted_ability_ids.has("shadow_step"), "Assassin Level 3 should unlock, not grant, Shadow Step.", failures)
	check(not assassin.equipped_abilities.has("shadow_step"), "Shadow Step should require spending an Ability Point.", failures)

	var martial_artist := CombatantState.new()
	martial_artist.level = 2
	martial_artist.set_meta("class_data", MartialArtistData)
	var martial_initial := system.initialize_character(martial_artist)
	check(martial_artist.experience == 100, "A Level 2 character should normalize to the Level 2 XP threshold.", failures)
	check(martial_initial.max_hp_gained == 15 and martial_artist.base_max_hp == 16, "Martial Artist Levels 1-2 should add 15 HP.", failures)
	check(martial_initial.granted_ability_ids.has("build_up_body"), "Martial Artist Level 1 should grant Build Up Body.", failures)
	check(not martial_initial.granted_ability_ids.has("combo_techniques"), "Martial Artist Level 2 should learn optional Abilities by spending Ability Points, not receive Combo Techniques automatically.", failures)
	check(martial_artist.ability_points == 2, "A Level 2 Martial Artist should receive 1 Ability Point for each Level.", failures)

	var repeated := system.initialize_character(martial_artist)
	check(repeated.max_hp_gained == 0 and repeated.granted_ability_ids.is_empty(), "Class rewards must not be granted twice.", failures)

	for failure in failures:
		push_error(failure)
	print("CLASS_PROGRESSION_TEST: PASS" if failures.is_empty() else "CLASS_PROGRESSION_TEST: FAIL (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
