extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var arena = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var actor: CombatantState = arena.combat_system.get_combat_state().get_current_actor()
	var actor_node: Node2D
	for combatant_node in arena.get_all_combatant_nodes():
		if combatant_node.state != null and combatant_node.state.id == actor.id:
			actor_node = combatant_node
			break
	var camera: BattlefieldCameraController = arena.get_node("BattlefieldCamera")
	camera.position = camera.map_bounds.end
	camera._clamp_to_map()
	var distance_before := camera.global_position.distance_to(actor_node.global_position)
	var focused: bool = arena.focus_camera_on_current_actor(0.0)
	var success := focused and camera.global_position.distance_to(actor_node.global_position) < distance_before
	arena.queue_free()
	await process_frame
	print("TURN_CAMERA_FOCUS_TEST: " + ("PASS" if success else "FAIL"))
	quit(0 if success else 1)
