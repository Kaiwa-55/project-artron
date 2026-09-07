extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var arena = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	root.add_child(arena)
	# Let any opening enemy action finish before exercising the idle HUD.
	await create_timer(2.0).timeout
	arena.combat_system.pending_action = null
	arena.combat_system.pending_reaction = {}
	arena.combat_system.step_back_move_actor_id = ""
	arena.combat_system.ability_move_actor_id = ""
	var portrait: Control = arena.get_node("UILayer/Control/ReferencePlayerHUD").find_child("CharacterPortrait", true, false)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	portrait.gui_input.emit(event)
	var success: bool = arena.inventory_drawer.visible
	portrait.gui_input.emit(event)
	success = success and arena.inventory_drawer.visible
	arena.inventory_drawer.hide()
	event.button_index = MOUSE_BUTTON_RIGHT
	portrait.gui_input.emit(event)
	success = success and not arena.inventory_drawer.visible
	arena.combat_system.pending_action = ActionRequest.new("player", ActionTypes.Type.ATTACK)
	arena.combat_system.pending_reaction = {"reactions": ["test"]}
	event.button_index = MOUSE_BUTTON_LEFT
	portrait.gui_input.emit(event)
	success = success and not arena.inventory_drawer.visible
	arena.queue_free()
	await process_frame
	print("PORTRAIT_CHARACTER_PANEL_TEST: " + ("PASS" if success else "FAIL"))
	quit(0 if success else 1)
