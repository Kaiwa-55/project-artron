extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var arena = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	root.add_child(arena)
	var player: CombatantState = arena.combat_system.get_combat_state().get_combatant("player")
	arena.combat_system.get_combat_state().current_actor_id = player.id
	player.ap = player.max_ap
	var success: bool = arena.action_category_buttons.size() == 5 and arena.action_category_buttons.has("throw")
	arena.show_action_menu("throw")
	success = success and arena.action_menu_list.get_child_count() == 2
	for button in arena.action_menu_list.get_children():
		success = success and button is Button and button.disabled and button.text.contains("Equip first")
	var axe = load("res://data/equipment/hand_axe.tres")
	arena.combat_system.equipment_system.equip_hand_item_without_cost(player, axe, 0)
	arena.combat_system.equipment_system.refresh_equipment(player)
	arena.show_action_menu("throw")
	var enabled := 0
	for button in arena.action_menu_list.get_children():
		if not button.disabled:
			enabled += 1
			button.pressed.emit()
	success = success and enabled == 1 and arena.pending_target_attack.thrown_item == axe
	arena.cancel_attack_targeting()
	arena.show_action_menu("attack")
	for button in arena.action_menu_list.get_children():
		if button is Button:
			success = success and not button.text.begins_with("Throw")
	player.ap = 0
	arena.show_action_menu("throw")
	for button in arena.action_menu_list.get_children():
		success = success and button.disabled
	await process_frame
	var dock: Control = arena.get_node("UILayer/Control/ReferenceActionDock")
	for button in arena.action_category_buttons.values():
		success = success and dock.get_global_rect().encloses(button.get_global_rect())
	arena.queue_free()
	await process_frame
	print("THROW_MENU_TEST: " + ("PASS" if success else "FAIL"))
	quit(0 if success else 1)
