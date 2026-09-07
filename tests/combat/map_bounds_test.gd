extends SceneTree


func _init() -> void:
	var rules := MapRules.new()
	rules.set_playable_bounds(Vector2(250, 250), Vector2(-1500, -1500))
	var actor := CombatantState.new()
	actor.id = "actor"
	actor.display_name = "Actor"
	actor.position = Vector2(120, 120)
	actor.collision_radius_feet = 2.5
	var combatants := {actor.id: actor}
	var expected_size := Vector2(3000, 3000)
	var inside := rules.validate_movement_path(actor, Vector2.ZERO, combatants)
	var outside := rules.validate_movement_path(actor, Vector2(1510, 0), combatants)
	var passed: bool = rules.playable_bounds.position == Vector2(-1500, -1500) and rules.playable_bounds.size == expected_size and inside.success and not outside.success
	print("MAP_BOUNDS_TEST: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
