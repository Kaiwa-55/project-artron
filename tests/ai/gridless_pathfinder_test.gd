extends SceneTree

const PathfinderScript = preload("res://combat/ai/gridless_pathfinder.gd")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var system := CombatSystem.new()
	var actor := CombatantState.new()
	actor.id = "actor"
	actor.position = Vector2.ZERO
	actor.collision_radius_feet = 2.5
	var blocker := CombatantState.new()
	blocker.id = "blocker"
	blocker.position = Vector2(100.0, 0.0)
	blocker.collision_radius_feet = 2.5
	var combatants := {actor.id: actor, blocker.id: blocker}
	var goal := Vector2(220.0, 0.0)
	var pathfinder = PathfinderScript.new()
	var path: PackedVector2Array = pathfinder.find_path(system, actor, goal, combatants)
	var success := path.size() > 2 and path[0].is_equal_approx(actor.position) and path[path.size() - 1].is_equal_approx(goal)
	if success:
		for index in range(path.size() - 1):
			if not pathfinder.is_segment_clear(system, actor, path[index], path[index + 1], combatants):
				success = false
				break
	if not success:
		push_error("Gridless pathfinder must route around a blocking combatant.")
	print("GRIDLESS_PATHFINDER_TEST: " + ("PASS" if success else "FAIL") + " " + str(path))
	quit(0 if success else 1)
