class_name RestPanel
extends Control

signal action_selected(actor_id: String, action_id: String)
signal rest_completed()

const UITheme := preload("res://scenes/ui/artron_ui_theme.gd")

var party: Array[CombatantState] = []
var choices_by_actor: Dictionary = {}
var _party_rows: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	hide()


func open_for_party(members: Array[CombatantState]) -> void:
	party = members.filter(func(member): return member != null)
	choices_by_actor.clear()
	_build_party_rows()
	show()
	move_to_front()


func _build() -> void:
	if get_node_or_null("Shade") != null:
		return
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.035, 0.05, 0.84)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(center)
	var card := PanelContainer.new()
	card.name = "CampCard"
	card.custom_minimum_size = Vector2(480, 0)
	card.add_theme_stylebox_override("panel", UITheme.style(UITheme.WINDOW_BACKGROUND, UITheme.GOLD, UITheme.CARD_PADDING))
	center.add_child(card)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	var title := UITheme.label("CAMPFIRE", UITheme.TITLE_SIZE, UITheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var summary := UITheme.label("Each character chooses one camp action. The party carries its remaining resources into the next encounter.", UITheme.FONT_SIZE, UITheme.MUTED)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(summary)
	column.add_child(HSeparator.new())
	_party_rows = VBoxContainer.new()
	_party_rows.name = "PartyRows"
	_party_rows.add_theme_constant_override("separation", 6)
	column.add_child(_party_rows)


func _build_party_rows() -> void:
	for child in _party_rows.get_children():
		_party_rows.remove_child(child)
		child.queue_free()
	for member in party:
		var row := PanelContainer.new()
		row.name = member.id
		row.add_theme_stylebox_override("panel", UITheme.style(UITheme.CARD_BACKGROUND, UITheme.CARD_BORDER, 6))
		_party_rows.add_child(row)
		var content := VBoxContainer.new()
		content.name = "Content"
		content.add_theme_constant_override("separation", 5)
		row.add_child(content)
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 8)
		content.add_child(header)
		var name := UITheme.label(member.display_name, UITheme.FONT_SIZE, UITheme.TEXT)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(name)
		header.add_child(UITheme.label("HP %d/%d" % [member.hp, member.max_hp], UITheme.FONT_SIZE, UITheme.HEALTH_FILL))
		var mana := UITheme.label("Mana %d/%d" % [member.mana, member.max_mana], UITheme.FONT_SIZE, UITheme.ALLY)
		mana.visible = member.max_mana > 0
		header.add_child(mana)
		var actions := HBoxContainer.new()
		actions.name = "Actions"
		actions.add_theme_constant_override("separation", 4)
		content.add_child(actions)
		_add_action(actions, member.id, "TEND WOUNDS", "Restore 50% Max HP", "wounds")
		_add_action(actions, member.id, "QUIET FOCUS", "Restore 50% Max Mana", "focus")
		_add_action(actions, member.id, "TRAINING", "Gain 1 Ability Point", "training")


func _add_action(parent: HBoxContainer, actor_id: String, title: String, description: String, action_id: String) -> void:
	var button := Button.new()
	button.name = action_id.capitalize()
	button.text = "%s\n%s" % [title, description]
	button.custom_minimum_size = Vector2(0, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.tooltip_text = description
	UITheme.apply_button_style(button)
	button.add_theme_font_size_override("font_size", UITheme.SECTION_SIZE)
	button.pressed.connect(_choose_action.bind(actor_id, action_id, parent))
	parent.add_child(button)


func _choose_action(actor_id: String, action_id: String, actions: HBoxContainer) -> void:
	if choices_by_actor.has(actor_id):
		return
	choices_by_actor[actor_id] = action_id
	for button in actions.get_children():
		if button is Button:
			button.disabled = true
	var chosen: Button = actions.get_node(action_id.capitalize())
	chosen.disabled = false
	chosen.text = "SELECTED\n%s" % chosen.tooltip_text
	chosen.add_theme_stylebox_override("normal", UITheme.style(UITheme.SELECTED_BACKGROUND, UITheme.GOLD, 4))
	action_selected.emit(actor_id, action_id)
	if choices_by_actor.size() == party.size():
		rest_completed.emit()
		hide()
