extends SceneTree

const RunMapScene := preload("res://scenes/run/RunMap.tscn")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var failures: Array[String] = []
	var run_map = RunMapScene.instantiate()
	root.add_child(run_map)
	await process_frame
	var buttons: Array[Node] = run_map.party_inventory.get_children()
	check(buttons.size() == run_map.run_state.party_progression_states.size(), "Run Map creates one Inventory button per party member", failures)
	var first_id: String = run_map.get_party_entries()[0].id
	run_map.open_party_inventory(first_id)
	check(run_map.character_panel.visible, "Party Inventory opens from Run Map", failures)
	check(run_map.character_panel.standalone_character.id == first_id, "Inventory shows the selected party member", failures)
	run_map.queue_free()
	if failures.is_empty():
		print("RUN_MAP_INVENTORY_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
