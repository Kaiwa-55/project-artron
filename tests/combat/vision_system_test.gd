extends SceneTree

const VisionSystemScript = preload("res://combat/vision/vision_system.gd")

func _init() -> void:
	var observer := CombatantState.new()
	observer.vision = 2
	var target := CombatantState.new()
	target.base_concealment = 1
	target.concealment_bonus = 2
	var normal := VisionSystemScript.get_visibility_result(observer, target, 3)
	var dark_vision := CombatantState.new()
	dark_vision.vision = observer.vision
	dark_vision.base_concealment = observer.base_concealment
	dark_vision.concealment_bonus = observer.concealment_bonus
	dark_vision.dark_vision = 1
	var improved := VisionSystemScript.get_visibility_result(dark_vision, target, 3)
	var blocked := VisionSystemScript.get_visibility_result(observer, target, 0, false)
	var passed: bool = normal.effective_concealment == 4 \
		and normal.not_visible \
		and improved.effective_concealment == 4 \
		and improved.not_visible \
		and blocked.not_visible
	print("VISION_SYSTEM_TEST: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
