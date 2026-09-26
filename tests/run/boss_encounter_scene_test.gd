extends SceneTree

const CombatScene := preload("res://scenes/prototype/PrototypeCombat.tscn")
const RunMapScene := preload("res://scenes/run/RunMap.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var first := load("res://data/encounter/run_boss_goblin_entrance.tres") as EncounterData
	var encounter := first
	var expected_maps := [&"goblin_entry", &"goblin_road_battle", &"goblin_village_battle"]
	for expected_map in expected_maps:
		set_meta("active_encounter_data", encounter)
		var combat := CombatScene.instantiate()
		root.add_child(combat)
		check(combat.dungeon_world != null and combat.dungeon_world.map_data.map_id == expected_map, "Combat should load map %s." % expected_map)
		check(combat.enemy_nodes.size() >= 2, "Combat on %s should spawn its goblins." % expected_map)
		combat.queue_free()
		await process_frame
		encounter = encounter.next_encounter
	set_meta("active_encounter_data", first)
	var active_combat := CombatScene.instantiate()
	root.add_child(active_combat)
	current_scene = active_combat
	for expected_id in ["run_boss_goblin_road", "run_boss_goblin_village"]:
		active_combat.open_next_encounter(active_combat.get_active_encounter_data().next_encounter)
		await create_timer(0.9).timeout
		var cutscene := current_scene
		check(cutscene != null and cutscene.name == "EncounterCutscene", "Victory handoff should show the next cutscene.")
		if cutscene == null:
			break
		check(cutscene.image_rect.texture == get_meta("active_encounter_data").cutscene_image, "Cutscene should show the next stage's image.")
		cutscene.start_combat()
		await process_frame
		await process_frame
		active_combat = current_scene
		check(active_combat != null and active_combat.get_active_encounter_data().id == expected_id, "Victory handoff should open %s." % expected_id)
		if active_combat == null:
			break
	if active_combat != null:
		active_combat.queue_free()
		current_scene = null
	remove_meta("active_encounter_data")
	var run_map := RunMapScene.instantiate()
	root.add_child(run_map)
	current_scene = run_map
	var test_button: Button = run_map.get_node("Margin/Layout/TestGoblinBossButton")
	test_button.pressed.emit()
	await process_frame
	await process_frame
	check(String(get_meta("active_run_node_id", "")) == "boss", "Test button should use the Boss reward node.")
	check(current_scene != null and current_scene.name == "EncounterCutscene", "Test button should show the first cutscene.")
	if current_scene != null:
		check(current_scene.image_rect.texture == first.cutscene_image, "First cutscene should show the supplied entrance image.")
		current_scene.start_combat()
		await process_frame
		await process_frame
		check(current_scene != null and current_scene.get_active_encounter_data().id == first.id, "Continue should launch the first Goblin encounter.")
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	remove_meta("active_encounter_data")
	var normal_run_map := RunMapScene.instantiate()
	root.add_child(normal_run_map)
	current_scene = normal_run_map
	var predecessor: MapNodeData
	for node in normal_run_map.run_state.nodes:
		if node.next_node_ids.has("boss"):
			predecessor = node
			break
	check(predecessor != null, "Run should have a path into the Boss node.")
	if predecessor != null:
		normal_run_map.run_state.current_node_id = predecessor.id
		normal_run_map.select_node("boss")
		normal_run_map.confirm_selected_node()
		await process_frame
		await process_frame
		check(current_scene != null and current_scene.name == "EncounterCutscene", "Entering the final Run node should open the first cutscene.")
	for failure in failures:
		push_error(failure)
	print("BOSS_ENCOUNTER_SCENE_TEST: PASS" if failures.is_empty() else "BOSS_ENCOUNTER_SCENE_TEST: FAIL (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
