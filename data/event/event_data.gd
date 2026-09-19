class_name EventData
extends Resource

@export var id: StringName
@export var title: String = ""
@export_multiline var description: String = ""
@export var illustration: Texture2D
@export var narration_audio: AudioStream
@export var narration_autoplay: bool = true
@export_range(-80.0, 24.0, 0.1) var narration_volume_db: float = 0.0
@export var choices: Array[EventChoice] = []
@export var start_conditions: Array[EventCondition] = []
@export var on_start_effects: Array[EventEffect] = []
@export var on_end_effects: Array[EventEffect] = []
@export var can_repeat: bool = false


func can_start(context: EventContext) -> bool:
	if context == null:
		return false
	if not can_repeat and context.game_state.has_completed_event(id):
		return false
	return start_conditions.all(func(condition): return condition != null and condition.is_met(context))
