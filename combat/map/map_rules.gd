class_name MapRules
extends RefCounted

# Gridless map scale. Positions, collision radii, and obstacles use world units.
var world_units_per_foot: float = 12.0
var obstacles: Array[Dictionary] = []
var playable_bounds: Rect2 = Rect2()


func set_playable_bounds(size_feet: Vector2, origin: Vector2 = Vector2.ZERO) -> void:
	playable_bounds = Rect2(origin, Vector2(
		maxf(0.0, size_feet.x) * world_units_per_foot,
		maxf(0.0, size_feet.y) * world_units_per_foot
	))


func has_playable_bounds() -> bool:
	return playable_bounds.size.x > 0.0 and playable_bounds.size.y > 0.0


func add_circular_obstacle(center: Vector2, radius_world_units: float, label: String = "Obstacle") -> void:
	obstacles.append({
		"center": center,
		"radius": maxf(0.0, radius_world_units),
		"label": label
	})


func clear_obstacles() -> void:
	obstacles.clear()


func get_attack_range_world_units(range_feet: float) -> float:
	return maxf(0.0, range_feet) * world_units_per_foot


func get_combatant_radius_world_units(combatant) -> float:
	return maxf(0.0, combatant.collision_radius_feet) * world_units_per_foot


func get_targeting_preview_radius_world_units(attacker, range_feet: float) -> float:
	# A target is in reach when its body touches this circle, not its center.
	return get_combatant_radius_world_units(attacker) + get_attack_range_world_units(range_feet)


func get_edge_distance_world_units(first, second) -> float:
	var center_distance: float = first.position.distance_to(second.position)
	var combined_radii: float = get_combatant_radius_world_units(first) + get_combatant_radius_world_units(second)
	return maxf(0.0, center_distance - combined_radii)


func is_target_in_range(attacker, target, range_feet: float) -> bool:
	return get_edge_distance_world_units(attacker, target) <= get_attack_range_world_units(range_feet)


func has_line_of_sight(start: Vector2, finish: Vector2) -> bool:
	for obstacle in obstacles:
		var center: Vector2 = obstacle.get("center", Vector2.ZERO)
		var radius: float = float(obstacle.get("radius", 0.0))
		if segment_distance_to_point(start, finish, center) < radius:
			return false
	return true


func validate_movement_path(actor, destination: Vector2, combatants: Dictionary) -> ActionResult:
	if has_playable_bounds():
		var actor_radius := get_combatant_radius_world_units(actor)
		var safe_bounds := playable_bounds.grow(-actor_radius)
		if safe_bounds.size.x <= 0.0 or safe_bounds.size.y <= 0.0 or not safe_bounds.has_point(destination):
			return ActionResult.failure("Destination is outside the playable map.")
	for other in combatants.values():
		if other == actor or other.is_dying():
			continue
		var minimum_distance: float = get_combatant_radius_world_units(actor) + get_combatant_radius_world_units(other)
		if segment_distance_to_point(actor.position, destination, other.position) < minimum_distance:
			return ActionResult.failure("Movement path is blocked by %s." % other.display_name)

	for obstacle in obstacles:
		var obstacle_center: Vector2 = obstacle.get("center", Vector2.ZERO)
		var obstacle_radius: float = float(obstacle.get("radius", 0.0))
		if segment_distance_to_point(actor.position, destination, obstacle_center) < get_combatant_radius_world_units(actor) + obstacle_radius:
			return ActionResult.failure("Movement path is blocked by %s." % obstacle.get("label", "an obstacle"))

	return ActionResult.success_result()


func segment_distance_to_point(start: Vector2, finish: Vector2, point: Vector2) -> float:
	var segment := finish - start
	var segment_length_squared := segment.length_squared()
	if is_zero_approx(segment_length_squared):
		return start.distance_to(point)
	var progress := clampf((point - start).dot(segment) / segment_length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * progress)
