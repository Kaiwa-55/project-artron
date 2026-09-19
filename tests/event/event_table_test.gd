extends SceneTree

const EventTableScript := preload("res://data/event/event_table.gd")
const EventTableEntryScript := preload("res://data/event/event_table_entry.gd")

var failures: Array[String] = []


func _init() -> void:
	var world := GameState.new()
	var context := EventContext.new(world)
	var common := EventData.new()
	common.id = "common"
	var rare := EventData.new()
	rare.id = "rare"
	var locked := EventData.new()
	locked.id = "locked"
	var required_flag := EventCondition.new()
	required_flag.type = EventCondition.Type.FLAG
	required_flag.key = "unlock_rare_event"
	required_flag.comparison = EventCondition.Comparison.EQUAL

	var common_entry := EventTableEntryScript.new()
	common_entry.id = "common_entry"
	common_entry.event = common
	common_entry.weight = 3.0
	common_entry.remove_after_victory = true
	var rare_entry := EventTableEntryScript.new()
	rare_entry.id = "rare_entry"
	rare_entry.event = rare
	rare_entry.weight = 1.0
	var locked_entry := EventTableEntryScript.new()
	locked_entry.event = locked
	locked_entry.weight = 1000.0
	locked_entry.conditions = [required_flag]
	var table := EventTableScript.new()
	table.id = "test_events"
	table.entries = [common_entry, rare_entry, locked_entry]

	var first_rng := RandomNumberGenerator.new()
	first_rng.seed = 77123
	var second_rng := RandomNumberGenerator.new()
	second_rng.seed = 77123
	check(table.pick_event(context, first_rng) == table.pick_event(context, second_rng), "The same seed should select the same Event.")

	var counts := {"common": 0, "rare": 0, "locked": 0}
	for seed_value in range(400):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var selected := table.pick_event(context, rng)
		counts[String(selected.id)] += 1
	check(counts.common > counts.rare * 2, "A weight of 3 should be selected substantially more often than a weight of 1.")
	check(counts.locked == 0, "EventTable Entries whose required Flag is missing should be excluded from the weighted roll.")

	world.set_flag("unlock_rare_event", true)
	locked_entry.weight = 1.0
	var found_unlocked := false
	for seed_value in range(100):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		if table.pick_event(context, rng) == locked:
			found_unlocked = true
			break
	check(found_unlocked, "An EventTable Entry should enter the pool after its required Flag matches.")

	world.remove_event_table_entry(table.get_entry_key(common_entry))
	for seed_value in range(50):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		check(table.pick_event(context, rng) != common, "A removable Event should leave its EventTable after Victory.")
	world.remove_event_table_entry(table.get_entry_key(rare_entry))
	var rare_still_available := false
	for seed_value in range(100):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		if table.pick_event(context, rng) == rare:
			rare_still_available = true
			break
	check(rare_still_available, "An Entry with remove_after_victory disabled should remain available.")

	var empty_table := EventTableScript.new()
	check(empty_table.pick_event(context) == null, "An empty EventTable should safely return no Event.")
	check(table.pick_event(null) == null, "An EventTable should safely reject a missing context.")

	for failure in failures:
		push_error(failure)
	print("EVENT_TABLE_TEST: PASS" if failures.is_empty() else "EVENT_TABLE_TEST: FAIL (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
