extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var arena = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var player: CombatantState = arena.combat_system.get_combat_state().get_combatant("player")
	arena.combat_system.get_combat_state().current_actor_id = player.id
	player.ap = player.max_ap
	var success: bool = arena.action_category_buttons.size() == 6 and arena.action_category_buttons.has("basic") and arena.action_category_buttons.has("item") and not arena.action_category_buttons.has("throw") and not arena.action_category_buttons.has("escape")
	var basic_button: Button = arena.action_category_buttons["basic"]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = basic_button.get_global_rect().get_center()
	click.global_position = click.position
	var motion := InputEventMouseMotion.new()
	motion.position = click.position
	motion.global_position = click.position
	root.push_input(motion, true)
	await process_frame
	click.pressed = true
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	await process_frame
	var basic_entries: Array[String] = []
	for child in arena.action_menu_list.get_children():
		if child is Button:
			basic_entries.append(child.text)
	success = success and arena.minor_action_scroll.visible and not arena.action_menu_panel.visible and basic_entries == ["THROW", "ESCAPE"]
	arena.action_category_buttons["ability"].pressed.emit()
	success = success and arena.minor_action_scroll.visible and arena.action_menu_list.get_child_count() > 0
	player.hp = maxi(1, player.max_hp - 6)
	arena.show_action_menu("item")
	var item_buttons: Array[Button] = []
	for child in arena.action_menu_list.get_children():
		if child is Button:
			item_buttons.append(child)
	success = success and item_buttons.size() == 1 and item_buttons[0].text.begins_with("Minor Healing Potion") and not item_buttons[0].disabled
	if item_buttons.size() == 1:
		item_buttons[0].pressed.emit()
	success = success and player.hp == player.max_hp and player.item_inventory.is_empty()
	player.ap = player.max_ap
	var rooted = load("res://data/status/rooted.tres")
	var enemy: CombatantState = arena.combat_system.get_combat_state().combatants.values().filter(func(actor): return actor.team != player.team).front()
	arena.combat_system.effect_system.apply_effect(player, rooted, "test_root", "Test Root", false, enemy)
	arena.show_action_menu("escape")
	var escape_entries: Array[String] = []
	for child in arena.action_menu_list.get_children():
		if child is Button:
			escape_entries.append(child.text)
	success = success and escape_entries.size() == 2 and escape_entries[0].contains("BACK") and escape_entries[1].begins_with("Rooted")
	player.remove_status("rooted")
	arena.show_action_menu("throw")
	var unequipped_throw_buttons := 0
	for child in arena.action_menu_list.get_children():
		if child is Button and child.disabled and not child.get_meta("menu_navigation", false):
			unequipped_throw_buttons += 1
	success = success and unequipped_throw_buttons == 2
	var axe = load("res://data/equipment/hand_axe.tres")
	arena.combat_system.equipment_system.equip_hand_item_without_cost(player, axe, 0)
	arena.combat_system.equipment_system.refresh_equipment(player)
	arena.show_action_menu("throw")
	var enabled := 0
	for button in arena.action_menu_list.get_children():
		if button is Button and button.text.begins_with(axe.display_name) and not button.disabled:
			enabled += 1
			button.pressed.emit()
	success = success and enabled == 1 and arena.pending_target_attack.thrown_item == axe
	arena.cancel_attack_targeting()
	arena.show_action_menu("attack")
	var attack_buttons: Array[Node] = arena.action_menu_list.get_children().filter(func(child): return child is Button and not child.disabled)
	success = success and attack_buttons.all(func(button): return not button.text.contains(" AP"))
	if not attack_buttons.is_empty():
		attack_buttons[0].pressed.emit()
	success = success and arena.pending_target_attack != null
	arena.cancel_attack_targeting()
	for button in arena.action_menu_list.get_children():
		if button is Button:
			success = success and not button.text.begins_with("Throw")
			var card = button._make_custom_tooltip(button.tooltip_text)
			success = success and card.get_node("Column/Stats").text.contains("Base damage:")
			card.free()
	for category in ["skill", "ability"]:
		arena.show_action_menu(category)
		for button in arena.action_menu_list.get_children():
			if button is Button:
				var card = button._make_custom_tooltip(button.tooltip_text)
				success = success and not card.get_node("Column/Title").text.is_empty()
				card.free()
	player.ap = 0
	arena.show_action_menu("throw")
	for button in arena.action_menu_list.get_children():
		if button is Button and not button.get_meta("menu_navigation", false):
			success = success and button.disabled
	await process_frame
	var dock: Control = arena.get_node("UILayer/Control/CombatUI/Combat_bar/Combat_bar_Container/VBoxContainer/Combat_bar/MarginContainer/HBoxContainer/Action_Bar_Major")
	for button in arena.action_category_buttons.values():
		success = success and dock.get_global_rect().encloses(button.get_global_rect())
	for child in arena.action_menu_list.get_children():
		arena.action_menu_list.remove_child(child)
		child.queue_free()
	for index in range(8):
		arena.add_action_menu_button("Action %d" % index, "", func(): pass)
	await process_frame
	success = success and arena.minor_action_list.columns == 4
	success = success and arena.minor_action_scroll.get_h_scroll_bar().max_value > arena.minor_action_scroll.get_h_scroll_bar().page
	var icon_button := Button.new()
	icon_button.text = "Icon Action"
	arena.style_minor_action_button(icon_button, load("res://assets/ui/Will.png"))
	success = success and icon_button.text.is_empty() and icon_button.has_node("ActionIcon") and icon_button.get_node("ActionName").text == "Icon Action"
	icon_button.free()
	arena.queue_free()
	await process_frame
	print("THROW_MENU_TEST: " + ("PASS" if success else "FAIL"))
	quit(0 if success else 1)
