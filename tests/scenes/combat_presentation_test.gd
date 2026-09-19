extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func capture(filename: String) -> void:
	if "--capture-combat" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://work/" + filename + ".png")


func run_test() -> void:
	root.size = Vector2i(1280, 720)
	var scene = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	scene.set_script(preload("res://tests/helpers/idle_combat_ui.gd"))
	root.add_child(scene)
	scene.combat_system.get_combat_state().current_actor_id = "player"
	scene.combat_system.start_current_turn()
	ui_refresh(scene)
	await process_frame
	await process_frame
	var ui: Control = scene.get_node("UILayer/Control")
	var dock: Control = ui.get_node("CombatUI/Combat_bar")
	var minor: Control = dock.get_node("Action_bar_Minor")
	var player = scene.get_displayed_party_member()
	player.max_mana = 20
	player.mana = 15
	scene.refresh_essential_hud()
	await process_frame
	var frame: Control = dock.get_node("Combat_bar_Container/VBoxContainer/Combat_bar")
	var resource_column: Control = frame.get_node("MarginContainer/HBoxContainer/DefenseAndResource/VBoxContainer")
	check(frame.get_global_rect().encloses(resource_column.get_global_rect()), "HP, Mana and class resource must fit in the compact frame")
	await capture("combat-polished-hud")
	scene.show_action_menu("attack")
	await process_frame
	check(ui.get_global_rect().encloses(minor.get_global_rect()), "Expanded actions fit the viewport")
	check(not minor.get_global_rect().intersects(frame.get_global_rect()), "Expanded actions do not overlap the main controls")
	check(minor.visible, "Action category opens its drawer")
	await capture("combat-polished-actions")
	minor.get_node("MenuHeader/Close").pressed.emit()
	check(not minor.visible, "Close returns battlefield space")
	scene.show_action_menu("basic")
	scene._on_action_category_pressed("basic")
	check(not minor.visible, "Pressing the same category closes its drawer")
	scene.show_action_menu("basic")
	scene.action_menu_list.get_child(0).pressed.emit()
	check(minor.visible, "Submenu navigation keeps the drawer open")
	minor.hide()
	ui.add_log_message("Action unavailable: select a target within weapon range.")
	scene.toggle_combat_log()
	await process_frame
	await capture("combat-polished-log")
	scene.toggle_combat_log()
	var reactions: Array = []
	for index in range(7):
		var reaction := ReactionData.new()
		reaction.display_name = "Defensive reaction %d" % index
		reaction.description = "Respond to the incoming attack. Spend one Action Point to protect this character."
		reaction.ap_cost = 1
		reactions.append(reaction)
	ui.show_reaction_prompt({"reactions": reactions})
	await process_frame
	for path in ["CombatUI/Reaction", "CombatUI/ReactionDescription"]:
		check(ui.get_global_rect().encloses(ui.get_node(path).get_global_rect()), "Reaction panel fits the viewport")
	await capture("combat-polished-reaction")
	ui.hide_reaction_prompt()
	scene.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("COMBAT_PRESENTATION_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func ui_refresh(scene: Node) -> void:
	scene.get_node("UILayer/Control").update_ui()
