class_name AreaVisual3D
extends Node3D

var fill: MeshInstance3D
var outline: MeshInstance3D
var animation_sprite: Sprite3D
var animation_last_frame := 0

func configure(shape: int, origin: Vector3, target: Vector3, radius: float, length: float, width: float, angle_degrees: float, fill_color: Color, edge_color: Color) -> void:
	if is_instance_valid(fill):
		fill.queue_free()
		outline.queue_free()
	var points: Array[Vector3] = []
	var center := Vector3(target.x, target.y + 0.2, target.z)
	match shape:
		SkillData.AreaShape.CIRCLE:
			for index in range(48):
				var angle := TAU * float(index) / 48.0
				points.append(center + Vector3(cos(angle), 0, sin(angle)) * radius)
		SkillData.AreaShape.LINE:
			var direction := Vector3(target.x - origin.x, 0, target.z - origin.z).normalized()
			if direction.is_zero_approx():
				return
			var side := Vector3(-direction.z, 0, direction.x) * width * 0.5
			var start := Vector3(origin.x, center.y, origin.z)
			points = [start + side, start + direction * length + side, start + direction * length - side, start - side]
		SkillData.AreaShape.CONE:
			var direction := Vector2(target.x - origin.x, target.z - origin.z).angle()
			var half_angle := deg_to_rad(angle_degrees * 0.5)
			center = Vector3(origin.x, center.y, origin.z)
			points.append(center)
			for index in range(25):
				var theta := direction + lerpf(-half_angle, half_angle, float(index) / 24.0)
				points.append(center + Vector3(cos(theta), 0, sin(theta)) * length)
	if points.size() < 3:
		return
	fill = MeshInstance3D.new()
	fill.name = "AreaFill"
	var fill_mesh := ImmediateMesh.new()
	fill_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(1, points.size() - 1):
		for vertex in [points[0], points[index], points[index + 1]]:
			fill_mesh.surface_set_color(fill_color)
			fill_mesh.surface_add_vertex(vertex)
	fill_mesh.surface_end()
	fill.mesh = fill_mesh
	fill.material_override = _material()
	add_child(fill)
	outline = MeshInstance3D.new()
	outline.name = "AreaOutline"
	var edge_mesh := ImmediateMesh.new()
	edge_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for index in range(points.size()):
		var next := (index + 1) % points.size()
		for vertex in [points[index], points[next]]:
			edge_mesh.surface_set_color(edge_color)
			edge_mesh.surface_add_vertex(vertex + Vector3.UP * 0.03)
	edge_mesh.surface_end()
	outline.mesh = edge_mesh
	outline.material_override = _material()
	add_child(outline)

func set_animation(template: AttackAnimationData, shape: int, origin: Vector3, target: Vector3, radius: float, length: float, width: float, units_per_foot: float, angle_degrees: float = 90.0) -> void:
	if template.sprite_sheet == null:
		return
	animation_sprite = Sprite3D.new()
	animation_sprite.name = "AreaSpriteFrames"
	animation_sprite.texture = template.sprite_sheet
	animation_sprite.hframes = maxi(1, template.columns)
	animation_sprite.vframes = maxi(1, template.rows)
	animation_sprite.frame = clampi(template.first_frame, 0, animation_sprite.hframes * animation_sprite.vframes - 1)
	animation_last_frame = clampi(template.last_frame, animation_sprite.frame, animation_sprite.hframes * animation_sprite.vframes - 1)
	animation_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	animation_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	animation_sprite.rotation_degrees.x = -90.0
	animation_sprite.pixel_size = 1.0 / units_per_foot
	var frame_width := float(template.sprite_sheet.get_width()) / animation_sprite.hframes
	var frame_height := float(template.sprite_sheet.get_height()) / animation_sprite.vframes
	if shape == SkillData.AreaShape.CIRCLE:
		animation_sprite.position = target + Vector3.UP * 0.28
		if template.circle_fit_sprite_to_area:
			var scale_factor := radius * 2.0 * units_per_foot / maxf(1.0, frame_width)
			animation_sprite.scale = Vector3.ONE * scale_factor * template.effect_scale.x
	else:
		var direction := Vector2(target.x - origin.x, target.z - origin.z).normalized()
		animation_sprite.position = Vector3(origin.x + direction.x * length * 0.5, target.y + 0.28, origin.z + direction.y * length * 0.5)
		animation_sprite.rotation_degrees.y = -rad_to_deg(direction.angle())
		var area_width := width if shape == SkillData.AreaShape.LINE else length * 2.0 * tan(deg_to_rad(angle_degrees * 0.5))
		animation_sprite.scale = Vector3(length * units_per_foot / maxf(1.0, frame_width), area_width * units_per_foot / maxf(1.0, frame_height), 1.0) * Vector3(template.effect_scale.x, template.effect_scale.y, 1.0)
	add_child(animation_sprite)

func play(duration: float) -> void:
	if is_instance_valid(animation_sprite):
		var first := animation_sprite.frame
		var tween := create_tween()
		tween.tween_method(func(value: float):
			if is_instance_valid(animation_sprite):
				animation_sprite.frame = mini(animation_last_frame, int(value)), float(first), float(animation_last_frame + 1), duration)
	var timer := get_tree().create_timer(maxf(0.05, duration))
	timer.timeout.connect(queue_free)

func _material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	return material
