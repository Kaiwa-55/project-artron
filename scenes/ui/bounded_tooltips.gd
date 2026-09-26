extends CanvasLayer
## Shared, wrapped tooltip for controls using tooltip_text throughout the game.
var panel: Panel
var description: RichTextLabel
var hovered: Control
var elapsed := 0.0

func _ready() -> void:
	layer = 100
	panel = Panel.new()
	panel.add_theme_stylebox_override("panel", ArtronUITheme.style(ArtronUITheme.WINDOW_BACKGROUND, ArtronUITheme.CARD_BORDER, 8))
	add_child(panel)
	description = RichTextLabel.new()
	description.add_theme_font_size_override("normal_font_size", 11)
	description.add_theme_color_override("default_color", ArtronUITheme.TEXT)
	description.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.scroll_active = true
	panel.add_child(description)
	panel.hide()

func show_description(value: String, pointer: Vector2) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var width := minf(320.0, viewport_size.x - 24.0)
	description.position = Vector2(8, 8)
	description.size = Vector2(width - 16.0, viewport_size.y - 40.0)
	if description.text != value:
		description.text = value
		description.get_v_scroll_bar().value = 0
	var height := minf(float(description.get_content_height()) + 16.0, viewport_size.y - 24.0)
	panel.size = Vector2(width, maxf(32.0, height))
	description.size = panel.size - Vector2(16, 16)
	panel.position = (pointer + Vector2(12, 18)).clamp(Vector2(12, 12), (viewport_size - panel.size - Vector2(12, 12)).max(Vector2(12, 12)))
	panel.show()

func _process(delta: float) -> void:
	var mouse := get_viewport().get_mouse_position()
	if panel.visible and is_instance_valid(hovered) and hovered.is_visible_in_tree() and panel.get_global_rect().has_point(mouse):
		return
	var control := get_viewport().gui_get_hovered_control()
	while control != null and control.tooltip_text.is_empty():
		control = control.get_parent_control()
	if control != hovered:
		hovered = control
		elapsed = 0.0
		panel.hide()
	if not is_instance_valid(hovered) or not hovered.is_visible_in_tree():
		panel.hide()
		return
	elapsed += delta
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		elapsed = 0.0
		panel.hide()
	elif elapsed >= 0.45:
		show_description(hovered.tooltip_text, mouse)
