class_name TargetingSystem
extends RefCounted

const SkillDataScript = preload("res://data/skill/skill_data.gd")

func validate_target_point(actor: CombatantState, point: Vector2, skill, map_rules) -> ActionResult:
	if actor == null or skill == null:
		return ActionResult.failure("Targeting data is missing.")
	var range_feet: float = skill.targeting_range_feet
	if range_feet <= 0.0 and skill.attack_data != null:
		range_feet = skill.attack_data.range_feet
	var distance_feet: float = actor.position.distance_to(point) / map_rules.world_units_per_foot
	if distance_feet > range_feet:
		return ActionResult.failure("Target point is out of range.")
	if skill.requires_line_of_sight and not map_rules.has_line_of_sight(actor.position, point):
		return ActionResult.failure("Target point is blocked by an obstacle.")
	return ActionResult.success_result()

func collect_targets(actor: CombatantState, point: Vector2, skill, combat_state: CombatState, map_rules) -> Array[CombatantState]:
	var targets: Array[CombatantState] = []
	if actor == null or skill == null:
		return targets
	for candidate in combat_state.combatants.values():
		if candidate == null or candidate.is_dying() or not target_filter_matches(actor, candidate, skill.target_filter):
			continue
		if candidate == actor and not skill.include_caster:
			continue
		if is_inside_area(actor, candidate, point, skill, map_rules):
			if skill.area_blocked_by_obstacles and not map_rules.has_line_of_sight(get_area_origin(actor, point, skill), candidate.position):
				continue
			targets.append(candidate)
	if skill.include_caster and not actor.is_dying() and target_filter_matches(actor, actor, skill.target_filter) \
		and is_inside_area(actor, actor, point, skill, map_rules) and not targets.has(actor):
		if not skill.area_blocked_by_obstacles or map_rules.has_line_of_sight(get_area_origin(actor, point, skill), actor.position):
			targets.append(actor)
	targets.sort_custom(func(first, second): return combat_state.turn_order.find(first.id) < combat_state.turn_order.find(second.id))
	return targets

func get_targeting_preview(actor: CombatantState, point: Vector2, skill, combat_state: CombatState, map_rules) -> Dictionary:
	var validation := validate_target_point(actor, point, skill, map_rules)
	return {
		"valid": validation.success,
		"failure_reason": validation.failure_reason,
		"targets": collect_targets(actor, point, skill, combat_state, map_rules) if validation.success else [],
		"origin": get_area_origin(actor, point, skill),
		"point": point,
		"area_shape": skill.area_shape,
		"range_feet": skill.targeting_range_feet,
		"radius_feet": skill.area_radius_feet,
		"line_length_feet": skill.line_length_feet,
		"line_width_feet": skill.line_width_feet,
		"cone_angle_degrees": skill.cone_angle_degrees,
	}

func get_area_origin(actor: CombatantState, point: Vector2, skill) -> Vector2:
	return actor.position if skill.area_shape == SkillDataScript.AreaShape.LINE or skill.area_shape == SkillDataScript.AreaShape.CONE else point

func target_filter_matches(actor: CombatantState, candidate: CombatantState, filter: int) -> bool:
	match filter:
		SkillDataScript.TargetFilter.ENEMIES:
			return candidate.team != actor.team
		SkillDataScript.TargetFilter.ALLIES:
			return candidate.team == actor.team
	return true

func is_inside_area(actor: CombatantState, candidate: CombatantState, point: Vector2, skill, map_rules) -> bool:
	var candidate_radius: float = map_rules.get_combatant_radius_world_units(candidate)
	match skill.area_shape:
		SkillDataScript.AreaShape.CIRCLE:
			return candidate.position.distance_to(point) <= skill.area_radius_feet * map_rules.world_units_per_foot + candidate_radius
		SkillDataScript.AreaShape.LINE:
			var maximum_length: float = skill.line_length_feet * map_rules.world_units_per_foot
			var finish := actor.position + actor.position.direction_to(point) * maximum_length
			var projection: float = (candidate.position - actor.position).dot(actor.position.direction_to(point))
			return projection >= -candidate_radius and projection <= maximum_length + candidate_radius and map_rules.segment_distance_to_point(actor.position, finish, candidate.position) <= skill.line_width_feet * 0.5 * map_rules.world_units_per_foot + candidate_radius
		SkillDataScript.AreaShape.CONE:
			var maximum_range: float = skill.targeting_range_feet * map_rules.world_units_per_foot
			var offset := candidate.position - actor.position
			if offset.length() > maximum_range + candidate_radius:
				return false
			if offset.is_zero_approx():
				return skill.include_caster
			var direction := actor.position.direction_to(point)
			var center_angle: float = absf(rad_to_deg(direction.angle_to(offset.normalized())))
			var angular_padding: float = rad_to_deg(asin(minf(1.0, candidate_radius / maxf(candidate_radius, offset.length()))))
			return center_angle <= skill.cone_angle_degrees * 0.5 + angular_padding
		_:
			return candidate.position.distance_to(point) <= candidate_radius
