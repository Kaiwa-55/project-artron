extends Node3D

const TOKEN_CAPTURE_SCALE := 4.0

var proxy: Combatant
var target := Vector3.INF
var travel: Tween
var sprite: Sprite3D
var label: Label3D
var capture: SubViewport
var capture_camera: Camera2D
var capture_layer: int
var map_data: BuildingMapData
var observer_visible: bool = true
var selection_visual: Sprite3D
var concealment_visual: Label3D
var status_visuals: Node3D
var status_signature: String = ""
var attack_visual: Sprite3D
var displayed_health := Vector2i(-1, -1)

func setup(source: Combatant, source_map: BuildingMapData) -> void:
	proxy = source
	map_data = source_map
	position = proxy.state.world_position
	target = position
	sprite = Sprite3D.new()
	capture = SubViewport.new()
	# Capture the 2D token near its source resolution instead of shrinking it to
	# roughly 60 pixels and enlarging that low-resolution result in the 3D view.
	capture.size = Vector2i(512, 512)
	capture.transparent_bg = true
	capture.disable_3d = true
	capture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	capture.world_2d = get_viewport().world_2d
	capture_layer = 1 << (2 + int(proxy.get_meta("capture_index", 0)))
	capture.canvas_cull_mask = capture_layer
	add_child(capture)
	capture_camera = Camera2D.new()
	capture_camera.zoom = Vector2.ONE * TOKEN_CAPTURE_SCALE
	capture.add_child(capture_camera)
	sprite.texture = capture.get_texture()
	# Discard the transparent capture area so its quad cannot darken the map.
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.rotation_degrees.x = -90.0
	sprite.position.y = 0.3
	sprite.pixel_size = 1.0 / (proxy.state.spatial_units_per_foot * TOKEN_CAPTURE_SCALE)
	add_child(sprite)
	if sprite.texture == null:
		var disk := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = proxy.state.collision_radius_feet
		mesh.bottom_radius = mesh.top_radius
		mesh.height = 0.25
		disk.mesh = mesh
		add_child(disk)
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 1, -proxy.state.collision_radius_feet - 1)
	label.pixel_size = 0.035
	label.font_size = 24
	add_child(label)
	selection_visual = Sprite3D.new()
	selection_visual.texture = preload("res://assets/ui/ui03.png")
	selection_visual.region_enabled = true
	selection_visual.region_rect = Rect2(192, 0, 48, 48)
	selection_visual.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	selection_visual.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	selection_visual.rotation_degrees.x = -90.0
	selection_visual.position.y = 0.45
	add_child(selection_visual)
	concealment_visual = Label3D.new()
	concealment_visual.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	concealment_visual.font_size = 11
	concealment_visual.pixel_size = 1.0 / proxy.state.spatial_units_per_foot
	concealment_visual.modulate = Color("f8d477")
	concealment_visual.outline_size = 3
	add_child(concealment_visual)
	status_visuals = Node3D.new()
	add_child(status_visuals)
	proxy.spatial_visual = self
	proxy.show()
	_set_capture_layer(proxy)

func _set_capture_layer(node: Node, outside_token: bool = false) -> void:
	# These UI elements have their own 3D visuals; capturing them would clip
	# at the edge of the token's 512px viewport.
	outside_token = outside_token or node == proxy.selection_frame or node == proxy.concealment_badge or node == proxy.status_icon_layer
	if node is Label and node in proxy.floating_value_labels:
		outside_token = true
	if node == proxy.attack_sprite and (node is Sprite2D or node.get_meta("spatial_area_effect", false)):
		outside_token = true
	if node is CanvasItem:
		node.visibility_layer = 0 if outside_token else capture_layer
	for child in node.get_children():
		_set_capture_layer(child, outside_token)

func sync_state() -> void:
	if proxy == null or proxy.state == null:
		return
	var state := proxy.state
	proxy.refresh_status_icons()
	var on_stairs := _is_on_stairs_at(position)
	var under_stairs := _is_under_stairs_at(position)
	# A horizontal token must clear the uphill side of its supporting ramp.
	sprite.position.y = state.collision_radius_feet + 0.3 if on_stairs else 0.3
	label.text = state.display_name
	var current_health := Vector2i(state.hp, state.max_hp)
	if current_health != displayed_health:
		displayed_health = current_health
		proxy.queue_redraw()
	sprite.modulate = Color(1.25, 1.15, 0.75) if proxy.selected else Color.WHITE
	selection_visual.visible = proxy.selected
	selection_visual.pixel_size = (state.collision_radius_feet * 2.0 + 20.0 / state.spatial_units_per_foot) / 48.0
	concealment_visual.visible = is_instance_valid(proxy.concealment_badge) and proxy.concealment_badge.visible
	if concealment_visual.visible:
		concealment_visual.text = proxy.concealment_badge.text
		concealment_visual.position = Vector3(state.collision_radius_feet + 8.0 / state.spatial_units_per_foot, 1.1, state.collision_radius_feet * 0.2)
	_refresh_status_visuals()
	# Keep a ground-floor token readable when an upper-floor staircase is
	# physically between it and the top-down camera. A token traveling on the
	# slope also stays above the stair artwork instead of sinking into it.
	var attack_offset := proxy.visual_offset / state.spatial_units_per_foot
	sprite.position.x = attack_offset.x
	sprite.position.z = attack_offset.y
	sprite.no_depth_test = under_stairs or on_stairs
	label.no_depth_test = under_stairs or on_stairs
	# Floor images use the transparent render pass. Draw stair tokens afterward
	# so the focused upper-floor image cannot paint over them.
	sprite.render_priority = 10 if under_stairs or on_stairs else 0
	label.render_priority = 10 if under_stairs or on_stairs else 0
	if not target.is_equal_approx(state.world_position):
		if travel != null:
			travel.kill()
		target = state.world_position
		travel = create_tween()
		var route := state.movement_path_3d
		if route.size() < 2 or not route[-1].is_equal_approx(target):
			route = PackedVector3Array([position, target])
		for i in range(1, route.size()):
			travel.tween_property(self, "position", route[i], maxf(0.02, route[i - 1].distance_to(route[i]) / 25.0))
		state.movement_path_3d = PackedVector3Array()
	proxy.global_position = Vector2(position.x, position.z) * state.spatial_units_per_foot
	# Melee lunges animate visual_offset, which can exceed the token viewport.
	# Keep the 2D capture centered on the art while moving its 3D quad.
	capture_camera.position = proxy.global_position + proxy.visual_offset
	_sync_attack_visual()
	_set_capture_layer(proxy)

func _sync_attack_visual() -> void:
	var source := proxy.attack_sprite as Sprite2D
	if not is_instance_valid(source) or source.get_meta("spatial_area_effect", false):
		if is_instance_valid(attack_visual):
			attack_visual.hide()
		return
	if not is_instance_valid(attack_visual):
		attack_visual = Sprite3D.new()
		attack_visual.top_level = true
		attack_visual.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		attack_visual.render_priority = 5
		attack_visual.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		add_child(attack_visual)
	attack_visual.texture = source.texture
	attack_visual.hframes = source.hframes
	attack_visual.vframes = source.vframes
	attack_visual.frame = source.frame
	attack_visual.pixel_size = 1.0 / proxy.state.spatial_units_per_foot
	attack_visual.scale = Vector3(source.scale.x, source.scale.y, 1.0)
	attack_visual.rotation = Vector3(-PI * 0.5, -source.global_rotation, 0)
	attack_visual.global_position = Vector3(source.global_position.x / proxy.state.spatial_units_per_foot, position.y + 0.65, source.global_position.y / proxy.state.spatial_units_per_foot)
	attack_visual.modulate = source.modulate
	attack_visual.visible = source.visible

func _refresh_status_visuals() -> void:
	if proxy.status_icon_signature == status_signature:
		return
	status_signature = proxy.status_icon_signature
	for child in status_visuals.get_children():
		child.queue_free()
	var statuses: Array[EffectInstance] = []
	for instance in proxy.state.effects:
		if instance != null and instance.data != null and instance.data.status_kind != EffectData.StatusKind.NONE:
			statuses.append(instance)
	var units := proxy.state.spatial_units_per_foot
	for index in range(statuses.size()):
		var instance := statuses[index]
		var angle := -PI * 0.75 + TAU * float(index) / float(statuses.size())
		var offset := Vector2.from_angle(angle) * (proxy.state.collision_radius_feet + 17.0 / units)
		var anchor := Node3D.new()
		anchor.position = Vector3(offset.x, 0.8, offset.y)
		status_visuals.add_child(anchor)
		var background := MeshInstance3D.new()
		var disk := CylinderMesh.new()
		disk.top_radius = 12.0 / units
		disk.bottom_radius = disk.top_radius
		disk.height = 0.05
		background.mesh = disk
		var material := StandardMaterial3D.new()
		material.albedo_color = proxy.get_status_color(instance.data.status_kind)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		background.material_override = material
		anchor.add_child(background)
		if instance.data.icon_texture != null:
			var icon := Sprite3D.new()
			icon.texture = instance.data.icon_texture
			icon.rotation_degrees.x = -90.0
			icon.position.y = 0.08
			icon.pixel_size = 18.0 / (units * maxf(1.0, icon.texture.get_width()))
			icon.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			anchor.add_child(icon)
		else:
			var abbreviation := Label3D.new()
			abbreviation.text = proxy.get_status_abbreviation(instance.data.status_kind)
			abbreviation.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			abbreviation.font_size = 10
			abbreviation.pixel_size = 1.0 / units
			abbreviation.position.y = 0.15
			anchor.add_child(abbreviation)
		if instance.stack_count > 1:
			var count := Label3D.new()
			count.text = str(instance.stack_count)
			count.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			count.font_size = 9
			count.pixel_size = 1.0 / units
			count.position = Vector3(12.0 / units, 0.2, 12.0 / units)
			anchor.add_child(count)

func _is_under_stairs_at(world_position: Vector3) -> bool:
	if map_data == null:
		return false
	for transition in map_data.transitions:
		var stair_point := _closest_stair_point(transition, world_position)
		if stair_point != Vector3.INF and world_position.y + 0.1 < stair_point.y:
			return true
	return false

func _is_on_stairs_at(world_position: Vector3) -> bool:
	if map_data == null:
		return false
	for transition in map_data.transitions:
		var stair_point := _closest_stair_point(transition, world_position)
		if stair_point != Vector3.INF and absf(world_position.y - stair_point.y) <= 0.15:
			return true
	return false

func _closest_stair_point(transition: BuildingTransitionData, world_position: Vector3) -> Vector3:
	if transition == null:
		return Vector3.INF
	var from_surface := map_data.get_surface(transition.from_surface_id)
	var to_surface := map_data.get_surface(transition.to_surface_id)
	if from_surface == null or to_surface == null:
		return Vector3.INF
	var map_position := map_data.logic_to_map(map_data.world_to_logic(world_position))
	var segment := transition.to_position - transition.from_position
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return Vector3.INF
	var progress := clampf((map_position - transition.from_position).dot(segment) / length_squared, 0.0, 1.0)
	var closest_map := transition.from_position + segment * progress
	if map_position.distance_to(closest_map) > transition.width_feet * map_data.pixels_per_foot * 0.5:
		return Vector3.INF
	return map_data.logic_to_world(
		map_data.map_to_logic(closest_map),
		lerpf(transition.get_from_elevation(from_surface.elevation_feet), transition.get_to_elevation(to_surface.elevation_feet), progress)
	)

func is_moving() -> bool:
	return travel != null and travel.is_running()

func is_pickable() -> bool:
	return observer_visible and is_visible_in_tree()
