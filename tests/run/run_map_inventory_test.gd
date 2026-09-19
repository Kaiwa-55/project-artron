extends SceneTree

const RunMapScene := preload("res://scenes/run/RunMap.tscn")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var failures: Array[String] = []
	var run_map = RunMapScene.instantiate()
	root.add_child(run_map)
	await process_frame
	var buttons: Array[Node] = run_map.party_inventory.get_children()
	check(buttons.size() == run_map.run_state.party_progression_states.size(), "Run Map creates one Inventory button per party member", failures)
	var first_id: String = run_map.get_party_entries()[0].id
	run_map.open_party_inventory(first_id)
	check(run_map.character_panel.visible, "Party Inventory opens from Run Map", failures)
	check(run_map.character_panel.standalone_character.id == first_id, "Inventory shows the selected party member", failures)
	check(not run_map.character_panel.changes_locked, "Run Map allows equipment changes", failures)
	for resolution in [Vector2i(640, 360), Vector2i(1280, 720), Vector2i(1906, 1052)]:
		root.size = resolution
		for tab in ["inventory", "equipment", "abilities"]:
			run_map.character_panel.set_tab(tab)
			for frame in range(4):
				await process_frame
			var panel = run_map.character_panel
			var viewport_bounds := Rect2(Vector2.ZERO, root.get_visible_rect().size)
			check(viewport_bounds.encloses(panel.inventory_view.get_global_rect()), "Map window fits viewport at %s on %s" % [resolution, tab], failures)
			check(viewport_bounds.encloses(panel.exit_button.get_global_rect()), "Close button stays on screen at %s on %s" % [resolution, tab], failures)
			if "--map-inventory-screenshots" in OS.get_cmdline_user_args() and resolution == Vector2i(1906, 1052):
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://work/map-%s-fixed.png" % tab)
	var member: CombatantState = run_map.character_panel.standalone_character
	var equipment = member.equipment_inventory.filter(func(item): return item != null and item.slot != EquipmentData.Slot.ARMOR).front()
	var ap_before := member.ap
	run_map.character_panel.equipment_change_requested.emit(equipment, 3)
	check(member.equipped_items.get(3) == equipment, "Run Map equips the selected item for this party member", failures)
	check(member.ap == ap_before, "Run Map equipment changes do not spend Combat AP", failures)
	var armor = member.equipment_inventory.filter(func(item): return item != null and item.slot == EquipmentData.Slot.ARMOR).front()
	var fortitude_before := member.fortitude
	var reflex_before := member.reflex
	run_map.character_panel.equipment_change_requested.emit(armor, EquipmentData.Slot.ARMOR)
	check(member.equipped_items.get(EquipmentData.Slot.ARMOR) == armor, "Run Map allows changing Body armor", failures)
	check(member.fortitude == fortitude_before + armor.fortitude_bonus, "Equipping armor immediately recalculates Fortitude", failures)
	check(member.reflex == reflex_before + armor.reflex_bonus, "Equipping armor immediately recalculates Reflex", failures)
	var passive_bonus := AbilitySystem.new().get_passive_defense_bonus(member)
	check(run_map.character_panel.defense_labels["Fortitude"].text == "Fortitude  %d" % (member.fortitude + passive_bonus), "Inventory refreshes displayed Fortitude immediately", failures)
	check(run_map.character_panel.defense_labels["Reflex"].text == "Reflex  %d" % (member.reflex + passive_bonus), "Inventory refreshes displayed Reflex immediately", failures)
	run_map.queue_free()
	if failures.is_empty():
		print("RUN_MAP_INVENTORY_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
