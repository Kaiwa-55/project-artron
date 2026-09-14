class_name GameState
extends Resource

@export var flags: Dictionary = {}
@export var reputation: Dictionary = {}
@export var quest_state: Dictionary = {}
@export var chapter: int = 1
@export var world_state: Dictionary = {}
@export var resources: Dictionary = {}
@export var completed_event_ids: Array[String] = []


func get_flag(key: StringName, default_value: Variant = false) -> Variant:
	return flags.get(String(key), default_value)


func set_flag(key: StringName, value: Variant) -> void:
	flags[String(key)] = value


func modify_reputation(faction_id: StringName, amount: int) -> int:
	var key := String(faction_id)
	var updated := int(reputation.get(key, 0)) + amount
	reputation[key] = updated
	return updated


func modify_resource(resource_id: StringName, amount: int) -> int:
	var key := String(resource_id)
	var updated := int(resources.get(key, 0)) + amount
	resources[key] = updated
	return updated


func mark_event_completed(event_id: StringName) -> void:
	var key := String(event_id)
	if not key.is_empty() and not completed_event_ids.has(key):
		completed_event_ids.append(key)


func has_completed_event(event_id: StringName) -> bool:
	return completed_event_ids.has(String(event_id))
