extends RefCounted
## Shared visual vocabulary for every creation page and future extensions.
const ArtronTheme = preload("res://scenes/ui/artron_ui_theme.gd")
const GOLD = ArtronTheme.GOLD
const INK = ArtronTheme.WINDOW_BACKGROUND
const PAPER = ArtronTheme.TEXT
const MUTED = ArtronTheme.MUTED
static var density_scale := 1.0


static func set_compact_density(compact: bool) -> void:
	density_scale = 0.76 if compact else 1.0

static func box(color: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.border_color = border
	result.set_border_width_all(width)
	result.set_corner_radius_all(4)
	result.content_margin_left = 14
	result.content_margin_right = 14
	result.content_margin_top = 10
	result.content_margin_bottom = 10
	return result

static func make_theme() -> Theme:
	var result := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Noto Sans"])
	result.default_font = font
	result.default_font_size = ArtronTheme.FONT_SIZE
	result.set_color("font_color", "Label", PAPER)
	result.set_color("font_color", "Button", PAPER)
	result.set_color("font_hover_color", "Button", Color.WHITE)
	result.set_color("font_disabled_color", "Button", Color("#78817d"))
	result.set_stylebox("normal", "Button", box(ArtronTheme.BUTTON_BACKGROUND, ArtronTheme.BUTTON_BORDER))
	result.set_stylebox("hover", "Button", box(ArtronTheme.BUTTON_HOVER, GOLD))
	result.set_stylebox("pressed", "Button", box(ArtronTheme.BUTTON_PRESSED, GOLD, 2))
	result.set_stylebox("disabled", "Button", box(ArtronTheme.DISABLED_BACKGROUND, ArtronTheme.DISABLED_BORDER))
	result.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), GOLD, 2))
	result.set_stylebox("normal", "LineEdit", box(ArtronTheme.BUTTON_BACKGROUND, ArtronTheme.BUTTON_BORDER))
	result.set_stylebox("focus", "LineEdit", box(ArtronTheme.BUTTON_HOVER, GOLD))
	result.set_color("font_color", "LineEdit", PAPER)
	return result

static func label(parent: Node, text: String, size: int = 16, color: Color = PAPER, serif: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", maxi(8, roundi(size * density_scale)))
	node.add_theme_color_override("font_color", color)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if serif:
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Georgia", "Noto Serif"])
		node.add_theme_font_override("font", font)
	parent.add_child(node)
	return node

static func button(parent: Node, text: String, callback: Callable, selected: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = roundi(42 * density_scale)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if callback.is_valid():
		node.pressed.connect(callback)
	if selected:
		node.add_theme_stylebox_override("normal", box(Color("#2a291f"), GOLD, 2))
		node.add_theme_color_override("font_color", GOLD)
	parent.add_child(node)
	return node

static func column(parent: Node, spacing: int = 12) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_constant_override("separation", spacing)
	parent.add_child(node)
	return node

static func panel(parent: Node) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", box(ArtronTheme.CARD_BACKGROUND, ArtronTheme.CARD_BORDER))
	parent.add_child(node)
	return node

static func scroll_column(parent: Node) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	return column(scroll)

static func line(parent: Node) -> void:
	var node := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = Color("#66573a")
	style.thickness = 1
	node.add_theme_stylebox_override("separator", style)
	node.add_theme_constant_override("separation", 2)
	node.custom_minimum_size.y = 1
	parent.add_child(node)

static func art(parent: Node, texture: Texture2D, height: float) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	node.custom_minimum_size.y = height * density_scale
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	if texture != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		node.texture = atlas
		node.resized.connect(func(): fit_art(node, atlas, texture))
	return node

static func square_art(parent: Node, texture: Texture2D, side: float) -> TextureRect:
	var node := art(parent, texture, side)
	node.name = "PortraitArt"
	node.custom_minimum_size = Vector2(side, side) * density_scale
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	return node

static func fit_art(node: TextureRect, atlas: AtlasTexture, texture: Texture2D) -> void:
	if node.size.y <= 0 or node.size.x <= 0:
		return
	var source := texture.get_size()
	var ratio := node.size.x / node.size.y
	var cropped := Vector2(minf(source.x, source.y * ratio), minf(source.y, source.x / ratio))
	# Top-aligned crop keeps faces visible in wide banners. Original art is untouched.
	atlas.region = Rect2(Vector2((source.x - cropped.x) * 0.65, 0), cropped)

static func card(parent: Node, title: String, subtitle: String, texture: Texture2D, selected: bool, callback: Callable, square_texture: bool = false) -> Button:
	var node := button(parent, "", callback, selected)
	node.custom_minimum_size.y = (214 if texture != null else 94) * density_scale
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(margin)
	var content := column(margin, 5)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if texture != null:
		if square_texture:
			square_art(content, texture, 136)
		else:
			art(content, texture, 136)
	var heading := label(content, ("◆ " if selected else "") + title, 20, GOLD if selected else PAPER, true)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var detail := label(content, subtitle, 13, MUTED)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

static func traits_text(source) -> String:
	var parts: PackedStringArray = []
	for entry in source.traits:
		if entry != null:
			parts.append(entry.display_name)
	return "  /  ".join(parts)
