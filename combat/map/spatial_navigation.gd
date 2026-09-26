extends RefCounted

# A visibility graph in real world feet. All actors (including AI) use the
# same swept-clearance queries and continuous ramp segments.
var data: BuildingMapData
var rules_ref: WeakRef
var graph_cache: Dictionary = {}
var path_cache: Dictionary = {}
var rules:
	get:
		return rules_ref.get_ref()

func _init(source: BuildingMapData, map_rules) -> void:
	data = source
	rules_ref = weakref(map_rules)

func ramp_point(link: BuildingTransitionData, end: bool) -> Vector3:
	var surface := data.get_surface(link.to_surface_id if end else link.from_surface_id)
	var elevation := link.get_to_elevation(surface.elevation_feet) if end else link.get_from_elevation(surface.elevation_feet)
	return data.logic_to_world(data.map_to_logic(link.to_position if end else link.from_position), elevation)

func height_at(point: Vector2, id: StringName) -> float:
	var surface := data.get_surface(id)
	if surface != null:
		return surface.elevation_feet
	for link in data.transitions:
		if link.transition_id == id:
			var a := ramp_point(link, false)
			var b := ramp_point(link, true)
			var p := data.logic_to_map(point)
			var horizontal_length := link.from_position.distance_squared_to(link.to_position)
			if horizontal_length <= 0.0001:
				return a.y
			var t := clampf((p - link.from_position).dot(link.to_position - link.from_position) / horizontal_length, 0.0, 1.0)
			return lerpf(a.y, b.y, t)
	return 0.0

func surface_at(point: Vector3, fallback: StringName) -> StringName:
	for link in data.transitions:
		var a := ramp_point(link, false)
		var b := ramp_point(link, true)
		if not ramp_contains(point, link, 0.0):
			continue
		var horizontal := Vector2(b.x - a.x, b.z - a.z)
		var progress := clampf((Vector2(point.x - a.x, point.z - a.z)).dot(horizontal) / horizontal.length_squared(), 0.0, 1.0)
		if progress < 0.001:
			return link.from_surface_id
		if progress > 0.999:
			return link.to_surface_id
		return link.transition_id
	var map_point := data.logic_to_map(data.world_to_logic(point))
	for surface in data.surfaces:
		if surface == null or absf(point.y - surface.elevation_feet) >= 0.05:
			continue
		var on_walkable := surface.walkable_rects.any(func(rect: Rect2): return rect.has_point(map_point))
		var in_opening := surface.opening_rects.any(func(rect: Rect2): return rect.has_point(map_point))
		if on_walkable and not in_opening:
			return surface.surface_id
	return fallback

func supported(point: Vector3, id: StringName, radius: float) -> bool:
	var surface := data.get_surface(id)
	var p := data.logic_to_map(data.world_to_logic(point))
	if surface == null:
		for link in data.transitions:
			if link.transition_id == id:
				return ramp_contains(point, link, radius)
		return false
	for offset in [Vector2.ZERO, Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius)]:
		var sample: Vector2 = p + offset * data.pixels_per_foot
		var ramp_supported := false
		for link in data.transitions:
			if id == link.to_surface_id and point.distance_to(ramp_point(link, true)) <= radius + 0.1:
				var sample_3d := data.logic_to_world(data.map_to_logic(sample), point.y)
				var closest := Geometry3D.get_closest_point_to_segment(sample_3d, ramp_point(link, false), ramp_point(link, true))
				ramp_supported = sample_3d.distance_to(closest) <= radius + 0.1
		if ramp_supported:
			continue
		var opening_supported := false
		for opening in surface.opening_rects:
			if not opening.has_point(sample):
				continue
			for link in data.transitions:
				if link.to_surface_id != id or not opening.has_point(link.to_position):
					continue
				var stair_direction := (link.to_position - link.from_position).normalized()
				var sample_offset := sample - link.to_position
				var lateral_distance := absf(sample_offset.cross(stair_direction))
				if lateral_distance <= link.width_feet * data.pixels_per_foot * 0.5 + 0.1:
					opening_supported = true
					break
			if not opening_supported:
				return false
			break
		if not surface.walkable_rects.any(func(rect: Rect2): return rect.has_point(sample)):
			if not opening_supported:
				return false
	return true

func clear_segment(a: Vector3, b: Vector3, id: StringName, radius: float, ignored_door_key: String = "") -> bool:
	var start := data.world_to_logic(a)
	var finish := data.world_to_logic(b)
	for obstacle in rules.obstacles:
		if not obstacle.get("blocks_movement", true):
			continue
		if ignored_door_key != "" and obstacle.get("door_key", "") == ignored_door_key:
			continue
		var obstacle_id := StringName(obstacle.get("surface_id", &""))
		if obstacle_id != &"" and obstacle_id != id:
			continue
		if obstacle.get("shape", "circle") == "rect":
			if rules.segment_intersects_rect(start, finish, Rect2(obstacle.rect).grow(radius * data.pixels_per_foot)):
				return false
		elif obstacle.get("shape", "circle") == "segment":
			if rules.segment_segment_proximity(start, finish, obstacle.get("from", Vector2.ZERO), obstacle.get("to", Vector2.ZERO)).distance < float(obstacle.radius) + radius * data.pixels_per_foot:
				return false
		elif rules.segment_distance_to_point(start, finish, obstacle.center) < float(obstacle.radius) + radius * data.pixels_per_foot:
			return false
	# A rectangle is convex: if both footprint centers fit inside the same
	# inset walkable rect, the whole segment is supported. Openings still need
	# the detailed check because they can cut a hole through that rectangle.
	var surface := data.get_surface(id)
	if surface != null:
		var margin := radius * data.pixels_per_foot
		var from_map := data.logic_to_map(start)
		var to_map := data.logic_to_map(finish)
		var crosses_opening := false
		for opening in surface.opening_rects:
			if rules.segment_intersects_rect(from_map, to_map, opening.grow(margin)):
				crosses_opening = true
				break
		if not crosses_opening:
			for walkable in surface.walkable_rects:
				if walkable.size.x <= margin * 2.0 or walkable.size.y <= margin * 2.0:
					continue
				var safe_rect: Rect2 = walkable.grow(-margin)
				if safe_rect.has_point(from_map) and safe_rect.has_point(to_map):
					return true
	else:
		for link in data.transitions:
			if link.transition_id == id and ramp_contains(a, link, radius) and ramp_contains(b, link, radius):
				return true
	var steps := maxi(1, ceili(a.distance_to(b) / 0.75))
	for i in range(steps + 1):
		if not supported(a.lerp(b, float(i) / steps), id, radius):
			return false
	return true

func clear_around_combatants(a: Vector3, b: Vector3, actor: CombatantState, combatants: Dictionary) -> bool:
	for other in combatants.values():
		if other == actor:
			continue
		if rules.movement_segment_blocked_by_combatant(a, b, actor, other):
			return false
	return true

func ramp_contains(point: Vector3, link: BuildingTransitionData, radius: float) -> bool:
	var start := ramp_point(link, false)
	var finish := ramp_point(link, true)
	var horizontal := Vector2(finish.x - start.x, finish.z - start.z)
	var length_squared := horizontal.length_squared()
	if length_squared <= 0.0001 or link.width_feet * 0.5 < radius:
		return false
	var offset := Vector2(point.x - start.x, point.z - start.z)
	var progress := offset.dot(horizontal) / length_squared
	if progress < -0.001 or progress > 1.001:
		return false
	var lateral_distance := absf(offset.cross(horizontal)) / sqrt(length_squared)
	return absf(point.y - lerpf(start.y, finish.y, clampf(progress, 0.0, 1.0))) < 0.05 and lateral_distance <= link.width_feet * 0.5 - radius + 0.01

func path(actor: CombatantState, destination: Vector2, target_id: StringName = &"", ignored_door_key: String = "", combatants: Dictionary = {}) -> PackedVector3Array:
	var goal_id := target_id if target_id != &"" else actor.surface_id
	var goal := data.logic_to_world(destination, height_at(destination, goal_id))
	var radius := actor.collision_radius_feet
	var cache_key := str([actor.world_position, actor.surface_id, destination, goal_id, radius, rules.obstacles.size(), rules.door_revision, ignored_door_key])
	if combatants.is_empty() and path_cache.has(cache_key):
		return path_cache[cache_key]
	if actor.surface_id == goal_id and clear_segment(actor.world_position, goal, goal_id, radius, ignored_door_key) and clear_around_combatants(actor.world_position, goal, actor, combatants):
		return PackedVector3Array([actor.world_position, goal])
	var graph_key := str([radius, rules.obstacles.size(), rules.door_revision, ignored_door_key])
	if not combatants.is_empty():
		# The cursor changes the goal every frame, but the map and occupants do
		# not. Reuse the expensive visibility graph until a combatant moves.
		var occupants := PackedStringArray()
		for other in combatants.values():
			if other != actor:
				occupants.append(str([other.id, other.world_position, other.collision_radius_feet]))
		occupants.sort()
		graph_key = str([graph_key, actor.id, occupants])
	if graph_cache.has(graph_key):
		var cached: Dictionary = graph_cache[graph_key]
		return _query_graph(cached.graph, cached.ids, actor, goal, goal_id, radius, cache_key, ignored_door_key, combatants)
	var graph := AStar3D.new()
	var ids: Array[StringName] = [actor.surface_id, goal_id]
	graph.add_point(0, actor.world_position)
	graph.add_point(1, goal)
	for surface in data.surfaces:
		var bounds: Array[Rect2] = surface.wall_solid_rects() + surface.railing_rects + surface.invisible_wall_rects + surface.opening_rects
		for wall in surface.wall_solid_segments(data.pixels_per_foot):
			bounds.append(Rect2(wall.from, Vector2(wall.to) - Vector2(wall.from)).abs().grow(float(wall.width_feet) * data.pixels_per_foot * 0.5))
		for door in surface.doors:
			if door != null and not rules.door_is_open(surface.surface_id, door.door_id):
				bounds.append(door.rect)
		for rect in bounds:
			var expanded: Rect2 = rect.grow(radius * data.pixels_per_foot + 1.0)
			for corner in [expanded.position, expanded.end, Vector2(expanded.end.x, expanded.position.y), Vector2(expanded.position.x, expanded.end.y)]:
				var point := data.logic_to_world(data.map_to_logic(corner), surface.elevation_feet)
				if supported(point, surface.surface_id, radius) and clear_around_combatants(point, point, actor, combatants):
					graph.add_point(ids.size(), point)
					ids.append(surface.surface_id)
	# Moving around a character near a landing may require a turn on the floor
	# before entering the ramp, just as it would on an ordinary walkable floor.
	for other in combatants.values():
		if other == actor:
			continue
		var clearance: float = radius + other.collision_radius_feet + 0.8
		for surface in data.surfaces:
			if surface == null or absf(surface.elevation_feet - other.elevation_feet) >= clearance:
				continue
			for step in range(16):
				var direction := Vector2.from_angle(TAU * float(step) / 16.0)
				var point: Vector3 = other.world_position + Vector3(direction.x * clearance, surface.elevation_feet - other.elevation_feet, direction.y * clearance)
				if supported(point, surface.surface_id, radius) and clear_around_combatants(point, point, actor, combatants):
					graph.add_point(ids.size(), point)
					ids.append(surface.surface_id)
	for link in data.transitions:
		if link.width_feet < radius * 2.0:
			continue
		var start := ramp_point(link, false)
		var finish := ramp_point(link, true)
		var direction := finish - start
		if direction.length_squared() <= 0.0001:
			continue
		var lateral := Vector3(-direction.z, 0.0, direction.x).normalized()
		var half_width := maxf(0.0, link.width_feet * 0.5 - radius - 0.1)
		# Each point along the landing edge is a valid entrance. The route may
		# cross the ramp at any lateral position, not only its centerline.
		var entries: Array[int] = []
		var exits: Array[int] = []
		for column in range(9):
			var offset := half_width * (float(column) - 4.0) * 0.25
			var entry := start + lateral * offset
			var exit_point := finish + lateral * offset
			if not supported(entry, link.from_surface_id, radius) or not supported(exit_point, link.to_surface_id, radius):
				continue
			if not clear_around_combatants(entry, entry, actor, combatants) or not clear_around_combatants(exit_point, exit_point, actor, combatants):
				continue
			var first := ids.size()
			graph.add_point(first, entry)
			ids.append(link.from_surface_id)
			graph.add_point(first + 1, exit_point)
			ids.append(link.to_surface_id)
			entries.append(first)
			exits.append(first + 1)
		for entry_id in entries:
			for exit_id in exits:
				if clear_segment(graph.get_point_position(entry_id), graph.get_point_position(exit_id), link.transition_id, radius, ignored_door_key) and clear_around_combatants(graph.get_point_position(entry_id), graph.get_point_position(exit_id), actor, combatants):
					graph.connect_points(entry_id, exit_id, link.bidirectional)
	for i in range(2, ids.size()):
		for j in range(i + 1, ids.size()):
			if ids[i] == ids[j] and clear_segment(graph.get_point_position(i), graph.get_point_position(j), ids[i], radius, ignored_door_key) and clear_around_combatants(graph.get_point_position(i), graph.get_point_position(j), actor, combatants):
				graph.connect_points(i, j)
	if graph_cache.size() >= 32:
		graph_cache.clear()
	graph_cache[graph_key] = {"graph": graph, "ids": ids}
	return _query_graph(graph, ids, actor, goal, goal_id, radius, cache_key, ignored_door_key, combatants)

func _query_graph(graph: AStar3D, ids: Array[StringName], actor: CombatantState, goal: Vector3, goal_id: StringName, radius: float, key: String, ignored_door_key: String = "", combatants: Dictionary = {}) -> PackedVector3Array:
	graph.remove_point(0)
	graph.remove_point(1)
	graph.add_point(0, actor.world_position)
	graph.add_point(1, goal)
	ids[0] = actor.surface_id
	ids[1] = goal_id
	for index in [0, 1]:
		for other in range(2, ids.size()):
			if ids[index] == ids[other] and clear_segment(graph.get_point_position(index), graph.get_point_position(other), ids[index], radius, ignored_door_key) and clear_around_combatants(graph.get_point_position(index), graph.get_point_position(other), actor, combatants):
				graph.connect_points(index, other)
			for link in data.transitions:
				if ids[index] == link.transition_id and link.width_feet >= radius * 2.0:
					var entry := ramp_point(link, false)
					var exit_point := ramp_point(link, true)
					var endpoint := graph.get_point_position(other)
					var on_from_edge := ids[other] == link.from_surface_id and absf(endpoint.y - entry.y) < 0.05
					var on_to_edge := ids[other] == link.to_surface_id and absf(endpoint.y - exit_point.y) < 0.05
					if (on_from_edge or on_to_edge) and ramp_contains(endpoint, link, radius) and clear_segment(graph.get_point_position(index), endpoint, link.transition_id, radius, ignored_door_key) and clear_around_combatants(graph.get_point_position(index), endpoint, actor, combatants):
						graph.connect_points(index, other, link.bidirectional)
	var result := graph.get_point_path(0, 1)
	if combatants.is_empty():
		if path_cache.size() >= 256:
			path_cache.clear()
		path_cache[key] = result
	return result

static func length_of(points: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total

static func truncate(points: PackedVector3Array, budget: float) -> PackedVector3Array:
	if points.is_empty():
		return points
	var result := PackedVector3Array([points[0]])
	for i in range(1, points.size()):
		var distance := points[i - 1].distance_to(points[i])
		if distance > budget:
			result.append(points[i - 1].move_toward(points[i], budget))
			break
		result.append(points[i])
		budget -= distance
	return result
