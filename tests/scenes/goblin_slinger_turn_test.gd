extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var prototype = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	root.add_child(prototype)
	await process_frame
	var order: Array[String] = ["player", "ally", "goblin_slinger"]
	prototype.combat_system.combat_state.turn_order = order
	prototype.combat_system.combat_state.current_actor_id = "player"
	prototype.combat_system.combat_state.current_round = 1
	prototype.combat_system.start_current_turn()
	var safety := 0
	while prototype.combat_system.combat_state.current_round <= 2 and safety < 300:
		safety += 1
		if prototype.combat_system.has_pending_reaction():
			prototype.resolve_reaction_choice(-1)
		elif prototype.is_player_party_turn() and not prototype.is_movement_animating():
			prototype.next_turn()
		await create_timer(0.02).timeout
	var slinger_attacks := 0
	var animated_attacks := 0
	for event in prototype.combat_system.event_system.event_history:
		if event.source_id == "goblin_slinger" and event.type in [EventTypes.Type.ATTACK_HIT, EventTypes.Type.ATTACK_MISS]:
			slinger_attacks += 1
			if event.data.get("animation_template") != null:
				animated_attacks += 1
	if slinger_attacks == 0:
		push_error("Goblin Slinger must perform at least one Attack in the prototype Encounter. AI log: %s" % str(prototype.get_node("UILayer/Control").local_log_entries))
	if animated_attacks != slinger_attacks:
		push_error("Every Goblin Slinger Attack must have visible projectile feedback.")
	print("GOBLIN_SLINGER_TURN_TEST: " + ("PASS" if slinger_attacks > 0 and animated_attacks == slinger_attacks else "FAIL") + " attacks=" + str(slinger_attacks))
	prototype.queue_free()
	quit(0 if slinger_attacks > 0 and animated_attacks == slinger_attacks else 1)
