extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var arena = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	arena.set_script(preload("res://tests/helpers/idle_combat_ui.gd"))
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
	success = verify(arena.minor_action_scroll.visible and not arena.action_menu_panel.visible and basic_entries.has("THROW") and basic_entries.has("ESCAPE"), "Basic menu includes THROW and ESCAPE") and success
	arena.action_category_buttons["ability"].pressed.emit()
	success = verify(arena.minor_action_scroll.visible and arena.action_menu_list.get_child_count() > 0, "arena.minor_action_scroll.visible and arena.action_menu_list.get_child_count() > 0") and success
	player.hp = maxi(1, player.max_hp - 6)
	arena.show_action_menu("item")
	var item_buttons: Array[Button] = []
	for child in arena.action_menu_list.get_children():
		if child is Button:
			item_buttons.append(child)
	var potion_buttons: Array[Button] = item_buttons.filter(func(button): return button.text.begins_with("Minor Healing Potion"))
	success = verify(potion_buttons.size() == 1 and not potion_buttons[0].disabled, "The healing potion is available among inventory items") and success
	if potion_buttons.size() == 1:
		potion_buttons[0].pressed.emit()
	success = verify(player.hp == player.max_hp and player.item_inventory.all(func(stack): return stack.item.id != "minor_healing_potion"), "Healing potion is consumed while other inventory remains") and success
	player.ap = player.max_ap
	var rooted = load("res://data/status/rooted.tres")
	var enemy: CombatantState = arena.combat_system.get_combat_state().combatants.values().filter(func(actor): return actor.team != player.team).front()
	arena.combat_system.effect_system.apply_effect(player, rooted, "test_root", "Test Root", false, enemy)
	arena.show_action_menu("escape")
	var escape_entries: Array[String] = []
	for child in arena.action_menu_list.get_children():
		if child is Button:
			escape_entries.append(child.text)
	success = verify(escape_entries.size() == 2 and escape_entries[0].contains("BACK") and escape_entries[1].begins_with("Rooted"), "escape_entries.size() == 2 and escape_entries[0].contains(\"BACK\") and escape_entries[1].begins_with(\"Rooted\")") and success
	player.remove_status("rooted")
	# Explicit loadout: this test must not depend on the editable starter inventory.
	player.equipment_inventory.assign([load("res://data/equipment/hand_axe.tres"), load("res://data/equipment/dagger.tres")])
	player.equipped_items.erase(0)
	player.equipped_items.erase(3)
	arena.combat_system.equipment_system.refresh_equipment(player)
	arena.show_action_menu("throw")
	await process_frame
	var throw_row_y: float = (arena.action_menu_list.get_child(0) as Control).global_position.y
	for choice in arena.action_menu_list.get_children():
		success = verify(is_equal_approx((choice as Control).global_position.y, throw_row_y), "Throw choices stay on one row") and success
	var unequipped_throw_buttons := 0
	for child in arena.action_menu_list.get_children():
		if child is Button and child.disabled and not child.get_meta("menu_navigation", false):
			unequipped_throw_buttons += 1
	success = verify(unequipped_throw_buttons == 2, "unequipped_throw_buttons == 2") and success
	var axe = load("res://data/equipment/hand_axe.tres")
	arena.combat_system.equipment_system.equip_hand_item_without_cost(player, axe, 0)
	arena.combat_system.equipment_system.refresh_equipment(player)
	arena.show_action_menu("throw")
	var enabled := 0
	for button in arena.action_menu_list.get_children():
		if button is Button and button.text.begins_with(axe.display_name) and not button.disabled:
			enabled += 1
			button.pressed.emit()
	success = verify(enabled == 1 and arena.pending_target_attack.thrown_item == axe, "enabled == 1 and arena.pending_target_attack.thrown_item == axe") and success
	arena.cancel_attack_targeting()
	arena.show_action_menu("attack")
	var attack_buttons: Array[Node] = arena.action_menu_list.get_children().filter(func(child): return child is Button and not child.disabled)
	success = verify(attack_buttons.all(func(button): return not button.text.contains(" AP")), "attack_buttons.all(func(button): return not button.text.contains(\" AP\"))") and success
	if not attack_buttons.is_empty():
		attack_buttons[0].pressed.emit()
	success = verify(arena.pending_target_attack != null, "arena.pending_target_attack != null") and success
	arena.cancel_attack_targeting()
	for button in arena.action_menu_list.get_children():
		if button is Button:
			success = verify(not button.text.begins_with("Throw"), "not button.text.begins_with(\"Throw\")") and success
			var card = button._make_custom_tooltip(button.tooltip_text)
			success = verify(card.get_node("Column/Stats").text.contains("Base damage:"), "card.get_node(\"Column/Stats\").text.contains(\"Base damage:\")") and success
			card.free()
	for category in ["skill", "ability"]:
		arena.show_action_menu(category)
		for button in arena.action_menu_list.get_children():
			if button is Button:
				var card = button._make_custom_tooltip(button.tooltip_text)
				success = verify(not card.get_node("Column/Title").text.is_empty(), "not card.get_node(\"Column/Title\").text.is_empty()") and success
				card.free()
	player.ap = 0
	arena.show_action_menu("throw")
	for button in arena.action_menu_list.get_children():
		if button is Button and not button.get_meta("menu_navigation", false):
			success = verify(button.disabled, "button.disabled") and success
	await process_frame
	var dock: Control = arena.get_node("UILayer/Control/CombatUI/Combat_bar/Combat_bar_Container/VBoxContainer/Combat_bar/MarginContainer/HBoxContainer/Action_Bar_Major")
	for button in arena.action_category_buttons.values():
		success = verify(dock.get_global_rect().encloses(button.get_global_rect()), "dock.get_global_rect().encloses(button.get_global_rect())") and success
	for child in arena.action_menu_list.get_children():
		arena.action_menu_list.remove_child(child)
		child.queue_free()
	for index in range(16):
		arena.add_action_menu_button("Action %d" % index, "", func(): pass)
	await process_frame
	success = verify(arena.minor_action_list.columns == 16, "All action choices stay on one row") and success
	success = verify(arena.minor_action_scroll.get_h_scroll_bar().max_value > arena.minor_action_scroll.get_h_scroll_bar().page, "arena.minor_action_scroll.get_h_scroll_bar().max_value > arena.minor_action_scroll.get_h_scroll_bar().page") and success
	var icon_button := Button.new()
	icon_button.text = "Icon Action"
	arena.style_minor_action_button(icon_button, load("res://assets/ui/Will.png"))
	success = verify(icon_button.text.is_empty() and icon_button.has_node("ActionIcon") and icon_button.get_node("ActionName").text == "Icon Action", "icon_button.text.is_empty() and icon_button.has_node(\"ActionIcon\") and icon_button.get_node(\"ActionName\").text == \"Icon Action\"") and success
	icon_button.free()
	arena.queue_free()
	await process_frame
	print("THROW_MENU_TEST: " + ("PASS" if success else "FAIL"))
	quit(0 if success else 1)

func verify(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
	return condition
