extends SceneTree

const RUN_MAP := "res://scenes/run/RunMap.tscn"
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func settle() -> void:
	await process_frame
	await process_frame

func run_test() -> void:
	var leader: CharacterData = load("res://data/character/player.tres").duplicate()
	leader.display_name = "Dungeon Test Leader"
	set_meta("active_party_characters", [leader])
	change_scene_to_file(RUN_MAP)
	await settle()
	var run_map = current_scene
	var state: RunState = run_map.run_state
	var gold_before := state.gold
	var node_before := state.current_node_id
	var hp_before := state.player_progression_state.hp
	var mana_before := state.player_progression_state.mana
	var completed_before := state.completed_node_ids.duplicate()
	var selected := ""
	for node in state.nodes:
		if state.can_enter(node.id):
			selected = node.id
			run_map.select_node(selected)
			break
	run_map.get_node("Margin/Layout/ExploreBuildingButton").pressed.emit()
	await settle()
	var dungeon = current_scene
	check(dungeon.scene_file_path.ends_with("DungeonExploration.tscn"), "Run Map button opens real dungeon scene")
	check(dungeon.active_run == state, "Reuse active RunState")
	check(dungeon.hero_name == leader.display_name, "Use the existing party leader")
	dungeon.player.position = Vector2(235,790)
	dungeon.use_stairs()
	dungeon.player.position = Vector2(760,1100)
	dungeon.return_to_run()
	await settle()
	check(current_scene.scene_file_path == RUN_MAP, "Return opens Run Map")
	check(current_scene.run_state == state, "Same run survives return")
	check(current_scene.selected_node_id == selected, "Selected route survives return")
	check(state.gold == gold_before and state.current_node_id == node_before and state.completed_node_ids == completed_before, "Exploring does not spend gold or consume a run node")
	check(state.player_progression_state.hp == hp_before and state.player_progression_state.mana == mana_before, "HP and Mana survive roundtrip")
	current_scene.open_building_exploration()
	await settle()
	check(current_scene.floor_id == 1 and current_scene.player.position.distance_to(Vector2(760,1100)) < 0.1, "Re-entry restores floor and position")
	current_scene.return_to_run()
	await settle()
	current_scene.start_run(123456)
	current_scene.open_building_exploration()
	await settle()
	check(current_scene.floor_id == 0 and current_scene.player.position == Vector2(760,1500), "New run starts at entrance")
	current_scene.queue_free()
	await settle()
	print("DUNGEON_RUN_ROUNDTRIP_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
