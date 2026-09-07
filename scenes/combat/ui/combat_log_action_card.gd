class_name CombatLogActionCard
extends PanelContainer


func setup(entry: Dictionary) -> void:
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
