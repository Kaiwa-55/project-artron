extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var packed: PackedScene = load("res://scenes/combat/ui/ActionBarLayoutConcept.tscn")
	var scene: Control = packed.instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.get_node("ActionBarPanel").position == Vector2(0, 500), "Action bar is aligned to the bottom-left", failures)
	check(scene.get_node("ActionBarPanel/Actions").get_child_count() == 5, "Five action category components are present", failures)
	check(scene.get_node("ActionBarPanel/LeftQuickSlots").get_child_count() == 4, "Left quick-slot grid contains four slots", failures)
	check(scene.get_node("ActionBarPanel/RightQuickSlots").get_child_count() == 4, "Right quick-slot grid contains four slots", failures)
	check(scene.get_node("EndTurn").position == Vector2(1095, 625), "End Turn button matches the brief placement", failures)
	check(scene.get_node("ActionBarPanel/PortraitFrame/Portrait").texture != null, "Portrait asset is assigned", failures)
	check(scene.get_node("ActionBarPanel/Actions/Attack").texture != null and scene.get_node("ActionBarPanel/Defenses/Fortitude").texture != null, "Action and defense assets are assigned", failures)
	for failure in failures:
		push_error(failure)
	print("ACTION_BAR_LAYOUT_CONCEPT_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
