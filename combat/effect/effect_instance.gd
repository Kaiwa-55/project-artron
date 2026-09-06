class_name EffectInstance
extends RefCounted


var data: EffectData
var remaining_turns: int = 0
var stack_count: int = 1


func _init(p_data: EffectData) -> void:
	data = p_data
	remaining_turns = p_data.duration_turns
	stack_count = mini(p_data.max_stacks, p_data.stacks_on_apply)
