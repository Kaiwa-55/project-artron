class_name EventSystem
extends RefCounted

signal event_emitted(event: CombatEvent)


var event_history: Array[CombatEvent] = []


func emit(
	event: CombatEvent
) -> void:
	if event == null:
		return

	event_history.append(event)
	event_emitted.emit(event)


func clear() -> void:
	event_history.clear()


func get_history() -> Array[CombatEvent]:
	return event_history.duplicate()
