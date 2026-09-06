extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var system := ProgressionSystem.new()
	var character := CombatantState.new()

	var initial := system.initialize_character(character)
	check(initial.success, "Character initialization should succeed.", failures)
	check(character.level == 1 and character.experience == 0, "A new character should begin at Level 1 with 0 XP.", failures)
	check(character.ability_points == 1, "Level 1 should grant its initial Ability Point.", failures)
	check(character.pending_level_up_choices.size() == 1, "Level 1 Ability choice should remain pending.", failures)
	check(initial.ability_points_gained == 1 and initial.has_pending_choices(), "Initialization should report its pending Ability choice.", failures)
	var repeated_initialization := system.initialize_character(character)
	check(repeated_initialization.ability_points_gained == 0, "Initialization must not grant the same rewards twice.", failures)

	var first_gain := system.add_experience(character, 99)
	check(first_gain.success and not first_gain.has_level_up(), "99 XP should not cause a Level-up.", failures)
	check(character.level == 1 and system.get_xp_to_next_level(character) == 1, "The character should need 1 XP for Level 2.", failures)

	var multi_level := system.add_experience(character, 501)
	check(multi_level.levels_gained == [2, 3, 4], "A large XP reward should process Levels 2, 3, and 4 in order.", failures)
	check(character.level == 4 and character.experience == 600, "The character should reach Level 4 at 600 total XP.", failures)
	check(multi_level.ability_points_gained == 2, "Levels 2-4 should grant 2 Ability Points.", failures)
	check(multi_level.attribute_points_gained == 1, "Level 4 should grant 1 Attribute Point.", failures)
	check(character.ability_points == 3 and character.attribute_points == 1, "All earned points should remain on the character.", failures)
	var constitution_before := character.constitution
	var attribute_choice = system.increase_attribute(character, AttributeTypes.Type.CONSTITUTION)
	check(attribute_choice.success and character.constitution == constitution_before + 1, "A pending Attribute Point should increase the chosen Attribute.", failures)
	check(character.attribute_points == 0 and character.selected_level_attributes == [AttributeTypes.Type.CONSTITUTION], "Attribute choice should be recorded and consume its point.", failures)

	var maximum := system.add_experience(character, 999999)
	check(maximum.current_level == 10 and character.experience == 4500, "Progression should clamp at Level 10 and its XP threshold.", failures)
	check(system.get_xp_to_next_level(character) == 0, "Maximum Level should require no additional XP.", failures)
	check(not system.can_level_up(character), "A maximum-Level character cannot Level-up.", failures)

	var invalid := system.add_experience(character, -1)
	check(not invalid.success, "Negative XP should be rejected.", failures)

	var preselected_character := CombatantState.new()
	var preselected_ability := AbilityData.new()
	preselected_ability.id = "preselected"
	preselected_ability.display_name = "Preselected"
	preselected_character.available_abilities = [preselected_ability]
	preselected_character.selected_ability_ids = [preselected_ability.id]
	var preselected_result := system.initialize_character(preselected_character)
	check(preselected_result.success and preselected_character.ability_points == 0, "Character Creation selections should consume earned Ability Points once.", failures)
	check(preselected_character.pending_level_up_choices.is_empty(), "A preselected Ability should clear its matching pending choice.", failures)

	for failure in failures:
		push_error(failure)
	print("PROGRESSION_SYSTEM_TEST: PASS" if failures.is_empty() else "PROGRESSION_SYSTEM_TEST: FAIL (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
