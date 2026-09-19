class_name ArtronUITheme
extends RefCounted

const FONT_SIZE := 11
const TITLE_SIZE := 18
const SECTION_SIZE := 9
const BUTTON_HEIGHT := 26
const WINDOW_PADDING := 12
const CARD_PADDING := 10
const BUTTON_PADDING := 6
const WINDOW_BACKGROUND := Color("101923")
const CARD_BACKGROUND := Color("18232e")
const BUTTON_BACKGROUND := Color("202d38")
const BUTTON_HOVER := Color("2b3b47")
const BUTTON_PRESSED := Color("3b3a2a")
const SELECTED_BACKGROUND := Color("343327")
const WINDOW_BORDER := Color("57604f")
const CARD_BORDER := Color("33424d")
const BUTTON_BORDER := Color("3c4c56")
const GOLD := Color("d8b56b")
const TEXT := Color("d4dce2")
const MUTED := Color("9ba9b7")
const DISABLED_BACKGROUND := Color("11171d")
const DISABLED_BORDER := Color("27323b")
const DISABLED_TEXT := Color("68737e")
const HEALTH_FILL := Color("4f9b72")
const MANA_FILL := Color("426b99")
const HEAT_FILL := Color("a86b43")
const ENEMY := Color("bc6d69")
const ALLY := Color("6bafbd")


static func create_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	return theme


static func style(background: Color, border: Color, padding: int, border_width: int = 1) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = background
	result.border_color = border
	result.set_border_width_all(border_width)
	result.set_corner_radius_all(4)
	result.content_margin_left = padding
	result.content_margin_right = padding
	result.content_margin_top = padding
	result.content_margin_bottom = padding
	return result


static func apply_button_style(button: Button) -> void:
	button.custom_minimum_size.y = BUTTON_HEIGHT
	button.add_theme_stylebox_override("normal", style(BUTTON_BACKGROUND, BUTTON_BORDER, BUTTON_PADDING))
	button.add_theme_stylebox_override("hover", style(BUTTON_HOVER, GOLD, BUTTON_PADDING))
	button.add_theme_stylebox_override("pressed", style(BUTTON_PRESSED, GOLD, BUTTON_PADDING))
	button.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), GOLD, BUTTON_PADDING))
	button.add_theme_stylebox_override("disabled", style(DISABLED_BACKGROUND, DISABLED_BORDER, BUTTON_PADDING))
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", DISABLED_TEXT)


static func apply_combat_theme(root: Control) -> void:
	root.theme = create_theme()
	_apply_combat_children(root)


static func _apply_combat_children(parent: Node) -> void:
	for node in parent.get_children():
		if node.name == "CharacterPanel":
			continue
		if node is Button:
			apply_button_style(node)
		elif node is Panel or node is PanelContainer:
			node.add_theme_stylebox_override("panel", style(CARD_BACKGROUND, CARD_BORDER, CARD_PADDING))
		elif node is NinePatchRect:
			_apply_nine_patch_surface(node)
		elif node is ProgressBar:
			node.modulate = Color.WHITE
			node.show_behind_parent = false
			node.add_theme_stylebox_override("background", style(BUTTON_BACKGROUND, CARD_BORDER, 1))
			var fill_color: Color = {"Mana": MANA_FILL, "Faith": GOLD, "Heat": HEAT_FILL, "TempHp": ALLY}.get(node.get_parent().name, HEALTH_FILL)
			node.add_theme_stylebox_override("fill", style(fill_color, fill_color, 1))
		elif node is Label:
			if node.label_settings != null:
				node.label_settings = node.label_settings.duplicate()
				node.label_settings.font_color = TEXT
				node.label_settings.outline_size = 0
				node.label_settings.font_size = clampi(node.label_settings.font_size, 9, FONT_SIZE)
			node.add_theme_color_override("font_color", TEXT)
		_apply_combat_children(node)


static func _apply_nine_patch_surface(node: NinePatchRect) -> void:
	node.texture = null
	# Texture patch margins also impose a minimum size, even after clearing texture.
	node.patch_margin_left = 0
	node.patch_margin_top = 0
	node.patch_margin_right = 0
	node.patch_margin_bottom = 0
	var surface := node.get_node_or_null("ThemeSurface") as Panel
	if surface == null:
		surface = Panel.new()
		surface.name = "ThemeSurface"
		surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.show_behind_parent = true
		node.add_child(surface)
	surface.add_theme_stylebox_override("panel", style(CARD_BACKGROUND, CARD_BORDER, CARD_PADDING))


static func label(caption: String, font_size: int = FONT_SIZE, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = caption
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result
