@tool
extends EditorPlugin

const CATALOG_PATH := "res://data/world/map_catalog.tres"
const BLOCK_EDITOR_SCENE: PackedScene = preload("res://addons/building_map_editor/block_editor_3d.tscn")
const AUTHORING_CANVAS_SCENE: PackedScene = preload("res://addons/building_map_editor/map_authoring_canvas.tscn")
const WallDataScript := preload("res://data/world/building_wall_data.gd")
const OBJECT_PRESETS: Array[BuildingObjectPresetData] = [
	preload("res://data/world/object_presets/crate.tres"),
	preload("res://data/world/object_presets/table.tres"),
	preload("res://data/world/object_presets/pillar.tres"),
	preload("res://data/world/object_presets/low_cover.tres"),
]

var dock: VBoxContainer
var canvas
var id_edit: LineEdit
var name_edit: LineEdit
var size_x: SpinBox
var size_y: SpinBox
var scale_edit: SpinBox
var level_height: SpinBox
var floor_count: SpinBox
var object_height: SpinBox
var wall_height: SpinBox
var wall_width: SpinBox
var snap_edit: SpinBox
var layer_select: OptionButton
var tool_select: OptionButton
var path_edits: Array[LineEdit] = []
var texture_rows: Array[Control] = []
var textures: Array[Texture2D] = [null, null, null, null, null, null, null, null]
var file_dialog: FileDialog
var pending_texture_index := 0
var pending_object_texture := false
var status: Label
var panel_3d: VBoxContainer
var block_editor
var workspace: HSplitContainer
var layer_3d_select: OptionButton
var stair_from_select: OptionButton
var stair_to_select: OptionButton
var object_preset_select: OptionButton
var object_edit_panel: VBoxContainer
var object_name_edit: LineEdit
var object_height_edit: SpinBox
var object_collision_edit: CheckButton
var object_movement_edit: CheckButton
var object_los_edit: CheckButton
var object_color_edit: ColorPickerButton
var object_texture_label: Label
var object_layer_select: OptionButton
var layers_window: Window
var layers_floor_select: OptionButton
var layers_list: ItemList
var door_initial_2d: CheckButton
var door_initial_3d: CheckButton
var map_file_dialog: FileDialog
var light_level_select: OptionButton
var light_radius_edit: SpinBox

func _set_door_initial_open(value: bool) -> void:
	if canvas != null:
		canvas.door_starts_open = value
	if door_initial_2d != null:
		door_initial_2d.set_pressed_no_signal(value)
	if door_initial_3d != null:
		door_initial_3d.set_pressed_no_signal(value)

func _enter_tree() -> void:
	_cleanup_workspace()
	path_edits.clear()
	texture_rows.clear()
	textures = [null, null, null, null, null, null, null, null]
	dock = VBoxContainer.new()
	dock.name = "Building Map"
	dock.custom_minimum_size = Vector2(360, 0)
	_build_form()
	_build_3d_panel()
	workspace = HSplitContainer.new()
	workspace.name = "Map Builder"
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var settings_scroll := ScrollContainer.new()
	settings_scroll.custom_minimum_size.x = 390
	settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	workspace.add_child(settings_scroll)
	settings_scroll.add_child(dock)
	dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.add_child(panel_3d)
	panel_3d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_3d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_layers_dialog()
	EditorInterface.get_editor_main_screen().add_child(workspace)
	workspace.hide()
	for field in [size_x, size_y, scale_edit, level_height, snap_edit]:
		field.value_changed.connect(func(_value):
			_on_layer_changed(layer_select.selected)
			_refresh_3d())
	canvas.connect("shape_added", _refresh_3d)
	canvas.shape_added.connect(_refresh_layers_list_if_open)
	block_editor.data_changed.connect(_refresh_layers_list_if_open)
	block_editor.object_selection_changed.connect(func(_data: Dictionary): call_deferred("_refresh_layers_list_if_open"))

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "Map Builder"

func _make_visible(value: bool) -> void:
	if is_instance_valid(workspace): workspace.visible = value

func _exit_tree() -> void:
	_cleanup_workspace()

func _cleanup_workspace() -> void:
	if is_instance_valid(workspace):
		workspace.free()
	workspace = null
	dock = null
	panel_3d = null
	block_editor = null
	canvas = null
	file_dialog = null
	map_file_dialog = null
	status = null
	layers_window = null
	layers_floor_select = null
	layers_list = null
	door_initial_2d = null
	door_initial_3d = null

func _build_3d_panel() -> void:
	panel_3d = VBoxContainer.new()
	var toolbar := HFlowContainer.new()
	panel_3d.add_child(toolbar)
	layer_3d_select = OptionButton.new()
	toolbar.add_child(layer_3d_select)
	var open_layers_3d := Button.new()
	open_layers_3d.text = "Layers..."
	open_layers_3d.pressed.connect(func(): _open_layers_dialog(layer_3d_select.selected))
	toolbar.add_child(open_layers_3d)
	var tool := OptionButton.new()
	for label in ["Select", "Floor", "Wall", "Invisible Wall", "Opening", "Railing", "Object", "Door", "Stairs", "Light (click/drag)"]: tool.add_item(label)
	tool.select(0)
	toolbar.add_child(tool)
	light_level_select = OptionButton.new()
	for label in ["Bright (0)", "Normal (1)", "Dim (2)", "Dark (3)"]:
		light_level_select.add_item(label)
	light_level_select.select(1)
	toolbar.add_child(light_level_select)
	light_radius_edit = _spin(toolbar, "Circle radius ft", 0.1, 500, 15)
	light_level_select.item_selected.connect(func(index: int):
		canvas.light_level = index
		block_editor.update_selected_light(index, light_radius_edit.value))
	light_radius_edit.value_changed.connect(func(value: float):
		canvas.light_radius_feet = value
		block_editor.update_selected_light(light_level_select.selected, value))
	door_initial_3d = CheckButton.new()
	door_initial_3d.text = "Door starts open"
	door_initial_3d.toggled.connect(_set_door_initial_open)
	toolbar.add_child(door_initial_3d)
	var show_lower := CheckButton.new()
	show_lower.text = "Show lower floor"
	show_lower.tooltip_text = "Show Ground beneath Level 1 for alignment. Off keeps the active texture from overlapping another floor."
	toolbar.add_child(show_lower)
	var width := _spin(toolbar, "Block width px", 1, 2048, 40)
	var depth := _spin(toolbar, "Block depth px", 1, 2048, 40)
	var stair_start_height := _spin(toolbar, "Stair start ft", -100, 1000, 0)
	var stair_end_height := _spin(toolbar, "Stair end ft", -100, 1000, level_height.value)
	object_preset_select = OptionButton.new()
	for preset in OBJECT_PRESETS: object_preset_select.add_item(preset.display_name)
	toolbar.add_child(object_preset_select)
	stair_from_select = OptionButton.new()
	stair_to_select = OptionButton.new()
	toolbar.add_child(stair_from_select)
	toolbar.add_child(stair_to_select)
	var refresh_button := Button.new()
	refresh_button.text = "Save map"
	toolbar.add_child(refresh_button)
	var load_button := Button.new()
	load_button.text = "Load map..."
	load_button.pressed.connect(_open_map_loader)
	toolbar.add_child(load_button)
	var delete_button := Button.new()
	delete_button.text = "Delete selected"
	delete_button.disabled = true
	toolbar.add_child(delete_button)
	var hint := Label.new()
	hint.text = "Wall: drag from start to end; set height and thickness on the left. Light: click for a circle, drag for a rectangle. Select: drag to move, Delete to remove."
	panel_3d.add_child(hint)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var notice := Label.new()
	notice.text = "Ready. Select a tool and click on the map."
	notice.add_theme_color_override("font_color", Color("e8bd59"))
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_3d.add_child(notice)
	_build_object_editor(panel_3d)
	for view_name in ["Top view", "3D view", "Fit map"]:
		var view_button := Button.new()
		view_button.text = view_name
		view_button.pressed.connect(func():
			if view_name == "Fit map": block_editor.fit_map()
			else: block_editor.reset_view(view_name == "Top view"))
		toolbar.add_child(view_button)
	block_editor = BLOCK_EDITOR_SCENE.instantiate()
	block_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_3d.add_child(block_editor)
	layer_3d_select.item_selected.connect(func(index: int): block_editor.set_layer(_surface_id(index)))
	tool.item_selected.connect(func(index: int): block_editor.set_tool([&"select", &"walkable", &"wall", &"invisible_wall", &"opening", &"railing", &"object", &"door", &"stairs", &"light_point"][index]))
	show_lower.toggled.connect(Callable(block_editor, "set_show_lower_floor"))
	width.value_changed.connect(func(value: float): block_editor.set_block_size(Vector2(value, depth.value)))
	depth.value_changed.connect(func(value: float): block_editor.set_block_size(Vector2(width.value, value)))
	stair_start_height.value_changed.connect(func(value: float):
		canvas.stair_start_feet = value
		block_editor.set_stair_elevations(value, stair_end_height.value))
	stair_end_height.value_changed.connect(func(value: float):
		canvas.stair_end_feet = value
		block_editor.set_stair_elevations(stair_start_height.value, value))
	stair_from_select.item_selected.connect(func(_index: int): _refresh_stair_surface_selection())
	stair_to_select.item_selected.connect(func(_index: int): _refresh_stair_surface_selection())
	object_preset_select.item_selected.connect(_select_object_preset)
	refresh_button.pressed.connect(_save_map)
	delete_button.pressed.connect(Callable(block_editor, "delete_selected"))
	block_editor.connect("selection_changed", func(has_selection: bool): delete_button.disabled = not has_selection)
	block_editor.connect("notice_changed", func(message: String): notice.text = message)
	block_editor.connect("object_selection_changed", _show_object_editor)
	block_editor.light_selection_changed.connect(_show_light_editor)
	block_editor.wall_selection_changed.connect(_show_wall_editor)
	block_editor.connect("layer_change_requested", func(requested_layer: StringName):
		var index := _surface_index(requested_layer)
		layer_3d_select.select(index)
		block_editor.set_layer(requested_layer)
	)
	_refresh_floor_controls()
	_select_object_preset(0)

func _show_light_editor(data: Dictionary) -> void:
	if data.is_empty():
		light_radius_edit.editable = true
		return
	light_level_select.select(clampi(int(data.get("level", 1)), 0, 3))
	light_radius_edit.set_value_no_signal(float(data.get("radius_feet", 15.0)))
	light_radius_edit.editable = not data.has("rect")
	canvas.light_level = light_level_select.selected
	canvas.light_radius_feet = light_radius_edit.value


func _show_wall_editor(data: Dictionary) -> void:
	if data.is_empty() or wall_height == null or wall_width == null:
		return
	wall_height.set_value_no_signal(float(data.get("height_feet", 9.0)))
	wall_width.set_value_no_signal(float(data.get("width_feet", 1.5)) * scale_edit.value)
	canvas.wall_height_feet = wall_height.value
	canvas.wall_width_pixels = wall_width.value

func _build_object_editor(parent: Control) -> void:
	object_edit_panel = VBoxContainer.new()
	object_edit_panel.visible = false
	parent.add_child(object_edit_panel)
	var title := Label.new()
	title.text = "EDIT OBJECT"
	object_edit_panel.add_child(title)
	var fields := HFlowContainer.new()
	object_edit_panel.add_child(fields)
	object_name_edit = LineEdit.new()
	object_name_edit.placeholder_text = "Object name"
	object_name_edit.custom_minimum_size.x = 130
	fields.add_child(object_name_edit)
	object_height_edit = _spin(fields, "Height ft", 0.1, 100, 3)
	object_collision_edit = CheckButton.new()
	object_collision_edit.text = "Collision"
	fields.add_child(object_collision_edit)
	object_movement_edit = CheckButton.new()
	object_movement_edit.text = "Blocks movement"
	fields.add_child(object_movement_edit)
	object_los_edit = CheckButton.new()
	object_los_edit.text = "Blocks sight/AoE"
	fields.add_child(object_los_edit)
	object_color_edit = ColorPickerButton.new()
	object_color_edit.text = "Color"
	fields.add_child(object_color_edit)
	var object_layer_label := Label.new()
	object_layer_label.text = "Image layer"
	fields.add_child(object_layer_label)
	object_layer_select = OptionButton.new()
	object_layer_select.add_item("Behind map image", 0)
	object_layer_select.add_item("Above map image", 1)
	object_layer_select.tooltip_text = "Choose whether this object's image appears behind or above its floor map image. Collision is unchanged."
	fields.add_child(object_layer_select)
	object_layer_select.item_selected.connect(func(index: int): block_editor.update_selected_object({"image_layer": index}))
	object_texture_label = Label.new()
	object_texture_label.text = "No object image"
	fields.add_child(object_texture_label)
	var browse_image := Button.new()
	browse_image.text = "Choose object PNG"
	browse_image.pressed.connect(_browse_object_texture)
	fields.add_child(browse_image)
	var clear_image := Button.new()
	clear_image.text = "Clear image"
	clear_image.pressed.connect(func():
		object_texture_label.text = "No object image"
		block_editor.update_selected_object({"texture": null}))
	fields.add_child(clear_image)
	var apply := Button.new()
	apply.text = "Apply object properties"
	apply.pressed.connect(_apply_object_editor)
	fields.add_child(apply)

func _show_object_editor(data: Dictionary) -> void:
	if object_edit_panel == null: return
	object_edit_panel.visible = not data.is_empty()
	if data.is_empty(): return
	object_name_edit.text = data.get("display_name", "Map Object")
	object_height_edit.value = data.get("height_feet", 3.0)
	object_collision_edit.button_pressed = data.get("collision_enabled", true)
	object_movement_edit.button_pressed = data.get("blocks_movement", true)
	object_los_edit.button_pressed = data.get("blocks_line_of_sight", true)
	object_color_edit.color = data.get("color", Color("8a6544"))
	object_layer_select.select(clampi(int(data.get("image_layer", 1)), 0, 1))
	var object_texture = data.get("texture")
	object_texture_label.text = object_texture.resource_path if object_texture is Texture2D else "No object image"

func _apply_object_editor() -> void:
	if block_editor == null: return
	block_editor.update_selected_object({
		"display_name": object_name_edit.text.strip_edges(),
		"height_feet": object_height_edit.value,
		"collision_enabled": object_collision_edit.button_pressed,
		"blocks_movement": object_movement_edit.button_pressed,
		"blocks_line_of_sight": object_los_edit.button_pressed,
		"color": object_color_edit.color,
		"image_layer": object_layer_select.selected,
	})

func _refresh_3d() -> void:
	if block_editor == null or canvas == null: return
	canvas.pixels_per_foot = scale_edit.value
	canvas.stair_end_feet = level_height.value if canvas.stairs.is_empty() else canvas.stair_end_feet
	block_editor.set_snap(snap_edit.value)
	var texture_map: Dictionary = {}
	var elevations: Dictionary = {}
	for index in range(_floor_total()):
		var id := _surface_id(index)
		texture_map[id] = textures[index]
		elevations[id] = index * level_height.value
	block_editor.configure(canvas, Vector2(size_x.value, size_y.value), scale_edit.value, level_height.value, texture_map, elevations)
	_refresh_stair_surface_selection()

func _floor_total() -> int:
	return int(floor_count.value) if floor_count != null else 2

func _surface_id(index: int) -> StringName:
	return &"ground" if index == 0 else StringName("level_%d" % index)

func _surface_label(index: int) -> String:
	return "Ground" if index == 0 else "Level %d" % index

func _surface_index(id: StringName) -> int:
	if id == &"ground": return 0
	return clampi(String(id).trim_prefix("level_").to_int(), 0, maxi(0, _floor_total() - 1))

func _refresh_floor_controls() -> void:
	if floor_count == null: return
	var total: int = _floor_total()
	for index in range(texture_rows.size()): texture_rows[index].visible = index < total
	for selector_value in [layer_select, layer_3d_select, stair_from_select, stair_to_select]:
		var selector: OptionButton = selector_value
		if selector == null: continue
		var previous: int = selector.selected
		selector.clear()
		for index in range(total): selector.add_item(_surface_label(index))
		selector.select(clampi(previous, 0, total - 1))
	for index in range(total): canvas.ensure_layer(_surface_id(index))
	if stair_to_select != null and total > 1 and stair_to_select.selected == 0: stair_to_select.select(1)
	_on_layer_changed(clampi(layer_select.selected, 0, total - 1))
	_refresh_3d()
	_refresh_layer_floor_choices()

func _build_layers_dialog() -> void:
	layers_window = Window.new()
	layers_window.title = "Map Layers"
	layers_window.size = Vector2i(400, 450)
	layers_window.close_requested.connect(func(): layers_window.hide())
	workspace.add_child(layers_window)
	layers_window.hide()
	var margin := MarginContainer.new()
	layers_window.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	var hint := Label.new()
	hint.text = "Bottom to top. Select an object and move it across the map image or another object."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(hint)
	layers_floor_select = OptionButton.new()
	layers_floor_select.item_selected.connect(_on_layers_floor_selected)
	layout.add_child(layers_floor_select)
	layers_list = ItemList.new()
	layers_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layers_list.item_selected.connect(_on_layer_row_selected)
	layout.add_child(layers_list)
	var buttons := HBoxContainer.new()
	layout.add_child(buttons)
	var move_down := Button.new()
	move_down.text = "Move down"
	move_down.pressed.connect(func(): _move_selected_layer(-1))
	buttons.add_child(move_down)
	var move_up := Button.new()
	move_up.text = "Move up"
	move_up.pressed.connect(func(): _move_selected_layer(1))
	buttons.add_child(move_up)
	_refresh_layer_floor_choices()

func _refresh_layer_floor_choices() -> void:
	if layers_floor_select == null:
		return
	var previous := layers_floor_select.selected
	layers_floor_select.clear()
	for index in range(_floor_total()):
		layers_floor_select.add_item(_surface_label(index))
	layers_floor_select.select(clampi(previous, 0, _floor_total() - 1))
	_refresh_layers_list()

func _open_layers_dialog(floor_index: int) -> void:
	if layers_window == null:
		return
	var selected_floor := clampi(floor_index, 0, _floor_total() - 1)
	layers_floor_select.select(selected_floor)
	_sync_layers_floor(selected_floor)
	_refresh_layers_list()
	layers_window.popup_centered()

func _refresh_layers_list_if_open() -> void:
	if layers_window != null and layers_window.visible:
		_refresh_layers_list()

func _on_layers_floor_selected(floor_index: int) -> void:
	_sync_layers_floor(floor_index)
	_refresh_layers_list()

func _sync_layers_floor(floor_index: int) -> void:
	var floor_id := _surface_id(floor_index)
	layer_3d_select.select(floor_index)
	layer_select.select(floor_index)
	_on_layer_changed(floor_index)
	if block_editor.active_layer != floor_id:
		block_editor.set_layer(floor_id)

func _refresh_layers_list() -> void:
	if layers_list == null or canvas == null or layers_floor_select == null:
		return
	var floor_index := layers_floor_select.selected
	if floor_index < 0:
		return
	var floor_id := _surface_id(floor_index)
	layers_list.clear()
	var objects: Array = canvas.shapes[floor_id].object
	for object_index in canvas.object_layer_order(floor_id):
		var label := "Map image: %s" % _surface_label(floor_index) if object_index == -1 else "Object: %s" % objects[object_index].get("display_name", "Map Object")
		var row := layers_list.item_count
		layers_list.add_item(label)
		layers_list.set_item_metadata(row, object_index)
		if object_index >= 0 and block_editor != null and block_editor.selected_layer == floor_id and block_editor.selected_kind == "object" and block_editor.selected_index == object_index:
			layers_list.select(row)

func _on_layer_row_selected(row: int) -> void:
	var floor_index := layers_floor_select.selected
	var floor_id := _surface_id(floor_index)
	var object_index := int(layers_list.get_item_metadata(row))
	_sync_layers_floor(floor_index)
	if object_index >= 0:
		block_editor.select_object(floor_id, object_index)
	else:
		block_editor.clear_selection()

func _move_selected_layer(direction: int) -> void:
	var selected_rows := layers_list.get_selected_items()
	if selected_rows.is_empty():
		return
	var object_index := int(layers_list.get_item_metadata(selected_rows[0]))
	if object_index < 0:
		return
	var floor_id := _surface_id(layers_floor_select.selected)
	var new_index: int = canvas.move_object_layer(floor_id, object_index, direction)
	block_editor.select_object(floor_id, new_index)
	_refresh_layers_list()

func _refresh_stair_surface_selection() -> void:
	if block_editor == null or stair_from_select == null or stair_to_select == null: return
	var from_id: StringName = _surface_id(stair_from_select.selected)
	var to_id: StringName = _surface_id(stair_to_select.selected)
	block_editor.configure_stair_surfaces(from_id, to_id)

func _select_object_preset(index: int) -> void:
	if index < 0 or index >= OBJECT_PRESETS.size() or canvas == null: return
	var preset := OBJECT_PRESETS[index]
	var value := {
		"preset_id": preset.preset_id,
		"display_name": preset.display_name,
		"height_feet": preset.height_feet,
		"collision_enabled": preset.collision_enabled,
		"blocks_movement": preset.blocks_movement,
		"blocks_line_of_sight": preset.blocks_line_of_sight,
		"color": preset.color,
		"texture": preset.texture,
		"image_layer": 1,
	}
	canvas.object_preset = value
	if block_editor != null:
		block_editor.set_object_preset(value)
		block_editor.set_block_size(preset.default_size_pixels)
	if object_height != null: object_height.value = preset.height_feet

func _set_object_height(value: float) -> void:
	if canvas == null: return
	canvas.object_preset["height_feet"] = value
	if block_editor != null:
		var preset: Dictionary = block_editor.object_preset.duplicate()
		preset["height_feet"] = value
		block_editor.set_object_preset(preset)

func _build_form() -> void:
	var title := Label.new()
	title.text = "BUILDING MAP AUTHORING"
	dock.add_child(title)
	var steps := Label.new()
	steps.text = "1. Choose images and scale\n2. Pick a floor and place blocks\n3. Save map"
	dock.add_child(steps)
	id_edit = _line("Map ID", "new_building")
	name_edit = _line("Display name", "New Building")
	var dimensions := VBoxContainer.new()
	dock.add_child(dimensions)
	size_x = _spin(dimensions, "Width", 64, 16384, 1600)
	size_y = _spin(dimensions, "Height", 64, 16384, 1600)
	scale_edit = _spin(dimensions, "Px/ft", 1, 256, 12)
	level_height = _spin(dimensions, "Level ft", 1, 100, 10)
	floor_count = _spin(dimensions, "Floor count", 1, 8, 2)
	object_height = _spin(dimensions, "Object height ft", 0.1, 100, 3)
	object_height.value_changed.connect(_set_object_height)
	wall_height = _spin(dimensions, "Wall height ft", 0.1, 100, 9)
	wall_width = _spin(dimensions, "Wall thickness px", 1, 512, 20)
	wall_height.value_changed.connect(func(value: float):
		canvas.wall_height_feet = value
		block_editor.update_selected_wall(value, wall_width.value))
	wall_width.value_changed.connect(func(value: float):
		canvas.wall_width_pixels = value
		block_editor.update_selected_wall(wall_height.value, value))
	floor_count.value_changed.connect(func(_value: float): _refresh_floor_controls())
	var snap_row := HBoxContainer.new()
	dock.add_child(snap_row)
	var snap_label := Label.new()
	snap_label.text = "Snap pixels"
	snap_label.custom_minimum_size.x = 90
	snap_row.add_child(snap_label)
	snap_edit = _spin(snap_row, "Snap every N source pixels", 1, 512, 10)
	snap_edit.value_changed.connect(func(value: float):
		if canvas != null:
			canvas.set_snap_pixels(value)
	)
	for floor_index in range(8):
		var row := HBoxContainer.new()
		dock.add_child(row)
		texture_rows.append(row)
		var edit := LineEdit.new()
		edit.placeholder_text = "%s PNG" % _surface_label(floor_index)
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(edit)
		path_edits.append(edit)
		var button := Button.new()
		button.text = "Browse"
		var index := path_edits.size() - 1
		button.pressed.connect(func(): _browse_texture(index))
		row.add_child(button)
	var controls := HBoxContainer.new()
	dock.add_child(controls)
	layer_select = OptionButton.new()
	layer_select.item_selected.connect(_on_layer_changed)
	controls.add_child(layer_select)
	tool_select = OptionButton.new()
	for label in ["Walkable", "Wall", "Invisible Wall", "Opening", "Railing", "Object", "Door", "Stairs", "Light (click/drag)"]: tool_select.add_item(label)
	tool_select.item_selected.connect(func(index: int): canvas.set_tool([&"walkable", &"wall", &"invisible_wall", &"opening", &"railing", &"object", &"door", &"stairs", &"light_point"][index]))
	controls.add_child(tool_select)
	door_initial_2d = CheckButton.new()
	door_initial_2d.text = "Door starts open"
	door_initial_2d.toggled.connect(_set_door_initial_open)
	controls.add_child(door_initial_2d)
	var undo := Button.new()
	undo.text = "Undo"
	undo.pressed.connect(func(): canvas.undo_last())
	controls.add_child(undo)
	var open_layers_2d := Button.new()
	open_layers_2d.text = "Layers..."
	open_layers_2d.pressed.connect(func(): _open_layers_dialog(layer_select.selected))
	controls.add_child(open_layers_2d)
	canvas = AUTHORING_CANVAS_SCENE.instantiate()
	canvas.set_snap_pixels(snap_edit.value)
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var canvas_controls := HBoxContainer.new()
	dock.add_child(canvas_controls)
	var toggle_2d := CheckButton.new()
	toggle_2d.text = "Show optional 2D drawing"
	toggle_2d.toggled.connect(func(value): canvas.visible = value)
	canvas_controls.add_child(toggle_2d)
	var zoom_out := Button.new()
	zoom_out.text = "−"
	zoom_out.tooltip_text = "Zoom out 2D map"
	zoom_out.pressed.connect(func(): canvas.zoom_at_screen_position(1.0 / MapAuthoringCanvas.ZOOM_STEP, canvas.size * 0.5))
	canvas_controls.add_child(zoom_out)
	var zoom_in := Button.new()
	zoom_in.text = "+"
	zoom_in.tooltip_text = "Zoom in 2D map"
	zoom_in.pressed.connect(func(): canvas.zoom_at_screen_position(MapAuthoringCanvas.ZOOM_STEP, canvas.size * 0.5))
	canvas_controls.add_child(zoom_in)
	var fit_2d := Button.new()
	fit_2d.text = "Fit 2D"
	fit_2d.pressed.connect(func(): canvas.reset_view())
	canvas_controls.add_child(fit_2d)
	var zoom_label := Label.new()
	zoom_label.text = "100%"
	canvas.zoom_changed.connect(func(value: float): zoom_label.text = "%d%%" % roundi(value * 100.0))
	canvas_controls.add_child(zoom_label)
	dock.add_child(canvas)
	canvas.hide()
	var help := Label.new()
	help.text = "2D: wheel to zoom, middle drag to pan. Wall: drag a line from start to end. Other shapes: drag rectangles. For stairs, drag its bounding box first, then click the start and end points."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(help)
	var save := Button.new()
	save.text = "SAVE + REGISTER MAP"
	save.pressed.connect(_save_map)
	dock.add_child(save)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(status)
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.png ; PNG Images"])
	file_dialog.file_selected.connect(_texture_selected)
	dock.add_child(file_dialog)
	map_file_dialog = FileDialog.new()
	map_file_dialog.access = FileDialog.ACCESS_RESOURCES
	map_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	map_file_dialog.filters = PackedStringArray(["*.tres ; Building Map Resources"])
	map_file_dialog.file_selected.connect(_load_map)
	dock.add_child(map_file_dialog)
	_refresh_floor_controls()

func _line(label: String, initial: String) -> LineEdit:
	var row := HBoxContainer.new()
	dock.add_child(row)
	var caption := Label.new()
	caption.text = label
	caption.custom_minimum_size.x = 90
	row.add_child(caption)
	var edit := LineEdit.new()
	edit.text = initial
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	return edit

func _spin(parent: Control, tooltip: String, minimum: float, maximum: float, initial: float) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var caption := Label.new()
	caption.text = tooltip
	row.add_child(caption)
	var spin := SpinBox.new()
	spin.tooltip_text = tooltip
	spin.min_value = minimum
	spin.max_value = maximum
	spin.value = initial
	spin.custom_minimum_size.x = 72
	row.add_child(spin)
	return spin

func _browse_texture(index: int) -> void:
	pending_object_texture = false
	pending_texture_index = index
	file_dialog.popup_centered_ratio(0.7)

func _browse_object_texture() -> void:
	pending_object_texture = true
	file_dialog.popup_centered_ratio(0.7)

func _texture_selected(path: String) -> void:
	var loaded := load(path) as Texture2D
	if loaded == null:
		status.text = "Could not load texture: %s" % path
		return
	if pending_object_texture:
		pending_object_texture = false
		object_texture_label.text = path
		block_editor.update_selected_object({"texture": loaded})
		return
	textures[pending_texture_index] = loaded
	path_edits[pending_texture_index].text = path
	_on_layer_changed(layer_select.selected)
	_refresh_3d()

func _open_map_loader() -> void:
	if map_file_dialog != null:
		map_file_dialog.popup_centered_ratio(0.7)

func _load_map(path: String) -> void:
	var map := load(path) as BuildingMapData
	if map == null:
		status.text = "Could not load BuildingMapData: %s" % path
		return
	if map.surfaces.is_empty():
		status.text = "Map has no surfaces: %s" % path
		return

	id_edit.text = String(map.map_id)
	name_edit.text = map.display_name
	size_x.value = map.source_size.x
	size_y.value = map.source_size.y
	scale_edit.value = map.pixels_per_foot
	var first_elevation := map.surfaces[0].elevation_feet
	level_height.value = _infer_level_height(map, first_elevation)
	floor_count.value = clampi(map.surfaces.size(), 1, 8)
	textures = [null, null, null, null, null, null, null, null]
	for index in range(map.surfaces.size()):
		var surface: BuildingSurfaceData = map.surfaces[index]
		textures[index] = surface.texture
		path_edits[index].text = surface.texture.resource_path if surface.texture != null else ""
	_refresh_floor_controls()
	canvas.clear_all()
	canvas.light_points.assign(map.light_points)
	for index in range(map.surfaces.size()):
		var surface: BuildingSurfaceData = map.surfaces[index]
		var floor_id := _surface_id(index)
		canvas.ensure_layer(floor_id)
		canvas.shapes[floor_id].walkable.assign(surface.walkable_rects)
		for wall_index in range(surface.wall_rects.size()):
			canvas.shapes[floor_id].wall.append({"rect": surface.wall_rects[wall_index], "height_feet": surface.wall_rect_heights_feet[wall_index] if wall_index < surface.wall_rect_heights_feet.size() else 9.0})
		for wall in surface.wall_segments:
			if wall != null:
				canvas.shapes[floor_id].wall.append({"from": wall.from_position, "to": wall.to_position, "width_feet": wall.width_feet, "height_feet": wall.height_feet})
		canvas.shapes[floor_id].opening.assign(surface.opening_rects)
		canvas.shapes[floor_id].railing.assign(surface.railing_rects)
		canvas.shapes[floor_id].invisible_wall.assign(surface.invisible_wall_rects)
		for door in surface.doors:
			canvas.shapes[floor_id].door.append({"rect": door.rect, "starts_open": door.starts_open})
		for object_data in surface.objects:
			canvas.shapes[floor_id].object.append({
				"preset_id": object_data.preset_id,
				"display_name": object_data.display_name,
				"rect": object_data.rect,
				"height_feet": object_data.height_feet,
				"collision_enabled": object_data.collision_enabled,
				"blocks_movement": object_data.blocks_movement,
				"blocks_line_of_sight": object_data.blocks_line_of_sight,
				"color": object_data.color,
				"texture": object_data.texture,
				"image_layer": object_data.image_layer,
			})
	for transition in map.transitions:
		var bounds := Rect2(transition.from_position, transition.to_position - transition.from_position).abs().grow(transition.width_feet * map.pixels_per_foot * 0.5)
		var from_elevation := transition.from_elevation_feet if transition.use_custom_elevations else _surface_elevation(map, transition.from_surface_id)
		var to_elevation := transition.to_elevation_feet if transition.use_custom_elevations else _surface_elevation(map, transition.to_surface_id)
		canvas.stairs.append({
			"from": transition.from_position,
			"to": transition.to_position,
			"from_surface_id": transition.from_surface_id,
			"to_surface_id": transition.to_surface_id,
			"from_elevation_feet": from_elevation,
			"to_elevation_feet": to_elevation,
			"width_feet": transition.width_feet,
			"bounds": bounds,
		})
	canvas.set_layer(&"ground", textures[0])
	_refresh_3d()
	status.text = "Loaded map for editing: %s" % path

func _infer_level_height(map: BuildingMapData, fallback: float) -> float:
	if map.surfaces.size() < 2:
		return maxf(1.0, fallback)
	var delta := map.surfaces[1].elevation_feet - map.surfaces[0].elevation_feet
	return maxf(1.0, delta)

func _surface_elevation(map: BuildingMapData, surface_id: StringName) -> float:
	for surface in map.surfaces:
		if surface != null and surface.surface_id == surface_id:
			return surface.elevation_feet
	return 0.0

func _on_layer_changed(index: int) -> void:
	canvas.source_size = Vector2(size_x.value, size_y.value)
	canvas.set_layer(_surface_id(index), textures[index])

func _save_map() -> void:
	var map_id := id_edit.text.strip_edges().to_snake_case()
	if map_id.is_empty() or textures[0] == null:
		status.text = "Map ID and Ground PNG are required."
		return
	for authored_stair in canvas.stairs:
		if authored_stair.get("from_surface_id", &"ground") == authored_stair.get("to_surface_id", &"level_1"):
			status.text = "A stair must connect two different floors."
			return
		var reaches_opening := false
		var stair_to_id: StringName = authored_stair.get("to_surface_id", &"level_1")
		for opening: Rect2 in canvas.shapes[stair_to_id].opening:
			if opening.has_point(authored_stair.to):
				reaches_opening = true
				break
		if not reaches_opening:
			status.text = "Every stair endpoint must be inside a Level 1 Opening rectangle."
			return
	canvas.source_size = Vector2(size_x.value, size_y.value)
	var map := BuildingMapData.new()
	map.map_id = StringName(map_id)
	map.display_name = name_edit.text.strip_edges()
	map.source_size = canvas.source_size
	map.pixels_per_foot = scale_edit.value
	for light in canvas.light_points:
		map.light_points.append(light.duplicate(true))
	for floor_index in range(_floor_total()):
		var surface := _surface(_surface_id(floor_index), _surface_label(floor_index), floor_index * level_height.value, textures[floor_index])
		if floor_index == 0 and surface.walkable_rects.is_empty(): surface.walkable_rects = [Rect2(Vector2.ZERO, map.source_size)]
		map.surfaces.append(surface)
	for index in range(canvas.stairs.size()):
		var authored: Dictionary = canvas.stairs[index]
		var transition := BuildingTransitionData.new()
		transition.transition_id = StringName("stairs_%d" % (index + 1))
		transition.from_surface_id = authored.get("from_surface_id", &"ground")
		transition.to_surface_id = authored.get("to_surface_id", &"level_1")
		transition.from_position = authored.from
		transition.to_position = authored.to
		transition.use_custom_elevations = true
		var authored_start_feet: float = authored.get("from_elevation_feet", 0.0)
		var authored_end_feet: float = authored.get("to_elevation_feet", level_height.value)
		transition.from_elevation_feet = authored_start_feet
		transition.to_elevation_feet = authored_end_feet
		transition.width_feet = authored.width_feet
		transition.render_as_wedge = true
		map.transitions.append(transition)
	var directory := "res://data/world/%s" % map_id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var save_path := "%s/%s_map.tres" % [directory, map_id]
	var error := ResourceSaver.save(map, save_path)
	if error != OK:
		status.text = "Save failed: %s" % error_string(error)
		return
	var catalog := load(CATALOG_PATH) as BuildingMapCatalog
	if catalog != null:
		var replaced := false
		for index in range(catalog.maps.size()):
			if catalog.maps[index] != null and catalog.maps[index].map_id == map.map_id:
				catalog.maps[index] = map
				replaced = true
				break
		if not replaced:
			catalog.maps.append(map)
		ResourceSaver.save(catalog, CATALOG_PATH)
	EditorInterface.get_resource_filesystem().scan()
	status.text = "Saved and registered: %s" % save_path

func _surface(id: StringName, display: String, elevation: float, layer_texture: Texture2D) -> BuildingSurfaceData:
	var surface := BuildingSurfaceData.new()
	surface.surface_id = id
	surface.display_name = display
	surface.elevation_feet = elevation
	surface.texture = layer_texture
	var authored: Dictionary = canvas.shapes[id]
	surface.walkable_rects.assign(authored.walkable)
	for wall in authored.wall:
		if wall is Dictionary and wall.has("from"):
			var segment = WallDataScript.new()
			segment.from_position = wall.from
			segment.to_position = wall.to
			segment.width_feet = maxf(0.1, float(wall.get("width_feet", 1.5)))
			segment.height_feet = maxf(0.1, float(wall.get("height_feet", 9.0)))
			surface.wall_segments.append(segment)
		else:
			surface.wall_rects.append(wall.get("rect", Rect2()) if wall is Dictionary else wall)
			surface.wall_rect_heights_feet.append(float(wall.get("height_feet", 9.0)) if wall is Dictionary else 9.0)
	surface.opening_rects.assign(authored.opening)
	surface.railing_rects.assign(authored.railing)
	surface.invisible_wall_rects.assign(authored.invisible_wall)
	for index in range(authored.door.size()):
		var door := BuildingDoorData.new()
		var authored_door: Dictionary = authored.door[index]
		door.door_id = StringName("door_%d" % (index + 1))
		door.rect = authored_door.get("rect", Rect2())
		door.starts_open = bool(authored_door.get("starts_open", false))
		surface.doors.append(door)
	for index in range(authored.object.size()):
		var object := BuildingObjectData.new()
		var authored_object = authored.object[index]
		object.object_id = StringName("object_%d" % (index + 1))
		object.preset_id = authored_object.get("preset_id", &"crate") if authored_object is Dictionary else &"crate"
		object.display_name = authored_object.get("display_name", "Map Object %d" % (index + 1)) if authored_object is Dictionary else "Map Object %d" % (index + 1)
		object.rect = authored_object.get("rect", Rect2()) if authored_object is Dictionary else authored_object
		object.height_feet = authored_object.get("height_feet", object_height.value) if authored_object is Dictionary else object_height.value
		object.collision_enabled = authored_object.get("collision_enabled", true) if authored_object is Dictionary else true
		object.blocks_movement = authored_object.get("blocks_movement", true) if authored_object is Dictionary else true
		object.blocks_line_of_sight = authored_object.get("blocks_line_of_sight", true) if authored_object is Dictionary else true
		object.color = authored_object.get("color", Color("8a6544")) if authored_object is Dictionary else Color("8a6544")
		object.texture = authored_object.get("texture") if authored_object is Dictionary else null
		object.image_layer = int(authored_object.get("image_layer", 1)) if authored_object is Dictionary else 1
		surface.objects.append(object)
	return surface
