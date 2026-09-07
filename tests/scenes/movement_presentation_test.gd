extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var failures: Array[String] = []
	var arena = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	root.add_child(arena)
	var actor: CombatantState = arena.combat_system.get_combat_state().get_combatant("player")
	arena.combat_system.get_combat_state().current_actor_id = actor.id
	actor.position = Vector2(100, 100)
	actor.ap = 3
	actor.movement_in_progress = true
	actor.movement_remaining_feet = 5.0
	var token: Combatant = arena.get_node("BattlefieldWorld/PlayerCharacter")
	token.setup(actor)
	var preview: Dictionary = arena.movement_presentation.build_preview(Vector2(100, 1000))
	check(preview.endpoint.is_equal_approx(Vector2(100, 160)) and preview.text.contains("5.0 / 5.0 ft"), "Preview clamps to remaining 5 ft", failures)
	actor.position = Vector2(160, 100)
	token.refresh_from_state()
	check(token.global_position.is_equal_approx(Vector2(100, 100)) and token.is_movement_animating(), "Token starts interpolating from its previous position", failures)
	await create_timer(0.08).timeout
	check(token.is_movement_animating() or token.global_position.is_equal_approx(actor.position), "Token is animating or has already reached the destination", failures)
	var tween := token.movement_tween
	token.refresh_from_state()
	check(tween == token.movement_tween, "Refresh does not restart the same movement tween", failures)
	var turn: String = arena.combat_system.get_combat_state().current_actor_id
	arena.next_turn()
	check(arena.combat_system.get_combat_state().current_actor_id == turn, "End Turn remains locked while movement animates", failures)
	await create_timer(0.4).timeout
	check(token.global_position.is_equal_approx(actor.position) and not token.is_movement_animating(), "Token reaches its logical destination", failures)
	arena.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("MOVEMENT_PRESENTATION_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition: failures.append(message)
