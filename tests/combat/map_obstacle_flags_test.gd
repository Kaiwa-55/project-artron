extends SceneTree


func _init() -> void:
	var rules := MapRules.new()
	rules.add_circular_obstacle(Vector2(50, 0), 15.0, "Curtain", false, true)
	var walker := CombatantState.new()
	walker.position = Vector2(0, 0)
	walker.collision_radius_feet = 0.0
	var blocks_sight := not rules.has_line_of_sight(Vector2.ZERO, Vector2(100, 0))
	var allows_movement := rules.validate_movement_path(walker, Vector2(100, 0), {}).success
	rules.clear_obstacles()
	rules.add_circular_obstacle(Vector2(50, 0), 15.0, "Low Fence", true, false)
	var allows_sight := rules.has_line_of_sight(Vector2.ZERO, Vector2(100, 0))
	var blocks_movement := not rules.validate_movement_path(walker, Vector2(100, 0), {}).success
	var passed: bool = blocks_sight and allows_movement and allows_sight and blocks_movement
	print("MAP_OBSTACLE_FLAGS_TEST: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
