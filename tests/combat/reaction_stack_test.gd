extends SceneTree

const ResolutionContextScript = preload("res://combat/reaction/resolution_context.gd")

func _init() -> void:
	var failures: Array[String] = []
	var context = ResolutionContextScript.new()
	var root := ActionRequest.new("root", ActionTypes.Type.ATTACK)
	context.begin(root)
	var parent = context.open_frame(root, {"name": "Parry"})
	var child = context.open_frame(root, {"name": "Counter"})
	check(parent != null and parent.depth == 1, "First Reaction must open at depth 1", failures)
	check(child != null and child.depth == 2 and child.parent_id == parent.id, "Nested Reaction must retain its parent and depth", failures)
	check(context.complete_current("enemy", "counter"), "Top Reaction should resolve first", failures)
	check(context.current_frame() == parent, "Completing a child must resume its parent frame", failures)
	check(context.complete_current("player", "parry"), "Parent Reaction should resolve after its child", failures)
	context.begin(root)
	for depth in range(ResolutionContextScript.MAX_REACTION_DEPTH):
		check(context.open_frame(root, {"depth": depth}) != null, "Reaction frame inside depth limit should open", failures)
	check(context.open_frame(root, {"too_deep": true}) == null, "Reaction depth limit must stop an infinite chain", failures)
	context.begin(root)
	context.enqueue_trigger({"timing": "before_damage"})
	check(context.pop_next_trigger().get("timing") == "before_damage", "Trigger Queue must preserve pending trigger order", failures)

	if failures.is_empty(): print("REACTION_STACK_TEST: PASS"); quit(0)
	for failure in failures: push_error(failure)
	quit(1)

func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition: failures.append(message)
