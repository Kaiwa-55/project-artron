extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var arena = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	arena.set_script(preload("res://tests/helpers/idle_combat_ui.gd"))
	root.add_child(arena)
	arena.combat_system.get_combat_state().current_actor_id = "player"
	arena.combat_system.start_current_turn()
	await process_frame
	await process_frame
	var minor_actions: VBoxContainer = arena.get_node("UILayer/Control/CombatUI/Combat_bar/Action_bar_Minor")
	var success := not minor_actions.visible
	arena.show_action_menu("attack")
	await process_frame
	success = success and minor_actions.visible and arena.action_menu_list.get_child_count() > 0
	var first_action: Control = arena.action_menu_list.get_child(0)
	success = success and first_action.custom_minimum_size == Vector2(28, 28) and minor_actions.size.y <= 54.1
	success = success and is_equal_approx(first_action.size.x, first_action.size.y)
	success = success and first_action.get_theme_font_size("font_size") == 4
	success = success and first_action.get_node("ActionName").get_theme_constant("line_spacing") == -3
	var player: CombatantState = arena.combat_system.get_combat_state().get_combatant("player")
	var bow: EquipmentData = load("res://data/equipment/shortbow.tres")
	arena.combat_system.equipment_system.equip_hand_item_without_cost(player, bow, 0)
	arena.combat_system.equipment_system.refresh_equipment(player)
	arena.show_action_menu("attack")
	await process_frame
	var choices: Array[Node] = arena.action_menu_list.get_children()
	success = success and choices.size() == 3 and arena.minor_action_list.columns == 3
	if choices.size() == 3:
		var row_y: float = (choices[0] as Control).global_position.y
		for choice in choices:
			success = success and is_equal_approx((choice as Control).global_position.y, row_y)
			success = success and arena.minor_action_scroll.get_global_rect().encloses((choice as Control).get_global_rect())
		success = success and (choices[0] as Button).text.contains("ลูกธนูธรรมดา") and (choices[1] as Button).text.contains("ลูกธนูหนัก")
	success = success and minor_actions.size.y <= 54.1
	arena.show_action_menu("basic")
	await process_frame
	success = success and minor_actions.size.x < 300.0 and arena.minor_action_title.get_theme_font_size("font_size") == 4
	success = success and minor_actions.get_node("MenuHeader/Close").get_theme_font_size("font_size") == 4
	for action in arena.action_menu_list.get_children():
		if action is Button:
			success = success and is_equal_approx(action.size.x, action.size.y) and action.get_theme_font_size("font_size") == 4
	arena.queue_free()
	await process_frame
	print("MINOR_ACTION_VISIBILITY_TEST: " + ("PASS" if success else "FAIL"))
	quit(0 if success else 1)
