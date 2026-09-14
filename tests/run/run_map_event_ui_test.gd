extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	root.size = Vector2i(640, 360)
	var run_map = load("res://scenes/run/RunMap.tscn").instantiate()
	root.add_child(run_map)
	await process_frame
	await process_frame

	check(run_map.event_manager != null and run_map.encounter_manager != null, "RunMap should create the Event/Encounter flow managers.")
	check(run_map.event_panel != null and not run_map.event_panel.visible, "Event panel should start hidden.")
	var generator := RunGenerator.new()
	var event_node := generator.create_node("event_test", MapNodeData.NodeType.EVENT, 1, 0, 1)
	check(event_node != null and event_node.event_data != null, "Generated Event nodes should receive authored EventData.")
	var second_event_node := generator.create_node("event_test_2", MapNodeData.NodeType.EVENT, 2, 0, 2)
	check(event_node.event_data.id != second_event_node.event_data.id, "Each map Event node should have an independent completion id.")
	var selector_choice := EventChoice.new()
	selector_choice.text = "Choose a scout"
	selector_choice.actor_mode = EventChoice.ActorMode.SELECT_ONE
	var selector_event := EventData.new()
	selector_event.id = "ui_actor_selection"
	selector_event.choices = [selector_choice]
	check(run_map.event_manager.start_event(selector_event, run_map.get_event_context()), "Character-selection Event should open on RunMap.")
	await process_frame
	var selector_button := run_map.event_panel.choice_list.get_child(0) as Button
	await click_control(selector_button)
	check(run_map.event_panel.pending_choice_index == 0, "Selecting a SELECT_ONE Choice should open the character picker.")
	check(run_map.event_panel.choice_list.get_child_count() == run_map.event_manager.context.party.size() + 1, "Character picker should list every eligible member plus Back.")
	var actor_button := run_map.event_panel.choice_list.get_child(0) as Button
	check(actor_button.text == run_map.event_manager.context.party[0].display_name, "Character picker should display party member names.")
	await click_control(actor_button)
	check(run_map.event_manager.active_event == null and not run_map.event_panel.visible, "Choosing a character should resolve the Choice and close a terminal Event.")

	var event_data := load("res://data/event/strange_caravan.tres") as EventData
	check(run_map.event_manager.start_event(event_data, run_map.get_event_context()), "RunMap should open authored EventData.")
	await process_frame
	check(run_map.event_panel.visible and not run_map.event_panel.title_label.visible, "Event UI should hide the Event title during the cutscene.")
	check(run_map.event_panel.image_rect.texture == event_data.illustration, "Event UI should show the optional Event illustration.")
	check(run_map.event_panel.choice_list.get_child_count() >= 2, "Event UI should render visible Choices.")

	var encounter_button: Button
	for child in run_map.event_panel.choice_list.get_children():
		if child is Button and child.text == "Call out to anyone inside":
			encounter_button = child
			break
	check(encounter_button != null and not encounter_button.disabled, "Encounter Choice button should accept input.")
	if encounter_button != null:
		check(encounter_button.custom_minimum_size.y <= 24.0, "Event Choice buttons should use the compact height.")
		check(encounter_button.get_theme_stylebox("normal") is StyleBoxEmpty, "Event Choices should be transparent at rest.")
		var hover_style := encounter_button.get_theme_stylebox("hover") as StyleBoxFlat
		check(hover_style != null and is_zero_approx(hover_style.bg_color.a) and hover_style.border_width_left > 0, "Event Choices should show only a border on hover.")
		await click_control(encounter_button)
	var encounter := event_data.choices[1].encounter
	check(run_map.pending_encounter_from_event and run_map.event_panel.pending_encounter == encounter, "Encounter Choice should open the Encounter preview instead of changing scenes immediately.")
	check(run_map.event_panel.image_rect.texture == encounter.encounter_image, "Encounter preview should display EncounterData.encounter_image.")
	check(run_map.event_panel.choice_list.get_child_count() == 1 and run_map.event_panel.choice_list.get_child(0).text == "BEGIN ENCOUNTER", "Encounter preview should require explicit confirmation.")

	var persisted_run: RunState = run_map.run_state
	root.remove_child(run_map)
	run_map.queue_free()
	await process_frame
	set_meta("active_run_state", persisted_run)
	set_meta("active_event_encounter", true)
	set_meta("active_event_encounter_data", encounter)
	set_meta("pending_event_encounter_result", EncounterResult.Type.VICTORY)
	var returned_map = load("res://scenes/run/RunMap.tscn").instantiate()
	root.add_child(returned_map)
	await process_frame
	await process_frame
	check(returned_map.event_manager.active_event == encounter.victory_event, "Returning from Event-owned Combat should open its result Event.")
	check(returned_map.event_panel.visible and not returned_map.event_panel.title_label.visible, "RunMap should present the result Event without showing its title.")
	check(persisted_run.game_state.get_flag("defeated_bandit_ambush"), "Result Event Effects should update the persisted Run GameState.")
	returned_map.queue_free()
	remove_meta("active_run_state")
	if failures.is_empty():
		print("RUN_MAP_EVENT_UI_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("RUN_MAP_EVENT_UI_TEST: FAIL (%d)" % failures.size())
		quit(1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func click_control(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	Input.parse_input_event(motion)
	await process_frame
	var press := InputEventMouseButton.new()
	press.position = position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventMouseButton.new()
	release.position = position
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
