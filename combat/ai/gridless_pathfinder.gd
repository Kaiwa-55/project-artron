class_name GridlessPathfinder
extends RefCounted

const SAMPLE_COUNT := 12
const CLEARANCE_WORLD_UNITS := 4.0


func find_path(system: CombatSystem, actor: CombatantState, goal: Vector2, combatants: Dictionary) -> PackedVector2Array:
	var direct := PackedVector2Array([actor.position, goal])
	if is_segment_clear(system, actor, actor.position, goal, combatants):
		return direct

	var nodes: Array[Vector2] = [actor.position, goal]
	append_combatant_clearance_nodes(system, actor, combatants, nodes)
	append_obstacle_clearance_nodes(system, actor, combatants, nodes)
	var route := shortest_visible_route(system, actor, combatants, nodes)
	return route


func append_combatant_clearance_nodes(system: CombatSystem, actor: CombatantState, combatants: Dictionary, nodes: Array[Vector2]) -> void:
	var actor_radius: float = system.map_rules.get_combatant_radius_world_units(actor)
	for other in combatants.values():
		if other == null or other == actor or other.is_dying():
			continue
		var radius: float = actor_radius + system.map_rules.get_combatant_radius_world_units(other) + CLEARANCE_WORLD_UNITS
		append_ring_nodes(system, actor, combatants, other.position, radius, nodes)


func append_obstacle_clearance_nodes(system: CombatSystem, actor: CombatantState, combatants: Dictionary, nodes: Array[Vector2]) -> void:
	var actor_radius: float = system.map_rules.get_combatant_radius_world_units(actor)
	for obstacle in system.map_rules.obstacles:
		var center: Vector2 = obstacle.get("center", Vector2.ZERO)
		var radius: float = actor_radius + float(obstacle.get("radius", 0.0)) + CLEARANCE_WORLD_UNITS
		append_ring_nodes(system, actor, combatants, center, radius, nodes)


func append_ring_nodes(system: CombatSystem, actor: CombatantState, combatants: Dictionary, center: Vector2, radius: float, nodes: Array[Vector2]) -> void:
	for index in range(SAMPLE_COUNT):
		var angle: float = TAU * float(index) / float(SAMPLE_COUNT)
		var point := center + Vector2.RIGHT.rotated(angle) * radius
		if is_point_clear(system, actor, point, combatants):
			nodes.append(point)


func is_point_clear(system: CombatSystem, actor: CombatantState, point: Vector2, combatants: Dictionary) -> bool:
	var actor_radius: float = system.map_rules.get_combatant_radius_world_units(actor)
	for other in combatants.values():
		if other == null or other == actor or other.is_dying():
			continue
		var minimum: float = actor_radius + system.map_rules.get_combatant_radius_world_units(other)
		if point.distance_to(other.position) < minimum:
			return false
	for obstacle in system.map_rules.obstacles:
		var minimum: float = actor_radius + float(obstacle.get("radius", 0.0))
		if point.distance_to(obstacle.get("center", Vector2.ZERO)) < minimum:
			return false
	return true


func is_segment_clear(system: CombatSystem, actor: CombatantState, start: Vector2, finish: Vector2, combatants: Dictionary) -> bool:
	var actor_radius: float = system.map_rules.get_combatant_radius_world_units(actor)
	for other in combatants.values():
		if other == null or other == actor or other.is_dying():
			continue
		var minimum: float = actor_radius + system.map_rules.get_combatant_radius_world_units(other)
		if system.map_rules.segment_distance_to_point(start, finish, other.position) < minimum:
			return false
	for obstacle in system.map_rules.obstacles:
		var minimum: float = actor_radius + float(obstacle.get("radius", 0.0))
		if system.map_rules.segment_distance_to_point(start, finish, obstacle.get("center", Vector2.ZERO)) < minimum:
			return false
	return true


func shortest_visible_route(system: CombatSystem, actor: CombatantState, combatants: Dictionary, nodes: Array[Vector2]) -> PackedVector2Array:
	var distance: Array[float] = []
	var previous: Array[int] = []
	var visited: Array[bool] = []
	for _node in nodes:
		distance.append(INF)
		previous.append(-1)
		visited.append(false)
	distance[0] = 0.0
	for _step in range(nodes.size()):
		var current := -1
		var best := INF
		for index in range(nodes.size()):
			if not visited[index] and distance[index] < best:
				best = distance[index]
				current = index
		if current < 0 or current == 1:
			break
		visited[current] = true
		for neighbor in range(nodes.size()):
			if neighbor == current or visited[neighbor]:
				continue
			if not is_segment_clear(system, actor, nodes[current], nodes[neighbor], combatants):
				continue
			var proposed: float = distance[current] + nodes[current].distance_to(nodes[neighbor])
			if proposed < distance[neighbor]:
				distance[neighbor] = proposed
				previous[neighbor] = current
	if previous[1] < 0:
		return PackedVector2Array()
	var reversed: Array[Vector2] = []
	var cursor := 1
	while cursor >= 0:
		reversed.append(nodes[cursor])
		cursor = previous[cursor]
	reversed.reverse()
	return PackedVector2Array(reversed)
