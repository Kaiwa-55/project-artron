class_name EventSystem
extends RefCounted


var event_history: Array[CombatEvent] = []


func emit(
	event: CombatEvent
) -> void:
	if event == null:
		return

	event_history.append(event)


func clear() -> void:
	event_history.clear()


func get_history() -> Array[CombatEvent]:
	return event_history.duplicate()
