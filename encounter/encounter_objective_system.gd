class_name EncounterObjectiveSystem
extends RefCounted

signal objective_updated(objective: EncounterObjective, completed: bool)
signal all_required_completed

var combat_system: CombatSystem
var objectives: Array[EncounterObjective] = []
var completed_by_id: Dictionary = {}
var resolved: bool = false


func setup(system: CombatSystem, configured_objectives: Array) -> void:
	disconnect_combat_events()
	combat_system = system
	objectives.assign(configured_objectives)
	completed_by_id.clear()
	resolved = false
	for index in range(objectives.size()):
		var objective := objectives[index]
		if objective != null:
			completed_by_id[_get_key(objective, index)] = false
	if combat_system != null and not combat_system.event_system.event_emitted.is_connected(_on_combat_event):
		combat_system.event_system.event_emitted.connect(_on_combat_event)
	evaluate()


func disconnect_combat_events() -> void:
	if combat_system != null and combat_system.event_system.event_emitted.is_connected(_on_combat_event):
		combat_system.event_system.event_emitted.disconnect(_on_combat_event)


func evaluate() -> void:
	if resolved or combat_system == null or combat_system.combat_state == null or objectives.is_empty():
		return
	for index in range(objectives.size()):
		var objective := objectives[index]
		if objective == null:
			continue
		var key := _get_key(objective, index)
		if bool(completed_by_id.get(key, false)):
			continue
		if _is_completed(objective):
			completed_by_id[key] = true
			objective_updated.emit(objective, true)
	if _all_required_objectives_completed():
		resolved = true
		all_required_completed.emit()


func get_states() -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for index in range(objectives.size()):
		var objective := objectives[index]
		if objective == null:
			continue
		states.append({
			"objective": objective,
			"id": _get_key(objective, index),
			"text": objective.get_display_text(),
			"required": objective.required,
			"completed": bool(completed_by_id.get(_get_key(objective, index), false)),
		})
	return states


func _is_completed(objective: EncounterObjective) -> bool:
	var state := combat_system.combat_state
	match objective.type:
		EncounterObjective.Type.DEFEAT_ALL:
			return not state.combatants.values().any(func(member): return member != null and member.team == objective.target_team and not member.is_dying())
		EncounterObjective.Type.DEFEAT_TARGET:
			var target: CombatantState = state.get_combatant(objective.target_id)
			return target != null and target.is_dying()
		EncounterObjective.Type.SURVIVE_TURNS:
			return state.current_round > objective.turn_count
		EncounterObjective.Type.REACH_AREA:
			return _has_reached_area(objective)
	return false


func _has_reached_area(objective: EncounterObjective) -> bool:
	var world_units_per_foot: float = combat_system.map_rules.world_units_per_foot
	var center := objective.area_center_feet * world_units_per_foot
	var radius := objective.area_radius_feet * world_units_per_foot
	for member in combat_system.combat_state.combatants.values():
		if member == null or member.is_dying():
			continue
		if not objective.actor_id.is_empty() and member.id != objective.actor_id:
			continue
		if objective.actor_id.is_empty() and member.team != objective.actor_team:
			continue
		if member.position.distance_to(center) <= radius:
			return true
	return false


func _all_required_objectives_completed() -> bool:
	var has_required := false
	for index in range(objectives.size()):
		var objective := objectives[index]
		if objective == null or not objective.required:
			continue
		has_required = true
		if not bool(completed_by_id.get(_get_key(objective, index), false)):
			return false
	return has_required


func _get_key(objective: EncounterObjective, index: int) -> String:
	return String(objective.id) if not String(objective.id).is_empty() else "objective_%d" % index


func _on_combat_event(event: CombatEvent) -> void:
	if event == null or event.type in [EventTypes.Type.COMBAT_VICTORY, EventTypes.Type.COMBAT_DEFEAT]:
		return
	evaluate()
