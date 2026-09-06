extends SceneTree

const DefaultProgression = preload("res://data/progression/default_progression.tres")


func _init() -> void:
	var failures: Array[String] = []
	check(DefaultProgression.is_valid(), "Default progression table should be valid.", failures)
	check(DefaultProgression.max_level == 10, "Maximum level should be 10.", failures)
	check(DefaultProgression.get_cumulative_xp_for_level(1) == 0, "Level 1 should begin at 0 XP.", failures)
	check(DefaultProgression.get_cumulative_xp_for_level(5) == 1000, "Level 5 should begin at 1,000 XP.", failures)
	check(DefaultProgression.get_cumulative_xp_for_level(10) == 4500, "Level 10 should begin at 4,500 XP.", failures)
	check(DefaultProgression.get_level_for_xp(99) == 1, "99 XP should remain Level 1.", failures)
	check(DefaultProgression.get_level_for_xp(100) == 2, "100 XP should reach Level 2.", failures)
	check(DefaultProgression.get_level_for_xp(999) == 4, "999 XP should remain Level 4.", failures)
	check(DefaultProgression.get_level_for_xp(999999) == 10, "XP above the table should clamp to Level 10.", failures)
	check(DefaultProgression.get_xp_span_for_level(4) == 400, "Level 4 to 5 should require 400 XP.", failures)
	check(DefaultProgression.get_xp_to_next_level(4, 850) == 150, "850 XP at Level 4 should need 150 XP.", failures)
	check(DefaultProgression.get_xp_to_next_level(10, 4500) == 0, "Maximum Level should need no more XP.", failures)
	check(DefaultProgression.get_ability_points_for_level(1) == 1, "Level 1 should grant 1 Ability Point.", failures)
	check(DefaultProgression.get_ability_points_for_level(3) == 0, "Level 3 should not grant an Ability Point.", failures)
	check(DefaultProgression.get_attribute_points_for_level(4) == 1, "Level 4 should grant 1 Attribute Point.", failures)
	check(DefaultProgression.get_attribute_points_for_level(8) == 1, "Level 8 should grant 1 Attribute Point.", failures)

	for failure in failures:
		push_error(failure)
	print("PROGRESSION_DATA_TEST: PASS" if failures.is_empty() else "PROGRESSION_DATA_TEST: FAIL (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
