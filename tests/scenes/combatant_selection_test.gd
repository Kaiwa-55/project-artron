extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var prototype = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	root.add_child(prototype)
	await process_frame
	await process_frame
	var state = prototype.combat_system.get_combat_state()
	state.current_actor_id = "player"
	var ally_node = prototype.get_node("AllyCharacter")
	var player_node = prototype.get_node("PlayerCharacter")
	var test_button := Button.new()
	prototype.action_category_buttons = {"test": test_button}

	check(prototype.select_target_at(ally_node.global_position), "Out-of-turn Ally can be clicked")
	prototype.refresh_action_dock()
	prototype.refresh_end_turn_lock()
	check(prototype.selected_character_id == "ally" and ally_node.selected, "Clicked Ally receives the ui03 selection frame")
	check(ally_node.selection_frame.centered and ally_node.selection_frame.position.is_equal_approx(Vector2.ZERO), "ui03 frame is centered on the selected token")
	check(ally_node.selection_frame.region_rect == Rect2(192.0, 0.0, 48.0, 48.0), "ui03 uses its exact 48x48 sprite-sheet cell")
	prototype.refresh_essential_hud()
	check(prototype.essential_player_status.text.contains("Ally"), "Player HUD switches to the selected controllable character")
	check(not test_button.disabled, "Out-of-turn Ally can open Action categories to inspect them")
	prototype.show_action_menu("attack")
	var listed_action = prototype.action_menu_list.get_children().filter(func(child): return child is Button).front()
	check(listed_action.disabled, "Out-of-turn Ally's listed Actions cannot be executed")
	check(prototype.action_menu_list.get_children().any(func(child): return child is Button and child.text.contains("Unarmed Attack")), "Attack menu lists the selected character's Unarmed Attack")
	check(prototype.reference_end_turn_button.disabled, "Out-of-turn Ally cannot end the active Turn")

	check(prototype.select_target_at(player_node.global_position), "Active character can be clicked")
	prototype.refresh_action_dock()
	check(prototype.selected_character_id == "player" and player_node.selected and not ally_node.selected, "Selection frame moves to the latest clicked character")
	check(not test_button.disabled, "Active character can use Actions")

	var enemy_node = prototype.get_enemy_nodes().front()
	check(prototype.select_target_at(enemy_node.global_position), "Enemy can be selected for inspection")
	prototype.get_node("Control").update_ui()
	check(prototype.get_node("Control/Enemy_panel").visible, "Enemy selection opens enemy information")
	check(prototype.get_node("Control/Enemy_panel/VBoxContainer/Name").text == enemy_node.state.display_name, "Enemy information belongs to the selected enemy")

	prototype.queue_free()
	for failure in failures:
		push_error(failure)
	print("COMBATANT_SELECTION_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
