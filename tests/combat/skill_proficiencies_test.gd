extends SceneTree

const PlayerData = preload("res://data/character/player.tres")
const VisionSystemScript = preload("res://combat/vision/vision_system.gd")


func _init() -> void:
	var observer: CombatantState = PlayerData.create_combatant_state()
	var target: CombatantState = PlayerData.create_combatant_state()
	var defaults_valid := observer.skill_ranks == {
		"stealth": 0, "perception": 0, "athletics": 0, "acrobatics": 0, "survival": 0,
	}
	observer.skill_ranks["perception"] = 2
	target.skill_ranks["stealth"] = 1
	var result: Dictionary = VisionSystemScript.get_visibility_result(observer, target, 3)
	var passed: bool = defaults_valid \
		and observer.get_skill_rank("athletics") == 0 \
		and result.total_concealment == 4 \
		and result.visible
	print("SKILL_PROFICIENCIES_TEST: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
