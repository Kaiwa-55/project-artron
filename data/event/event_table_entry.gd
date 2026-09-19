class_name EventTableEntry
extends Resource

@export var id: StringName
@export var event: EventData
@export_range(0.0, 1000000.0, 0.1, "or_greater") var weight: float = 1.0
@export var conditions: Array[EventCondition] = []
@export var remove_after_victory: bool = false


func get_id() -> String:
	if not String(id).is_empty():
		return String(id)
	return String(event.id) if event != null else ""


func is_available(context: EventContext) -> bool:
	if context == null:
		return false
	return conditions.all(func(condition): return condition != null and condition.is_met(context))
