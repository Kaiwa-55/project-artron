extends Control

const CREATE_PARTY := "res://scenes/run/CreateParty.tscn"
const DESERT_ART := preload("res://assets/run/desert_run_map.png")
@onready var save_game = get_node("/root/SaveGame")

var heading: Label
var status: Label
var button_list: VBoxContainer
var page := "home"


func _ready() -> void:
	_build()
	show_home()


func _build() -> void:
	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.texture = DESERT_ART
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.025, 0.04, 0.055, 0.75)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(310, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101b27")
	style.border_color = Color("d8b667")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	heading = Label.new()
	heading.text = "PROJECT ARTRON"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color("e6c678"))
	column.add_child(heading)
	var subtitle := Label.new()
	subtitle.text = "A journey through the desert"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 11)
	column.add_child(subtitle)
	button_list = VBoxContainer.new()
	button_list.add_theme_constant_override("separation", 8)
	column.add_child(button_list)
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 10)
	status.add_theme_color_override("font_color", Color("f2bd9a"))
	column.add_child(status)


func show_home() -> void:
	page = "home"
	_clear_buttons()
	status.text = ""
	_add_button("NEW GAME", show_new_slots)
	_add_button("LOAD GAME", show_load_slots)
	_add_button("QUIT", get_tree().quit)


func show_new_slots() -> void:
	page = "new"
	_show_slots()


func show_load_slots() -> void:
	page = "load"
	_show_slots()


func _show_slots() -> void:
	_clear_buttons()
	status.text = "Choose a slot to begin." if page == "new" else "Choose a saved Run."
	for slot in range(1, 4):
		var summary: Dictionary = save_game.get_slot_summary(slot)
		var saved_time := String(summary.get("saved_at", "")).substr(5, 11).replace("T", " ")
		var label := "SLOT %d — EMPTY" % slot if summary.is_empty() else "SLOT %d — %s · %s" % [slot, String(summary.node).capitalize(), saved_time]
		var button := _add_button(label, choose_new_slot.bind(slot) if page == "new" else load_game.bind(slot))
		button.disabled = summary.is_empty() and page == "load"
	_add_button("BACK", show_home)


func choose_new_slot(slot: int) -> void:
	if save_game.get_slot_summary(slot).is_empty():
		start_new(slot)
		return
	var confirmation := ConfirmationDialog.new()
	confirmation.title = "Replace saved Run?"
	confirmation.dialog_text = "Starting a new game in Slot %d will replace its saved Run." % slot
	confirmation.confirmed.connect(start_new.bind(slot))
	confirmation.close_requested.connect(confirmation.queue_free)
	confirmation.confirmed.connect(confirmation.queue_free)
	add_child(confirmation)
	confirmation.popup_centered()


func start_new(slot: int) -> void:
	save_game.active_slot = slot
	for key in ["active_run_state", "active_run_node_id", "active_party_characters", "party_setup_state", "created_character_data", "restart_run_seed"]:
		if get_tree().has_meta(key):
			get_tree().remove_meta(key)
	if get_tree().change_scene_to_file(CREATE_PARTY) != OK:
		status.text = "Could not open character creation."


func load_game(slot: int) -> void:
	if not save_game.load_slot(slot):
		_show_slots()
		status.text = save_game.last_error


func _clear_buttons() -> void:
	for child in button_list.get_children():
		child.queue_free()


func _add_button(label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(260, 38)
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(action)
	button_list.add_child(button)
	return button
