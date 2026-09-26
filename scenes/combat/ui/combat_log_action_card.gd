class_name CombatLogActionCard
extends PanelContainer

const UITheme := preload("res://scenes/ui/artron_ui_theme.gd")

var _actor_name: String = ""
var _target_name: String = ""


func setup(entry: Dictionary, compact: bool = false) -> void:
	var card_style := UITheme.style(UITheme.WINDOW_BACKGROUND, UITheme.CARD_BORDER, 0)
	card_style.set_border_width_all(0)
	card_style.border_width_left = 2
	add_theme_stylebox_override("panel", card_style)
	_actor_name = String(entry.get("actor", "System"))
	_target_name = String(entry.get("target", ""))
	$Margin/Content/Header/ActionName.text = String(entry.get("action", "Combat Event"))
	$Margin/Content/Header/ActionType.text = String(entry.get("type", "EVENT"))
	$Margin/Content/Resolution/Actor/Token.text = _actor_name.left(1).to_upper()
	$Margin/Content/Resolution/Actor/Info/Name.text = _actor_name
	$Margin/Content/Resolution/Actor/Info/Role.text = String(entry.get("actor_role", "Actor"))
	$Margin/Content/Resolution/Result/Outcome.text = String(entry.get("outcome", "RESOLVED"))
	$Margin/Content/Resolution/Result/Roll.text = String(entry.get("roll", ""))
	$Margin/Content/Resolution/Result/Damage.text = String(entry.get("damage", ""))
	$Margin/Content/Resolution/Target.visible = not _target_name.is_empty()
	$Margin/Content/Resolution/Target/Token.text = _target_name.left(1).to_upper()
	$Margin/Content/Resolution/Target/Info/Name.text = _target_name
	$Margin/Content/Resolution/Target/Info/Role.text = String(entry.get("target_role", "Target"))
	$Margin/Content/Details.text = String(entry.get("details", ""))
	$Margin/Content/Details.visible = not $Margin/Content/Details.text.is_empty()
	_apply_outcome_color(String(entry.get("tone", "neutral")))
	apply_compact_layout(compact)


func apply_compact_layout(compact: bool) -> void:
	custom_minimum_size = Vector2.ZERO
	var margin: MarginContainer = $Margin
	margin.add_theme_constant_override("margin_left", 7 if compact else 10)
	margin.add_theme_constant_override("margin_top", 6 if compact else 8)
	margin.add_theme_constant_override("margin_right", 7 if compact else 10)
	margin.add_theme_constant_override("margin_bottom", 6 if compact else 8)
	$Margin/Content.add_theme_constant_override("separation", 3 if compact else 5)
	$Margin/Content/Header/ActionName.add_theme_font_size_override("font_size", 7 if compact else 15)
	$Margin/Content/Header/ActionName.clip_text = false
	$Margin/Content/Header/ActionName.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Margin/Content/Header/ActionType.add_theme_font_size_override("font_size", 6 if compact else 13)
	$Margin/Content/Resolution.add_theme_constant_override("separation", 1 if compact else 5)
	for section_path in ["Actor", "Target"]:
		var section: HBoxContainer = $Margin/Content/Resolution.get_node(section_path)
		section.custom_minimum_size = Vector2.ZERO if compact else Vector2(82.0, 38.0)
		section.add_theme_constant_override("separation", 2 if compact else 5)
		var token: Label = section.get_node("Token")
		token.visible = not compact
		token.custom_minimum_size = Vector2(34.0, 34.0)
		section.get_node("Info/Name").add_theme_font_size_override("font_size", 6 if compact else 16)
		section.get_node("Info/Role").add_theme_font_size_override("font_size", 6 if compact else 12)
		section.get_node("Info/Role").visible = not compact
	$Margin/Content/Resolution/Actor/Info/Name.text = "%s → %s" % [_actor_name, _target_name] if compact and not _target_name.is_empty() else _actor_name
	$Margin/Content/Resolution/Target.visible = not compact and not _target_name.is_empty()
	var result: VBoxContainer = $Margin/Content/Resolution/Result
	result.custom_minimum_size = Vector2.ZERO if compact else Vector2(112.0, 38.0)
	for label_name in ["Outcome", "Roll", "Damage"]:
		var label: Label = result.get_node(label_name)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if compact else HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 7 if compact else 13)
		label.visible = not label.text.is_empty()
	$Margin/Content/Details.add_theme_font_size_override("font_size", 6 if compact else 12)
	$Margin/Content/Details.max_lines_visible = -1
	$Margin/Content/Details.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING


func _apply_outcome_color(tone: String) -> void:
	var color := UITheme.TEXT
	match tone:
		"damage": color = UITheme.ENEMY
		"heal": color = UITheme.HEALTH_FILL
		"status": color = Color("c7a7ff")
		"reaction": color = UITheme.GOLD
		"turn": color = UITheme.ALLY
	$Margin/Content/Resolution/Result/Outcome.add_theme_color_override("font_color", color)
	$Margin/Content/Header/ActionType.add_theme_color_override("font_color", color)
	var card_style := get_theme_stylebox("panel") as StyleBoxFlat
	if card_style != null:
		card_style.border_color = color
