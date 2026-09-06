extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var arena = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	root.add_child(arena)
	var actor: CombatantState = arena.combat_system.get_combat_state().get_combatant("player")
	arena.combat_system.get_combat_state().current_actor_id = actor.id
	actor.position = Vector2(100, 100)
	actor.ap = 3
	actor.movement_in_progress = true
	actor.movement_remaining_feet = 5.0
	var token: Combatant = arena.get_node("PlayerCharacter")
	token.setup(actor)
	var preview: Dictionary = arena.movement_presentation.build_preview(Vector2(100, 1000))
	var success: bool = preview.endpoint.is_equal_approx(Vector2(100, 160)) and preview.text.contains("5.0 / 5.0 ft")
	actor.position = Vector2(160, 100)
	token.refresh_from_state()
	success = success and token.global_position.is_equal_approx(Vector2(100, 100)) and token.is_movement_animating()
	await create_timer(0.08).timeout
	success = success and token.global_position.x > 100.0 and token.global_position.x < 160.0
	var tween := token.movement_tween
	token.refresh_from_state()
	success = success and tween == token.movement_tween
	var turn: String = arena.combat_system.get_combat_state().current_actor_id
	arena.next_turn()
	success = success and arena.combat_system.get_combat_state().current_actor_id == turn
	await create_timer(0.3).timeout
	success = success and token.global_position.is_equal_approx(actor.position) and not token.is_movement_animating()
	arena.queue_free()
	await process_frame
	print("MOVEMENT_PRESENTATION_TEST: " + ("PASS" if success else "FAIL"))
	quit(0 if success else 1)
