extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var failures: Array[String] = []
	var arena = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	root.add_child(arena)
	# Drive presentation manually so Prototype AI/_process cannot race this test's
	# event queue between assertions.
	arena.movement_presentation.set_process(false)
	arena.combat_system.combat_state.combat_result = CombatEnums.CombatResult.VICTORY
	for token in arena.get_all_combatant_nodes():
		token.setup(token.state)
	var attacker: Combatant = arena.get_node("BattlefieldWorld/PlayerCharacter")
	var target: Combatant = arena.get_node("BattlefieldWorld/EnemyCharacter")
	arena.combat_system.combat_state.current_actor_id = attacker.state.id
	# Ignore setup/AI events so this test observes only the event emitted below.
	arena.movement_presentation.collect_attack_animations()
	arena.movement_presentation.event_cursor = arena.combat_system.event_system.event_history.size()
	arena.movement_presentation.attack_queue.clear()
	var sword = load("res://data/attack/iron_sword.tres")
	var template = sword.animation_template
	check(template != null, "Iron Sword has an animation template", failures)
	var origin := attacker.state.position
	var ap := attacker.state.ap
	var speed := attacker.state.movement_remaining_feet
	# Final attack events are queued; roll/declaration events do not animate.
	var result := AttackResult.new()
	result.hit = false
	var action_result: ActionResult = arena.combat_system.action_system.build_attack_result(attacker.state, target.state, sword, result)
	arena.combat_system.emit_events(action_result.events)
	check(arena.movement_presentation.sync_movement(), "Final attack event is consumed by presentation", failures)
	check(attacker.is_attack_animating(), "Attacker begins the template animation", failures)
	await create_timer(0.08).timeout
	check(attacker.state.position == origin and attacker.global_position == origin, "Attack animation does not alter logical position", failures)
	# Repeated polling must not replay the same result.
	arena.movement_presentation.sync_movement()
	await create_timer(0.5).timeout
	check(attacker.visual_offset.is_zero_approx(), "Attack visual returns to origin", failures)
	check(not arena.movement_presentation.sync_movement(), "Processed attack event is not replayed", failures)
	check(attacker.state.ap == ap and attacker.state.movement_remaining_feet == speed, "Presentation does not change AP or movement", failures)
	# Effect-only Abilities use the same presentation queue without an AttackData.
	var ability_event := CombatEvent.new(EventTypes.Type.ABILITY_TRIGGERED, attacker.state.id, target.state.id, {
		"ability_name": "Animated Ability",
		"animation_template": template,
		"animation_origin": attacker.state.position,
		"animation_target": target.state.position,
	})
	var animated_ability_events: Array[CombatEvent] = [ability_event]
	arena.combat_system.emit_events(animated_ability_events)
	check(arena.movement_presentation.sync_movement(), "Animated Ability event is consumed by presentation", failures)
	check(attacker.is_attack_animating(), "Effect-only Ability starts its assigned animation", failures)
	await create_timer(0.5).timeout
	# Reusing the same template and resetting during playback restores the visual.
	attacker.play_attack_animation(template, origin, target.state.position, target.state.collision_radius_feet, 12.0)
	await create_timer(0.08).timeout
	attacker.setup(attacker.state)
	check(attacker.visual_offset.is_zero_approx() and not attacker.is_attack_animating(), "Setup safely resets an animation in progress", failures)
	arena.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("ATTACK_ANIMATION_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition: failures.append(message)
