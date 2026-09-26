@tool
class_name BuildingBlockEditor3D
extends SubViewportContainer

const MapLightVisual := preload("res://data/world/map_light_visual.gd")

signal data_changed
signal selection_changed(has_selection: bool)
signal layer_change_requested(layer: StringName)
signal notice_changed(message: String)
signal object_selection_changed(data: Dictionary)
signal light_selection_changed(data: Dictionary)
signal wall_selection_changed(data: Dictionary)

const BLOCK_COLORS := {
	&"walkable": Color(0.18, 0.75, 0.28, 0.55),
	&"wall": Color(0.55, 0.22, 0.14, 1.0),
	&"invisible_wall": Color(0.85, 0.9, 1.0, 0.28),
	&"opening": Color(0.1, 0.65, 1.0, 0.65),
	&"railing": Color(0.9, 0.65, 0.12, 1.0),
	&"object": Color(0.55, 0.32, 0.14, 1.0),
	&"door": Color(1.0, 0.64, 0.12, 1.0),
}

var authoring_canvas: MapAuthoringCanvas
var source_size := Vector2(1600, 1600)
var pixels_per_foot := 12.0
var level_height := 10.0
var stair_start_feet := 0.0
var stair_end_feet := 10.0
var snap_pixels := 10.0
var block_size_pixels := Vector2(40, 40)
var active_layer: StringName = &"ground"
var active_tool: StringName = &"select"
var textures: Dictionary = {}
var layer_elevations: Dictionary = {&"ground": 0.0, &"level_1": 10.0}
var stair_from_surface: StringName = &"ground"
var stair_to_surface: StringName = &"level_1"
var object_preset: Dictionary = {"preset_id": &"crate", "display_name": "Crate", "height_feet": 3.0, "collision_enabled": true, "blocks_movement": true, "blocks_line_of_sight": true, "color": Color("8a6544")}
var viewport_3d: SubViewport
var world_root: Node3D
var block_root: Node3D
var camera: Camera3D
var stair_start := Vector2.INF
var stair_bounds := Rect2()
var stair_box_drag_start := Vector2.INF
var stair_box_drag_current := Vector2.INF
var light_drag_start := Vector2.INF
var light_drag_current := Vector2.INF
var wall_drag_start := Vector2.INF
var wall_drag_current := Vector2.INF
var middle_dragging := false
var camera_target := Vector3.ZERO
var show_lower_floor := false
var selected_layer: StringName = &""
var selected_kind := ""
var selected_index := -1
var selection_dragging := false
var selection_drag_offset := Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(360, 320)
	stretch = true
	focus_mode = Control.FOCUS_ALL
	viewport_3d = SubViewport.new()
	viewport_3d.world_3d = World3D.new()
	viewport_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_3d.transparent_bg = false
	add_child(viewport_3d)
	world_root = Node3D.new()
	viewport_3d.add_child(world_root)
	block_root = Node3D.new()
	block_root.name = "Blocks"
	world_root.add_child(block_root)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 120.0
	camera.current = true
	world_root.add_child(camera)
	camera.look_at_from_position(Vector3(0, 95, 70), camera_target)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.shadow_enabled = true
	world_root.add_child(light)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.045, 0.055)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.55
	environment.environment = env
	world_root.add_child(environment)
	refresh()

func configure(canvas: MapAuthoringCanvas, map_size: Vector2, ppf: float, height: float, layer_textures: Dictionary, elevations: Dictionary = {}) -> void:
	authoring_canvas = canvas
	source_size = map_size
	pixels_per_foot = maxf(1.0, ppf)
	level_height = height
	if is_equal_approx(stair_end_feet, 10.0): stair_end_feet = height
	textures = layer_textures
	if not elevations.is_empty(): layer_elevations = elevations
	refresh()

func configure_stair_surfaces(from_id: StringName, to_id: StringName) -> void:
	stair_from_surface = from_id
	stair_to_surface = to_id

func set_object_preset(value: Dictionary) -> void:
	object_preset = value.duplicate()

func update_selected_light(level: int, radius_feet: float) -> void:
	if selected_kind != "light_point" or not _selection_is_valid():
		return
	var point: Dictionary = authoring_canvas.light_points[selected_index].duplicate()
	point["level"] = clampi(level, 0, 3)
	if not point.has("rect"):
		point["radius_feet"] = maxf(0.1, radius_feet)
	authoring_canvas.light_points[selected_index] = point
	authoring_canvas.queue_redraw()
	refresh()
	data_changed.emit()

func set_layer(value: StringName) -> void:
	active_layer = value
	clear_selection()
	refresh()

func set_show_lower_floor(value: bool) -> void:
	show_lower_floor = value
	refresh()

func _layer_is_visible(layer: StringName) -> bool:
	var layer_height: float = layer_elevations.get(layer, 0.0)
	var active_height: float = layer_elevations.get(active_layer, 0.0)
	return layer == active_layer or (show_lower_floor and layer_height < active_height)

func _visual_floor_start(layer: StringName) -> int:
	var elevation: float = layer_elevations.get(layer, 0.0)
	var rank := 0
	for other_layer in layer_elevations:
		if float(layer_elevations[other_layer]) < elevation:
			rank += 1
	return -128 + rank * (256 / maxi(layer_elevations.size(), 1))

func _visual_floor_priority(layer: StringName) -> int:
	var behind_count := 0
	if authoring_canvas != null and authoring_canvas.shapes.has(layer):
		for entry in authoring_canvas.shapes[layer].object:
			if entry is Dictionary and int(entry.get("image_layer", 1)) == 0:
				behind_count += 1
	var band := 256 / maxi(layer_elevations.size(), 1)
	return _visual_floor_start(layer) + mini(behind_count + 1, band - 2)

func _object_visual_priority(layer: StringName, index: int) -> int:
	var objects: Array = authoring_canvas.shapes[layer].object
	var image_layer := int(objects[index].get("image_layer", 1))
	var position := 0
	for earlier in range(index):
		if (int(objects[earlier].get("image_layer", 1)) == 0) == (image_layer == 0):
			position += 1
	var band := 256 / maxi(layer_elevations.size(), 1)
	var floor_start := _visual_floor_start(layer)
	var map_priority := _visual_floor_priority(layer)
	if image_layer == 0:
		return mini(floor_start + 1 + position, map_priority - 1)
	return mini(map_priority + 1 + position, floor_start + band - 1)

func set_tool(value: StringName) -> void:
	active_tool = value
	stair_start = Vector2.INF
	stair_bounds = Rect2()
	stair_box_drag_start = Vector2.INF
	stair_box_drag_current = Vector2.INF
	light_drag_start = Vector2.INF
	light_drag_current = Vector2.INF
	wall_drag_start = Vector2.INF
	wall_drag_current = Vector2.INF
	if active_tool != &"select": clear_selection()
	if active_tool == &"stairs" and active_layer != stair_from_surface:
		active_layer = stair_from_surface
		layer_change_requested.emit(stair_from_surface)
		refresh()
		notice_changed.emit("Stairs: drag a box around the full staircase.")

func set_snap(value: float) -> void:
	snap_pixels = maxf(1.0, value)


func update_selected_wall(height_feet: float, width_pixels: float) -> void:
	if selected_kind != "wall" or not _selection_is_valid():
		return
	var entry = authoring_canvas.shapes[selected_layer].wall[selected_index]
	if not entry is Dictionary:
		return
	entry["height_feet"] = height_feet
	if entry.has("from"):
		entry["width_feet"] = width_pixels / pixels_per_foot
	authoring_canvas.queue_redraw()
	refresh()
	data_changed.emit()

func set_block_size(value: Vector2) -> void:
	block_size_pixels = Vector2(maxf(snap_pixels, value.x), maxf(snap_pixels, value.y))
	if selected_kind == "object" and _selection_is_valid():
		var entry: Dictionary = authoring_canvas.shapes[selected_layer][selected_kind][selected_index]
		var rect: Rect2 = entry.rect
		rect.position = (rect.get_center() - block_size_pixels * 0.5).clamp(Vector2.ZERO, source_size - block_size_pixels)
		rect.size = block_size_pixels
		entry.rect = rect
		authoring_canvas.shapes[selected_layer][selected_kind][selected_index] = entry
		authoring_canvas.queue_redraw()
		refresh()
		data_changed.emit()
		object_selection_changed.emit(entry.duplicate())
	if selected_kind == "stairs" and _selection_is_valid() and not authoring_canvas.stairs[selected_index].has("bounds"):
		_resize_selected_stair()
		refresh()
		data_changed.emit()

func set_stair_elevations(start_feet: float, end_feet: float) -> void:
	stair_start_feet = start_feet
	stair_end_feet = end_feet
	if selected_kind == "stairs" and _selection_is_valid():
		var stair: Dictionary = authoring_canvas.stairs[selected_index]
		stair.from_elevation_feet = start_feet
		stair.to_elevation_feet = end_feet
		authoring_canvas.stairs[selected_index] = stair
		authoring_canvas.queue_redraw()
		refresh()
		data_changed.emit()

func refresh() -> void:
	if not is_instance_valid(world_root):
		return
	for child in block_root.get_children(): child.queue_free()
	for child in world_root.get_children():
		if child.has_meta("map_plane"): child.queue_free()
	for layer in layer_elevations:
		var elevation: float = layer_elevations[layer]
		_create_plane(layer, elevation, textures.get(layer))
	if authoring_canvas == null:
		return
	for layer in authoring_canvas.shapes:
		for kind in authoring_canvas.shapes[layer]:
			var entries: Array = authoring_canvas.shapes[layer][kind]
			for index in range(entries.size()):
				_create_block(layer, StringName(kind), _entry_rect(entries[index]), index, entries[index])
	for index in range(authoring_canvas.stairs.size()):
		_create_stair_preview(authoring_canvas.stairs[index], index)
	for index in range(authoring_canvas.light_points.size()):
		_create_light_preview(authoring_canvas.light_points[index], index)
	if light_drag_start != Vector2.INF and light_drag_current != Vector2.INF:
		var preview := Rect2(light_drag_start, light_drag_current - light_drag_start).abs()
		if preview.size.x >= snap_pixels and preview.size.y >= snap_pixels:
			_create_light_preview({"surface_id": active_layer, "rect": preview, "level": authoring_canvas.light_level}, -1)
	if wall_drag_start != Vector2.INF and wall_drag_current != Vector2.INF and wall_drag_start.distance_to(wall_drag_current) >= snap_pixels:
		_create_wall_preview(active_layer, {"from": wall_drag_start, "to": wall_drag_current, "width_feet": authoring_canvas.wall_width_pixels / pixels_per_foot, "height_feet": authoring_canvas.wall_height_feet}, -1)
	if stair_bounds.has_area():
		_create_stair_bounds_preview(stair_bounds, true)
	elif stair_box_drag_start != Vector2.INF:
		_create_stair_bounds_preview(Rect2(stair_box_drag_start, stair_box_drag_current - stair_box_drag_start).abs(), true)

func _create_light_preview(point: Dictionary, index: int) -> void:
	var layer: StringName = point.get("surface_id", &"ground")
	var elevation: float = layer_elevations.get(layer, 0.0)
	var area: Rect2 = point.get("rect", Rect2())
	var center: Vector2 = area.get_center() if point.has("rect") else point.get("position", Vector2.ZERO)
	var color: Color = [Color("ffe08a"), Color("a8d9ff"), Color("7175c9"), Color("35364e")][clampi(int(point.get("level", 1)), 0, 3)]
	var visual := MeshInstance3D.new()
	var shape: PrimitiveMesh
	if point.has("rect"):
		var box := BoxMesh.new()
		box.size = Vector3(area.size.x / pixels_per_foot, 0.04, area.size.y / pixels_per_foot)
		shape = box
	else:
		var disk := CylinderMesh.new()
		disk.top_radius = maxf(0.1, float(point.get("radius_feet", 15.0)))
		disk.bottom_radius = disk.top_radius
		disk.height = 0.04
		shape = disk
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, 0.2)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if selected_kind == "light_point" and selected_index == index:
		material.albedo_color.a = 0.4
	shape.material = material
	visual.mesh = shape
	visual.position = _map_to_world(center, elevation + 0.12)
	visual.visible = _layer_is_visible(layer)
	block_root.add_child(visual)
	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = color
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = marker_material
	marker.mesh = sphere
	marker.position = visual.position + Vector3.UP * 0.6
	marker.visible = visual.visible
	block_root.add_child(marker)

func _create_plane(layer: StringName, elevation: float, map_texture: Texture2D) -> void:
	if map_texture == null:
		return
	var visual := MeshInstance3D.new()
	visual.set_meta("map_plane", true)
	visual.visible = _layer_is_visible(layer)
	var plane := PlaneMesh.new()
	plane.size = source_size / pixels_per_foot
	var points: Array[Dictionary] = authoring_canvas.light_points if authoring_canvas != null else []
	var material: ShaderMaterial = MapLightVisual.create_material(map_texture, source_size, points, layer, pixels_per_foot)
	material.render_priority = _visual_floor_priority(layer)
	plane.material = material
	visual.mesh = plane
	visual.position.y = elevation
	world_root.add_child(visual)

func _create_block(layer: StringName, kind: StringName, rect: Rect2, index: int, entry = null) -> void:
	if kind == &"wall" and entry is Dictionary and entry.has("from"):
		_create_wall_preview(layer, entry, index)
		return
	var elevation: float = layer_elevations.get(layer, 0.0)
	var height := 0.12
	if kind == &"wall": height = float(entry.get("height_feet", 9.0)) if entry is Dictionary else 9.0
	elif kind == &"invisible_wall": height = 9.0
	elif kind == &"door": height = 0.15 if entry is Dictionary and entry.get("starts_open", false) else 8.0
	elif kind == &"railing": height = 3.0
	elif kind == &"object" and entry is Dictionary: height = entry.get("height_feet", 3.0)
	var visual := MeshInstance3D.new()
	visual.set_meta("layer", layer)
	visual.set_meta("kind", kind)
	visual.set_meta("rect", rect)
	visual.visible = _layer_is_visible(layer)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(rect.size.x / pixels_per_foot, height, rect.size.y / pixels_per_foot)
	var material := StandardMaterial3D.new()
	material.albedo_color = entry.get("color", BLOCK_COLORS.get(kind, Color.WHITE)) if entry is Dictionary else BLOCK_COLORS.get(kind, Color.WHITE)
	var object_texture: Texture2D = entry.get("texture") if entry is Dictionary else null
	if layer == selected_layer and String(kind) == selected_kind and index == selected_index:
		material.albedo_color = material.albedo_color.lightened(0.45)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.75, 0.15)
		material.emission_energy_multiplier = 0.8
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if material.albedo_color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	visual.mesh = _create_object_preview_mesh(mesh.size, material.albedo_color, object_texture, _object_visual_priority(layer, index)) if kind == &"object" and object_texture != null else mesh
	var center := rect.get_center() - source_size * 0.5
	visual.position = Vector3(center.x / pixels_per_foot, elevation + height * 0.5 + 0.04, center.y / pixels_per_foot)
	block_root.add_child(visual)


func _create_wall_preview(layer: StringName, entry: Dictionary, index: int) -> void:
	var start: Vector2 = entry.get("from", Vector2.ZERO)
	var finish: Vector2 = entry.get("to", Vector2.ZERO)
	var direction := finish - start
	if direction.length_squared() <= 0.001:
		return
	var height := float(entry.get("height_feet", 9.0))
	var width := float(entry.get("width_feet", 1.5))
	var visual := MeshInstance3D.new()
	visual.visible = _layer_is_visible(layer)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, height, direction.length() / pixels_per_foot)
	var material := StandardMaterial3D.new()
	material.albedo_color = BLOCK_COLORS.wall.lightened(0.45) if layer == selected_layer and selected_kind == "wall" and index == selected_index else BLOCK_COLORS.wall
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	visual.mesh = mesh
	visual.position = _map_to_world((start + finish) * 0.5, float(layer_elevations.get(layer, 0.0)) + height * 0.5 + 0.04)
	visual.rotation.y = atan2(direction.x, direction.y)
	block_root.add_child(visual)

func _create_object_preview_mesh(size: Vector3, color: Color, texture: Texture2D, draw_priority: int = 0) -> ArrayMesh:
	var half := size * 0.5
	var top_points := [Vector3(-half.x, half.y, -half.z), Vector3(half.x, half.y, -half.z), Vector3(half.x, half.y, half.z), Vector3(-half.x, half.y, half.z)]
	var top_uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex_index in [0, 2, 1, 0, 3, 2]:
		top.set_uv(top_uvs[vertex_index])
		top.add_vertex(top_points[vertex_index])
	var result := top.commit()
	var top_material := StandardMaterial3D.new()
	top_material.albedo_color = Color.WHITE
	top_material.albedo_texture = texture
	top_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	top_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	top_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	top_material.render_priority = draw_priority
	result.surface_set_material(0, top_material)
	# A textured object is a flat image; its full box exists only as collision.
	# Solid sides would show through transparent pixels in the tilted editor view.
	if texture != null:
		return result
	var bottom := [Vector3(-half.x, -half.y, -half.z), Vector3(half.x, -half.y, -half.z), Vector3(half.x, -half.y, half.z), Vector3(-half.x, -half.y, half.z)]
	var sides := SurfaceTool.new()
	sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [[top_points[0], top_points[1], bottom[1], bottom[0]], [top_points[1], top_points[2], bottom[2], bottom[1]], [top_points[2], top_points[3], bottom[3], bottom[2]], [top_points[3], top_points[0], bottom[0], bottom[3]]]:
		for vertex_index in [0, 1, 2, 0, 2, 3]:
			sides.add_vertex(face[vertex_index])
	sides.commit(result)
	var side_material := StandardMaterial3D.new()
	side_material.albedo_color = color
	side_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	side_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.surface_set_material(1, side_material)
	return result

func _create_stair_preview(stair: Dictionary, index: int) -> void:
	if stair.has("bounds"):
		_create_stair_bounds_preview(Rect2(stair.bounds), selected_kind == "stairs" and selected_index == index)
	if not Vector2(stair.from).is_finite() or not Vector2(stair.to).is_finite(): return
	var from_elevation: float = stair.get("from_elevation_feet", 0.0)
	var to_elevation: float = stair.get("to_elevation_feet", level_height)
	var stair_width: float = stair.get("width_feet", 9.0)
	var first := _map_to_world(stair.from, from_elevation)
	var last := _map_to_world(stair.to, to_elevation)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(stair_width, 0.25, first.distance_to(last))
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.3, 0.95)
	if selected_kind == "stairs" and selected_index == index:
		material.albedo_color = Color(1.0, 0.75, 0.15)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.55, 0.1)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	visual.mesh = mesh
	visual.position = (first + last) * 0.5
	block_root.add_child(visual)
	visual.look_at(last, Vector3.UP)

func _create_stair_bounds_preview(bounds: Rect2, highlighted: bool) -> void:
	if not bounds.has_area() or not bounds.position.is_finite() or not bounds.size.is_finite(): return
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(bounds.size.x / pixels_per_foot, 0.08, bounds.size.y / pixels_per_foot)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.7, 0.15, 0.42) if highlighted else Color(0.7, 0.3, 0.95, 0.2)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	visual.mesh = mesh
	var center := bounds.get_center() - source_size * 0.5
	visual.position = Vector3(center.x / pixels_per_foot, 0.06, center.y / pixels_per_foot)
	block_root.add_child(visual)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		grab_focus()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.size = maxf(15.0, camera.size * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.size = minf(400.0, camera.size * 1.1)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			middle_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if active_tool == &"select":
				if event.pressed: _begin_selection(event.position)
				else: selection_dragging = false
			elif active_tool == &"light_point":
				if event.pressed:
					light_drag_start = _map_point(event.position)
					light_drag_current = light_drag_start
				else:
					_commit_light_drag(event.position)
			elif active_tool == &"wall":
				if event.pressed:
					wall_drag_start = _map_point(event.position)
					wall_drag_current = wall_drag_start
				else:
					_commit_wall_drag(event.position)
			elif active_tool == &"stairs" and not stair_bounds.has_area():
				if event.pressed:
					stair_box_drag_start = _map_point(event.position)
					stair_box_drag_current = stair_box_drag_start
				else:
					_finish_stair_box(event.position)
			elif event.pressed:
				_place_at(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_remove_at(event.position)
	elif event is InputEventMouseMotion and selection_dragging:
		_drag_selection(event.position)
	elif event is InputEventMouseMotion and light_drag_start != Vector2.INF:
		var drag_point := _map_point(event.position)
		if drag_point != Vector2.INF:
			light_drag_current = drag_point
			refresh()
	elif event is InputEventMouseMotion and wall_drag_start != Vector2.INF:
		var drag_point := _map_point(event.position)
		if drag_point != Vector2.INF:
			wall_drag_current = drag_point
			refresh()
	elif event is InputEventMouseMotion and stair_box_drag_start != Vector2.INF:
		var drag_point := _map_point(event.position)
		if drag_point != Vector2.INF and drag_point.is_finite():
			stair_box_drag_current = drag_point
			refresh()
	elif event is InputEventMouseMotion and middle_dragging:
		if event.alt_pressed:
			_orbit_drag(event.relative)
		else:
			var previous := _plane_point(event.position - event.relative)
			var current := _plane_point(event.position)
			if previous != Vector3.INF and current != Vector3.INF:
				var shift := previous - current
				camera.position += shift
				camera_target += shift
		accept_event()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q: _orbit_camera(-15.0)
		elif event.keycode == KEY_E: _orbit_camera(15.0)
		elif event.keycode == KEY_F: fit_map()
		elif event.keycode == KEY_DELETE: delete_selected()
		elif event.keycode == KEY_ESCAPE: clear_selection()

func _begin_selection(screen_point: Vector2) -> void:
	var point := _map_point(screen_point)
	if point == Vector2.INF:
		clear_selection()
		return
	selected_layer = active_layer
	selected_kind = ""
	selected_index = -1
	for index in range(authoring_canvas.light_points.size() - 1, -1, -1):
		var light: Dictionary = authoring_canvas.light_points[index]
		if light.get("surface_id", &"ground") != active_layer:
			continue
		var hits := Rect2(light.rect).has_point(point) if light.has("rect") else Vector2(light.get("position", Vector2.ZERO)).distance_to(point) <= maxf(snap_pixels, 12.0)
		if hits:
			selected_kind = "light_point"
			selected_index = index
			selection_drag_offset = point - (Rect2(light.rect).position if light.has("rect") else Vector2(light.get("position", Vector2.ZERO)))
			selection_dragging = true
			selection_changed.emit(true)
			light_selection_changed.emit(light.duplicate())
			refresh()
			return
	var layer_shapes: Dictionary = authoring_canvas.shapes[active_layer]
	for kind in layer_shapes:
		var entries: Array = layer_shapes[kind]
		for index in range(entries.size() - 1, -1, -1):
			if kind == "wall" and entries[index] is Dictionary and entries[index].has("from"):
				var wall: Dictionary = entries[index]
				if _distance_to_segment(point, wall.from, wall.to) <= maxf(snap_pixels, float(wall.get("width_feet", 1.5)) * pixels_per_foot * 0.5):
					selected_kind = "wall"
					selected_index = index
					selection_drag_offset = point - wall.from
					selection_dragging = true
					selection_changed.emit(true)
					wall_selection_changed.emit(wall.duplicate())
					refresh()
					return
				continue
			var rect := _entry_rect(entries[index])
			if rect.has_point(point):
				selected_kind = String(kind)
				selected_index = index
				selection_drag_offset = point - rect.get_center()
				selection_dragging = true
				selection_changed.emit(true)
				if selected_kind == "object": object_selection_changed.emit(entries[index].duplicate())
				if selected_kind == "wall": wall_selection_changed.emit(entries[index].duplicate() if entries[index] is Dictionary else {"height_feet": 9.0, "width_feet": authoring_canvas.wall_width_pixels / pixels_per_foot})
				refresh()
				return
	if active_layer == stair_from_surface:
		for index in range(authoring_canvas.stairs.size() - 1, -1, -1):
			var stair: Dictionary = authoring_canvas.stairs[index]
			var stair_width: float = stair.get("width_feet", 9.0)
			var width_pixels := stair_width * pixels_per_foot
			var hits_stair := Rect2(stair.get("bounds", Rect2())).has_point(point) if stair.has("bounds") else _distance_to_segment(point, stair.from, stair.to) <= width_pixels * 0.5
			if hits_stair:
				selected_kind = "stairs"
				selected_index = index
				selection_drag_offset = point - stair.from
				selection_dragging = true
				selection_changed.emit(true)
				refresh()
				return
	clear_selection()

func _drag_selection(screen_point: Vector2) -> void:
	if not _selection_is_valid(): return
	var point := _map_point(screen_point)
	if point == Vector2.INF: return
	if selected_kind == "light_point":
		var light: Dictionary = authoring_canvas.light_points[selected_index].duplicate()
		if light.has("rect"):
			var rect: Rect2 = light.rect
			rect.position = (point - selection_drag_offset).clamp(Vector2.ZERO, source_size - rect.size)
			light["rect"] = rect
		else:
			light["position"] = (point - selection_drag_offset).clamp(Vector2.ZERO, source_size)
		authoring_canvas.light_points[selected_index] = light
		authoring_canvas.queue_redraw()
		refresh()
		data_changed.emit()
		return
	if selected_kind == "stairs":
		var stair: Dictionary = authoring_canvas.stairs[selected_index]
		var delta: Vector2 = point - selection_drag_offset - stair.from
		stair.from += delta
		stair.to += delta
		if stair.has("bounds"):
			var bounds: Rect2 = stair.bounds
			bounds.position = (bounds.position + delta).clamp(Vector2.ZERO, source_size - bounds.size)
			stair.bounds = bounds
		_move_stair_opening(stair, delta)
		authoring_canvas.stairs[selected_index] = stair
		authoring_canvas.queue_redraw()
		refresh()
		data_changed.emit()
		return
	if selected_kind == "wall":
		var selected_entry = authoring_canvas.shapes[selected_layer].wall[selected_index]
		if selected_entry is Dictionary and selected_entry.has("from"):
			var wall: Dictionary = selected_entry.duplicate()
			var delta: Vector2 = point - selection_drag_offset - Vector2(wall.from)
			var bounds := Rect2(wall.from, Vector2(wall.to) - Vector2(wall.from)).abs()
			delta = delta.clamp(-bounds.position, source_size - bounds.end)
			wall.from += delta
			wall.to += delta
			authoring_canvas.shapes[selected_layer].wall[selected_index] = wall
			authoring_canvas.queue_redraw()
			refresh()
			data_changed.emit()
			return
	var entries: Array = authoring_canvas.shapes[selected_layer][selected_kind]
	var rect := _entry_rect(entries[selected_index])
	var center := point - selection_drag_offset
	center = Vector2(roundf(center.x / snap_pixels), roundf(center.y / snap_pixels)) * snap_pixels
	rect.position = (center - rect.size * 0.5).clamp(Vector2.ZERO, source_size - rect.size)
	if entries[selected_index] is Dictionary:
		entries[selected_index]["rect"] = rect
	else:
		entries[selected_index] = rect
	authoring_canvas.queue_redraw()
	refresh()
	data_changed.emit()

func delete_selected() -> void:
	if not _selection_is_valid(): return
	if selected_kind == "light_point":
		authoring_canvas.light_points.remove_at(selected_index)
	elif selected_kind == "stairs":
		var stair: Dictionary = authoring_canvas.stairs[selected_index]
		_remove_stair_opening(stair)
		authoring_canvas.stairs.remove_at(selected_index)
	else:
		authoring_canvas.shapes[selected_layer][selected_kind].remove_at(selected_index)
	authoring_canvas.queue_redraw()
	clear_selection()
	refresh()
	data_changed.emit()

func clear_selection() -> void:
	selected_layer = &""
	selected_kind = ""
	selected_index = -1
	selection_dragging = false
	selection_changed.emit(false)
	object_selection_changed.emit({})
	light_selection_changed.emit({})
	wall_selection_changed.emit({})
	refresh()

func select_object(layer: StringName, index: int) -> void:
	if authoring_canvas == null or not authoring_canvas.shapes.has(layer):
		return
	var objects: Array = authoring_canvas.shapes[layer].object
	if index < 0 or index >= objects.size():
		return
	active_layer = layer
	selected_layer = layer
	selected_kind = "object"
	selected_index = index
	selection_dragging = false
	selection_changed.emit(true)
	object_selection_changed.emit(objects[index].duplicate())
	refresh()

func _selection_is_valid() -> bool:
	if authoring_canvas == null or selected_index < 0 or not authoring_canvas.shapes.has(selected_layer): return false
	if selected_kind == "light_point": return selected_index < authoring_canvas.light_points.size()
	if selected_kind == "stairs": return selected_index < authoring_canvas.stairs.size()
	if not authoring_canvas.shapes[selected_layer].has(selected_kind): return false
	return selected_index < authoring_canvas.shapes[selected_layer][selected_kind].size()

func update_selected_object(properties: Dictionary) -> void:
	if selected_kind != "object" or not _selection_is_valid(): return
	var entry: Dictionary = authoring_canvas.shapes[selected_layer][selected_kind][selected_index]
	for key in properties: entry[key] = properties[key]
	authoring_canvas.shapes[selected_layer][selected_kind][selected_index] = entry
	authoring_canvas.queue_redraw()
	refresh()
	data_changed.emit()
	object_selection_changed.emit(entry.duplicate())

func _plane_point(screen_point: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen_point)
	var direction := camera.project_ray_normal(screen_point)
	if absf(direction.y) < 0.00001: return Vector3.INF
	var elevation: float = layer_elevations.get(active_layer, 0.0)
	return origin + direction * ((elevation - origin.y) / direction.y)

func _orbit_drag(delta: Vector2) -> void:
	var offset := camera.position - camera_target
	var radius := offset.length()
	var yaw := atan2(offset.x, offset.z) - delta.x * 0.006
	var pitch := clampf(asin(clampf(offset.y / radius, -1.0, 1.0)) + delta.y * 0.006, deg_to_rad(15), deg_to_rad(89))
	offset = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * radius
	camera.look_at_from_position(camera_target + offset, camera_target)

func fit_map() -> void:
	var offset := camera.position - camera_target
	var active_elevation: float = layer_elevations.get(active_layer, 0.0)
	camera_target = Vector3(0, active_elevation, 0)
	camera.look_at_from_position(camera_target + offset, camera_target)
	var aspect := maxf(0.1, size.x / maxf(1.0, size.y))
	camera.size = maxf(source_size.y, source_size.x / aspect) / pixels_per_foot * 1.15

func _map_point(screen_point: Vector2) -> Vector2:
	var origin := camera.project_ray_origin(screen_point)
	var direction := camera.project_ray_normal(screen_point)
	var elevation: float = layer_elevations.get(active_layer, 0.0)
	if is_zero_approx(direction.y): return Vector2.INF
	var distance := (elevation - origin.y) / direction.y
	if distance < 0.0: return Vector2.INF
	var hit := origin + direction * distance
	var point := Vector2(hit.x, hit.z) * pixels_per_foot + source_size * 0.5
	point = Vector2(roundf(point.x / snap_pixels), roundf(point.y / snap_pixels)) * snap_pixels
	if not Rect2(Vector2.ZERO, source_size).has_point(point): return Vector2.INF
	return point

func _place_at(screen_point: Vector2) -> void:
	if authoring_canvas == null: return
	var point := _map_point(screen_point)
	if point == Vector2.INF: return
	if active_tool == &"light_point":
		authoring_canvas.light_points.append({"surface_id": active_layer, "position": point, "radius_feet": authoring_canvas.light_radius_feet, "level": authoring_canvas.light_level})
	elif active_tool == &"stairs":
		if stair_start == Vector2.INF:
			if not stair_bounds.has_point(point):
				notice_changed.emit("Start point must be inside the stair box.")
				return
			stair_start = point
			refresh()
			notice_changed.emit("Start set (white). Now click the end point inside the box.")
		else:
			if not stair_bounds.has_point(point):
				notice_changed.emit("End point must be inside the stair box.")
				return
			var direction := point - stair_start
			if direction.length() < snap_pixels:
				notice_changed.emit("Start and end points must be different.")
				return
			var end := point
			var perpendicular := Vector2(-direction.normalized().y, direction.normalized().x)
			var width_pixels := minf(stair_bounds.size.x / maxf(absf(perpendicular.x), 0.001), stair_bounds.size.y / maxf(absf(perpendicular.y), 0.001))
			width_pixels = maxf(snap_pixels, width_pixels)
			var opening_size := Vector2(maxf(width_pixels, snap_pixels * 2.0), maxf(width_pixels, snap_pixels * 2.0))
			var opening_rect := Rect2(end - opening_size * 0.5, opening_size)
			opening_rect.position = opening_rect.position.clamp(Vector2.ZERO, source_size - opening_rect.size)
			var has_opening := false
			authoring_canvas.ensure_layer(stair_to_surface)
			for existing: Rect2 in authoring_canvas.shapes[stair_to_surface].opening:
				if existing.has_point(end):
					has_opening = true
					opening_rect = existing
					break
			if not has_opening:
				authoring_canvas.shapes[stair_to_surface].opening.append(opening_rect)
			authoring_canvas.stairs.append({"from": stair_start, "to": end, "from_surface_id": stair_from_surface, "to_surface_id": stair_to_surface, "from_elevation_feet": stair_start_feet, "to_elevation_feet": stair_end_feet, "width_feet": width_pixels / pixels_per_foot, "opening_rect": opening_rect, "bounds": stair_bounds})
			stair_start = Vector2.INF
			stair_bounds = Rect2()
			notice_changed.emit("Stair created. Drag another box to create the next stair.")
	else:
		var rect := Rect2(point - block_size_pixels * 0.5, block_size_pixels)
		rect.position = rect.position.clamp(Vector2.ZERO, source_size - rect.size)
		if active_tool == &"object":
			var entry := object_preset.duplicate()
			entry["rect"] = rect
			authoring_canvas.shapes[active_layer][String(active_tool)].append(entry)
		elif active_tool == &"door":
			authoring_canvas.shapes[active_layer].door.append({"rect": rect, "starts_open": authoring_canvas.door_starts_open})
		else:
			authoring_canvas.shapes[active_layer][String(active_tool)].append(rect)
	authoring_canvas.queue_redraw()
	refresh()
	data_changed.emit()


func _commit_wall_drag(screen_point: Vector2) -> void:
	if wall_drag_start == Vector2.INF:
		return
	var finish := _map_point(screen_point)
	if finish != Vector2.INF and wall_drag_start.distance_to(finish) >= snap_pixels:
		authoring_canvas.shapes[active_layer].wall.append({"from": wall_drag_start, "to": finish, "width_feet": authoring_canvas.wall_width_pixels / pixels_per_foot, "height_feet": authoring_canvas.wall_height_feet})
		authoring_canvas.queue_redraw()
		data_changed.emit()
	wall_drag_start = Vector2.INF
	wall_drag_current = Vector2.INF
	refresh()

func _commit_light_drag(screen_point: Vector2) -> void:
	if light_drag_start == Vector2.INF:
		return
	var end := _map_point(screen_point)
	if end != Vector2.INF:
		var rect := Rect2(light_drag_start, end - light_drag_start).abs()
		if rect.size.x >= snap_pixels and rect.size.y >= snap_pixels:
			authoring_canvas.light_points.append({"surface_id": active_layer, "rect": rect, "level": authoring_canvas.light_level})
		else:
			authoring_canvas.light_points.append({"surface_id": active_layer, "position": end, "radius_feet": authoring_canvas.light_radius_feet, "level": authoring_canvas.light_level})
		authoring_canvas.queue_redraw()
		data_changed.emit()
	light_drag_start = Vector2.INF
	light_drag_current = Vector2.INF
	refresh()

func _finish_stair_box(screen_point: Vector2) -> void:
	if stair_box_drag_start == Vector2.INF: return
	var end := _map_point(screen_point)
	if end != Vector2.INF:
		var bounds := Rect2(stair_box_drag_start, end - stair_box_drag_start).abs()
		if bounds.size.x >= snap_pixels and bounds.size.y >= snap_pixels:
			stair_bounds = bounds
			stair_start = Vector2.INF
			notice_changed.emit("Box set. Click the stair start point inside it.")
	stair_box_drag_start = Vector2.INF
	stair_box_drag_current = Vector2.INF
	refresh()

func _remove_at(screen_point: Vector2) -> void:
	if authoring_canvas == null: return
	var point := _map_point(screen_point)
	if point == Vector2.INF: return
	for index in range(authoring_canvas.light_points.size() - 1, -1, -1):
		var light: Dictionary = authoring_canvas.light_points[index]
		if light.get("surface_id", &"ground") != active_layer:
			continue
		var hits := Rect2(light.rect).has_point(point) if light.has("rect") else Vector2(light.get("position", Vector2.ZERO)).distance_to(point) <= maxf(snap_pixels, 12.0)
		if hits:
			authoring_canvas.light_points.remove_at(index)
			authoring_canvas.queue_redraw()
			clear_selection()
			data_changed.emit()
			return
	var best_kind := ""
	var best_index := -1
	var best_distance := INF
	for kind in authoring_canvas.shapes[active_layer]:
		var entries: Array = authoring_canvas.shapes[active_layer][kind]
		for index in range(entries.size()):
			if kind == "wall" and entries[index] is Dictionary and entries[index].has("from"):
				var wall: Dictionary = entries[index]
				var line_distance := _distance_to_segment(point, wall.from, wall.to)
				if line_distance <= maxf(snap_pixels, float(wall.get("width_feet", 1.5)) * pixels_per_foot * 0.5) and line_distance < best_distance:
					best_distance = line_distance
					best_kind = kind
					best_index = index
				continue
			var entry_rect := _entry_rect(entries[index])
			var distance := entry_rect.get_center().distance_to(point)
			if distance < best_distance and entry_rect.has_point(point):
				best_distance = distance
				best_kind = kind
				best_index = index
	if best_index >= 0:
		authoring_canvas.shapes[active_layer][best_kind].remove_at(best_index)
		authoring_canvas.queue_redraw()
		refresh()
		data_changed.emit()

func _entry_rect(entry) -> Rect2:
	if entry is Dictionary and entry.has("from"):
		return Rect2(entry.from, Vector2(entry.to) - Vector2(entry.from)).abs().grow(float(entry.get("width_feet", 1.5)) * pixels_per_foot * 0.5)
	return Rect2(entry.get("rect", Rect2())) if entry is Dictionary else Rect2(entry)

func _orbit_camera(degrees: float) -> void:
	var offset := camera.position - camera_target
	offset = offset.rotated(Vector3.UP, deg_to_rad(degrees))
	camera.position = camera_target + offset
	camera.look_at(camera_target)

func _map_to_world(point: Vector2, elevation: float) -> Vector3:
	var centered := point - source_size * 0.5
	return Vector3(centered.x / pixels_per_foot, elevation, centered.y / pixels_per_foot)

func _distance_to_segment(point: Vector2, first: Vector2, last: Vector2) -> float:
	var segment := last - first
	var length_squared := segment.length_squared()
	if length_squared <= 0.001: return point.distance_to(first)
	var factor := clampf((point - first).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(first + segment * factor)

func _resize_selected_stair() -> void:
	var stair: Dictionary = authoring_canvas.stairs[selected_index]
	var direction: Vector2 = stair.to - stair.from
	if direction.length() <= 0.001: direction = Vector2.DOWN
	stair.to = stair.from + direction.normalized() * block_size_pixels.y
	stair.width_feet = block_size_pixels.x / pixels_per_foot
	var old_opening: Rect2 = stair.get("opening_rect", Rect2())
	var opening_size := Vector2(maxf(block_size_pixels.x, snap_pixels * 2.0), maxf(block_size_pixels.x, snap_pixels * 2.0))
	var opening_rect := Rect2(stair.to - opening_size * 0.5, opening_size)
	opening_rect.position = opening_rect.position.clamp(Vector2.ZERO, source_size - opening_rect.size)
	_replace_stair_opening(old_opening, opening_rect)
	stair.opening_rect = opening_rect
	authoring_canvas.stairs[selected_index] = stair
	authoring_canvas.queue_redraw()

func _move_stair_opening(stair: Dictionary, delta: Vector2) -> void:
	if not stair.has("opening_rect"): return
	var old_opening: Rect2 = stair.opening_rect
	var next_opening := old_opening
	next_opening.position = (next_opening.position + delta).clamp(Vector2.ZERO, source_size - next_opening.size)
	_replace_stair_opening(old_opening, next_opening)
	stair.opening_rect = next_opening

func _remove_stair_opening(stair: Dictionary) -> void:
	if not stair.has("opening_rect"): return
	var opening: Rect2 = stair.opening_rect
	var to_id: StringName = stair.get("to_surface_id", &"level_1")
	for index in range(authoring_canvas.shapes[to_id].opening.size() - 1, -1, -1):
		if Rect2(authoring_canvas.shapes[to_id].opening[index]) == opening:
			authoring_canvas.shapes[to_id].opening.remove_at(index)
			return

func _replace_stair_opening(old_opening: Rect2, next_opening: Rect2) -> void:
	var to_id := stair_to_surface
	if selected_kind == "stairs" and _selection_is_valid(): to_id = authoring_canvas.stairs[selected_index].get("to_surface_id", &"level_1")
	for index in range(authoring_canvas.shapes[to_id].opening.size()):
		if Rect2(authoring_canvas.shapes[to_id].opening[index]) == old_opening:
			authoring_canvas.shapes[to_id].opening[index] = next_opening
			return
	authoring_canvas.shapes[to_id].opening.append(next_opening)

func reset_view(top: bool = false) -> void:
	camera_target = Vector3.ZERO
	camera.size = maxf(source_size.x, source_size.y) / pixels_per_foot * 1.15
	var offset := Vector3(0, 120, 0.01) if top else Vector3(0, 95, 70)
	camera.look_at_from_position(offset, camera_target)
	fit_map()
