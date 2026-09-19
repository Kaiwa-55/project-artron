extends RefCounted
## Compact combat variant. Palette and states remain shared with Inventory.
const Shared := preload("res://scenes/ui/artron_ui_theme.gd")
const RESOURCE := preload("res://scenes/ui/themes/combat_theme.tres")
const BODY := 8
const HEADING := 10
const DOCK_HEIGHT := 76.0
const DOCK_WIDTH := 400.0
const HEADER_HEIGHT := 30.0


static func text(label: Label, font_size: int = BODY, color: Color = Shared.TEXT) -> void:
	# Authored LabelSettings take priority over Theme; remove that competing source.
	label.label_settings = null
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func apply(ui: Control) -> void:
	ui.theme = RESOURCE
	var dock: Control = ui.get_node("CombatUI/Combat_bar")
	var menu_close: Button = dock.get_node("Action_bar_Minor/MenuHeader/Close")
	menu_close.custom_minimum_size = Vector2(32, 16)
	for state in ["normal", "hover", "pressed", "disabled"]:
		menu_close.add_theme_stylebox_override(state, Shared.style(Shared.BUTTON_BACKGROUND, Shared.CARD_BORDER, 2))
	text(dock.get_node("Action_bar_Minor/MenuHeader").get_child(0), BODY, Shared.GOLD)
	dock.get_node("Action_bar_Minor/MenuHeader").get_child(0).add_theme_stylebox_override("normal", Shared.style(Shared.CARD_BACKGROUND, Shared.CARD_BORDER, 3))
	var content: HBoxContainer = dock.get_node("Combat_bar_Container/VBoxContainer/Combat_bar/MarginContainer/HBoxContainer")
	content.add_theme_constant_override("separation", 10)
	var profile: VBoxContainer = content.get_node("Profile")
	for label in profile.get_children():
		if label is Label:
			text(label, BODY, Shared.GOLD if label.name == "Name" else Shared.MUTED)
	# Secondary character details remain in the portrait tooltip / Character window.
	for field in ["Weapon", "Resistance", "Imunity"]:
		profile.get_node(field).hide()
	var defenses: HBoxContainer = content.get_node("DefenseAndResource/HBoxContainer")
	for defense in defenses.get_children():
		defense.add_theme_constant_override("separation", 3)
		defense.get_node("TextureRect").hide()
		text(defense.get_node("Value"), BODY)
		var caption: Label = defense.get_node(NodePath(defense.name))
		caption.text = {"Fortitude": "FORT", "Reflex": "REF", "Will": "WILL"}[str(defense.name)]
		text(caption, BODY, Shared.MUTED)
		defense.move_child(caption, 0)
	var resources: VBoxContainer = content.get_node("DefenseAndResource/VBoxContainer")
	resources.add_theme_constant_override("separation", 3)
	resources.clip_contents = false
	for resource in resources.get_children():
		resource.custom_minimum_size = Vector2(84, 12)
		text(resource.get_node("ProgressBar/Value"))
	for card in content.get_node("Action_Bar_Major").get_children():
		text(card.get_node("Label"))
		card.get_node("Label").hide()
		var button: Button = card.get_node("Button")
		button.text = card.name.to_upper()
		button.flat = false
		button.add_theme_font_size_override("font_size", BODY)
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var status: Label = dock.get_node("Combat_bar_Container/VBoxContainer/StatusBar/Status")
	text(status, BODY, Shared.MUTED)
	var end_turn: Control = ui.get_node("CombatUI/Endturn")
	end_turn.get_node("VBoxContainer").add_theme_constant_override("separation", 3)
	text(end_turn.get_node("VBoxContainer/Label2"), BODY, Shared.MUTED)
	text(end_turn.get_node("VBoxContainer/Label"), HEADING, Shared.GOLD)
	# The full-card button is above the text in the authored scene.
	end_turn.get_node("VBoxContainer").z_index = 1
	end_turn.get_node("VBoxContainer").mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_turn.get_node("Button").flat = false
	for path in ["Reaction/Reaction/VBoxContainer/ReactionScroll/ReactionList/ReactionTemplate/HBoxContainer/VBoxContainer", "Reaction/Reaction/VBoxContainer"]:
		ui.get_node("CombatUI/" + path).add_theme_constant_override("separation", 4)
	var reaction_content: HBoxContainer = ui.get_node("CombatUI/Reaction/Reaction/VBoxContainer/ReactionScroll/ReactionList/ReactionTemplate/HBoxContainer")
	reaction_content.z_index = 1
	reaction_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for control in reaction_content.find_children("*", "Control", true, false):
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text(ui.get_node("CombatUI/ReactionDescription/Frame/Description"), Shared.FONT_SIZE)
	ui.get_node("CombatUI/ReactionDescription/Frame/Description").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.get_node("CombatUI/Reaction/Reaction/VBoxContainer/HBoxContainer").size_flags_vertical = Control.SIZE_SHRINK_END
	for panel_path in ["CombatUI/Reaction", "CombatUI/ReactionDescription"]:
		var panel: PanelContainer = ui.get_node(panel_path)
		panel.add_theme_stylebox_override("panel", Shared.style(Shared.CARD_BACKGROUND, Shared.GOLD, 4))
