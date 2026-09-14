class_name CombatLogActionCard
extends PanelContainer


func setup(entry: Dictionary, compact: bool = false) -> void:
	var actor_name := String(entry.get("actor", "System"))
	var target_name := String(entry.get("target", ""))
	$Margin/Content/Header/ActionName.text = String(entry.get("action", "Combat Event"))
	$Margin/Content/Header/ActionType.text = String(entry.get("type", "EVENT"))
	$Margin/Content/Resolution/Actor/Token.text = actor_name.left(1).to_upper()
	$Margin/Content/Resolution/Actor/Info/Name.text = actor_name
	$Margin/Content/Resolution/Actor/Info/Role.text = String(entry.get("actor_role", "Actor"))
	$Margin/Content/Resolution/Result/Outcome.text = String(entry.get("outcome", "RESOLVED"))
	$Margin/Content/Resolution/Result/Roll.text = String(entry.get("roll", ""))
	$Margin/Content/Resolution/Result/Damage.text = String(entry.get("damage", ""))
	$Margin/Content/Resolution/Target.visible = not target_name.is_empty()
	$Margin/Content/Resolution/Target/Token.text = target_name.left(1).to_upper()
	$Margin/Content/Resolution/Target/Info/Name.text = target_name
	$Margin/Content/Resolution/Target/Info/Role.text = String(entry.get("target_role", "Target"))
	$Margin/Content/Details.text = String(entry.get("details", ""))
	$Margin/Content/Details.visible = not $Margin/Content/Details.text.is_empty()
	_apply_outcome_color(String(entry.get("tone", "neutral")))
	apply_compact_layout(compact)


func apply_compact_layout(compact: bool) -> void:
	custom_minimum_size = Vector2(0.0, 56.0 if compact else 112.0)
	var margin: MarginContainer = $Margin
	margin.add_theme_constant_override("margin_left", 3 if compact else 10)
	margin.add_theme_constant_override("margin_top", 3 if compact else 8)
	margin.add_theme_constant_override("margin_right", 3 if compact else 10)
	margin.add_theme_constant_override("margin_bottom", 3 if compact else 8)
	$Margin/Content.add_theme_constant_override("separation", 2 if compact else 5)
	$Margin/Content/Header/ActionName.add_theme_font_size_override("font_size", 8 if compact else 15)
	$Margin/Content/Header/ActionType.add_theme_font_size_override("font_size", 7 if compact else 16)
	$Margin/Content/Resolution.add_theme_constant_override("separation", 2 if compact else 5)
	for section_path in ["Actor", "Target"]:
		var section: HBoxContainer = $Margin/Content/Resolution.get_node(section_path)
		section.custom_minimum_size = Vector2(24.0 if compact else 82.0, 20.0 if compact else 38.0)
		section.add_theme_constant_override("separation", 2 if compact else 5)
		var token: Label = section.get_node("Token")
		token.visible = not compact
		token.custom_minimum_size = Vector2(34.0, 34.0)
		section.get_node("Info/Name").add_theme_font_size_override("font_size", 7 if compact else 16)
		section.get_node("Info/Role").add_theme_font_size_override("font_size", 7 if compact else 12)
		section.get_node("Info/Role").visible = not compact
	var result: VBoxContainer = $Margin/Content/Resolution/Result
	result.custom_minimum_size = Vector2(36.0 if compact else 112.0, 20.0 if compact else 38.0)
	result.get_node("Outcome").add_theme_font_size_override("font_size", 8 if compact else 16)
	result.get_node("Roll").add_theme_font_size_override("font_size", 7 if compact else 12)
	result.get_node("Damage").add_theme_font_size_override("font_size", 7 if compact else 12)
	$Margin/Content/Details.add_theme_font_size_override("font_size", 7 if compact else 12)


func _apply_outcome_color(tone: String) -> void:
	var color := Color("cbd5dc")
	match tone:
		"damage": color = Color("ff9b8f")
		"heal": color = Color("89e6ae")
		"status": color = Color("c7a7ff")
		"reaction": color = Color("ffd166")
		"turn": color = Color("78c9f4")
	$Margin/Content/Resolution/Result/Outcome.add_theme_color_override("font_color", color)
	$Margin/Content/Header/ActionType.add_theme_color_override("font_color", color)
