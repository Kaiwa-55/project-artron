extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var panel = load("res://InventoryandMore.tscn").instantiate()
	root.add_child(panel)
	var player: CombatantState = load("res://data/character/player.tres").create_combatant_state()
	StatSystem.new().refresh_combatant(player)
	panel.setup_standalone(player, "equipment", true)
	await process_frame
	check(not panel.has_node("PanelContainer"), "Old authored UI is removed")
	check(panel.tab_buttons.size() == 3, "Three functional tabs share one shell")
	check(panel.equipment_entries.get_child_count() == player.equipment_inventory.size(), "All equipment appears in the new list")
	var gear: EquipmentData = player.equipment_inventory.filter(func(item): return item != null and item.slot != EquipmentData.Slot.ARMOR).front()
	panel._select_entry(gear)
	var requests: Array = []
	panel.equipment_change_requested.connect(func(item, slot): requests.append([item, slot]))
	panel.equipment_action_bar.get_child(0).pressed.emit()
	check(requests.size() == 1 and requests[0][0] == gear, "Equip button routes the selected equipment")
	panel.set_changes_locked(true)
	check(panel.equipment_action_bar.get_children().all(func(button): return button.disabled), "Read-only gear cannot be changed")
	panel.set_changes_locked(false)
	var armor: EquipmentData = player.equipment_inventory.filter(func(item): return item != null and item.slot == EquipmentData.Slot.ARMOR).front()
	panel._select_entry(armor)
	check(not panel.equipment_action_bar.get_child(0).disabled, "Armor can be changed outside combat")
	var system := CombatSystem.new()
	system.combat_state = CombatState.new()
	system.combat_state.add_combatant(player)
	panel.setup(system, player.id)
	panel._select_entry(armor)
	check(panel.equipment_action_bar.get_child(0).disabled, "Armor stays locked during combat")
	player.ap = 0
	panel._select_entry(gear)
	check(panel.equipment_action_bar.get_children().all(func(button): return button.disabled), "No AP disables hand changes")
	panel.setup_standalone(player, "abilities", true)
	check(panel.profile_view.visible and not panel.equipment_view.visible, "Character tab opens the new profile")
	check(panel.defense_labels["Fortitude"].text == "Fortitude  %d" % panel._displayed_defenses(player)[0], "Profile shows derived defenses")
	check(panel.profile_abilities.get_child_count() > 2, "Character includes abilities and skills")
	var exit_position: Vector2 = panel.exit_button.global_position
	for tab in ["abilities", "equipment", "inventory"]:
		panel.tab_buttons[tab].pressed.emit()
		check(panel.active_tab == tab, "Navigation opens " + tab)
		if tab == "equipment":
			panel._select_entry(gear)
		panel.offset_top = 60
		panel.offset_bottom = -16
		for frame in range(4):
			await process_frame
		check(panel.get_global_rect().encloses(panel.inventory_view.get_global_rect()), "Window fits combat space on " + tab)
		check(panel.inventory_view.get_global_rect().encloses(panel.exit_button.get_global_rect()), "Close stays within " + tab)
		if "--character-screenshots" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://work/redesign-%s.png" % tab)
	panel.setup_standalone(CombatantState.new(), "equipment", true)
	check(panel.selected_entry == null and panel.equipment_action_bar.get_child_count() == 0, "Changing owner clears old equipment actions")
	var closed_events: Array = []
	panel.closed.connect(func(): closed_events.append(true))
	panel.exit_button.pressed.emit()
	check(not panel.visible and closed_events.size() == 1, "Close hides the whole panel")
	panel.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("INVENTORY_AND_MORE_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
