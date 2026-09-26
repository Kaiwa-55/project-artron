extends SceneTree

const SmokeFlask = preload("res://data/item/smoke_flask.tres")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var arena = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	arena.set_script(preload("res://tests/helpers/idle_combat_ui.gd"))
	root.add_child(arena)
	await process_frame
	await process_frame
	var player: CombatantState = arena.combat_system.get_combat_state().get_combatant("player")
	var rules = arena.combat_system.map_rules
	arena.combat_system.get_combat_state().current_actor_id = player.id
	player.ap = player.max_ap
	player.item_inventory.append(ItemStack.new(SmokeFlask, 1))
	arena.show_action_menu("item")
	var smoke_button: Button
	for child in arena.action_menu_list.get_children():
		if child is Button and child.text.begins_with("Smoke Flask"):
			smoke_button = child
	var success: bool = smoke_button != null and not smoke_button.disabled
	if success:
		smoke_button.pressed.emit()
		success = arena.ground_targeting_kind == "item"
		arena.confirm_ground_targeting(player.position)
	await process_frame
	success = success and rules.temporary_light_areas.size() == 1
	if not success:
		arena.queue_free()
		await process_frame
		push_error("Smoke Flask must enter ground targeting and create its area from the Item menu.")
		print("SMOKE_AREA_VISUAL_TEST: FAIL")
		quit(1)
		return
	var area_id: int = int(rules.temporary_light_areas[0].id)
	var visual = arena.smoke_visuals_3d.get(area_id)
	success = is_instance_valid(visual) and visual.has_node("AreaFill") and visual.has_node("AreaOutline")
	rules.expire_temporary_light_areas(arena.combat_system.combat_state.current_round + 3)
	arena._sync_smoke_visuals_3d()
	success = success and arena.smoke_visuals_3d.is_empty()
	arena.queue_free()
	await process_frame
	if not success:
		push_error("Smoke circle must appear on the 3D battlefield and disappear when the area expires.")
	print("SMOKE_AREA_VISUAL_TEST: " + ("PASS" if success else "FAIL"))
	quit(0 if success else 1)
