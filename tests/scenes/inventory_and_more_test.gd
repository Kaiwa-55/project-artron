extends SceneTree

const Scene := preload("res://InventoryandMore.tscn")
const PlayerData := preload("res://data/character/player.tres")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var failures: Array[String] = []
	var panel = Scene.instantiate()
	root.add_child(panel)
	await process_frame
	var player: CombatantState = PlayerData.create_combatant_state()
	panel.setup_standalone(player, "inventory")
	await process_frame
	check(panel.active_tab == "inventory", "Inventory tab opens", failures)
	check(panel.get_visible_entry_count() == player.item_inventory.size() + player.equipment_inventory.size(), "Inventory reads CombatantState", failures)
	check(panel.item_grid.get_child_count() == 16, "Inventory keeps sixteen authored slots", failures)
	check(panel.page_number.text.begins_with("1 / "), "Pagination is initialized", failures)
	check(panel.summary.get_child_count() > 4 and panel.tab_buttons.size() == 3, "CharacterPanel compatibility API remains complete", failures)
	if not player.equipment_inventory.is_empty():
		var source: Control = panel.item_grid.get_child(0).get_node("EntryButton")
		check(source.tooltip_text.is_empty(), "Inventory items do not show the default black description tooltip", failures)
		panel._show_item_preview(player.equipment_inventory[0], source)
		check(panel.item_preview.visible and panel.item_preview.entry == player.equipment_inventory[0], "Hover opens ItemWhenSelectedPanel with the hovered entry", failures)
		panel._hide_item_preview()
		check(not panel.item_preview.visible, "Leaving an Item hides ItemWhenSelectedPanel", failures)
	panel.set_changes_locked(false)
	var used_items: Array = []
	panel.item_use_requested.connect(func(item): used_items.append(item))
	if not player.item_inventory.is_empty():
		panel._select_entry(player.item_inventory[0])
		panel.use_button.pressed.emit()
	check(player.item_inventory.is_empty() or used_items.size() == 1, "Use button emits the selected Item through the API", failures)
	panel.set_tab("equipment")
	check(panel.get_visible_entry_count() == player.equipment_inventory.size(), "Equipment tab reads Equipment inventory", failures)
	check(panel.page_title.text == "Equipment", "Authored header follows active tab", failures)
	if not player.equipment_inventory.is_empty():
		panel._select_entry(player.equipment_inventory[0])
		check(panel.equipment_action_bar.visible and panel.equipment_action_bar.get_child_count() > 0, "Selecting Equipment shows slot choice buttons", failures)
	for index in range(4):
		var ability := AbilityData.new()
		ability.id = "profile_page_test_%d" % index
		ability.display_name = "Profile Test %d" % index
		ability.required_trait_ids.append("devotee")
		player.available_abilities.append(ability)
	panel.set_tab("abilities")
	check(panel.profile_view.visible and not panel.equipment_view.visible, "Character tab switches authored panels", failures)
	check(panel.profile_ability_scroll != null and panel.profile_ability_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "Ability list supports vertical scrolling", failures)
	check(panel.profile_runtime_ability_cards.size() >= 3, "Overflowing Ability categories render every card in the scroll list", failures)
	check(panel.profile_ability_slots[0].get_node_or_null("AbilityButton") != null, "Class Ability is rendered in the Class card", failures)
	var profile_ability_button := panel.profile_ability_slots[0].get_node_or_null("AbilityButton") as Button
	check(profile_ability_button == null or profile_ability_button.tooltip_text.is_empty(), "Profile Abilities do not show the default black description tooltip", failures)
	for slot in panel.profile_ability_slots:
		check(slot.get_node_or_null("frame") != null, "Every Ability category reuses the authored card component", failures)
	var class_card_name: Label = panel.profile_ability_slots[0].get_node("frame").find_child("Name", true, false) as Label
	check(class_card_name != null and class_card_name.text != "Name", "Runtime Ability data replaces authored placeholder text", failures)
	check(panel.profile_next_button == null or not panel.profile_next_button.is_visible_in_tree(), "Ability pagination controls are hidden", failures)
	var profile_name: Label = panel.profile_view.get_node("Profilecontainer/VBoxContainer/HBoxContainer/CharacterDetail/VBox/Name")
	check(profile_name.text == player.display_name, "Profile fields read CombatantState", failures)
	panel.set_tab("craft")
	check(panel.detail_label.text == "Crafting API is not available yet", "Unavailable crafting is explicit", failures)
	var closed_events: Array[bool] = []
	panel.closed.connect(func(): closed_events.append(true))
	var exit_position: Vector2 = panel.exit_button.global_position
	panel.profile_ability_scroll.scroll_vertical = 100
	await process_frame
	check(panel.exit_button.global_position.is_equal_approx(exit_position), "ExitButton remains fixed while Ability content scrolls", failures)
	panel.exit_button.pressed.emit()
	check(not panel.visible and closed_events.size() == 1, "ExitButton closes Inventory And More through the panel API", failures)
	panel.queue_free()
	await process_frame
	if failures.is_empty():
		print("INVENTORY_AND_MORE_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
