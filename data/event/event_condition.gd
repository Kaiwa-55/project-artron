class_name EventCondition
extends Resource

enum Type {
	ATTRIBUTE,
	ITEM,
	FLAG,
	LEVEL,
	STATUS,
	QUEST,
	PARTY,
	RANDOM,
}

enum Comparison {
	EQUAL,
	NOT_EQUAL,
	GREATER,
	GREATER_OR_EQUAL,
	LESS,
	LESS_OR_EQUAL,
}

enum ValueType {
	BOOLEAN,
	NUMBER,
	TEXT,
}

@export var type: Type = Type.FLAG
@export var key: StringName
@export var target_id: String = ""
@export var comparison: Comparison = Comparison.GREATER_OR_EQUAL
@export var value_type: ValueType = ValueType.BOOLEAN
@export var required_bool: bool = true
@export var required_number: float = 1.0
@export var required_text: String = ""
@export_range(0.0, 1.0, 0.01) var chance: float = 0.5
@export_multiline var failure_reason: String = "Requirements not met."


func is_met(context: EventContext) -> bool:
	if context == null:
		return false
	match type:
		Type.ATTRIBUTE:
			return _compare_number(context.get_stat(context.get_actor(target_id), key), required_number)
		Type.ITEM:
			return _compare_number(context.get_item_quantity(key, context.get_actor(target_id)), required_number)
		Type.FLAG:
			return _compare_value(context.game_state.get_flag(key))
		Type.LEVEL:
			return _compare_number(context.get_stat(context.get_actor(target_id), "level"), required_number)
		Type.STATUS:
			var actor := context.get_actor(target_id)
			return actor != null and actor.has_status(String(key)) == required_bool
		Type.QUEST:
			return _compare_value(context.game_state.quest_state.get(String(key)))
		Type.PARTY:
			return (context.find_party_member(String(key)) != null) == required_bool
		Type.RANDOM:
			return context.rng.randf() <= chance
	return false


func uses_choice_actor() -> bool:
	return target_id.is_empty() and type in [Type.ATTRIBUTE, Type.ITEM, Type.LEVEL, Type.STATUS]


func _compare_value(actual: Variant) -> bool:
	match value_type:
		ValueType.NUMBER:
			return _compare_number(float(actual) if actual != null else 0.0, required_number)
		ValueType.TEXT:
			return _compare_ordered(String(actual), required_text)
		_:
			return _compare_ordered(bool(actual), required_bool)


func _compare_number(actual: float, expected: float) -> bool:
	return _compare_ordered(actual, expected)


func _compare_ordered(actual: Variant, expected: Variant) -> bool:
	match comparison:
		Comparison.EQUAL:
			return actual == expected
		Comparison.NOT_EQUAL:
			return actual != expected
		Comparison.GREATER:
			return actual > expected
		Comparison.GREATER_OR_EQUAL:
			return actual >= expected
		Comparison.LESS:
			return actual < expected
		Comparison.LESS_OR_EQUAL:
			return actual <= expected
	return false
