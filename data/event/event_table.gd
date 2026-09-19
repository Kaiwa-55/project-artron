class_name EventTable
extends Resource

@export var id: StringName
@export var entries: Array[EventTableEntry] = []


func pick_event(context: EventContext, rng: RandomNumberGenerator = null) -> EventData:
	var entry := pick_entry(context, rng)
	return entry.event if entry != null else null


func pick_entry(context: EventContext, rng: RandomNumberGenerator = null) -> EventTableEntry:
	if context == null:
		return null
	var candidates: Array[EventTableEntry] = []
	var total_weight := 0.0
	for entry in entries:
		if entry == null or entry.event == null or entry.weight <= 0.0:
			continue
		if entry.remove_after_victory and context.game_state.is_event_table_entry_removed(get_entry_key(entry)):
			continue
		if not entry.is_available(context):
			continue
		if not entry.event.can_start(context):
			continue
		candidates.append(entry)
		total_weight += entry.weight
	if candidates.is_empty() or total_weight <= 0.0:
		return null
	var picker := rng if rng != null else context.rng
	var roll := picker.randf() * total_weight
	for entry in candidates:
		roll -= entry.weight
		if roll < 0.0:
			return entry
	return candidates.back()


func get_entry_key(entry: EventTableEntry) -> String:
	if entry == null:
		return ""
	var table_id := String(id)
	if table_id.is_empty():
		table_id = resource_path if not resource_path.is_empty() else "event_table"
	return "%s:%s" % [table_id, entry.get_id()]
