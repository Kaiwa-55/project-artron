extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var arena = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	root.add_child(arena)
	# Freeze the encounter on the Player before deferred Enemy AI can alter UI state.
	arena.combat_system.get_combat_state().current_actor_id = "player"
	for frame in range(3):
		await process_frame
	var system = arena.combat_system
	system.pending_action = null
	system.pending_reaction = {}
	system.step_back_move_actor_id = ""
	system.ability_move_actor_id = ""
	system.get_combat_state().current_actor_id = "player"
	var player: CombatantState = system.get_combat_state().get_combatant("player")
	player.ap = player.max_ap
	var panel = arena.inventory_drawer
	panel.set_changes_locked(false)
	panel.show()
	panel.set_tab("equipment")
	await process_frame
	var button: Button
	for row in panel.content_list.get_children():
		if row is HBoxContainer:
			for child in row.get_children():
				if child is Button and child.text == "Equip Hand 2 - 1 AP" and not child.disabled:
					button = child
					break
		if button != null:
			break
	var success: bool = button != null
	var ap := player.ap
	for frame in range(5):
		await process_frame
	success = success and is_instance_valid(button) and button.is_inside_tree()
	if is_instance_valid(button):
		button.pressed.emit()
		success = success and player.ap == ap - 1 and player.equipped_items.has(3)
	panel.set_changes_locked(true)
	for row in panel.content_list.get_children():
		if row is HBoxContainer:
			for child in row.get_children():
				if child is Button:
					success = success and child.disabled
	arena.queue_free()
	await process_frame
	print("EQUIPMENT_BUTTON_TEST: " + ("PASS" if success else "FAIL"))
	quit(0 if success else 1)
