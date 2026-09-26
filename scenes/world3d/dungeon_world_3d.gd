class_name DungeonWorld3D
extends Node3D

const MapLightVisual := preload("res://data/world/map_light_visual.gd")

const FLOOR_LAYER := 1
const WALL_LAYER := 2
const RAILING_LAYER := 4
const MOVEMENT_ONLY_LAYER := 8
const DOOR_INTERACTION_LAYER := 16
const VISIBILITY_LAYER_MASK := FLOOR_LAYER | WALL_LAYER | RAILING_LAYER

@export var map_data: BuildingMapData
@export var wall_height_feet: float = 9.0
@export var floor_thickness_feet: float = 0.35

var surface_nodes: Dictionary = {}
var focus_surface_id: StringName = &"ground"
var sight_debug: MeshInstance3D
var door_nodes: Dictionary = {}
var stair_hover_material: StandardMaterial3D
var visual_light_level := 1

func show_visibility_debug(result: Dictionary) -> void:
	if sight_debug == null:
		sight_debug = MeshInstance3D.new()
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.no_depth_test = true
		sight_debug.material_override = material
		add_child(sight_debug)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for sample in result.samples:
		mesh.surface_set_color(Color.GREEN if sample.clear else Color.RED)
		mesh.surface_add_vertex(sample.from)
		mesh.surface_add_vertex(sample.position)
	mesh.surface_end()
	sight_debug.mesh = mesh
	sight_debug.visible = true

func hide_visibility_debug() -> void:
	if is_instance_valid(sight_debug):
		sight_debug.hide()


func build(source: BuildingMapData) -> void:
	clear_world()
	map_data = source
	if map_data == null:
		return
	for surface in map_data.surfaces:
		if surface != null:
			_build_surface(surface)
	_build_transitions()
	set_visual_light_level(visual_light_level)

func set_visual_light_level(level: int) -> void:
	visual_light_level = clampi(level, 0, 3)
	if map_data == null:
		return
	for surface in map_data.surfaces:
		if surface == null or surface.texture == null:
			continue
		var root: Node3D = surface_nodes.get(surface.surface_id)
		if root == null:
			continue
		var visual := root.get_node_or_null("MapImage") as MeshInstance3D
		if visual != null:
			var material: ShaderMaterial = MapLightVisual.create_material(surface.texture, map_data.source_size, map_data.light_points, surface.surface_id, map_data.pixels_per_foot, visual_light_level)
			material.render_priority = _visual_floor_priority(surface)
			visual.material_override = material


func clear_world() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	surface_nodes.clear()
	door_nodes.clear()

func add_encounter_obstacles(obstacles: Array[Dictionary]) -> void:
	for obstacle in obstacles:
		if StringName(obstacle.get("surface_id", &"")) != &"":
			continue
		if not obstacle.get("blocks_line_of_sight", true):
			continue
		if obstacle.get("shape", "circle") == "rect":
			var rect: Rect2 = obstacle.rect
			rect.position = map_data.logic_to_map(rect.position)
			add_child(_create_box_body(rect, wall_height_feet * 0.5, wall_height_feet, WALL_LAYER, "EncounterWall"))
		else:
			var body := StaticBody3D.new()
			body.collision_layer = WALL_LAYER
			body.set_meta("occluder_type", "WALL")
			body.position = map_data.logic_to_world(obstacle.center, wall_height_feet * 0.5)
			var shape := CylinderShape3D.new()
			shape.radius = maxf(0.01, float(obstacle.radius) / map_data.pixels_per_foot)
			shape.height = wall_height_feet
			var collider := CollisionShape3D.new()
			collider.shape = shape
			body.add_child(collider)
			var visual := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = shape.radius
			mesh.bottom_radius = shape.radius
			mesh.height = shape.height
			visual.mesh = mesh
			body.add_child(visual)
			add_child(body)


func _build_surface(surface: BuildingSurfaceData) -> void:
	var root := Node3D.new()
	root.name = String(surface.surface_id)
	root.set_meta("surface_id", surface.surface_id)
	add_child(root)
	surface_nodes[surface.surface_id] = root
	if surface.texture != null:
		root.add_child(_create_surface_visual(surface))
	var solids := surface.solid_rects()
	for index in range(solids.size()):
		root.add_child(_create_box_body(solids[index], surface.elevation_feet - floor_thickness_feet * 0.5, floor_thickness_feet, FLOOR_LAYER, "Floor%d" % index))
	var walls := surface.wall_solid_entries()
	for index in range(walls.size()):
		var height: float = walls[index].height_feet
		root.add_child(_create_box_body(walls[index].rect, surface.elevation_feet + height * 0.5, height, WALL_LAYER, "Wall%d" % index))
	var wall_segments := surface.wall_solid_segments(map_data.pixels_per_foot)
	for index in range(wall_segments.size()):
		root.add_child(_create_wall_segment_body(wall_segments[index], surface, index))
	for index in range(surface.railing_rects.size()):
		root.add_child(_create_box_body(surface.railing_rects[index], surface.elevation_feet + 1.5, 3.0, RAILING_LAYER, "Railing%d" % index))
	for index in range(surface.invisible_wall_rects.size()):
		root.add_child(_create_box_body(surface.invisible_wall_rects[index], surface.elevation_feet + wall_height_feet * 0.5, wall_height_feet, MOVEMENT_ONLY_LAYER, "InvisibleWall%d" % index))
	for index in range(surface.objects.size()):
		if surface.objects[index] != null:
			root.add_child(_create_map_object(surface.objects[index], surface, index))
	for door in surface.doors:
		if door != null:
			root.add_child(_create_door(door, surface))

func _door_key(surface_id: StringName, door_id: StringName) -> String:
	return "%s/%s" % [surface_id, door_id]

func _create_door(door: BuildingDoorData, surface: BuildingSurfaceData) -> StaticBody3D:
	var body := _create_box_body(door.rect, surface.elevation_feet + door.height_feet * 0.5, door.height_feet, WALL_LAYER, "Door_%s" % door.door_id)
	body.set_meta("surface_id", surface.surface_id)
	body.set_meta("door_id", door.door_id)
	body.set_meta("occluder_type", "DOOR")
	var marker := Label3D.new()
	marker.name = "StateLabel"
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.font_size = 42
	marker.pixel_size = 0.025
	marker.no_depth_test = true
	marker.position.y = door.height_feet * 0.5 + 0.2
	body.add_child(marker)
	door_nodes[_door_key(surface.surface_id, door.door_id)] = body
	set_door_open(surface.surface_id, door.door_id, door.starts_open)
	return body

func set_door_open(surface_id: StringName, door_id: StringName, opened: bool) -> void:
	var body: StaticBody3D = door_nodes.get(_door_key(surface_id, door_id))
	if body == null:
		return
	body.collision_layer = DOOR_INTERACTION_LAYER if opened else WALL_LAYER | DOOR_INTERACTION_LAYER
	var visual: MeshInstance3D = body.get_child(1)
	var door_material := StandardMaterial3D.new()
	door_material.albedo_color = Color("43be92") if opened else Color("c67c22")
	door_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.material_override = door_material
	var door_height: float = (body.get_child(0) as CollisionShape3D).shape.size.y
	visual.scale.y = 0.02 if opened else 1.0
	visual.position.y = -door_height * 0.5 + 0.08 if opened else 0.0
	var marker: Label3D = body.get_node("StateLabel")
	marker.text = "OPEN" if opened else "CLOSED"
	marker.modulate = Color("70f4c2") if opened else Color("ffb347")

func pick_door(camera: Camera3D, screen_position: Vector2) -> Dictionary:
	if camera == null or not is_inside_tree():
		return {}
	var origin := camera.project_ray_origin(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen_position) * 500.0, DOOR_INTERACTION_LAYER)
	for attempt in range(16):
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return {}
		var body: StaticBody3D = hit.collider
		if body.is_visible_in_tree() and body.has_meta("door_id"):
			return {"surface_id": body.get_meta("surface_id"), "door_id": body.get_meta("door_id")}
		var excluded := query.exclude
		excluded.append(hit.rid)
		query.exclude = excluded
	return {}

func _visual_floor_start(elevation: float) -> int:
	var rank := 0
	for surface in map_data.surfaces:
		if surface != null and surface.elevation_feet < elevation:
			rank += 1
	return -128 + rank * (256 / maxi(map_data.surfaces.size(), 1))

func _visual_floor_priority(surface: BuildingSurfaceData) -> int:
	var behind_count := 0
	for object in surface.objects:
		if object != null and object.image_layer == 0:
			behind_count += 1
	var band := 256 / maxi(map_data.surfaces.size(), 1)
	return _visual_floor_start(surface.elevation_feet) + mini(behind_count + 1, band - 2)

func _object_visual_priority(surface: BuildingSurfaceData, index: int) -> int:
	var object := surface.objects[index]
	var position := 0
	for earlier in range(index):
		var previous := surface.objects[earlier]
		if previous != null and (previous.image_layer == 0) == (object.image_layer == 0):
			position += 1
	var band := 256 / maxi(map_data.surfaces.size(), 1)
	var floor_start := _visual_floor_start(surface.elevation_feet)
	var map_priority := _visual_floor_priority(surface)
	if object.image_layer == 0:
		return mini(floor_start + 1 + position, map_priority - 1)
	return mini(map_priority + 1 + position, floor_start + band - 1)


func _create_surface_visual(surface: BuildingSurfaceData) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MapImage"
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Openings remove physical floor collision, but the source map image should
	# remain intact. This keeps authored stair/opening artwork visible instead
	# of replacing it with a black cut-out.
	var rects := surface.walkable_rects
	if surface.walkable_rects.is_empty():
		rects = [Rect2(Vector2.ZERO, map_data.source_size)]
	for rect in rects:
		var corners := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
		for index in [0, 2, 1, 0, 3, 2]:
			builder.set_uv(corners[index] / map_data.source_size)
			builder.add_vertex(map_data.logic_to_world(map_data.map_to_logic(corners[index]), 0.0))
	builder.generate_normals()
	var material := StandardMaterial3D.new()
	material.albedo_texture = surface.texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.render_priority = _visual_floor_priority(surface)
	mesh_instance.mesh = builder.commit()
	mesh_instance.material_override = material
	mesh_instance.position.y = surface.elevation_feet
	return mesh_instance


func _create_box_body(rect: Rect2, elevation: float, height_feet: float, collision_layer: int, node_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = collision_layer
	body.collision_mask = 0
	body.set_meta("occluder_type", {FLOOR_LAYER: "FLOOR", WALL_LAYER: "WALL", RAILING_LAYER: "RAILING", MOVEMENT_ONLY_LAYER: "MOVEMENT_ONLY"}.get(collision_layer, "UNKNOWN"))
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(rect.size.x / map_data.pixels_per_foot, height_feet, rect.size.y / map_data.pixels_per_foot)
	shape_node.shape = shape
	var logic_center := map_data.map_to_logic(rect.get_center())
	body.position = map_data.logic_to_world(logic_center, elevation)
	body.add_child(shape_node)
	if collision_layer != FLOOR_LAYER and collision_layer != MOVEMENT_ONLY_LAYER:
		var visual := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = shape.size
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("70604c")
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		box.material = material
		visual.mesh = box
		body.add_child(visual)
	return body


func _create_wall_segment_body(wall: Dictionary, surface: BuildingSurfaceData, index: int) -> StaticBody3D:
	var length_feet: float = Vector2(wall.from).distance_to(wall.to) / map_data.pixels_per_foot
	var height: float = float(wall.height_feet)
	var rectangle := Rect2(Vector2.ZERO, Vector2(float(wall.width_feet), length_feet) * map_data.pixels_per_foot)
	var body := _create_box_body(rectangle, surface.elevation_feet + height * 0.5, height, WALL_LAYER, "WallSegment%d" % index)
	var center: Vector2 = (Vector2(wall.from) + Vector2(wall.to)) * 0.5
	body.position = map_data.logic_to_world(map_data.map_to_logic(center), surface.elevation_feet + height * 0.5)
	var direction: Vector2 = Vector2(wall.to) - Vector2(wall.from)
	body.rotation.y = atan2(direction.x, direction.y)
	return body

func _create_map_object(object: BuildingObjectData, surface: BuildingSurfaceData, index: int) -> StaticBody3D:
	var layer := (WALL_LAYER if object.blocks_line_of_sight else (MOVEMENT_ONLY_LAYER if object.blocks_movement else 0)) if object.collision_enabled else 0
	var body := StaticBody3D.new()
	body.name = "Object%d_%s" % [index, object.object_id]
	body.collision_layer = layer
	body.collision_mask = 0
	var size := Vector3(object.rect.size.x / map_data.pixels_per_foot, object.height_feet, object.rect.size.y / map_data.pixels_per_foot)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	var logic_center := map_data.map_to_logic(object.rect.get_center())
	body.position = map_data.logic_to_world(logic_center, surface.elevation_feet + object.height_feet * 0.5)
	body.set_meta("occluder_type", "OBJECT" if object.blocks_line_of_sight else "MOVEMENT_ONLY")
	body.set_meta("map_object", object)
	var visual := MeshInstance3D.new()
	visual.mesh = _create_object_mesh(size, object.color, object.texture, _object_visual_priority(surface, index))
	body.add_child(visual)
	return body

func _create_object_mesh(size: Vector3, color: Color, texture: Texture2D, draw_priority: int = 0) -> ArrayMesh:
	var half := size * 0.5
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top_points := [Vector3(-half.x, half.y, -half.z), Vector3(half.x, half.y, -half.z), Vector3(half.x, half.y, half.z), Vector3(-half.x, half.y, half.z)]
	var top_uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for vertex_index in [0, 2, 1, 0, 3, 2]:
		top.set_uv(top_uvs[vertex_index])
		top.add_vertex(top_points[vertex_index])
	top.generate_normals()
	var mesh := top.commit()
	var top_material := StandardMaterial3D.new()
	top_material.albedo_color = Color.WHITE if texture != null else color
	top_material.albedo_texture = texture
	top_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	top_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if texture != null:
		top_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	top_material.render_priority = draw_priority
	mesh.surface_set_material(0, top_material)
	if texture != null:
		return mesh
	var sides := SurfaceTool.new()
	sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bottom := [Vector3(-half.x, -half.y, -half.z), Vector3(half.x, -half.y, -half.z), Vector3(half.x, -half.y, half.z), Vector3(-half.x, -half.y, half.z)]
	for face in [[top_points[0], top_points[1], bottom[1], bottom[0]], [top_points[1], top_points[2], bottom[2], bottom[1]], [top_points[2], top_points[3], bottom[3], bottom[2]], [top_points[3], top_points[0], bottom[0], bottom[3]]]:
		for vertex_index in [0, 1, 2, 0, 2, 3]: sides.add_vertex(face[vertex_index])
	sides.generate_normals()
	sides.commit(mesh)
	var side_material := StandardMaterial3D.new()
	side_material.albedo_color = color
	side_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	side_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(1, side_material)
	return mesh


func _build_transitions() -> void:
	for transition in map_data.transitions:
		if transition == null:
			continue
		var from_surface := map_data.get_surface(transition.from_surface_id)
		var to_surface := map_data.get_surface(transition.to_surface_id)
		if from_surface == null or to_surface == null:
			continue
		var link := NavigationLink3D.new()
		link.name = String(transition.transition_id)
		link.bidirectional = transition.bidirectional
		link.start_position = map_data.logic_to_world(map_data.map_to_logic(transition.from_position), transition.get_from_elevation(from_surface.elevation_feet))
		link.end_position = map_data.logic_to_world(map_data.map_to_logic(transition.to_position), transition.get_to_elevation(to_surface.elevation_feet))
		link.set_meta("transition", transition)
		add_child(link)
		var a := link.start_position
		var b := link.end_position
		var sideways := Vector3(b.z - a.z, 0, a.x - b.x).normalized() * transition.width_feet * 0.5
		# The authored staircase artwork belongs to the destination floor. Showing
		# that crop on the ramp makes an upward connection readable from below.
		var mesh := _create_stair_wedge_mesh(a, b, sideways, to_surface.texture, transition.render_as_wedge)
		var ramp := StaticBody3D.new()
		ramp.name = "%s_ramp" % transition.transition_id
		ramp.collision_layer = FLOOR_LAYER
		ramp.set_meta("surface_id", transition.transition_id)
		ramp.set_meta("occluder_type", "STAIR")
		var collision := CollisionShape3D.new()
		# Only the sloping surface is solid; the space beneath is open.
		collision.shape = _create_stair_wedge_mesh(a, b, sideways, from_surface.texture, false).create_trimesh_shape()
		ramp.add_child(collision)
		var visual := MeshInstance3D.new()
		visual.name = "TransitionVisual"
		visual.mesh = mesh
		ramp.add_child(visual)
		add_child(ramp)


func update_transition_hover(current_surface_id: StringName, logic_position: Vector2, highlight_hovered: bool) -> void:
	if map_data == null:
		return
	var map_position := map_data.logic_to_map(logic_position)
	for transition in map_data.transitions:
		if transition == null:
			continue
		var ramp := get_node_or_null("%s_ramp" % transition.transition_id)
		var visual := ramp.get_node_or_null("TransitionVisual") if ramp != null else null
		if visual == null:
			continue
		var connected := current_surface_id in [transition.from_surface_id, transition.to_surface_id, transition.transition_id]
		var closest := Geometry2D.get_closest_point_to_segment(map_position, transition.from_position, transition.to_position)
		var over_stairs := map_position.distance_to(closest) <= transition.width_feet * map_data.pixels_per_foot * 0.5
		visual.visible = true
		if highlight_hovered and connected and over_stairs:
			if stair_hover_material == null:
				stair_hover_material = StandardMaterial3D.new()
				stair_hover_material.albedo_color = Color(0.35, 1.0, 0.78, 0.28)
				stair_hover_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				stair_hover_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				stair_hover_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			visual.material_overlay = stair_hover_material
		else:
			visual.material_overlay = null


func _create_stair_wedge_mesh(a: Vector3, b: Vector3, sideways: Vector3, texture: Texture2D, render_as_wedge: bool) -> ArrayMesh:
	var low := a if a.y <= b.y else b
	var high := b if a.y <= b.y else a
	var left_a := low - sideways
	var right_a := low + sideways
	var left_b := high - sideways
	var right_b := high + sideways
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [left_a, left_b, right_b, left_a, right_b, right_a]:
		top.set_uv(map_data.logic_to_map(map_data.world_to_logic(point)) / map_data.source_size)
		top.add_vertex(point)
	top.generate_normals()
	var mesh := top.commit()
	var top_material := StandardMaterial3D.new()
	top_material.albedo_texture = texture
	top_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	top_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.surface_set_material(0, top_material)
	if not render_as_wedge or is_equal_approx(low.y, high.y):
		return mesh
	var base_y := low.y
	var bottom_left_b := Vector3(left_b.x, base_y, left_b.z)
	var bottom_right_b := Vector3(right_b.x, base_y, right_b.z)
	var sides := SurfaceTool.new()
	sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side_vertices: Array[Vector3] = [
		left_a, bottom_left_b, left_b,
		right_a, right_b, bottom_right_b,
		bottom_left_b, bottom_right_b, right_b, bottom_left_b, right_b, left_b,
		left_a, right_a, bottom_right_b, left_a, bottom_right_b, bottom_left_b,
	]
	for point in side_vertices:
		sides.add_vertex(point)
	sides.generate_normals()
	sides.commit(mesh)
	var side_material := StandardMaterial3D.new()
	side_material.albedo_color = Color("70604c")
	side_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	side_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.surface_set_material(1, side_material)
	return mesh


func set_focus_surface(surface_id: StringName, show_adjacent: bool = false) -> void:
	var focus := map_data.get_surface(surface_id) if map_data != null else null
	if focus == null:
		return
	focus_surface_id = surface_id
	for id in surface_nodes:
		var surface := map_data.get_surface(id)
		surface_nodes[id].visible = id == surface_id or (show_adjacent and surface.elevation_feet < focus.elevation_feet)


func is_covered_by_visible_floor(world_position: Vector3) -> bool:
	if map_data == null:
		return false
	var map_position := map_data.logic_to_map(map_data.world_to_logic(world_position))
	for surface in map_data.surfaces:
		if surface == null or surface.elevation_feet <= world_position.y + 0.3:
			continue
		var surface_node: Node3D = surface_nodes.get(surface.surface_id)
		if surface_node == null or not surface_node.visible:
			continue
		var on_floor := false
		for walkable in surface.walkable_rects:
			if walkable.has_point(map_position):
				on_floor = true
				break
		if not on_floor:
			continue
		var in_opening := false
		for opening in surface.opening_rects:
			if opening.has_point(map_position):
				in_opening = true
				break
		if not in_opening:
			return true
	return false


func pick_surface_position(camera: Camera3D, screen_position: Vector2, surface_id: StringName) -> Dictionary:
	var surface := map_data.get_surface(surface_id) if map_data != null else null
	if camera == null or surface == null:
		return {}
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if is_zero_approx(direction.y):
		return {}
	var distance := (surface.elevation_feet - origin.y) / direction.y
	if distance < 0.0:
		return {}
	var world_position := origin + direction * distance
	return {"surface_id": surface_id, "world_position": world_position, "logic_position": map_data.world_to_logic(world_position)}


func has_line_of_sight(from_position: Vector3, to_position: Vector3, exclude: Array[RID] = []) -> bool:
	return bool(get_visibility_result(from_position, to_position, exclude).visible)


func get_visibility_result(from_position: Vector3, to_position: Vector3, exclude: Array[RID] = [], collision_mask: int = VISIBILITY_LAYER_MASK) -> Dictionary:
	if not is_inside_tree():
		return {"visible": true, "position": to_position}
	var query := PhysicsRayQueryParameters3D.create(from_position, to_position, collision_mask, exclude)
	query.hit_back_faces = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return {
		"visible": hit.is_empty(),
		"position": to_position if hit.is_empty() else Vector3(hit.position),
		"collider": null if hit.is_empty() else hit.collider,
	}




func pick_world(camera: Camera3D, screen_position: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen_position) * 500.0, FLOOR_LAYER)
	for attempt in range(32):
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return {}
		var collider: Node3D = hit.collider
		if collider.is_visible_in_tree():
			var id: StringName = collider.get_meta("surface_id", collider.get_parent().get_meta("surface_id", &"ground"))
			return {"surface_id": id, "world_position": hit.position, "logic_position": map_data.world_to_logic(hit.position)}
		var excluded := query.exclude
		excluded.append(hit.rid)
		query.exclude = excluded
	return {}


func resolve_transition_pick(picked: Dictionary, actor: CombatantState) -> Dictionary:
	if actor == null or map_data == null:
		return picked
	var picked_surface := StringName(picked.get("surface_id", &""))
	var picked_world := Vector3(picked.get("world_position", actor.world_position))
	var picked_map_position := map_data.logic_to_map(map_data.world_to_logic(picked_world))
	for transition in map_data.transitions:
		if transition == null:
			continue
		var actor_uses_transition := actor.surface_id in [transition.from_surface_id, transition.to_surface_id, transition.transition_id]
		var closest_map_point := Geometry2D.get_closest_point_to_segment(picked_map_position, transition.from_position, transition.to_position)
		var clicked_stair_area := actor_uses_transition \
			and picked_map_position.distance_to(closest_map_point) <= transition.width_feet * map_data.pixels_per_foot * 0.5
		if transition.transition_id != picked_surface and not clicked_stair_area:
			continue
		var from_surface := map_data.get_surface(transition.from_surface_id)
		var to_surface := map_data.get_surface(transition.to_surface_id)
		if from_surface == null or to_surface == null:
			return picked
		# Height follows progress up the ramp, while the clicked lateral position
		# stays unchanged. Movement validation handles body clearance at the edge.
		var stair_length := transition.from_position.distance_to(transition.to_position)
		if stair_length <= 0.001:
			return picked
		var progress := transition.from_position.distance_to(closest_map_point) / stair_length
		var destination_surface := transition.transition_id
		if progress <= 0.0001:
			destination_surface = transition.from_surface_id
		elif progress >= 0.9999:
			destination_surface = transition.to_surface_id
		var destination_map_position := picked_map_position
		var destination_elevation := lerpf(transition.get_from_elevation(from_surface.elevation_feet), transition.get_to_elevation(to_surface.elevation_feet), progress)
		var destination_world := map_data.logic_to_world(map_data.map_to_logic(destination_map_position), destination_elevation)
		return {
			"surface_id": destination_surface,
			"world_position": destination_world,
			"logic_position": map_data.world_to_logic(destination_world),
		}
	return picked
