class_name EventPanel
extends CanvasLayer

signal encounter_confirmed(data: EncounterData)

@onready var title_label: Label = $Backdrop/SafeArea/Content/Title
@onready var image_rect: TextureRect = $Backdrop/BackgroundImage
@onready var description_label: Label = $Backdrop/SafeArea/Content/Narrative/Margin/Bottom/Description
@onready var choice_list: VBoxContainer = $Backdrop/SafeArea/Content/Narrative/Margin/Bottom/ChoiceScroll/Choices

var event_manager: EventManager
var pending_encounter: EncounterData
var pending_choice_index: int = -1


func setup(manager: EventManager) -> void:
	if event_manager != null:
		if event_manager.event_started.is_connected(show_event):
			event_manager.event_started.disconnect(show_event)
		if event_manager.choices_changed.is_connected(show_choices):
			event_manager.choices_changed.disconnect(show_choices)
		if event_manager.event_finished.is_connected(_on_event_finished):
			event_manager.event_finished.disconnect(_on_event_finished)
		if event_manager.character_selection_requested.is_connected(show_character_selection):
			event_manager.character_selection_requested.disconnect(show_character_selection)
	event_manager = manager
	if event_manager != null:
		event_manager.event_started.connect(show_event)
		event_manager.choices_changed.connect(show_choices)
		event_manager.event_finished.connect(_on_event_finished)
		event_manager.character_selection_requested.connect(show_character_selection)


func show_event(data: EventData) -> void:
	pending_encounter = null
	pending_choice_index = -1
	title_label.text = data.title
	description_label.text = data.description
	_set_image(data.illustration)
	visible = true


func show_choices(states: Array[Dictionary]) -> void:
	_clear_choices()
	for state in states:
		if not bool(state.get("visible", true)):
			continue
		var button := Button.new()
		button.text = String(state.get("text", "Continue"))
		button.disabled = not bool(state.get("enabled", false))
		button.custom_minimum_size = Vector2(0, 24)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_choice_button(button)
		var reasons: Array = state.get("failure_reasons", [])
		button.tooltip_text = "\n".join(reasons)
		button.pressed.connect(_choose.bind(int(state.get("index", -1))))
		choice_list.add_child(button)
	_focus_first_enabled_choice.call_deferred()


func show_character_selection(choice_index: int, eligible_actor_ids: Array[String]) -> void:
	if event_manager == null or event_manager.active_event == null:
		return
	pending_choice_index = choice_index
	var choice := event_manager.active_event.choices[choice_index]
	title_label.text = "เลือกตัวละคร"
	description_label.text = "ใครจะเป็นผู้ดำเนินตัวเลือก: %s" % choice.text
	_clear_choices()
	for actor_id in eligible_actor_ids:
		var actor := event_manager.context.find_party_member(actor_id)
		if actor == null:
			continue
		var button := Button.new()
		button.text = actor.display_name
		button.custom_minimum_size = Vector2(0, 24)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_choice_button(button)
		button.pressed.connect(_select_actor.bind(actor_id))
		choice_list.add_child(button)
	var back_button := Button.new()
	back_button.text = "ย้อนกลับ"
	back_button.custom_minimum_size = Vector2(0, 24)
	_style_choice_button(back_button)
	back_button.pressed.connect(_return_to_choices)
	choice_list.add_child(back_button)
	_focus_first_enabled_choice.call_deferred()


func show_encounter(data: EncounterData) -> void:
	pending_encounter = data
	title_label.text = data.get_encounter_name()
	description_label.text = data.encounter_description
	_set_image(data.encounter_image if data.encounter_image != null else data.battlefield_texture)
	_clear_choices()
	var begin_button := Button.new()
	begin_button.text = "BEGIN ENCOUNTER"
	begin_button.custom_minimum_size = Vector2(0, 26)
	begin_button.mouse_filter = Control.MOUSE_FILTER_STOP
	begin_button.focus_mode = Control.FOCUS_ALL
	begin_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_choice_button(begin_button)
	begin_button.pressed.connect(_confirm_encounter)
	choice_list.add_child(begin_button)
	visible = true
	_focus_button.call_deferred(begin_button)


func close() -> void:
	pending_encounter = null
	pending_choice_index = -1
	visible = false
	_clear_choices()


func _choose(index: int) -> void:
	if event_manager != null:
		event_manager.choose(index)


func _select_actor(actor_id: String) -> void:
	if event_manager != null and pending_choice_index >= 0:
		event_manager.choose_for_actor(pending_choice_index, actor_id)


func _return_to_choices() -> void:
	if event_manager == null or event_manager.active_event == null:
		return
	show_event(event_manager.active_event)
	show_choices(event_manager.get_choice_states())


func _confirm_encounter() -> void:
	if pending_encounter != null:
		encounter_confirmed.emit(pending_encounter)


func _on_event_finished(_data: EventData) -> void:
	close()


func _set_image(texture: Texture2D) -> void:
	image_rect.texture = texture
	image_rect.modulate = Color.WHITE if texture != null else Color("151b26")


func _focus_first_enabled_choice() -> void:
	if not is_inside_tree() or not visible:
		return
	for child in choice_list.get_children():
		if child is Button and child.is_inside_tree() and not child.disabled:
			child.grab_focus()
			return


func _focus_button(button: Button) -> void:
	if is_instance_valid(button) and button.is_inside_tree() and visible and not button.disabled:
		button.grab_focus()


func _style_choice_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 9)
	button.add_theme_color_override("font_color", Color(0.94, 0.94, 0.92))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.82, 0.42))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.72, 0.25))
	button.add_theme_color_override("font_disabled_color", Color(0.62, 0.62, 0.60, 0.7))
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color.TRANSPARENT
	hover_style.border_color = Color(1.0, 0.76, 0.3, 0.9)
	hover_style.set_border_width_all(1)
	hover_style.set_corner_radius_all(2)
	button.add_theme_stylebox_override("hover", hover_style)
	var pressed_style := hover_style.duplicate()
	pressed_style.border_color = Color(1.0, 0.88, 0.55, 1.0)
	button.add_theme_stylebox_override("pressed", pressed_style)


func _clear_choices() -> void:
	for child in choice_list.get_children():
		choice_list.remove_child(child)
		child.queue_free()
