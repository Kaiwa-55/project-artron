extends SceneTree

const PrototypeScene := preload("res://scenes/prototype/PrototypeCombat.tscn")
const UITheme := preload("res://scenes/ui/artron_ui_theme.gd")
const CombatTheme := preload("res://scenes/ui/combat_ui_theme.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var scene = PrototypeScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var ui: Control = scene.get_node("UILayer/Control")
	check(ui.theme == CombatTheme.RESOURCE, "Combat uses the saved compact Theme resource")
	var header: Panel = ui.get_node("Header")
	var target: Panel = ui.get_node("Enemy_panel")
	var log: PanelContainer = ui.get_node("CombatLogPanel")
	var prompt: Panel = ui.get_node("ReactionPrompt")
	var action_menu: PanelContainer = ui.get_node("ActionMenu")
	check(header.get_theme_stylebox("panel").bg_color == UITheme.CARD_BACKGROUND, "Combat header uses the shared surface color")
	check(target.get_theme_stylebox("panel").border_color == UITheme.GOLD, "Target card uses the shared accent border")
	check(log.get_theme_stylebox("panel").border_color == UITheme.CARD_BORDER and prompt.get_theme_stylebox("panel").border_color == UITheme.GOLD, "Combat log and reaction prompt share the theme")
	check(action_menu.get_theme_stylebox("panel").bg_color == UITheme.CARD_BACKGROUND, "Action menu uses the shared card surface")
	var combat_frame: NinePatchRect = ui.get_node("CombatUI/Combat_bar/Combat_bar_Container/VBoxContainer/Combat_bar")
	check(combat_frame.texture == null and combat_frame.has_node("ThemeSurface"), "Combat action bar replaces the legacy image frame with a theme surface")
	var log_button: Button = ui.get_node("CombatLogButton")
	check(log_button.get_theme_stylebox("normal").bg_color == UITheme.BUTTON_BACKGROUND and log_button.get_theme_stylebox("hover").border_color == UITheme.GOLD, "Combat controls use shared button states")
	var status: Label = ui.get_node("CombatUI/Combat_bar/Combat_bar_Container/VBoxContainer/StatusBar/Status")
	check(status.get_theme_color("font_color") == UITheme.MUTED, "Combat status strip uses the shared text color")
	check(status.label_settings == null and status.get_theme_font_size("font_size") == CombatTheme.BODY, "Legacy LabelSettings no longer override the status typography")
	scene._apply_responsive_layout()
	check(status.get_theme_stylebox("normal").bg_color == UITheme.BUTTON_BACKGROUND, "Resizing must preserve the status palette")
	var resource_path := "MarginContainer/HBoxContainer/DefenseAndResource/VBoxContainer/"
	for resource_name in ["Hp", "Mana", "Faith", "Heat"]:
		var progress: ProgressBar = combat_frame.get_node(resource_path + resource_name + "/ProgressBar")
		check(progress.modulate == Color.WHITE and not progress.show_behind_parent, "Resource values are readable above the themed surface without legacy tint")
	check(combat_frame.get_node(resource_path + "Mana/ProgressBar").get_theme_stylebox("fill").bg_color == UITheme.MANA_FILL, "Mana uses its semantic shared color")
	var end_label: Label = ui.get_node("CombatUI/Endturn/VBoxContainer/Label")
	check(end_label.label_settings == null and end_label.get_theme_color("font_color") == UITheme.GOLD, "End Turn uses the shared accent and no old blue/brown styling")
	var inventory: Control = ui.get_node("CharacterPanel")
	var sentinel := Label.new()
	sentinel.add_theme_color_override("font_color", Color.MAGENTA)
	inventory.add_child(sentinel)
	UITheme.apply_combat_theme(ui)
	check(sentinel.get_theme_color("font_color") == Color.MAGENTA, "Combat theming must not recurse into the Inventory component")
	scene.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("COMBAT_THEME_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
