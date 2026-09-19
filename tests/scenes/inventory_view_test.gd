extends SceneTree

const UITheme := preload("res://scenes/ui/artron_ui_theme.gd")
var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	root.size = Vector2i(640, 360)
	var panel = load("res://InventoryandMore.tscn").instantiate()
	root.add_child(panel)
	var player := CombatantState.new()
	player.display_name = "Arden"
	player.max_hp = 30
	player.hp = 24
	player.max_mana = 12
	player.mana = 8
	player.ap = 3
	for index in range(24):
		var item := ItemData.new()
		item.display_name = "Healing Potion" if index == 0 else "Moonstone %02d" % index
		item.description = "Restores vitality. Choose a party member to use this item on." if index == 0 else "A pale stone carried in your backpack."
		item.category = ItemData.Category.CONSUMABLE if index == 0 else ItemData.Category.MATERIAL
		player.item_inventory.append(ItemStack.new(item, index + 1))
	panel.setup_standalone(player, "inventory", true)
	await process_frame
	await process_frame
	var view = panel.inventory_view
	check(view.is_visible_in_tree() and view.body.visible and not panel.has_node("PanelContainer"), "Inventory uses the native window without the old scene")
	check(view.theme.default_font_size == UITheme.FONT_SIZE and view.get_theme_stylebox("panel").bg_color == UITheme.WINDOW_BACKGROUND, "Inventory reads typography and window styling from the shared UI theme")
	check(view.entries.get_child_count() == 24, "Scrollable list includes all stacks")
	view.entries.get_child(0).pressed.emit()
	check(panel.selected_entry == player.item_inventory[0] and view.item_name.text == "Healing Potion", "Selecting a row updates item details")
	check(view.use_button.disabled, "Use is disabled when the hosting scene cannot handle item actions")
	var used: Array = []
	panel.item_use_requested.connect(func(item): used.append(item))
	panel.refresh()
	check(not view.use_button.disabled, "An unlocked inventory with an item action handler enables Use")
	view.use_button.pressed.emit()
	check(used.size() == 1 and used[0] == player.item_inventory[0].item, "Native Use button emits the existing item action")
	panel.set_changes_locked(true)
	check(view.use_button.disabled, "Locked inventories disable Use")
	panel.set_changes_locked(false)
	view.search.text = "healing"
	view.search.text_changed.emit(view.search.text)
	check(view.entries.get_child_count() == 1, "Search filters by item name")
	view.category.select(3)
	view.category.item_selected.emit(3)
	check(view.entries.get_child_count() == 0 and view.empty_label.visible, "Filter and search show an empty result message")
	view.search.clear()
	view.category.select(0)
	view.category.item_selected.emit(0)
	for viewport_size in [Vector2i(640, 360), Vector2i(1280, 720)]:
		root.size = viewport_size
		await process_frame
		await process_frame
		check(panel.get_global_rect().encloses(view.get_global_rect()), "Window fits the viewport at %s: parent %s, window %s" % [viewport_size, panel.get_global_rect(), view.get_global_rect()])
		check(view.get_global_rect().encloses(view.use_button.get_global_rect()), "Use button stays inside the window")
	root.size = Vector2i(640, 360)
	await process_frame
	await process_frame
	panel.offset_top = 60
	panel.offset_bottom = -16
	await process_frame
	await process_frame
	check(panel.get_global_rect().encloses(view.get_global_rect()), "Window fits the combat HUD's available area: %s inside %s" % [view.get_global_rect(), panel.get_global_rect()])
	panel.offset_top = 0
	panel.offset_bottom = 0
	await process_frame
	await process_frame
	if "--inventory-screenshot" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://work/inventory-redesign.png")
	player.item_inventory.clear()
	panel.refresh()
	check(view.empty_label.visible and view.use_button.disabled and panel.selected_entry == null, "Removing the selected stack clears stale details and actions")
	panel.set_tab("equipment")
	check(not view.body.visible and panel.equipment_view.visible, "Equipment navigation remains available")
	panel.set_tab("inventory")
	view.close_requested.emit()
	check(not panel.visible, "Close hides the whole window")
	panel.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("INVENTORY_VIEW_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
