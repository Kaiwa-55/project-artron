@tool
extends EditorPlugin

const EncounterScript := preload("res://data/encounter/encounter_data.gd")
const EnemyGroupScript := preload("res://data/encounter/enemy_group_data.gd")
const PreviewScript := preload("res://addons/encounter_builder/encounter_preview.gd")

var dock: VBoxContainer
var id_edit: LineEdit
var name_edit: LineEdit
var type_select: OptionButton
var map_edit: LineEdit
var texture_edit: LineEdit
var storm_enabled: CheckBox
var storm_intensity: SpinBox
var storm_wind_x: SpinBox
var storm_wind_y: SpinBox
var storm_speed: SpinBox
var storm_density: SpinBox
var storm_color: ColorPickerButton
var storm_opacity: SpinBox
var storm_particle_size: SpinBox
var groups_list: VBoxContainer
var status: Label
var resource_dialog: FileDialog
var pending_resource_kind := ""
var current: EncounterData
var group_rows: Array[Dictionary] = []
var preview_window: Window
var preview: EncounterPreview
var preview_target: OptionButton
var player_index: SpinBox
var details_window: Window
var details_inspector: EditorInspector

func _enter_tree() -> void:
	dock = VBoxContainer.new()
	dock.name = "Encounter Builder"
	dock.custom_minimum_size = Vector2(390, 0)
	_build_ui()
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)

func _exit_tree() -> void:
	if resource_dialog != null:
		resource_dialog.queue_free()
	if is_instance_valid(preview_window):
		preview_window.queue_free()
	if is_instance_valid(details_window):
		details_window.queue_free()
	remove_control_from_docks(dock)
	if dock != null:
		dock.queue_free()

func _build_ui() -> void:
	var title := Label.new()
	title.text = "ENCOUNTER BUILDER"
	dock.add_child(title)
	var help := Label.new()
	help.text = "Create or load EncounterData, then add dynamic enemy groups."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(help)
	var actions := HBoxContainer.new()
	dock.add_child(actions)
	var new_button := Button.new()
	new_button.text = "New"
	new_button.pressed.connect(_new_encounter)
	actions.add_child(new_button)
	var load_button := Button.new()
	load_button.text = "Load..."
	load_button.pressed.connect(_open_encounter)
	actions.add_child(load_button)
	var save_button := Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(_save_encounter)
	actions.add_child(save_button)
	var details_button := Button.new()
	details_button.text = "All fields..."
	details_button.pressed.connect(_open_details)
	actions.add_child(details_button)
	var preview_button := Button.new()
	preview_button.text = "Preview & spawns..."
	preview_button.pressed.connect(_open_preview)
	dock.add_child(preview_button)
	id_edit = _line("Encounter ID", "new_encounter")
	name_edit = _line("Display name", "New Encounter")
	type_select = OptionButton.new()
	for label in ["Combat", "Ambush", "Defense", "Survival", "Escape", "Boss"]: type_select.add_item(label)
	_add_labeled("Type", type_select)
	map_edit = _path_row("Building Map", "map")
	texture_edit = _path_row("Battlefield PNG", "texture")
	storm_enabled = CheckBox.new()
	storm_enabled.text = "Desert storm (3D)"
	dock.add_child(storm_enabled)
	storm_intensity = _storm_number("Storm intensity", 0.0, 1.0, 0.05)
	storm_wind_x = _storm_number("Wind X", -5.0, 5.0, 0.1)
	storm_wind_y = _storm_number("Wind Y", -5.0, 5.0, 0.1)
	storm_speed = _storm_number("Sand speed", 0.0, 5.0, 0.05)
	storm_density = _storm_number("Sand density", 0.0, 20.0, 0.1)
	storm_color = ColorPickerButton.new()
	storm_color.edit_alpha = false
	_add_labeled("Sand color", storm_color)
	storm_opacity = _storm_number("Sand opacity", 0.0, 1.0, 0.05)
	storm_particle_size = _storm_number("Grain size", 0.1, 5.0, 0.05)
	var group_title := Label.new()
	group_title.text = "DYNAMIC ENEMY GROUPS"
	dock.add_child(group_title)
	var add_group := Button.new()
	add_group.text = "Add enemy group"
	add_group.pressed.connect(_add_group)
	dock.add_child(add_group)
	var group_scroll := ScrollContainer.new()
	group_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	group_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dock.add_child(group_scroll)
	groups_list = VBoxContainer.new()
	groups_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_scroll.add_child(groups_list)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(status)
	resource_dialog = FileDialog.new()
	resource_dialog.access = FileDialog.ACCESS_RESOURCES
	resource_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	resource_dialog.filters = PackedStringArray(["*.tres ; Godot Resources", "*.png ; Images"])
	resource_dialog.file_selected.connect(_resource_selected)
	dock.add_child(resource_dialog)
	_build_windows()
	_new_encounter()

func _build_windows() -> void:
	preview_window = Window.new()
	preview_window.title = "Encounter map and spawn areas"
	preview_window.size = Vector2i(900, 680)
	preview_window.close_requested.connect(func(): preview_window.hide())
	dock.add_child(preview_window)
	preview_window.hide()
	var preview_layout := VBoxContainer.new()
	preview_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_window.add_child(preview_layout)
	var toolbar := HBoxContainer.new()
	preview_layout.add_child(toolbar)
	preview_target = OptionButton.new()
	preview_target.item_selected.connect(func(index: int):
		preview.selected_group = index - 1
		preview.queue_redraw())
	toolbar.add_child(preview_target)
	var player_label := Label.new()
	player_label.text = "Player #"
	toolbar.add_child(player_label)
	player_index = SpinBox.new()
	player_index.min_value = 1
	player_index.max_value = 20
	player_index.value = 1
	player_index.value_changed.connect(func(value: float): preview.selected_player = int(value) - 1)
	toolbar.add_child(player_index)
	var clear_button := Button.new()
	clear_button.text = "Clear selected area"
	clear_button.pressed.connect(_clear_selected_area)
	toolbar.add_child(clear_button)
	var hint := Label.new()
	hint.text = "Choose Player or an enemy group, then drag a rectangle on the map. Coordinates are feet from map center."
	preview_layout.add_child(hint)
	preview = PreviewScript.new()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.area_drawn.connect(_set_selected_area)
	preview_layout.add_child(preview)
	details_window = Window.new()
	details_window.title = "All EncounterData fields"
	details_window.size = Vector2i(520, 720)
	details_window.close_requested.connect(func(): details_window.hide())
	dock.add_child(details_window)
	details_window.hide()
	details_inspector = EditorInspector.create_default_inspector()
	details_inspector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	details_inspector.property_edited.connect(_on_detail_edited)
	details_window.add_child(details_inspector)

func _open_details() -> void:
	if not _sync_main_fields():
		return
	details_inspector.edit(current)
	details_window.popup_centered()

func _open_preview() -> void:
	if not _sync_main_fields():
		return
	_refresh_preview_targets()
	preview.set_encounter(current)
	preview_window.popup_centered()

func _refresh_preview_targets() -> void:
	var previous := preview_target.selected
	preview_target.clear()
	preview_target.add_item("Player spawn area")
	for group in current.enemy_groups:
		preview_target.add_item("Enemy: %s" % group.id)
	preview_target.select(clampi(previous, 0, preview_target.item_count - 1))
	preview.selected_group = preview_target.selected - 1
	preview.selected_player = int(player_index.value) - 1

func _set_selected_area(area: Rect2) -> void:
	if preview.selected_group < 0:
		var areas: Array[Rect2] = []
		areas.assign(current.player_spawn_areas_feet)
		while areas.size() <= preview.selected_player:
			areas.append(Rect2())
		areas[preview.selected_player] = area
		current.player_spawn_areas_feet = areas
	else:
		var group := current.enemy_groups[preview.selected_group] as EnemyGroupData
		if group != null:
			group.spawn_area_feet = area
	preview.queue_redraw()

func _clear_selected_area() -> void:
	if preview.selected_group < 0:
		if preview.selected_player < current.player_spawn_areas_feet.size():
			var areas: Array[Rect2] = []
			areas.assign(current.player_spawn_areas_feet)
			areas[preview.selected_player] = Rect2()
			current.player_spawn_areas_feet = areas
	elif preview.selected_group < current.enemy_groups.size():
		current.enemy_groups[preview.selected_group].spawn_area_feet = Rect2()
	preview.queue_redraw()

func _on_detail_edited(_property: String) -> void:
	_load_main_fields()
	_load_groups()
	_refresh_preview_targets()
	preview.set_encounter(current)

func _line(label: String, initial: String) -> LineEdit:
	var row := HBoxContainer.new()
	dock.add_child(row)
	var caption := Label.new()
	caption.text = label
	caption.custom_minimum_size.x = 105
	row.add_child(caption)
	var edit := LineEdit.new()
	edit.text = initial
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	return edit

func _add_labeled(label: String, control: Control) -> void:
	var row := HBoxContainer.new()
	dock.add_child(row)
	var caption := Label.new()
	caption.text = label
	caption.custom_minimum_size.x = 105
	row.add_child(caption)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)

func _path_row(label: String, kind: String) -> LineEdit:
	var row := HBoxContainer.new()
	dock.add_child(row)
	var caption := Label.new()
	caption.text = label
	caption.custom_minimum_size.x = 105
	row.add_child(caption)
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	var browse := Button.new()
	browse.text = "..."
	browse.pressed.connect(func():
		pending_resource_kind = kind
		resource_dialog.filters = PackedStringArray(["*.png ; PNG Images"] if kind == "texture" else ["*.tres ; Building Map Resources"])
		resource_dialog.popup_centered_ratio(0.7))
	row.add_child(browse)
	return edit

func _new_encounter() -> void:
	current = EncounterScript.new()
	current.id = "new_encounter"
	current.display_name = "New Encounter"
	_load_main_fields()
	_load_groups()
	status.text = "New encounter."

func _load_main_fields() -> void:
	id_edit.text = current.id
	name_edit.text = current.display_name
	type_select.select(current.type)
	map_edit.text = current.building_map.resource_path if current.building_map != null else ""
	texture_edit.text = current.battlefield_texture.resource_path if current.battlefield_texture != null else ""
	storm_enabled.button_pressed = current.desert_storm_enabled
	storm_intensity.value = current.desert_storm_intensity
	storm_wind_x.value = current.desert_storm_wind.x
	storm_wind_y.value = current.desert_storm_wind.y
	storm_speed.value = current.desert_storm_speed
	storm_density.value = current.desert_storm_density
	storm_color.color = current.desert_storm_color
	storm_opacity.value = current.desert_storm_opacity
	storm_particle_size.value = current.desert_storm_particle_size

func _load_groups() -> void:
	group_rows.clear()
	for group in current.enemy_groups:
		if group is EnemyGroupData:
			group_rows.append({"data": group})
	_refresh_groups()

func _sync_main_fields() -> bool:
	current.desert_storm_enabled = storm_enabled.button_pressed
	current.desert_storm_intensity = storm_intensity.value
	current.desert_storm_wind = Vector2(storm_wind_x.value, storm_wind_y.value)
	current.desert_storm_speed = storm_speed.value
	current.desert_storm_density = storm_density.value
	current.desert_storm_color = storm_color.color
	current.desert_storm_opacity = storm_opacity.value
	current.desert_storm_particle_size = storm_particle_size.value
	current.id = id_edit.text.strip_edges().to_snake_case()
	current.display_name = name_edit.text.strip_edges()
	current.type = type_select.selected
	if not map_edit.text.is_empty():
		var loaded_map := load(map_edit.text) as BuildingMapData
		if loaded_map == null:
			status.text = "Invalid Building Map: %s" % map_edit.text
			return false
		current.building_map = loaded_map
	else:
		current.building_map = null
	if not texture_edit.text.is_empty():
		var loaded_texture := load(texture_edit.text) as Texture2D
		if loaded_texture == null:
			status.text = "Invalid Battlefield PNG: %s" % texture_edit.text
			return false
		current.battlefield_texture = loaded_texture
	else:
		current.battlefield_texture = null
	return true

func _storm_number(label: String, minimum: float, maximum: float, step: float) -> SpinBox:
	var input := SpinBox.new()
	input.min_value = minimum
	input.max_value = maximum
	input.step = step
	_add_labeled(label, input)
	return input

func _open_encounter() -> void:
	pending_resource_kind = "encounter"
	resource_dialog.filters = PackedStringArray(["*.tres ; Encounter Resource"])
	resource_dialog.popup_centered_ratio(0.7)

func _resource_selected(path: String) -> void:
	if pending_resource_kind == "encounter":
		var loaded := load(path) as EncounterData
		if loaded == null:
			status.text = "Not an EncounterData resource."
			return
		current = loaded.duplicate(true)
		_load_main_fields()
		_load_groups()
		details_inspector.edit(current)
		preview.set_encounter(current)
		status.text = "Loaded: %s" % path
		return
	if pending_resource_kind == "map":
		if load(path) is BuildingMapData:
			map_edit.text = path
			_sync_main_fields()
			preview.set_encounter(current)
		else:
			status.text = "Not a BuildingMapData resource."
	elif pending_resource_kind == "texture":
		texture_edit.text = path
		_sync_main_fields()
		preview.set_encounter(current)
	elif pending_resource_kind.begins_with("enemy:"):
		var index := pending_resource_kind.trim_prefix("enemy:").to_int()
		var enemy := load(path) as CharacterData
		if enemy == null or index < 0 or index >= group_rows.size():
			status.text = "Not a CharacterData resource."
			return
		group_rows[index].data.enemy = enemy
		_refresh_groups()

func _add_group() -> void:
	var group := EnemyGroupScript.new()
	group.id = "group_%d" % (group_rows.size() + 1)
	var groups: Array[Resource] = []
	groups.assign(current.enemy_groups)
	groups.append(group)
	current.enemy_groups = groups
	group_rows.append({"data": group})
	_refresh_groups()
	_refresh_preview_targets()
	preview.queue_redraw()

func _refresh_groups() -> void:
	for child in groups_list.get_children(): child.queue_free()
	for row_data in group_rows:
		var group: EnemyGroupData = row_data.data
		var panel := VBoxContainer.new()
		var header := HBoxContainer.new()
		panel.add_child(header)
		var label := Label.new()
		label.text = group.id
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(label)
		var remove := Button.new()
		remove.text = "Remove"
		remove.pressed.connect(func():
			var groups: Array[Resource] = []
			groups.assign(current.enemy_groups)
			groups.erase(group)
			current.enemy_groups = groups
			group_rows.erase(row_data)
			_refresh_groups()
			_refresh_preview_targets()
			preview.queue_redraw())
		header.add_child(remove)
		var id_field := LineEdit.new()
		id_field.text = group.id
		id_field.tooltip_text = "Group ID"
		id_field.text_changed.connect(func(value: String):
			group.id = value.strip_edges().to_snake_case()
			label.text = group.id
			_refresh_preview_targets())
		panel.add_child(id_field)
		var choose := Button.new()
		choose.text = "Choose enemy..." if group.enemy == null else group.enemy.display_name
		choose.pressed.connect(func():
			pending_resource_kind = "enemy:%d" % group_rows.find(row_data)
			resource_dialog.filters = PackedStringArray(["*.tres ; Character Resource"])
			resource_dialog.popup_centered_ratio(0.7))
		panel.add_child(choose)
		var fields := HFlowContainer.new()
		panel.add_child(fields)
		var count := SpinBox.new()
		count.min_value = 1
		count.max_value = 50
		count.value = group.count
		count.tooltip_text = "Count"
		count.value_changed.connect(func(value): group.count = int(value))
		fields.add_child(count)
		var min_level := SpinBox.new()
		min_level.min_value = 1
		min_level.max_value = 10
		min_level.value = group.min_party_level
		min_level.tooltip_text = "Minimum party level"
		min_level.value_changed.connect(func(value): group.min_party_level = int(value))
		fields.add_child(min_level)
		var max_level := SpinBox.new()
		max_level.min_value = 0
		max_level.max_value = 10
		max_level.value = group.max_party_level
		max_level.tooltip_text = "Maximum party level; 0 = unlimited"
		max_level.value_changed.connect(func(value): group.max_party_level = int(value))
		fields.add_child(max_level)
		var inspect_group := Button.new()
		inspect_group.text = "All group fields..."
		inspect_group.pressed.connect(func():
			EditorInterface.edit_resource(group))
		panel.add_child(inspect_group)
		groups_list.add_child(panel)

func _save_encounter() -> void:
	if not _sync_main_fields():
		return
	if current.id.is_empty():
		status.text = "Encounter ID is required."
		return
	for group in current.enemy_groups:
		if group is EnemyGroupData and group.enemy == null:
			status.text = "Choose an enemy for group %s." % group.id
			return
	var directory := "res://data/encounter"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path := "%s/%s.tres" % [directory, current.id]
	var error := ResourceSaver.save(current, path)
	status.text = "Saved: %s" % path if error == OK else "Save failed: %s" % error_string(error)
	EditorInterface.get_resource_filesystem().scan()
