extends SceneTree

const PrototypeScene := preload("res://scenes/prototype/PrototypeCombat.tscn")

var failures: Array[String] = []


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func rect_fits(control: Control, viewport_size: Vector2) -> bool:
	return control.position.x >= -0.1 \
		and control.position.y >= -0.1 \
		and control.position.x + control.size.x <= viewport_size.x + 0.1 \
		and control.position.y + control.size.y <= viewport_size.y + 0.1


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var scene = PrototypeScene.instantiate()
	root.add_child(scene)
	await process_frame
	for viewport_size in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		DisplayServer.window_set_size(viewport_size)
		await process_frame
		var ui: Control = scene.get_node("UILayer/Control")
		scene._apply_responsive_layout()
		await process_frame
		var logical_size := ui.size
		for path in ["Header", "BottomActionRow", "ReferencePlayerHUD", "Enemy_panel", "CombatLogPanel", "ActionMenu", "CharacterPanel"]:
			var control: Control = ui.get_node(path)
			check(rect_fits(control, logical_size), "%s (%s, %s) must fit inside the %dx%d layout" % [path, control.position, control.size, int(logical_size.x), int(logical_size.y)])
		var bottom_row: HBoxContainer = ui.get_node("BottomActionRow")
		var action_dock: Control = bottom_row.get_node("ReferenceActionDock")
		var turn_hud: Control = bottom_row.get_node("ReferenceTurnHUD")
		check(bottom_row.position.y + bottom_row.size.y <= logical_size.y, "Bottom Action Row stays attached to the bottom safe area")
		check(action_dock.get_parent() == turn_hud.get_parent() and action_dock.get_parent() is HBoxContainer, "Action Bar and End Turn share one HBoxContainer")
		var player_hud: Control = ui.get_node("ReferencePlayerHUD")
		var player_status: Label = ui.get_node("ReferencePlayerHUD/Margin/Row/PlayerStatus")
		var portrait: TextureRect = ui.get_node("ReferencePlayerHUD/Margin/Row/CharacterPortrait")
		check(player_hud.size.x >= 300.0, "Player HUD reserves enough width for calculated character stats")
		check(not player_status.clip_text and player_status.autowrap_mode != TextServer.AUTOWRAP_OFF, "Player HUD wraps long Class and Resource text instead of clipping it")
		check(portrait.custom_minimum_size.x <= 78.0, "Player portrait leaves enough horizontal space for stats")
		check(is_equal_approx(player_hud.position.x + player_hud.size.x, turn_hud.global_position.x + turn_hud.size.x), "Player HUD aligns its right edge with End Turn")
		check(player_hud.position.y + player_hud.size.y <= bottom_row.position.y - 7.9, "Player HUD stays above End Turn")
	var state = scene.combat_system.get_combat_state()
	var player: CombatantState = state.get_combatant("player")
	state.current_actor_id = player.id
	player.effects.clear()
	player.movement_in_progress = false
	player.movement_remaining_feet = 0.0
	player.movement_distance_this_turn = player.get_effective_speed()
	scene.refresh_action_dock()
	check(scene.action_category_buttons["move"].disabled, "Move button is disabled after all Speed has been used")
	player.movement_distance_this_turn = 0.0
	var slowed = load("res://data/status/slowed.tres").duplicate(true)
	slowed.stacks_on_apply = 100
	scene.combat_system.effect_system.apply_effect(player, slowed)
	scene.refresh_action_dock()
	check(is_zero_approx(player.get_effective_speed()), "Slowed test setup reduces current Speed to zero")
	check(scene.action_category_buttons["move"].disabled, "Move button is disabled when Slowed reduces Speed to zero")
	scene.queue_free()
	for failure in failures:
		push_error(failure)
	print("RESPONSIVE_COMBAT_UI_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
