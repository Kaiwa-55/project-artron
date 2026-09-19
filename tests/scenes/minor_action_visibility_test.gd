extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var arena = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	arena.set_script(preload("res://tests/helpers/idle_combat_ui.gd"))
	root.add_child(arena)
	arena.combat_system.get_combat_state().current_actor_id = "player"
	arena.combat_system.start_current_turn()
	await process_frame
	await process_frame
	var minor_actions: VBoxContainer = arena.get_node("UILayer/Control/CombatUI/Combat_bar/Action_bar_Minor")
	var success := not minor_actions.visible
	arena.show_action_menu("attack")
	await process_frame
	success = success and minor_actions.visible and arena.action_menu_list.get_child_count() > 0
	var first_action: Control = arena.action_menu_list.get_child(0)
	success = success and first_action.custom_minimum_size == Vector2(80, 26) and minor_actions.size.y <= 76.1
	arena.queue_free()
	await process_frame
	print("MINOR_ACTION_VISIBILITY_TEST: " + ("PASS" if success else "FAIL"))
	quit(0 if success else 1)
