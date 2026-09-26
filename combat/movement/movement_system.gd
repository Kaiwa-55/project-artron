class_name MovementSystem
extends RefCounted

var map_rules
var ability_system
const SpatialNavigation = preload("res://combat/map/spatial_navigation.gd")

func spatial_path(actor: CombatantState, destination: Vector2, combat_state: CombatState = null, target_surface_id: StringName = &"") -> PackedVector3Array:
	var goal_id := target_surface_id if target_surface_id != &"" else (actor.requested_surface_id if actor.requested_surface_id != &"" else actor.surface_id)
	var navigation = map_rules.spatial_navigation
	if map_rules.building_map.get_surface(goal_id) == null:
		var stair_goal: Vector3 = map_rules.building_map.logic_to_world(destination, navigation.height_at(destination, goal_id))
		if not navigation.supported(stair_goal, goal_id, actor.collision_radius_feet):
			return PackedVector3Array()
	var route: PackedVector3Array = navigation.path(actor, destination, goal_id)
	if route.is_empty() and actor.surface_id == goal_id and map_rules.building_map.get_surface(goal_id) == null:
		var goal: Vector3 = map_rules.building_map.logic_to_world(destination, navigation.height_at(destination, goal_id))
		if navigation.supported(goal, goal_id, actor.collision_radius_feet):
			route = PackedVector3Array([actor.world_position, goal])
	var result := _refine_stair_route(route, actor, combat_state)
	if combat_state != null and _blocking_combatant(result, actor, combat_state) != null:
		var alternative: PackedVector3Array = navigation.path(actor, destination, goal_id, "", combat_state.combatants)
		if not alternative.is_empty():
			var adjusted := _refine_stair_route(alternative, actor, combat_state)
			if _blocking_combatant(adjusted, actor, combat_state) == null:
				return adjusted
	return result

func _refine_stair_route(route: PackedVector3Array, actor: CombatantState, combat_state: CombatState) -> PackedVector3Array:
	if route.size() < 2:
		return route
	var result := PackedVector3Array([route[0]])
	for i in range(1, route.size()):
		var detour := PackedVector3Array()
		for link in map_rules.spatial_navigation.data.transitions:
			var navigation = map_rules.spatial_navigation
			if link == null or not navigation.ramp_contains(route[i - 1], link, actor.collision_radius_feet) or not navigation.ramp_contains(route[i], link, actor.collision_radius_feet):
				continue
			if _stair_segment_clear(route[i - 1], route[i], link, actor, combat_state):
				break
			detour = _free_stair_segment(route[i - 1], route[i], link, actor, combat_state)
			if detour.is_empty() and not navigation.clear_segment(route[i - 1], route[i], link.transition_id, actor.collision_radius_feet):
				return PackedVector3Array()
			break
		if detour.is_empty():
			result.append(route[i])
		else:
			for step in range(1, detour.size()):
				result.append(detour[step])
	return result

func _stair_segment_clear(start: Vector3, finish: Vector3, link: BuildingTransitionData, actor: CombatantState, combat_state: CombatState) -> bool:
	return map_rules.spatial_navigation.clear_segment(start, finish, link.transition_id, actor.collision_radius_feet) and _blocking_combatant(PackedVector3Array([start, finish]), actor, combat_state) == null

func _free_stair_segment(start: Vector3, finish: Vector3, link: BuildingTransitionData, actor: CombatantState, combat_state: CombatState) -> PackedVector3Array:
	var navigation = map_rules.spatial_navigation
	var low: Vector3 = navigation.ramp_point(link, false)
	var high: Vector3 = navigation.ramp_point(link, true)
	var length := low.distance_to(high)
	if length <= 0.001:
		return PackedVector3Array()
	var half_width: float = link.width_feet * 0.5 - actor.collision_radius_feet - 0.1
	if half_width < 0.0:
		return PackedVector3Array()
	var lateral := Vector3(-(high - low).z, 0.0, (high - low).x).normalized()
	var longitudinal_steps := maxi(2, ceili(length / 1.5))
	var graph := AStar3D.new()
	graph.add_point(0, start)
	graph.add_point(1, finish)
	var cells: Dictionary = {}
	for row in range(longitudinal_steps + 1):
		var center := low.lerp(high, float(row) / longitudinal_steps)
		for column in range(9):
			var offset := half_width * (float(column) - 4.0) * 0.25
			var point := center + lateral * offset
			if _blocking_combatant(PackedVector3Array([point, point]), actor, combat_state) != null:
				continue
			if not navigation.supported(point, link.transition_id, actor.collision_radius_feet):
				continue
			var key := Vector2i(row, column)
			var point_id := graph.get_available_point_id()
			graph.add_point(point_id, point)
			cells[key] = point_id
	for key in cells:
		var point_id: int = cells[key]
		for neighbor in [key + Vector2i(0, 1), key + Vector2i(1, -1), key + Vector2i(1, 0), key + Vector2i(1, 1)]:
			if not cells.has(neighbor):
				continue
			var next_id: int = cells[neighbor]
			if _stair_segment_clear(graph.get_point_position(point_id), graph.get_point_position(next_id), link, actor, combat_state):
				graph.connect_points(point_id, next_id)
		for endpoint in [0, 1]:
			if graph.get_point_position(point_id).distance_to(graph.get_point_position(endpoint)) <= 6.0 and _stair_segment_clear(graph.get_point_position(point_id), graph.get_point_position(endpoint), link, actor, combat_state):
				graph.connect_points(point_id, endpoint)
	return graph.get_point_path(0, 1)

func _blocking_combatant(route: PackedVector3Array, actor: CombatantState, combat_state: CombatState) -> CombatantState:
	if combat_state == null:
		return null
	for other in combat_state.combatants.values():
		if other == actor:
			continue
		for i in range(1, route.size()):
			if map_rules.movement_segment_blocked_by_combatant(route[i - 1], route[i], actor, other):
				return other
	return null


func get_available_distance_feet(actor: CombatantState) -> float:
	if actor == null:
		return 0.0
	# Status effects such as Slowed can reduce current Speed to zero while a
	# split Move is still in progress. Current Speed always takes priority over
	# the distance that was reserved when the Move began.
	if actor.get_effective_speed() <= 0.001:
		return 0.0
	if actor.movement_in_progress:
		return actor.movement_remaining_feet
	# Each new Move action grants a fresh Speed allowance. Continuing an
	# unfinished Move reuses the remaining allowance without spending AP again.
	return actor.get_effective_speed() + (ability_system.get_first_move_distance_bonus(actor) if ability_system != null else 0.0)


func can_begin_or_continue_move(actor: CombatantState, ap_cost: int = 1) -> bool:
	if actor == null or get_available_distance_feet(actor) <= 0.001:
		return false
	return actor.movement_in_progress or actor.ap >= ap_cost


func plan_bounded_move(actor: CombatantState, destination: Vector2, maximum_feet: float, combat_state: CombatState) -> Dictionary:
	if actor == null or combat_state == null or maximum_feet <= 0.0:
		return {"validation": ActionResult.failure("Movement is unavailable.")}
	if actor.is_dying() or actor.has_status("rooted") or actor.has_status("grabbed"):
		return {"validation": ActionResult.failure("The character cannot Move.")}
	if map_rules.spatial_navigation != null:
		var route: PackedVector3Array = spatial_path(actor, destination, combat_state)
		if route.size() < 2:
			return {"validation": ActionResult.failure("No walkable route to that location.")}
		route = SpatialNavigation.truncate(route, maximum_feet)
		if route.size() < 2:
			return {"validation": ActionResult.failure("No walkable route within the movement range.")}
		var blocker: CombatantState = _blocking_combatant(route, actor, combat_state)
		if blocker != null:
			return {"validation": ActionResult.failure("Movement path is blocked by %s." % blocker.display_name)}
		var endpoint: Vector3 = route[-1]
		return {"validation": ActionResult.success_result(), "destination": map_rules.building_map.world_to_logic(endpoint), "world_position": endpoint, "surface_id": map_rules.spatial_navigation.surface_at(endpoint, actor.surface_id), "route": route, "distance_feet": SpatialNavigation.length_of(route)}
	var maximum_units: float = maximum_feet * map_rules.world_units_per_foot
	var endpoint_2d: Vector2 = actor.position + (destination - actor.position).limit_length(maximum_units)
	var validation: ActionResult = map_rules.validate_movement_path(actor, endpoint_2d, combat_state.combatants)
	return {"validation": validation, "destination": endpoint_2d, "distance_feet": actor.position.distance_to(endpoint_2d) / map_rules.world_units_per_foot}


func apply_bounded_move(actor: CombatantState, plan: Dictionary) -> void:
	if plan.has("route"):
		actor.movement_path_3d = plan["route"]
		actor.world_position = plan["world_position"]
		actor.surface_id = plan["surface_id"]
		actor.requested_surface_id = &""
	else:
		actor.position = plan["destination"]
	actor.movement_distance_this_turn += float(plan["distance_feet"])


func clamp_destination_to_remaining_speed(
	actor: CombatantState,
	destination: Vector2,
	movement: MovementData,
	combat_state: CombatState = null
) -> Vector2:
	if actor == null or movement == null:
		return destination
	if map_rules != null and map_rules.spatial_navigation != null:
		var navigation = map_rules.spatial_navigation
		var budget := get_available_distance_feet(actor)
		var full_route := spatial_path(actor, destination, combat_state)
		var route := SpatialNavigation.truncate(full_route, budget)
		if route.is_empty():
			return destination
		if SpatialNavigation.length_of(full_route) <= budget + 0.001:
			actor.requested_surface_id = navigation.surface_at(full_route[-1], actor.surface_id)
			return map_rules.building_map.world_to_logic(full_route[-1])
		# A partial stop can change the route around another actor. Recheck the
		# route to that stop so the Move never exceeds its Speed allowance.
		for attempt in range(8):
			actor.requested_surface_id = navigation.surface_at(route[-1], actor.surface_id)
			var adjusted: PackedVector3Array = spatial_path(actor, map_rules.building_map.world_to_logic(route[-1]), combat_state)
			if adjusted.is_empty() or SpatialNavigation.length_of(adjusted) <= budget + 0.001:
				break
			route = SpatialNavigation.truncate(adjusted, maxf(0.0, budget - 0.01))
		actor.requested_surface_id = navigation.surface_at(route[-1], actor.surface_id)
		return map_rules.building_map.world_to_logic(route[-1])
	var available_distance_feet: float = get_available_distance_feet(actor)
	var maximum_distance: float = maxf(0.0, available_distance_feet) \
		* movement.world_units_per_foot
	var requested_distance: float = actor.position.distance_to(destination)
	if requested_distance <= maximum_distance or requested_distance <= 0.001:
		return destination
	return actor.position + actor.position.direction_to(destination) * maximum_distance

func validate_move(
	actor: CombatantState,
	destination: Vector2,
	movement: MovementData,
	combat_state: CombatState = null,
	preview_route: PackedVector3Array = PackedVector3Array()
) -> ActionResult:

	if actor == null:
		return ActionResult.failure(
			"Actor does not exist."
		)

	if movement == null:
		return ActionResult.failure(
			"Movement data does not exist."
		)

	if actor.is_dying():
		return ActionResult.failure(
			"Actor is Dying."
		)
	if actor.has_status("rooted"):
		return ActionResult.failure("Rooted characters cannot Move.")
	if actor.has_status("grabbed"):
		return ActionResult.failure("Grabbed characters cannot Move.")

	if not actor.movement_in_progress and actor.ap < movement.ap_cost:
		return ActionResult.failure(
			"Not enough AP."
		)

	var distance := actor.position.distance_to(
		destination
	)

	var available_distance_feet: float = get_available_distance_feet(actor)
	if available_distance_feet <= 0.001:
		return ActionResult.failure("No Speed remaining this Turn.")
	if map_rules != null and map_rules.spatial_navigation != null:
		var route := preview_route if not preview_route.is_empty() else spatial_path(actor, destination, combat_state)
		if route.size() < 2:
			return ActionResult.failure("No walkable route to that location.")
		distance = SpatialNavigation.length_of(route) * movement.world_units_per_foot
		var blocker := _blocking_combatant(route, actor, combat_state)
		if blocker != null:
			return ActionResult.failure("Movement path is blocked by %s." % blocker.display_name)
	if distance > available_distance_feet * movement.world_units_per_foot + 0.01:
		return ActionResult.failure(
			"Destination exceeds remaining Speed."
		)

	if map_rules != null and combat_state != null and map_rules.spatial_navigation == null:
		var path_validation: ActionResult = map_rules.validate_movement_path(actor, destination, combat_state.combatants)
		if not path_validation.success:
			return path_validation

	return ActionResult.success_result()

func execute_move(
	actor: CombatantState,
	destination: Vector2,
	movement: MovementData,
	combat_state: CombatState = null
) -> ActionResult:

	var validation := validate_move(
		actor,
		destination,
		movement,
		combat_state
	)

	if not validation.success:
		return validation

	if not actor.movement_in_progress:
		var first_move_distance: float = get_available_distance_feet(actor)
		if not actor.spend_ap(movement.ap_cost):
			return ActionResult.failure(
				"Unable to spend AP."
			)
		actor.movement_in_progress = true
		actor.movement_remaining_feet = first_move_distance
		if ability_system != null:
			ability_system.commit_first_move_distance_bonuses(actor)

	var distance_feet: float = actor.position.distance_to(destination) \
		/ movement.world_units_per_foot
	if map_rules != null and map_rules.spatial_navigation != null:
		var route := spatial_path(actor, destination, combat_state)
		distance_feet = SpatialNavigation.length_of(route)
		actor.movement_path_3d = route
		actor.world_position = route[-1]
		actor.surface_id = map_rules.spatial_navigation.surface_at(route[-1], actor.requested_surface_id if actor.requested_surface_id != &"" else actor.surface_id)
		actor.requested_surface_id = &""
	else:
		actor.position = destination
	actor.movement_distance_this_turn += distance_feet
	actor.movement_remaining_feet = maxf(
		0.0,
		actor.movement_remaining_feet - distance_feet
	)
	if actor.movement_remaining_feet <= 0.001:
		actor.movement_remaining_feet = 0.0
		actor.movement_in_progress = false

	return ActionResult.success_result()
