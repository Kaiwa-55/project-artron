extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var arena = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	root.add_child(arena)
	var attacker: Combatant = arena.get_node("PlayerCharacter")
	var target: Combatant = arena.get_node("EnemyCharacter2")
	var sword = load("res://data/attack/iron_sword.tres")
	var template = sword.animation_template
	var success: bool = template != null
	var origin := attacker.state.position
	var ap := attacker.state.ap
	var speed := attacker.state.movement_remaining_feet
	# Final attack events are queued; roll/declaration events do not animate.
	var result := AttackResult.new()
	result.hit = false
	var action_result: ActionResult = arena.combat_system.action_system.build_attack_result(attacker.state, target.state, sword, result)
	arena.combat_system.emit_events(action_result.events)
	success = success and arena.movement_presentation.sync_movement() and attacker.is_attack_animating()
	await create_timer(0.12).timeout
	success = success and attacker.visual_offset.length() > 0.0 and attacker.state.position == origin and attacker.global_position == origin
	# Repeated polling must not replay the same result.
	arena.movement_presentation.sync_movement()
	await create_timer(0.5).timeout
	success = success and attacker.visual_offset.is_zero_approx() and not arena.movement_presentation.sync_movement()
	success = success and attacker.state.ap == ap and attacker.state.movement_remaining_feet == speed
	# Reusing the same template and resetting during playback restores the visual.
	attacker.play_attack_animation(template, origin, target.state.position, target.state.collision_radius_feet, 12.0)
	await create_timer(0.08).timeout
	attacker.setup(attacker.state)
	success = success and attacker.visual_offset.is_zero_approx() and not attacker.is_attack_animating()
	arena.queue_free()
	await process_frame
	print("ATTACK_ANIMATION_TEST: " + ("PASS" if success else "FAIL"))
	quit(0 if success else 1)
