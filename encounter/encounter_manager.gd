class_name EncounterManager
extends Node

signal encounter_started(data: EncounterData)
signal combat_requested(data: EncounterData)
signal encounter_finished(result: EncounterResult)
signal event_requested(data: EventData)

var active_encounter: EncounterData
var context: EventContext
var combat_system: CombatSystem


func start_encounter(data: EncounterData, event_context: EventContext) -> bool:
	if data == null or active_encounter != null:
		return false
	active_encounter = data
	context = event_context
	encounter_started.emit(data)
	combat_requested.emit(data)
	return true


func resume_encounter(data: EncounterData, event_context: EventContext) -> bool:
	if data == null or active_encounter != null:
		return false
	active_encounter = data
	context = event_context
	return true


func bind_combat_system(system: CombatSystem) -> void:
	if combat_system != null and combat_system.event_system.event_emitted.is_connected(_on_combat_event):
		combat_system.event_system.event_emitted.disconnect(_on_combat_event)
	combat_system = system
	if combat_system != null and not combat_system.event_system.event_emitted.is_connected(_on_combat_event):
		combat_system.event_system.event_emitted.connect(_on_combat_event)
	if context != null:
		context.combat_system = system


func finish_encounter(result: EncounterResult) -> bool:
	if active_encounter == null or result == null:
		return false
	var completed := active_encounter
	if result.type in [EncounterResult.Type.VICTORY, EncounterResult.Type.PARTIAL_VICTORY]:
		for effect in completed.rewards:
			if effect is EventEffect:
				effect.apply(context)
	var result_event := _get_result_event(completed, result.type)
	active_encounter = null
	encounter_finished.emit(result)
	if result_event is EventData:
		event_requested.emit(result_event)
	return true


func _get_result_event(data: EncounterData, result_type: EncounterResult.Type) -> Resource:
	match result_type:
		EncounterResult.Type.VICTORY:
			return data.victory_event
		EncounterResult.Type.PARTIAL_VICTORY:
			return data.partial_victory_event if data.partial_victory_event != null else data.victory_event
		EncounterResult.Type.DEFEAT:
			return data.defeat_event
		EncounterResult.Type.ESCAPE:
			return data.escape_event
	return null


func _on_combat_event(event: CombatEvent) -> void:
	if active_encounter == null or event == null:
		return
	match event.type:
		EventTypes.Type.COMBAT_VICTORY:
			finish_encounter(EncounterResult.new(EncounterResult.Type.VICTORY, event.data))
		EventTypes.Type.COMBAT_DEFEAT:
			finish_encounter(EncounterResult.new(EncounterResult.Type.DEFEAT, event.data))
