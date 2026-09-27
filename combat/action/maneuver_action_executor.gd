class_name ManeuverActionExecutor
extends RefCounted

const GrabbedStatus = preload("res://data/status/grabbed.tres")
const GrabbingStatus = preload("res://data/status/grabbing.tres")
const ProneStatus = preload("res://data/status/prone.tres")

var combat_system


func _init(p_combat_system) -> void:
	combat_system = p_combat_system


func execute(actor_id: String, target_id: String, maneuver: ActionTypes.Maneuver) -> ActionResult:
	var validation := validate(actor_id, target_id, maneuver)
	if not validation.success:
		return validation
	var actor: CombatantState = combat_system.combat_state.get_combatant(actor_id)
	if maneuver == ActionTypes.Maneuver.STAND:
		actor.spend_ap(1)
		actor.remove_status("prone")
		return _finish(actor, actor, maneuver, true)
	var target: CombatantState = combat_system.combat_state.get_combatant(target_id)
	combat_system.cancel_remaining_movement(actor)
	actor.spend_ap(1)
	var roll: int = combat_system.dice_system.roll_3d8()
	var strength_modifier: int = actor.get_modifier(actor.strength)
	var total: int = roll + strength_modifier
	var defense: int = combat_system.defense_system.get_defense(target, DefenseTypes.Type.HIGHEST)
	if total < defense:
		return _finish(actor, target, maneuver, false, {"roll": roll, "strength_modifier": strength_modifier, "total": total, "defense": defense})
	match maneuver:
		ActionTypes.Maneuver.GRAB:
			var grabbed: EffectInstance = target.add_effect(GrabbedStatus, "", "", false, actor.id, actor.class_dc)
			grabbed.source_combatant_name = actor.display_name
			var grabbing: EffectInstance = actor.add_effect(GrabbingStatus, "", "", false, target.id)
			grabbing.source_combatant_name = target.display_name
		ActionTypes.Maneuver.TRIP:
			target.add_effect(ProneStatus, "", "", false, actor.id, actor.class_dc)
		ActionTypes.Maneuver.PUSH, ActionTypes.Maneuver.PULL:
			var movement_outcome := _apply_forced_movement(actor, target, maneuver)
			return _finish(actor, target, maneuver, true, {"roll": roll, "strength_modifier": strength_modifier, "total": total, "defense": defense}.merged(movement_outcome))
	return _finish(actor, target, maneuver, true, {"roll": roll, "strength_modifier": strength_modifier, "total": total, "defense": defense})


func validate(actor_id: String, target_id: String, maneuver: ActionTypes.Maneuver) -> ActionResult:
	if combat_system.combat_state == null or combat_system.combat_state.is_finished():
		return ActionResult.failure("Combat is not active.")
	if combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement():
		return ActionResult.failure("Resolve the pending action first.")
	var actor: CombatantState = combat_system.combat_state.get_combatant(actor_id)
	if actor == null or actor.id != combat_system.combat_state.current_actor_id:
		return ActionResult.failure("Actor is not the current actor.")
	if actor.is_dying():
		return ActionResult.failure("Actor is Dying.")
	if actor.ap < 1:
		return ActionResult.failure("Not enough AP.")
	if maneuver == ActionTypes.Maneuver.STAND:
		return ActionResult.success_result() if actor.has_status("prone") else ActionResult.failure("Actor is not Prone.")
	var target: CombatantState = combat_system.combat_state.get_combatant(target_id)
	if target == null or target.is_dying() or target.team == actor.team:
		return ActionResult.failure("Choose a living enemy target.")
	if not combat_system.map_rules.is_target_in_range(actor, target, _get_melee_range(actor)):
		return ActionResult.failure("Target is outside melee range.")
	if maneuver == ActionTypes.Maneuver.GRAB:
		if actor.has_status("grabbing"):
			return ActionResult.failure("Actor is already Grabbing a target.")
		if target.has_status("grabbed"):
			return ActionResult.failure("Target is already Grabbed.")
	if maneuver == ActionTypes.Maneuver.TRIP and target.has_status("prone"):
		return ActionResult.failure("Target is already Prone.")
	if maneuver in [ActionTypes.Maneuver.PUSH, ActionTypes.Maneuver.PULL, ActionTypes.Maneuver.TRIP] and _is_two_sizes_larger(target, actor):
		return ActionResult.failure("Target is at least two Size levels larger.")
	return ActionResult.success_result()


func _get_melee_range(actor: CombatantState) -> float:
	# Unarmed attacks use the standard 5 ft melee reach when their Resource has
	# no explicit range (AttackData defaults to 0 for non-ranged attacks).
	return maxf(5.0, actor.unarmed_attack.range_feet) if actor.unarmed_attack != null else 5.0


func _is_two_sizes_larger(target: CombatantState, actor: CombatantState) -> bool:
	# Every doubled collision radius is one Size level; four times is two levels.
	return target.collision_radius_feet + 0.001 >= actor.collision_radius_feet * 4.0


func _apply_forced_movement(actor: CombatantState, target: CombatantState, maneuver: ActionTypes.Maneuver) -> Dictionary:
	var requested_feet: float = maxf(5.0, float(actor.get_modifier(actor.strength)) * 2.0 + 5.0)
	if requested_feet <= 0.0:
		return {}
	var origin := target.position
	var direction := actor.position.direction_to(target.position)
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	if maneuver == ActionTypes.Maneuver.PULL:
		direction = -direction
		var touching_distance: float = combat_system.map_rules.get_combatant_radius_world_units(actor) + combat_system.map_rules.get_combatant_radius_world_units(target)
		requested_feet = minf(requested_feet, maxf(0.0, (actor.position.distance_to(target.position) - touching_distance) / combat_system.map_rules.world_units_per_foot))
	var destination := _furthest_valid_destination(target, direction, requested_feet)
	var moved_feet: float = origin.distance_to(destination) / combat_system.map_rules.world_units_per_foot
	if moved_feet > 0.001:
		target.position = destination
	var outcome := {"from": origin, "to": destination, "distance_feet": moved_feet, "requested_distance_feet": requested_feet}
	if maneuver == ActionTypes.Maneuver.PUSH:
		var fall: Dictionary = combat_system.map_rules.get_fall_at(target, destination)
		if not fall.is_empty():
			target.surface_id = fall.surface_id
			target.elevation_feet = fall.elevation_feet
			var fall_damage := maxi(1, roundi(float(fall.distance_feet) / 5.0))
			target.apply_damage(fall_damage)
			outcome["fall_distance_feet"] = fall.distance_feet
			outcome["fall_damage"] = fall_damage
		var collision_damage: int = floori(maxf(0.0, requested_feet - moved_feet) * 2.0)
		if collision_damage > 0:
			target.apply_damage(collision_damage)
			outcome["collision_damage"] = collision_damage
	return outcome


func _furthest_valid_destination(target: CombatantState, direction: Vector2, distance_feet: float) -> Vector2:
	var origin := target.position
	var maximum_world: float = distance_feet * combat_system.map_rules.world_units_per_foot
	var full_destination := origin + direction * maximum_world
	if combat_system.map_rules.validate_movement_path(target, full_destination, combat_system.combat_state.combatants).success:
		return full_destination
	var low := 0.0
	var high := maximum_world
	for _index in range(16):
		var middle := (low + high) * 0.5
		var candidate := origin + direction * middle
		if combat_system.map_rules.validate_movement_path(target, candidate, combat_system.combat_state.combatants).success:
			low = middle
		else:
			high = middle
	return origin + direction * low


func _finish(actor: CombatantState, target: CombatantState, maneuver: ActionTypes.Maneuver, succeeded: bool, details: Dictionary = {}) -> ActionResult:
	var result := ActionResult.success_result()
	details["maneuver"] = ActionTypes.Maneuver.keys()[maneuver].capitalize()
	details["succeeded"] = succeeded
	details["ap_cost"] = 1
	result.events.append(CombatEvent.new(EventTypes.Type.MANEUVER_USED, actor.id, target.id, details))
	if details.has("to") and details["from"] != details["to"]:
		result.events.append(CombatEvent.new(EventTypes.Type.POSITION_CHANGED, target.id, actor.id, details))
	if int(details.get("collision_damage", 0)) > 0:
		result.events.append(CombatEvent.new(EventTypes.Type.DAMAGE_APPLIED, actor.id, target.id, {"amount": details["collision_damage"], "damage_type": "blunt"}))
	if int(details.get("fall_damage", 0)) > 0:
		result.events.append(CombatEvent.new(EventTypes.Type.DAMAGE_APPLIED, actor.id, target.id, {"amount": details["fall_damage"], "damage_type": "fall"}))
	combat_system.emit_events(result.events)
	refresh_grabs()
	combat_system.check_for_combat_end()
	return result


func refresh_grabs() -> void:
	if combat_system.combat_state == null:
		return
	for target in combat_system.combat_state.combatants.values():
		if not target.has_status("grabbed"):
			continue
		var holder := _get_grab_holder(target)
		if holder == null or holder.is_dying() or holder.has_status("prone") or _get_held_target(holder) != target or not combat_system.map_rules.is_target_in_range(holder, target, _get_melee_range(holder)):
			target.remove_status("grabbed")
			if holder != null:
				holder.remove_status("grabbing")
	for holder in combat_system.combat_state.combatants.values():
		if holder.has_status("grabbing"):
			var held_target := _get_held_target(holder)
			if held_target == null or not held_target.has_status("grabbed") or _get_grab_holder(held_target) != holder:
				holder.remove_status("grabbing")


func _get_grab_holder(target: CombatantState) -> CombatantState:
	for instance in target.effects:
		if instance != null and instance.data != null and instance.data.id == "grabbed":
			return combat_system.combat_state.get_combatant(instance.source_combatant_id)
	return null


func _get_held_target(holder: CombatantState) -> CombatantState:
	for instance in holder.effects:
		if instance != null and instance.data != null and instance.data.id == "grabbing":
			return combat_system.combat_state.get_combatant(instance.source_combatant_id)
	return null
