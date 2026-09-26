class_name MapRules
extends RefCounted

const VisionSystemScript = preload("res://combat/vision/vision_system.gd")
const VisibilityQuery = preload("res://combat/vision/visibility_query_3d.gd")
var visibility_query = VisibilityQuery.new()

# Gridless map scale. Positions, collision radii, and obstacles use world units.
var world_units_per_foot: float = 12.0
var obstacles: Array[Dictionary] = []
var playable_bounds: Rect2 = Rect2()
# 0 bright, 1 normal, 2 dim, 3 darkness. Effects may lower this value.
var light_level: int = 1
var light_areas: Array[Dictionary] = []
var temporary_light_areas: Array[Dictionary] = []
var next_temporary_light_area_id := 1
var light_points: Array[Dictionary] = []
var light_emitters: Array[CombatantState] = []
var building_map: BuildingMapData
var spatial_navigation
var spatial_world: Node3D
var door_revision := 0
var door_states: Dictionary = {}

func door_key(surface_id: StringName, door_id: StringName) -> String:
	return "%s/%s" % [surface_id, door_id]

func get_door(surface_id: StringName, door_id: StringName) -> BuildingDoorData:
	if building_map == null:
		return null
	var surface := building_map.get_surface(surface_id)
	if surface == null:
		return null
	for door in surface.doors:
		if door != null and door.door_id == door_id:
			return door
	return null

func door_is_open(surface_id: StringName, door_id: StringName) -> bool:
	return bool(door_states.get(door_key(surface_id, door_id), false))

func set_door_open(surface_id: StringName, door_id: StringName, opened: bool) -> bool:
	if get_door(surface_id, door_id) == null:
		return false
	var key := door_key(surface_id, door_id)
	if door_is_open(surface_id, door_id) == opened:
		return true
	door_states[key] = opened
	for index in range(obstacles.size()):
		if String(obstacles[index].get("door_key", "")) != key:
			continue
		obstacles[index]["blocks_movement"] = not opened
		obstacles[index]["blocks_line_of_sight"] = not opened
		break
	door_revision += 1
	if spatial_navigation != null:
		spatial_navigation.graph_cache.clear()
		spatial_navigation.path_cache.clear()
	if is_instance_valid(spatial_world) and spatial_world.has_method("set_door_open"):
		spatial_world.set_door_open(surface_id, door_id, opened)
	return true


func set_light_level(level: int) -> void:
	light_level = clampi(level, 0, 3)


func add_light_area(area: Rect2, level: int, label: String = "Light Area") -> void:
	light_areas.append({"area": area, "level": clampi(level, 0, 3), "label": label})


func add_temporary_light_area(center: Vector2, radius_feet: float, penalty: int, expires_round: int, surface_id: StringName = &"") -> void:
	temporary_light_areas.append({"id": next_temporary_light_area_id, "center": center, "radius": radius_feet * world_units_per_foot, "penalty": penalty, "expires_round": expires_round, "surface_id": surface_id})
	next_temporary_light_area_id += 1


func expire_temporary_light_areas(current_round: int) -> void:
	for index in range(temporary_light_areas.size() - 1, -1, -1):
		if int(temporary_light_areas[index].get("expires_round", 0)) <= current_round:
			temporary_light_areas.remove_at(index)


func get_light_level_at(position: Vector2, surface_id: StringName = &"") -> int:
	var base_level := light_level
	for index in range(light_points.size() - 1, -1, -1):
		var authored: Dictionary = light_points[index]
		if not authored.has("rect") or (surface_id != &"" and authored.get("surface_id", &"ground") != surface_id):
			continue
		if Rect2(authored.rect).has_point(position):
			base_level = int(authored.get("level", light_level))
			return apply_temporary_light_penalty(base_level, position, surface_id)
	var nearest_distance := INF
	var point_level := -1
	for point in light_points:
		if point.has("rect"):
			continue
		if surface_id != &"" and point.get("surface_id", &"ground") != surface_id:
			continue
		var distance := position.distance_to(point.get("position", Vector2.ZERO))
		if distance <= float(point.get("radius", 0.0)) and distance < nearest_distance:
			nearest_distance = distance
			point_level = int(point.get("level", light_level))
	if point_level >= 0:
		return apply_temporary_light_penalty(point_level, position, surface_id)
	for area in light_areas:
		if Rect2(area.get("area", Rect2())).has_point(position):
			base_level = int(area.get("level", light_level))
			break
	return apply_temporary_light_penalty(base_level, position, surface_id)


func apply_temporary_light_penalty(base_level: int, position: Vector2, surface_id: StringName) -> int:
	var penalty := 0
	for area in temporary_light_areas:
		if surface_id != &"" and area.get("surface_id", &"") != surface_id:
			continue
		if position.distance_to(area.center) <= float(area.radius):
			penalty = maxi(penalty, int(area.penalty))
	var brightness := 0
	for emitter in light_emitters:
		if emitter == null or emitter.is_dying() or (surface_id != &"" and emitter.surface_id != surface_id):
			continue
		for item in emitter.equipped_items.values():
			if item != null and item.light_level_bonus > 0 and item.light_radius_feet > 0.0 and emitter.position.distance_to(position) <= item.light_radius_feet * world_units_per_foot:
				brightness = maxi(brightness, item.light_level_bonus)
	return clampi(base_level + penalty - brightness, 0, 3)


func set_playable_bounds(size_feet: Vector2, origin: Vector2 = Vector2.ZERO) -> void:
	playable_bounds = Rect2(origin, Vector2(
		maxf(0.0, size_feet.x) * world_units_per_foot,
		maxf(0.0, size_feet.y) * world_units_per_foot
	))


func has_playable_bounds() -> bool:
	return playable_bounds.size.x > 0.0 and playable_bounds.size.y > 0.0


func add_circular_obstacle(center: Vector2, radius_world_units: float, label: String = "Obstacle", blocks_movement: bool = true, blocks_line_of_sight: bool = true) -> void:
	obstacles.append({
		"center": center,
		"radius": maxf(0.0, radius_world_units),
		"label": label,
		"blocks_movement": blocks_movement,
		"blocks_line_of_sight": blocks_line_of_sight,
	})


func add_rectangular_obstacle(rect: Rect2, label: String = "Wall", blocks_movement: bool = true, blocks_line_of_sight: bool = true, surface_id: StringName = &"", elevation_feet: float = 0.0, height_feet: float = 1000.0) -> void:
	obstacles.append({
		"shape": "rect",
		"rect": rect,
		"label": label,
		"blocks_movement": blocks_movement,
		"blocks_line_of_sight": blocks_line_of_sight,
		"surface_id": surface_id,
		"elevation_feet": elevation_feet,
		"height_feet": height_feet,
	})


func add_segment_obstacle(start: Vector2, finish: Vector2, half_width: float, label: String, surface_id: StringName, elevation_feet: float, height_feet: float) -> void:
	obstacles.append({
		"shape": "segment",
		"from": start,
		"to": finish,
		"radius": maxf(0.0, half_width),
		"label": label,
		"blocks_movement": true,
		"blocks_line_of_sight": true,
		"surface_id": surface_id,
		"elevation_feet": elevation_feet,
		"height_feet": height_feet,
	})


func clear_obstacles() -> void:
	obstacles.clear()


func configure_building_map(source: BuildingMapData) -> void:
	building_map = source
	light_points.clear()
	door_states.clear()
	door_revision = 0
	spatial_navigation = preload("res://combat/map/spatial_navigation.gd").new(source, self) if source != null else null
	clear_obstacles()
	if source == null:
		return
	world_units_per_foot = source.pixels_per_foot
	for point in source.light_points:
		if point.has("rect"):
			var map_rect: Rect2 = point.rect
			light_points.append({"surface_id": point.get("surface_id", &"ground"), "rect": Rect2(source.map_to_logic(map_rect.position), map_rect.size), "level": clampi(int(point.get("level", 1)), 0, 3)})
		else:
			light_points.append({
				"surface_id": point.get("surface_id", &"ground"),
				"position": source.map_to_logic(point.get("position", Vector2.ZERO)),
				"radius": maxf(0.0, float(point.get("radius_feet", 0.0))) * source.pixels_per_foot,
				"level": clampi(int(point.get("level", 1)), 0, 3),
			})
	set_playable_bounds(source.source_size / source.pixels_per_foot, -source.source_size * 0.5)
	for surface in source.surfaces:
		if surface == null:
			continue
		for wall in surface.wall_solid_entries():
			var wall_rect: Rect2 = wall.rect
			var logic_rect := Rect2(source.map_to_logic(wall_rect.position), wall_rect.size)
			add_rectangular_obstacle(logic_rect, "%s wall" % surface.display_name, true, true, surface.surface_id, surface.elevation_feet, float(wall.height_feet))
		for wall in surface.wall_solid_segments(source.pixels_per_foot):
			add_segment_obstacle(source.map_to_logic(wall.from), source.map_to_logic(wall.to), float(wall.width_feet) * source.pixels_per_foot * 0.5, "%s wall" % surface.display_name, surface.surface_id, surface.elevation_feet, float(wall.height_feet))
		for railing in surface.railing_rects:
			var logic_railing := Rect2(source.map_to_logic(railing.position), railing.size)
			add_rectangular_obstacle(logic_railing, "%s railing" % surface.display_name, true, true, surface.surface_id, surface.elevation_feet, 3.0)
		for invisible_wall in surface.invisible_wall_rects:
			var logic_blocker := Rect2(source.map_to_logic(invisible_wall.position), invisible_wall.size)
			add_rectangular_obstacle(logic_blocker, "%s invisible wall" % surface.display_name, true, false, surface.surface_id, surface.elevation_feet, 9.0)
		for object in surface.objects:
			if object == null or not object.collision_enabled or (not object.blocks_movement and not object.blocks_line_of_sight):
				continue
			var logic_object := Rect2(source.map_to_logic(object.rect.position), object.rect.size)
			add_rectangular_obstacle(logic_object, object.display_name, object.blocks_movement, object.blocks_line_of_sight, surface.surface_id, surface.elevation_feet, object.height_feet)
		for door in surface.doors:
			if door == null:
				continue
			var key := door_key(surface.surface_id, door.door_id)
			door_states[key] = door.starts_open
			var logic_door := Rect2(source.map_to_logic(door.rect.position), door.rect.size)
			add_rectangular_obstacle(logic_door, "%s door" % surface.display_name, not door.starts_open, not door.starts_open, surface.surface_id, surface.elevation_feet, door.height_feet)
			obstacles[-1]["door_key"] = key


func get_attack_range_world_units(range_feet: float) -> float:
	return maxf(0.0, range_feet) * world_units_per_foot


func get_combatant_radius_world_units(combatant) -> float:
	return maxf(0.0, combatant.collision_radius_feet) * world_units_per_foot


func get_targeting_preview_radius_world_units(attacker, range_feet: float) -> float:
	# A target is in reach when its body touches this circle, not its center.
	return get_combatant_radius_world_units(attacker) + get_attack_range_world_units(range_feet)


func get_edge_distance_world_units(first, second) -> float:
	var horizontal_feet: float = first.position.distance_to(second.position) / world_units_per_foot
	var vertical_feet: float = absf(float(first.elevation_feet) - float(second.elevation_feet))
	var center_distance: float = Vector2(horizontal_feet, vertical_feet).length() * world_units_per_foot
	var combined_radii: float = get_combatant_radius_world_units(first) + get_combatant_radius_world_units(second)
	return maxf(0.0, center_distance - combined_radii)


func is_target_in_range(attacker, target, range_feet: float) -> bool:
	return get_edge_distance_world_units(attacker, target) <= get_attack_range_world_units(range_feet)


func has_line_of_sight(start: Vector2, finish: Vector2) -> bool:
	for obstacle in obstacles:
		if not bool(obstacle.get("blocks_line_of_sight", true)):
			continue
		if String(obstacle.get("shape", "circle")) == "rect":
			if segment_intersects_rect(start, finish, Rect2(obstacle.get("rect", Rect2()))):
				return false
			continue
		if String(obstacle.get("shape", "circle")) == "segment":
			if segment_segment_proximity(start, finish, obstacle.from, obstacle.to).distance <= float(obstacle.radius):
				return false
			continue
		var center: Vector2 = obstacle.get("center", Vector2.ZERO)
		var radius: float = float(obstacle.get("radius", 0.0))
		if segment_distance_to_point(start, finish, center) < radius:
			return false
	return true


func get_visibility(observer, target) -> Dictionary:
	var spatial: Dictionary = {}
	var has_los: bool
	if is_instance_valid(spatial_world):
		spatial = visibility_query.query(spatial_world, observer, target)
		has_los = spatial.state != "HIDDEN"
	else:
		has_los = has_line_of_sight_between(observer, target)
	var result := VisionSystemScript.get_visibility_result(
		observer,
		target,
		get_light_level_at(target.position, target.surface_id),
		has_los
	)
	if not spatial.is_empty():
		result["spatial"] = spatial
		result["cover"] = spatial.cover
		if spatial.state == "PARTIAL" and not result.not_visible:
			result.visibility = VisionSystemScript.Visibility.PARTIALLY_VISIBLE
			result.visible = false
			result.partially_visible = true
			result.attack_penalty = VisionSystemScript.PARTIAL_ATTACK_PENALTY
	return result


func has_line_of_sight_between(observer, target) -> bool:
	if is_instance_valid(spatial_world):
		return visibility_query.query(spatial_world, observer, target).state != "HIDDEN"
	if building_map == null:
		return has_line_of_sight(observer.position, target.position)
	for obstacle in obstacles:
		if not bool(obstacle.get("blocks_line_of_sight", true)):
			continue
		var hit_progress := -1.0
		if String(obstacle.get("shape", "circle")) == "rect":
			hit_progress = segment_rect_hit_progress(observer.position, target.position, Rect2(obstacle.get("rect", Rect2())))
		elif String(obstacle.get("shape", "circle")) == "segment":
			var proximity := segment_segment_proximity(observer.position, target.position, obstacle.from, obstacle.to)
			if float(proximity.distance) <= float(obstacle.radius):
				hit_progress = float(proximity.progress)
		else:
			continue
		if hit_progress < 0.0:
			continue
		var ray_height := lerpf(float(observer.elevation_feet) + 5.0, float(target.elevation_feet) + 5.0, hit_progress)
		var bottom := float(obstacle.get("elevation_feet", 0.0))
		var top := bottom + float(obstacle.get("height_feet", 1000.0))
		if ray_height >= bottom and ray_height <= top:
			return false
	return true

func has_spatial_line_of_effect(from: Vector3, to: Vector3) -> bool:
	if is_instance_valid(spatial_world):
		return visibility_query.is_segment_clear(spatial_world, from, to)
	return has_line_of_sight(Vector2(from.x, from.z) * world_units_per_foot, Vector2(to.x, to.z) * world_units_per_foot)


func segment_rect_hit_progress(start: Vector2, finish: Vector2, rect: Rect2) -> float:
	var direction := finish - start
	var entry := 0.0
	var exit_time := 1.0
	for axis in range(2):
		if absf(direction[axis]) < 0.000001:
			if start[axis] < rect.position[axis] or start[axis] > rect.end[axis]:
				return -1.0
		else:
			var first := (rect.position[axis] - start[axis]) / direction[axis]
			var last := (rect.end[axis] - start[axis]) / direction[axis]
			entry = maxf(entry, minf(first, last))
			exit_time = minf(exit_time, maxf(first, last))
			if entry > exit_time:
				return -1.0
	return entry


func validate_movement_path(actor, destination: Vector2, combatants: Dictionary) -> ActionResult:
	if has_playable_bounds():
		var actor_radius := get_combatant_radius_world_units(actor)
		var safe_bounds := playable_bounds.grow(-actor_radius)
		if safe_bounds.size.x <= 0.0 or safe_bounds.size.y <= 0.0 or not safe_bounds.has_point(destination):
			return ActionResult.failure("Destination is outside the playable map.")
	for other in combatants.values():
		if other == actor or other.surface_id != actor.surface_id:
			continue
		var start_world := Vector3(actor.position.x / world_units_per_foot, actor.elevation_feet, actor.position.y / world_units_per_foot)
		var end_world := Vector3(destination.x / world_units_per_foot, actor.elevation_feet, destination.y / world_units_per_foot)
		if movement_segment_blocked_by_combatant(start_world, end_world, actor, other):
			return ActionResult.failure("Movement path is blocked by %s." % other.display_name)

	for obstacle in obstacles:
		if not bool(obstacle.get("blocks_movement", true)):
			continue
		var obstacle_surface := StringName(obstacle.get("surface_id", &""))
		if not obstacle_surface.is_empty() and obstacle_surface != actor.surface_id:
			continue
		if String(obstacle.get("shape", "circle")) == "rect":
			var wall: Rect2 = Rect2(obstacle.get("rect", Rect2())).grow(get_combatant_radius_world_units(actor))
			if segment_intersects_rect(actor.position, destination, wall):
				return ActionResult.failure("Movement path is blocked by %s." % obstacle.get("label", "a wall"))
			continue
		if String(obstacle.get("shape", "circle")) == "segment":
			if segment_segment_proximity(actor.position, destination, obstacle.from, obstacle.to).distance < get_combatant_radius_world_units(actor) + float(obstacle.radius):
				return ActionResult.failure("Movement path is blocked by %s." % obstacle.get("label", "a wall"))
			continue
		var obstacle_center: Vector2 = obstacle.get("center", Vector2.ZERO)
		var obstacle_radius: float = float(obstacle.get("radius", 0.0))
		if segment_distance_to_point(actor.position, destination, obstacle_center) < get_combatant_radius_world_units(actor) + obstacle_radius:
			return ActionResult.failure("Movement path is blocked by %s." % obstacle.get("label", "an obstacle"))

	return ActionResult.success_result()


func movement_segment_blocked_by_combatant(start_world: Vector3, end_world: Vector3, actor, other) -> bool:
	var minimum_distance: float = actor.collision_radius_feet + other.collision_radius_feet + 0.5
	var initial_distance: float = start_world.distance_to(other.world_position)
	var movement: Vector3 = end_world - start_world
	# A character already touching another may step away from that overlap.
	# The destination and the whole segment must move strictly farther away.
	if initial_distance < minimum_distance and end_world.distance_to(other.world_position) > initial_distance + 0.001 and movement.dot(other.world_position - start_world) <= 0.001:
		return false
	var nearest := Geometry3D.get_closest_point_to_segment(other.world_position, start_world, end_world)
	return nearest.distance_to(other.world_position) < minimum_distance - 0.001


func get_fall_at(actor, destination: Vector2) -> Dictionary:
	if building_map == null:
		return {}
	var current := building_map.get_surface(actor.surface_id)
	if current == null:
		return {}
	var map_point := building_map.logic_to_map(destination)
	if current.walkable_rects.any(func(rect: Rect2): return rect.has_point(map_point)):
		return {}
	var landing: BuildingSurfaceData
	for surface in building_map.surfaces:
		if surface == null or surface.elevation_feet >= current.elevation_feet:
			continue
		if not surface.walkable_rects.any(func(rect: Rect2): return rect.has_point(map_point)):
			continue
		if landing == null or surface.elevation_feet > landing.elevation_feet:
			landing = surface
	if landing == null:
		return {}
	return {
		"surface_id": landing.surface_id,
		"elevation_feet": landing.elevation_feet,
		"distance_feet": current.elevation_feet - landing.elevation_feet,
	}


func segment_distance_to_point(start: Vector2, finish: Vector2, point: Vector2) -> float:
	var segment := finish - start
	var segment_length_squared := segment.length_squared()
	if is_zero_approx(segment_length_squared):
		return start.distance_to(point)
	var progress := clampf((point - start).dot(segment) / segment_length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * progress)


func segment_segment_proximity(start: Vector2, finish: Vector2, other_start: Vector2, other_finish: Vector2) -> Dictionary:
	var direction := finish - start
	var other_direction := other_finish - other_start
	var cross := direction.cross(other_direction)
	if absf(cross) > 0.000001:
		var difference := other_start - start
		var progress := difference.cross(other_direction) / cross
		var other_progress := difference.cross(direction) / cross
		if progress >= 0.0 and progress <= 1.0 and other_progress >= 0.0 and other_progress <= 1.0:
			return {"distance": 0.0, "progress": progress}
	var nearest_distance := INF
	var nearest_progress := 0.0
	for point in [other_start, other_finish]:
		var progress: float = clampf((point - start).dot(direction) / maxf(direction.length_squared(), 0.000001), 0.0, 1.0)
		var distance: float = point.distance_to(start + direction * progress)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_progress = progress
	for progress in [0.0, 1.0]:
		var point: Vector2 = start + direction * progress
		var distance: float = segment_distance_to_point(other_start, other_finish, point)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_progress = progress
	return {"distance": nearest_distance, "progress": nearest_progress}


func segment_intersects_rect(start: Vector2, finish: Vector2, rect: Rect2) -> bool:
	var direction := finish - start
	var entry := 0.0
	var exit_time := 1.0
	for axis in range(2):
		if absf(direction[axis]) < 0.000001:
			if start[axis] < rect.position[axis] or start[axis] > rect.end[axis]:
				return false
		else:
			var first := (rect.position[axis] - start[axis]) / direction[axis]
			var last := (rect.end[axis] - start[axis]) / direction[axis]
			entry = maxf(entry, minf(first, last))
			exit_time = minf(exit_time, maxf(first, last))
			if entry > exit_time:
				return false
	return true
