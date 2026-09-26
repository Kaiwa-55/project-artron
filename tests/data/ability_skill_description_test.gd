extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func collect_resources(directory: String, paths: Array[String]) -> void:
	for name in DirAccess.get_files_at(directory):
		if name.ends_with(".tres"):
			paths.append(directory.path_join(name))
	for name in DirAccess.get_directories_at(directory):
		if name != "effect":
			collect_resources(directory.path_join(name), paths)

func run_test() -> void:
	var paths: Array[String] = []
	collect_resources("res://data/ability", paths)
	collect_resources("res://data/skill", paths)
	var thai := RegEx.new()
	thai.compile("[ก-๙]")
	var ability_count := 0
	var skill_count := 0
	for path in paths:
		var resource = load(path)
		check(resource is AbilityData or resource is SkillData, "%s loads as Ability or Skill" % path)
		if not (resource is AbilityData or resource is SkillData):
			continue
		check(not resource.description.is_empty() and thai.search(resource.description) != null, "%s has a Thai description" % path)
		if resource is AbilityData:
			ability_count += 1
		else:
			skill_count += 1
	check(ability_count == 96 and skill_count == 8, "All 96 Abilities and 8 Skills are covered")
	var cone: SkillData = load("res://data/skill/arcane_cone.tres")
	var burst: SkillData = load("res://data/skill/arcane_burst.tres")
	var wave: AbilityData = load("res://data/ability/ki_wave.tres")
	check(cone.description.contains("20 ฟุต") and is_equal_approx(cone.targeting_range_feet, 20.0), "Arcane Cone describes its actual range")
	check(burst.description.contains("25 ฟุต") and is_equal_approx(burst.targeting_range_feet, 25.0), "Arcane Burst describes its actual targeting range")
	check(wave.description.contains("1 AP") and wave.ap_cost == 1, "Ki Wave describes its actual AP cost")
	for failure in failures:
		push_error(failure)
	print("ABILITY_SKILL_DESCRIPTION_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
