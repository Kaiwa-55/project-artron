class_name GMConsole
extends PanelContainer

signal class_requested(class_data)
signal ability_requested(ability_data)
signal skill_requested(skill_data)
signal attribute_requested(attribute_name: String, delta: int)
signal command_requested(command: String)

const UITheme := preload("res://scenes/ui/artron_ui_theme.gd")

var _classes: Array = []
var _abilities: Array = []
var _skills: Array = []
var _ability_picker: OptionButton
var _skill_picker: OptionButton
var _attribute_picker: OptionButton
var _status_label: Label


func _ready() -> void:
	add_to_group("gm_console")
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# Keep the right edge on screen when the contents exceed the initial width.
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_left = -214
	offset_top = 4
	offset_right = -6
	offset_bottom = 354
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	add_theme_stylebox_override("panel", UITheme.style(UITheme.CARD_BACKGROUND, UITheme.GOLD, 6))
	hide()


func configure(classes: Array, abilities: Array, skills: Array) -> void:
	_classes = classes
	_abilities = abilities
	_skills = skills
	if is_node_ready():
		_build()


func toggle_console() -> void:
	visible = not visible
	if visible:
		move_to_front()
		grab_focus()


func set_status(message: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = message


func accepts_debug_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.keycode == KEY_F1:
		return true
	if not is_visible_in_tree():
		return false
	if event is InputEventMouseButton:
		return get_global_rect().has_point(event.position)
	if event is InputEventKey:
		var focused := get_viewport().gui_get_focus_owner()
		return focused != null and (focused == self or is_ancestor_of(focused))
	return false


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := UITheme.label("GM CONSOLE", 10, UITheme.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "F1"
	close.custom_minimum_size = Vector2(28, 18)
	UITheme.apply_button_style(close)
	close.pressed.connect(hide)
	header.add_child(close)
	_add_section(column, "RESOURCES")
	_add_row(column, [["FULL RESOURCES", "full_resources"], ["RESET TURN", "reset_turn"]])
	_add_section(column, "COMBAT")
	_add_row(column, [["RESET COMBAT", "reset_combat"]])
	_add_section(column, "TARGET")
	_add_row(column, [["DAMAGE 5", "damage_target"], ["HEAL 5", "heal_target"]])
	_add_section(column, "CHANGE CLASS")
	var class_row := HBoxContainer.new()
	class_row.add_theme_constant_override("separation", 3)
	column.add_child(class_row)
	for class_data in _classes:
		var button := Button.new()
		button.text = class_data.display_name.to_upper()
		button.tooltip_text = "GM: switch current character to %s" % class_data.display_name
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 7)
		UITheme.apply_button_style(button)
		button.pressed.connect(_request_class.bind(class_data))
		class_row.add_child(button)
	_add_section(column, "GRANT ABILITY")
	var ability_row := HBoxContainer.new()
	ability_row.add_theme_constant_override("separation", 3)
	column.add_child(ability_row)
	_ability_picker = OptionButton.new()
	_ability_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ability_picker.add_theme_font_size_override("font_size", 8)
	for ability in _abilities:
		_ability_picker.add_item(ability.display_name)
	ability_row.add_child(_ability_picker)
	var grant := Button.new()
	grant.text = "GRANT"
	grant.add_theme_font_size_override("font_size", 8)
	UITheme.apply_button_style(grant)
	grant.pressed.connect(_request_selected_ability)
	ability_row.add_child(grant)
	_add_section(column, "GRANT SKILL")
	var skill_row := HBoxContainer.new()
	skill_row.add_theme_constant_override("separation", 3)
	column.add_child(skill_row)
	_skill_picker = OptionButton.new()
	_skill_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_picker.add_theme_font_size_override("font_size", 8)
	for skill in _skills:
		_skill_picker.add_item(skill.display_name)
	skill_row.add_child(_skill_picker)
	var grant_skill := Button.new()
	grant_skill.text = "GRANT SKILL"
	grant_skill.add_theme_font_size_override("font_size", 7)
	UITheme.apply_button_style(grant_skill)
	grant_skill.pressed.connect(_request_selected_skill)
	skill_row.add_child(grant_skill)
	_add_section(column, "ATTRIBUTES")
	var attribute_row := HBoxContainer.new()
	attribute_row.add_theme_constant_override("separation", 3)
	column.add_child(attribute_row)
	_attribute_picker = OptionButton.new()
	_attribute_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attribute_picker.add_theme_font_size_override("font_size", 8)
	for attribute in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
		_attribute_picker.add_item(attribute)
	attribute_row.add_child(_attribute_picker)
	for change in [-1, 1]:
		var button := Button.new()
		button.text = "-1" if change < 0 else "+1"
		button.add_theme_font_size_override("font_size", 8)
		UITheme.apply_button_style(button)
		button.pressed.connect(_request_attribute_change.bind(change))
		attribute_row.add_child(button)
	_status_label = UITheme.label("Select a GM action.", 7, UITheme.MUTED)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status_label)


func _add_section(parent: VBoxContainer, text: String) -> void:
	var label := UITheme.label(text, 7, UITheme.MUTED)
	parent.add_child(label)


func _add_row(parent: VBoxContainer, entries: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	parent.add_child(row)
	for entry in entries:
		var button := Button.new()
		button.text = entry[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 8)
		UITheme.apply_button_style(button)
		button.pressed.connect(_request_command.bind(String(entry[1])))
		row.add_child(button)


func _request_class(class_data) -> void:
	class_requested.emit(class_data)


func _request_selected_ability() -> void:
	var index := _ability_picker.selected
	if index >= 0 and index < _abilities.size():
		ability_requested.emit(_abilities[index])


func _request_selected_skill() -> void:
	var index := _skill_picker.selected
	if index >= 0 and index < _skills.size():
		skill_requested.emit(_skills[index])


func _request_attribute_change(delta: int) -> void:
	if _attribute_picker.selected >= 0:
		attribute_requested.emit(_attribute_picker.get_item_text(_attribute_picker.selected), delta)


func _request_command(command: String) -> void:
	command_requested.emit(command)
