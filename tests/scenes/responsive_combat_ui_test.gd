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
	# Decorative nodes may be removed in the editor; initialization must still finish.
	var decoration = scene.get_node("UILayer/Control/CombatUI/Combat_bar/Combat_bar_Container/VBoxContainer/Combat_bar/MarginContainer/HBoxContainer/Action_Bar_Major/Attack/TextureRect")
	decoration.free()
	root.add_child(scene)
	await process_frame
	for viewport_size in [Vector2i(640, 360), Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		DisplayServer.window_set_size(viewport_size)
		root.size = viewport_size
		await process_frame
		var ui: Control = scene.get_node("UILayer/Control")
		scene._apply_responsive_layout()
		await process_frame
		var logical_size := ui.size
		if "--capture-combat" in OS.get_cmdline_user_args() and viewport_size == Vector2i(640, 360):
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://work/combat-layout.png")
		for path in ["Header", "CombatUI/Combat_bar", "CombatUI/Endturn", "Enemy_panel", "CombatLogPanel", "ActionMenu", "CharacterPanel"]:
			var control: Control = ui.get_node(path)
			check(rect_fits(control, logical_size), "%s (%s, %s) must fit inside the %dx%d layout" % [path, control.position, control.size, int(logical_size.x), int(logical_size.y)])
		var combat_bar: Control = ui.get_node("CombatUI/Combat_bar")
		var turn_hud: Control = ui.get_node("CombatUI/Endturn")
		var portrait: TextureRect = ui.get_node("CombatUI/Combat_bar/Combat_bar_Container/VBoxContainer/Combat_bar/MarginContainer/HBoxContainer/Profile/TextureRect")
		var action_grid: GridContainer = ui.get_node("CombatUI/Combat_bar/Combat_bar_Container/VBoxContainer/Combat_bar/MarginContainer/HBoxContainer/Action_Bar_Major")
		var minor_actions: VBoxContainer = ui.get_node("CombatUI/Combat_bar/Action_bar_Minor")
		var frame: Control = ui.get_node("CombatUI/Combat_bar/Combat_bar_Container/VBoxContainer/Combat_bar")
		check(frame.get_global_rect().encloses(frame.get_node("BG").get_global_rect()), "Combat background must not spill into minor actions")
		for slot in scene.minor_action_placeholder.get_children():
			check(slot.get_node("Label").text.is_empty(), "Empty action slots must not display editor placeholder text")
		var header: Control = ui.get_node("Header")
		var initiative_timeline: Control = ui.get_node("Header/InitiativeTimeline")
		var combat_log_button: Control = ui.get_node("CombatLogButton")
		var combat_log_panel: Control = ui.get_node("CombatLogPanel")
		check(combat_bar.position.y + combat_bar.size.y <= logical_size.y, "Combat bar stays attached to the bottom safe area")
		check(not combat_bar.get_global_rect().intersects(turn_hud.get_global_rect()), "Combat bar should not overlap End Turn")
		check(portrait.size.x <= 32.1 and portrait.size.y <= 32.1, "Character portrait must ignore its source image size")
		check(combat_bar.get_global_rect().encloses(action_grid.get_global_rect()), "Character portrait must not push Action buttons outside the Combat bar")
		check(minor_actions.visible and combat_bar.get_global_rect().encloses(minor_actions.get_global_rect()), "Minor Action slots should keep their authored position inside the Combat bar")
		check(header.get_global_rect().encloses(initiative_timeline.get_global_rect()), "Turn Order must fit inside the combat header")
		check(not combat_log_button.get_global_rect().intersects(initiative_timeline.get_global_rect()), "Combat Log button must not overlap Turn Order")
		check(not combat_log_panel.get_global_rect().intersects(header.get_global_rect()), "Combat Log panel %s must open below Turn Order %s" % [combat_log_panel.get_global_rect(), header.get_global_rect()])
		if logical_size.x > 700.0 and logical_size.y > 400.0:
			check(not combat_log_panel.get_global_rect().intersects(combat_bar.get_global_rect()), "Combat Log panel must stay above the combat bar")
		if viewport_size == Vector2i(640, 360):
			check(combat_bar.scale.is_equal_approx(Vector2.ONE), "Combat bar text must not be blurred by fractional scaling")
			check(combat_bar.size.x <= 414.1 and combat_bar.size.y <= 108.1, "Combat bar must use integer compact dimensions at 640x360")
			check(combat_log_panel.size.x <= 120.1 and combat_log_panel.size.y >= 295.0, "Combat Log panel %s must be half-width and extend to the bottom edge at 640x360" % combat_log_panel.size)
			var log_entries: VBoxContainer = ui.get_node("CombatLogPanel/Margin/VBoxContainer/Scroll/Entries")
			for card in log_entries.get_children():
				check(card.custom_minimum_size.y <= 56.1, "Combat Log cards must use their narrow 640x360 height")
	var state = scene.combat_system.get_combat_state()
	var player: CombatantState = state.get_combatant("player")
	var profile_path := "UILayer/Control/CombatUI/Combat_bar/Combat_bar_Container/VBoxContainer/Combat_bar/MarginContainer/HBoxContainer/Profile"
	check((scene.get_node(profile_path + "/Weapon") as Label).text.begins_with("Weapon: "), "Combat bar should show the equipped weapon")
	check((scene.get_node(profile_path + "/Resistance") as Label).text.begins_with("RES "), "Combat bar should compact Resistance into a tooltip badge")
	check((scene.get_node(profile_path + "/Imunity") as Label).text.begins_with("IMM "), "Combat bar should compact Immunity into a tooltip badge")
	check((scene.get_node("UILayer/Control/CombatUI/Combat_bar/Combat_bar_Container/VBoxContainer/StatusBar/Status") as Label).text.begins_with("STATUS: "), "Combat bar should show a compact Status strip")
	check((scene.get_node("UILayer/Control/CombatUI/Combat_bar/Combat_bar_Container/VBoxContainer/Combat_bar/MarginContainer/HBoxContainer/DefenseAndResource/VBoxContainer/Hp/ProgressBar/Value") as Label).text.begins_with("HP "), "Combat resource bars should include their names")
	scene.show_action_menu("attack")
	var has_cost_badge := false
	for action in scene.action_menu_list.get_children():
		if action is Button and action.get_node_or_null("CostBadge") != null:
			has_cost_badge = true
	check(has_cost_badge, "Combat action choices should show a resource-cost badge")
	state.current_actor_id = player.id
	player.effects.clear()
	player.movement_in_progress = false
	player.movement_remaining_feet = 0.0
	player.movement_distance_this_turn = player.get_effective_speed()
	scene.refresh_action_dock()
	check(not scene.action_category_buttons["move"].disabled, "Move button stays enabled for another Move action when AP remains")
	var saved_ap := player.ap
	player.ap = 0
	scene.refresh_action_dock()
	check(scene.action_category_buttons["move"].disabled, "Move button is disabled when a new Move cannot pay its AP cost")
	check(scene.action_category_buttons["move"].get_parent().modulate.r < 0.6, "Disabled Action categories should be visibly dimmed")
	player.ap = saved_ap
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
