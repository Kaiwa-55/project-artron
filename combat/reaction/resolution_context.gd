class_name ResolutionContext
extends RefCounted

const ReactionFrameScript = preload("res://combat/reaction/reaction_frame.gd")

const MAX_REACTION_DEPTH := 8
const MAX_REACTIONS_PER_CHAIN := 32

var root_action: ActionRequest
var frames: Array = []
var trigger_queue: Array[Dictionary] = []
var used_reaction_keys: Dictionary = {}
var next_frame_id: int = 1
var next_trigger_id: int = 1
var resolved_reaction_count: int = 0

func begin(action: ActionRequest) -> void:
	root_action = action
	frames.clear()
	trigger_queue.clear()
	used_reaction_keys.clear()
	next_frame_id = 1
	next_trigger_id = 1
	resolved_reaction_count = 0

func finish() -> void:
	root_action = null
	frames.clear()
	trigger_queue.clear()
	used_reaction_keys.clear()

func open_frame(action: ActionRequest, prompt: Dictionary):
	# A completed top frame remains the parent while its resolver is producing a
	# nested trigger. CombatSystem starts a fresh context for sequential/root prompts.
	var parent = frames.back() if not frames.is_empty() else null
	var depth: int = parent.depth + 1 if parent != null else 1
	if depth > MAX_REACTION_DEPTH or resolved_reaction_count >= MAX_REACTIONS_PER_CHAIN:
		return null
	var frame = ReactionFrameScript.new()
	frame.id = next_frame_id
	frame.trigger_id = next_trigger_id
	frame.depth = depth
	frame.parent_id = parent.id if parent != null else 0
	frame.request = action
	frame.prompt = prompt
	next_frame_id += 1
	next_trigger_id += 1
	frames.append(frame)
	return frame

func complete_current(reactor_id: String, reaction_id: String) -> bool:
	var frame = current_frame()
	if frame == null:
		return false
	if not reaction_id.is_empty():
		var key := "%s:%s:%d" % [reactor_id, reaction_id, frame.trigger_id]
		if used_reaction_keys.has(key) or resolved_reaction_count >= MAX_REACTIONS_PER_CHAIN:
			return false
		used_reaction_keys[key] = true
		resolved_reaction_count += 1
		frame.selected_reaction_id = reaction_id
	frame.completed = true
	return true

func enqueue_trigger(trigger: Dictionary) -> void:
	trigger_queue.append(trigger)

func pop_next_trigger() -> Dictionary:
	return trigger_queue.pop_front() if not trigger_queue.is_empty() else {}

func current_frame():
	for index in range(frames.size() - 1, -1, -1):
		if not frames[index].completed:
			return frames[index]
	return null

func get_open_depth() -> int:
	var frame = current_frame()
	return frame.depth if frame != null else 0

func is_limit_reached() -> bool:
	return get_open_depth() >= MAX_REACTION_DEPTH or resolved_reaction_count >= MAX_REACTIONS_PER_CHAIN
