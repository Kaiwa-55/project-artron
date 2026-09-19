extends SceneTree

var failures: Array[String] = []
var commands: Array[String] = []
var granted: Array = []
var granted_skills: Array = []
var attribute_changes: Array = []
var classes: Array = []

class KeySink extends Control:
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventKey:
			accept_event()

func _init() -> void:
	call_deferred("run_test")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func run_test() -> void:
	root.gui_embed_subwindows = true
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(640, 360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var arena = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	arena.set_script(preload("res://tests/helpers/gm_console_test_arena.gd"))
	root.add_child(arena)
	await process_frame
	await process_frame
	var console: Control = arena.gm_console
	check(not console.visible, "Console starts hidden")
	console.command_requested.connect(func(command): commands.append(command))
	console.class_requested.connect(func(data): classes.append(data))
	console.ability_requested.connect(func(data): granted.append(data))
	console.skill_requested.connect(func(data): granted_skills.append(data))
	console.attribute_requested.connect(func(attribute, delta): attribute_changes.append([attribute, delta]))
	var key_sink := KeySink.new()
	key_sink.focus_mode = Control.FOCUS_ALL
	key_sink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena.get_node("UILayer/Control").add_child(key_sink)
	key_sink.grab_focus()
	_toggle_key()
	await process_frame
	await process_frame
	check(console.visible, "First F1 opens console even when another control handles keyboard input")
	var repeat_key := InputEventKey.new()
	repeat_key.keycode = KEY_F1
	repeat_key.pressed = true
	repeat_key.echo = true
	root.push_input(repeat_key)
	check(console.visible, "Holding F1 does not toggle console again")
	key_sink.queue_free()
	check(root.get_visible_rect().encloses(console.get_global_rect()), "Console fits within the logical viewport")
	var player: CombatantState = arena.combat_system.get_combat_state().get_combatant("player")
	player.hp = 1
	await _click(_find_button(console, "FULL RESOURCES"), false)
	check(player.hp == player.max_hp, "Resource button restores HP")
	await _click(_find_button(console, "RESET COMBAT"))
	check(arena.reset_combat_requests == 1, "Reset Combat button restarts the encounter")
	# A pending presentation must not make the visible debug console inert.
	var token = arena.get_node("BattlefieldWorld/PlayerCharacter")
	token.movement_tween = token.create_tween()
	token.movement_tween.tween_interval(60.0)
	await process_frame
	player.hp = 1
	await _click(_find_button(console, "FULL RESOURCES"))
	check(player.hp == player.max_hp, "Console works while presentation input blocker is active")
	var outside := InputEventMouseMotion.new()
	outside.position = Vector2(10, 350)
	root.push_input(outside, true)
	check(root.gui_get_hovered_control() == arena.movement_presentation.blocker, "Gameplay remains blocked outside console during presentation")
	_toggle_key()
	check(not console.visible, "F1 closes console during presentation")
	_toggle_key()
	check(console.visible, "F1 opens console during presentation")
	token.movement_tween.kill()
	commands.clear()
	await _click(_find_button(console, "FULL RESOURCES"))
	await _click(_find_button(console, "RESET TURN"))
	var selected_ally := CombatantState.new()
	selected_ally.id = "gm_ally"
	selected_ally.team = player.team
	selected_ally.display_name = "GM Ally"
	selected_ally.max_hp = 10
	selected_ally.hp = 1
	arena.combat_system.get_combat_state().add_combatant(selected_ally)
	arena._select_character_from_initiative(selected_ally.id)
	await _click(_find_button(console, "HEAL 5"))
	await _click(_find_button(console, "DAMAGE 5"))
	check(selected_ally.hp == 1 and player.hp == player.max_hp, "Heal and Damage apply to the selected Turn Manager character")
	check(commands == ["full_resources", "reset_turn", "heal_target", "damage_target"], "All command buttons receive clicks")
	arena.selected_character_id = player.id
	for data in console._classes:
		await _click(_find_button(console, data.display_name.to_upper()))
	check(classes == console._classes, "All class buttons receive clicks")
	var picker: OptionButton = console._ability_picker
	await _click(picker)
	await process_frame
	picker.get_popup().hide()
	await _click(_find_button(console, "GRANT"))
	check(granted.size() == 1, "Grant button receives click")
	var skill_picker: OptionButton = console._skill_picker
	player.available_skills.clear()
	await _click(skill_picker)
	await process_frame
	skill_picker.get_popup().hide()
	await _click(_find_button(console, "GRANT SKILL"))
	check(granted_skills.size() == 1 and player.available_skills.has(granted_skills[0]), "Grant Skill adds the selected Skill")
	var scroll: ScrollContainer = console.get_child(0)
	scroll.scroll_vertical = 10000
	await process_frame
	var attribute_picker: OptionButton = console._attribute_picker
	attribute_picker.select(2)
	var constitution_before := player.constitution
	await _click(_find_button(console, "+1"))
	check(attribute_changes == [["CON", 1]] and player.constitution == constitution_before + 1, "Attribute control updates Constitution")
	scroll.scroll_vertical = 0
	await process_frame
	await _click(_find_button(console, "F1"))
	check(not console.visible, "Close button receives click")
	_toggle_key()
	check(console.visible, "F1 reopens after closing")
	_toggle_key()
	check(not console.visible, "F1 closes console")
	arena.queue_free()
	await process_frame
	for failure in failures:
		printerr(failure)
	print("GM_CONSOLE_INPUT_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _toggle_key() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_F1
	key.pressed = true
	root.push_input(key)
	key = key.duplicate()
	key.pressed = false
	root.push_input(key)

func _click(button: Button, move_mouse: bool = true) -> void:
	await process_frame
	check(button != null, "Button exists")
	if button == null:
		return
	check(root.get_visible_rect().encloses(button.get_global_rect()), "%s stays fully on screen" % button.text)
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	motion.global_position = motion.position
	if move_mouse:
		root.push_input(motion, true)
		check(root.gui_get_hovered_control() == button, "%s is not blocked by another control" % button.text)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = motion.position
	click.global_position = click.position
	click.pressed = true
	root.push_input(click, true)
	if button is OptionButton:
		check(button.get_popup().visible, "Ability picker opens on mouse press")
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)

func _find_button(parent: Node, button_text: String) -> Button:
	for child in parent.find_children("*", "Button", true, false):
		if child.text == button_text:
			return child
	return null

