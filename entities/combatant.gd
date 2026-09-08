class_name Combatant
extends Node2D

const TokenBuilder = preload("res://scenes/character_creation/token_image_builder.gd")
const SelectedFrameTexture = preload("res://assets/ui/ui03.png")


var state: CombatantState
var selected: bool = false
var movement_tween: Tween
var movement_target: Vector2
var attack_tween: Tween
var attack_sprite: Node2D
var no_damage_icon: Sprite2D
var no_damage_tween: Tween
var floating_value_labels: Array[Label] = []
var status_icon_layer: Control
var status_icon_signature: String = ""
var selection_frame: Sprite2D


func clear_no_damage_feedback() -> void:
	if no_damage_tween != null:
		no_damage_tween.kill()
	if is_instance_valid(no_damage_icon):
		no_damage_icon.queue_free()
	no_damage_icon = null


func show_no_damage_feedback() -> void:
	clear_no_damage_feedback()
	if state == null:
		return
	no_damage_icon = Sprite2D.new()
	no_damage_icon.texture = preload("res://assets/icon/skill_icons22.png")
	no_damage_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	no_damage_icon.scale = Vector2(0.5, 0.5)
	no_damage_icon.z_index = 30
	no_damage_icon.position = Vector2(0, -state.collision_radius_feet * 12.0 - 28.0)
	add_child(no_damage_icon)
	no_damage_tween = create_tween().set_parallel(true)
	no_damage_tween.tween_property(no_damage_icon, "position:y", no_damage_icon.position.y - 24.0, 0.8)
	no_damage_tween.tween_property(no_damage_icon, "modulate:a", 0.0, 0.4).set_delay(0.4)
	no_damage_tween.chain().tween_callback(func():
		if is_instance_valid(no_damage_icon):
			no_damage_icon.queue_free()
		no_damage_icon = null)


func clear_combat_value_feedback() -> void:
	for label in floating_value_labels:
		if is_instance_valid(label):
			label.queue_free()
	floating_value_labels.clear()


func show_combat_value_feedback(amount: int, is_heal: bool) -> void:
	if amount <= 0 or state == null:
		return
	floating_value_labels = floating_value_labels.filter(func(label: Label): return is_instance_valid(label))
	var label := Label.new()
	label.name = "HealNumber" if is_heal else "DamageNumber"
	label.text = ("+%d" if is_heal else "-%d") % amount
	label.custom_minimum_size = Vector2(112.0, 40.0)
	label.size = label.custom_minimum_size
	label.position = Vector2(-56.0, -state.collision_radius_feet * 12.0 - 54.0 - floating_value_labels.size() * 18.0)
	label.pivot_offset = label.size * 0.5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 40
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color("62e6a7") if is_heal else Color("ff626e"))
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.05, 0.95))
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	floating_value_labels.append(label)
	label.scale = Vector2(0.55, 0.55)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 54.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.55)
	tween.chain().tween_callback(func():
		floating_value_labels.erase(label)
		if is_instance_valid(label):
			label.queue_free())


func clear_attack_sprite() -> void:
	if is_instance_valid(attack_sprite):
		attack_sprite.queue_free()
	attack_sprite = null


func play_sprite_projectile(template: Resource, origin: Vector2, target: Vector2) -> void:
	if template.sprite_sheet == null:
		return
	attack_sprite = Sprite2D.new()
	add_child(attack_sprite)
	attack_sprite.top_level = true
	attack_sprite.z_index = 20
	attack_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	attack_sprite.texture = template.sprite_sheet
	attack_sprite.hframes = maxi(1, template.columns)
	attack_sprite.vframes = maxi(1, template.rows)
	var maximum: int = int(attack_sprite.hframes * attack_sprite.vframes - 1)
	var first := clampi(template.first_frame, 0, maximum)
	var last := clampi(template.last_frame, first, maximum)
	attack_sprite.frame = first
	attack_sprite.scale = template.effect_scale
	attack_sprite.global_position = origin
	attack_sprite.rotation = (origin.angle_to_point(target) if template.orient_to_target else 0.0) + deg_to_rad(template.rotation_offset_degrees)
	var duration := float(last - first + 1) / maxf(1.0, template.frames_per_second)
	attack_tween = create_tween().set_parallel(true)
	attack_tween.tween_property(attack_sprite, "global_position", target, duration)
	attack_tween.tween_method(func(value: float):
		if is_instance_valid(attack_sprite):
			attack_sprite.frame = mini(last, int(value)), float(first), float(last + 1), duration)
	attack_tween.chain().tween_callback(clear_attack_sprite)


func play_attached_directional(template: Resource, origin: Vector2, target: Vector2, scale_per_foot: float) -> void:
	if template.sprite_sheet == null:
		return
	attack_sprite = Sprite2D.new()
	add_child(attack_sprite)
	attack_sprite.top_level = true
	attack_sprite.z_index = 20
	attack_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	attack_sprite.texture = template.sprite_sheet
	attack_sprite.hframes = maxi(1, template.columns)
	attack_sprite.vframes = maxi(1, template.rows)
	var maximum: int = int(attack_sprite.hframes * attack_sprite.vframes - 1)
	var first := clampi(template.first_frame, 0, maximum)
	var last := clampi(template.last_frame, first, maximum)
	attack_sprite.frame = first
	attack_sprite.scale = template.effect_scale
	var direction := origin.direction_to(target)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	attack_sprite.global_position = origin + direction * template.attached_offset_feet * scale_per_foot
	attack_sprite.rotation = (origin.angle_to_point(target) if template.orient_to_target else 0.0) + deg_to_rad(template.rotation_offset_degrees)
	var duration := float(last - first + 1) / maxf(1.0, template.frames_per_second)
	attack_tween = create_tween()
	attack_tween.tween_method(func(value: float):
		if is_instance_valid(attack_sprite):
			attack_sprite.frame = mini(last, int(value)), float(first), float(last + 1), duration)
	attack_tween.tween_callback(clear_attack_sprite)


func play_cone_burst(template: Resource, origin: Vector2, target: Vector2, length_feet: float, angle_degrees: float, scale_per_foot: float) -> void:
	var cone := Node2D.new()
	add_child(cone)
	cone.top_level = true
	cone.z_index = 20
	var direction := origin.direction_to(target)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	cone.global_position = origin + direction * template.attached_offset_feet * scale_per_foot
	cone.rotation = origin.angle_to_point(target)
	var radius := maxf(0.1, length_feet) * scale_per_foot
	var half_angle := deg_to_rad(clampf(angle_degrees, 1.0, 360.0) * 0.5)
	var segments := maxi(4, template.cone_arc_segments)
	var points := PackedVector2Array([Vector2.ZERO])
	for index in range(segments + 1):
		var weight := float(index) / float(segments)
		points.append(Vector2.RIGHT.rotated(lerpf(-half_angle, half_angle, weight)) * radius)
	var fill := Polygon2D.new()
	fill.polygon = points
	fill.color = template.cone_fill_color
	cone.add_child(fill)
	var outline := Line2D.new()
	outline.width = 3.0
	outline.default_color = template.cone_edge_color
	outline.antialiased = true
	outline.points = points
	outline.add_point(Vector2.ZERO)
	cone.add_child(outline)
	var frame_sprite: Sprite2D
	var first := 0
	var last := 0
	var frame_duration := 0.0
	if template.sprite_sheet != null:
		frame_sprite = Sprite2D.new()
		frame_sprite.name = "SpriteFrames"
		frame_sprite.texture = template.sprite_sheet
		frame_sprite.hframes = maxi(1, template.columns)
		frame_sprite.vframes = maxi(1, template.rows)
		frame_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var maximum: int = frame_sprite.hframes * frame_sprite.vframes - 1
		first = clampi(template.first_frame, 0, maximum)
		last = clampi(template.last_frame, first, maximum)
		frame_sprite.frame = first
		frame_sprite.position = Vector2(radius * 0.5, 0.0)
		frame_sprite.rotation = deg_to_rad(template.rotation_offset_degrees)
		if template.cone_fit_sprite_to_area:
			var frame_size := Vector2(
				float(template.sprite_sheet.get_width()) / float(frame_sprite.hframes),
				float(template.sprite_sheet.get_height()) / float(frame_sprite.vframes)
			)
			var cone_width := radius * 2.0 * tan(minf(half_angle, deg_to_rad(89.0)))
			frame_sprite.scale = Vector2(
				radius / maxf(1.0, frame_size.x),
				cone_width / maxf(1.0, frame_size.y)
			) * template.effect_scale
		else:
			frame_sprite.scale = template.effect_scale
		cone.add_child(frame_sprite)
		frame_duration = float(last - first + 1) / maxf(1.0, template.frames_per_second)
	attack_sprite = cone
	cone.scale = Vector2(0.18, 0.18)
	cone.modulate.a = 0.0
	var duration := maxf(0.05, frame_duration if frame_sprite != null and template.cone_play_once else template.cone_duration_seconds)
	var appear_time := duration * 0.35
	var fade_time := duration * 0.45
	attack_tween = create_tween().set_parallel(true)
	attack_tween.tween_property(cone, "scale", Vector2.ONE, appear_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	attack_tween.tween_property(cone, "modulate:a", 1.0, appear_time)
	attack_tween.tween_property(cone, "modulate:a", 0.0, fade_time).set_delay(duration - fade_time)
	attack_tween.tween_property(cone, "scale", Vector2(1.08, 1.08), fade_time).set_delay(duration - fade_time)
	if frame_sprite != null:
		attack_tween.tween_method(func(value: float):
			if is_instance_valid(frame_sprite):
				if template.cone_play_once:
					frame_sprite.frame = mini(last, int(value))
				else:
					var frame_count := last - first + 1
					frame_sprite.frame = first + (int(value) % frame_count),
			float(first),
			float(last + 1) if template.cone_play_once else float(first) + duration * template.frames_per_second,
			duration)
	attack_tween.chain().tween_callback(clear_attack_sprite)


func play_circle_ground(template: Resource, target: Vector2, radius_feet: float, scale_per_foot: float) -> void:
	var circle := Node2D.new()
	add_child(circle)
	circle.top_level = true
	circle.z_index = 20
	circle.global_position = target
	var radius := maxf(0.1, radius_feet) * scale_per_foot
	var segments := maxi(8, template.circle_segments)
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	var fill := Polygon2D.new()
	fill.polygon = points
	fill.color = template.circle_fill_color
	circle.add_child(fill)
	var outline := Line2D.new()
	outline.width = 3.0
	outline.default_color = template.circle_edge_color
	outline.antialiased = true
	outline.points = points
	outline.add_point(points[0])
	circle.add_child(outline)
	var frame_sprite: Sprite2D
	var first := 0
	var last := 0
	var frame_duration := 0.0
	if template.sprite_sheet != null:
		frame_sprite = Sprite2D.new()
		frame_sprite.name = "SpriteFrames"
		frame_sprite.texture = template.sprite_sheet
		frame_sprite.hframes = maxi(1, template.columns)
		frame_sprite.vframes = maxi(1, template.rows)
		frame_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var maximum: int = frame_sprite.hframes * frame_sprite.vframes - 1
		first = clampi(template.first_frame, 0, maximum)
		last = clampi(template.last_frame, first, maximum)
		frame_sprite.frame = first
		frame_sprite.rotation = deg_to_rad(template.rotation_offset_degrees)
		if template.circle_fit_sprite_to_area:
			var frame_size := Vector2(
				float(template.sprite_sheet.get_width()) / float(frame_sprite.hframes),
				float(template.sprite_sheet.get_height()) / float(frame_sprite.vframes)
			)
			var diameter := radius * 2.0
			frame_sprite.scale = Vector2(
				diameter / maxf(1.0, frame_size.x),
				diameter / maxf(1.0, frame_size.y)
			) * template.effect_scale
		else:
			frame_sprite.scale = template.effect_scale
		circle.add_child(frame_sprite)
		frame_duration = float(last - first + 1) / maxf(1.0, template.frames_per_second)
	attack_sprite = circle
	circle.scale = Vector2(0.15, 0.15)
	circle.modulate.a = 0.0
	var duration := maxf(0.05, frame_duration if frame_sprite != null and template.circle_play_once else template.circle_duration_seconds)
	var appear_time := duration * 0.25
	var fade_time := duration * 0.35
	attack_tween = create_tween().set_parallel(true)
	attack_tween.tween_property(circle, "scale", Vector2.ONE, appear_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	attack_tween.tween_property(circle, "modulate:a", 1.0, appear_time)
	attack_tween.tween_property(circle, "modulate:a", 0.0, fade_time).set_delay(duration - fade_time)
	attack_tween.tween_property(circle, "scale", Vector2(1.06, 1.06), fade_time).set_delay(duration - fade_time)
	if frame_sprite != null:
		attack_tween.tween_method(func(value: float):
			if is_instance_valid(frame_sprite):
				if template.circle_play_once:
					frame_sprite.frame = mini(last, int(value))
				else:
					var frame_count := last - first + 1
					frame_sprite.frame = first + (int(value) % frame_count),
			float(first),
			float(last + 1) if template.circle_play_once else float(first) + duration * template.frames_per_second,
			duration)
	attack_tween.chain().tween_callback(clear_attack_sprite)
var visual_offset: Vector2 = Vector2.ZERO:
	set(value):
		visual_offset = value
		if is_instance_valid(status_icon_layer):
			status_icon_layer.position = visual_offset
		if is_instance_valid(selection_frame):
			selection_frame.position = visual_offset
		queue_redraw()


func is_attack_animating() -> bool:
	return attack_tween != null and attack_tween.is_running()


func play_attack_animation(template: Resource, origin: Vector2, target: Vector2, target_radius: float, scale_per_foot: float, area_length_feet: float = 0.0, cone_angle_degrees: float = 90.0, area_radius_feet: float = 0.0) -> void:
	if attack_tween != null:
		attack_tween.kill()
	clear_attack_sprite()
	visual_offset = Vector2.ZERO
	if template.animation_type == 1:
		play_sprite_projectile(template, origin, target)
		return
	if template.animation_type == 2:
		play_attached_directional(template, origin, target, scale_per_foot)
		return
	if template.animation_type == 3:
		play_cone_burst(template, origin, target, area_length_feet, cone_angle_degrees, scale_per_foot)
		return
	if template.animation_type == 4:
		play_circle_ground(template, target, area_radius_feet, scale_per_foot)
		return
	var direction := origin.direction_to(target)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var distance := maxf(0.0, origin.distance_to(target) - (state.collision_radius_feet + target_radius + template.contact_gap_feet) * scale_per_foot)
	var start := origin - global_position
	attack_tween = create_tween()
	attack_tween.tween_property(self, "visual_offset", start - direction * template.anticipation_feet * scale_per_foot, template.anticipation_seconds)
	attack_tween.tween_property(self, "visual_offset", start + direction * distance, template.approach_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	attack_tween.tween_interval(template.impact_seconds)
	attack_tween.tween_property(self, "visual_offset", Vector2.ZERO, template.return_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func is_movement_animating() -> bool:
	return movement_tween != null and movement_tween.is_running()


func setup(p_state: CombatantState) -> void:
	clear_no_damage_feedback()
	clear_combat_value_feedback()
	if attack_tween != null:
		attack_tween.kill()
	clear_attack_sprite()
	visual_offset = Vector2.ZERO
	if movement_tween != null:
		movement_tween.kill()
	state = p_state
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Every combatant token is normalized to the same transparent circular mask.
	if state != null and state.token_texture != null:
		state.token_texture = TokenBuilder.build(state.token_texture, state.token_scale, state.token_offset)
		state.token_scale = 1.0
		state.token_offset = Vector2.ZERO
	global_position = state.position
	movement_target = state.position
	ensure_selection_frame()
	refresh_selection_frame()
	ensure_status_icon_layer()
	refresh_status_icons(true)
	queue_redraw()


func refresh_from_state() -> void:
	if state == null:
		return

	if is_inside_tree() and not global_position.is_equal_approx(state.position):
		if not is_movement_animating() or not movement_target.is_equal_approx(state.position):
			if movement_tween != null:
				movement_tween.kill()
			movement_target = state.position
			var duration := clampf(global_position.distance_to(movement_target) / 300.0, 0.12, 1.2)
			movement_tween = create_tween()
			movement_tween.tween_property(self, "global_position", movement_target, duration)
	elif not is_inside_tree():
		global_position = state.position
	refresh_status_icons()
	queue_redraw()


func set_selected(value: bool) -> void:
	selected = value
	ensure_selection_frame()
	refresh_selection_frame()
	queue_redraw()


func ensure_selection_frame() -> void:
	if is_instance_valid(selection_frame):
		return
	selection_frame = Sprite2D.new()
	selection_frame.name = "SelectionFrame"
	selection_frame.texture = SelectedFrameTexture
	selection_frame.region_enabled = true
	# ui03 is 240x144: five columns by three rows, so each frame is 48x48.
	selection_frame.region_rect = Rect2(192.0, 0.0, 48.0, 48.0)
	selection_frame.centered = true
	selection_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	selection_frame.z_index = 4
	add_child(selection_frame)


func refresh_selection_frame() -> void:
	if not is_instance_valid(selection_frame):
		return
	selection_frame.visible = selected
	selection_frame.position = visual_offset
	if state == null:
		return
	var diameter: float = state.collision_radius_feet * 24.0 + 20.0
	selection_frame.scale = Vector2.ONE * (diameter / 48.0)


func ensure_status_icon_layer() -> void:
	if is_instance_valid(status_icon_layer):
		return
	status_icon_layer = Control.new()
	status_icon_layer.name = "StatusIcons"
	status_icon_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Battlefield feedback must stay above its token but below every HUD panel.
	status_icon_layer.z_index = 2
	add_child(status_icon_layer)


func refresh_status_icons(force: bool = false) -> void:
	if state == null:
		return
	ensure_status_icon_layer()
	var statuses: Array[EffectInstance] = []
	var signature_parts: PackedStringArray = []
	for instance in state.effects:
		if instance == null or instance.data == null or instance.data.status_kind == EffectData.StatusKind.NONE:
			continue
		statuses.append(instance)
		var icon_path := instance.data.icon_texture.resource_path if instance.data.icon_texture != null else ""
		signature_parts.append("%s:%d:%d:%s" % [instance.data.id, instance.stack_count, instance.remaining_turns, icon_path])
	var signature := ",".join(signature_parts)
	if not force and signature == status_icon_signature:
		return
	status_icon_signature = signature
	for child in status_icon_layer.get_children():
		status_icon_layer.remove_child(child)
		child.queue_free()
	if statuses.is_empty():
		return
	var token_radius: float = state.collision_radius_feet * 12.0
	var ring_radius: float = token_radius + 17.0
	var count: int = statuses.size()
	for index in range(count):
		var instance: EffectInstance = statuses[index]
		var angle: float = -PI * 0.75 + (TAU * float(index) / float(maxi(1, count)))
		var icon := PanelContainer.new()
		icon.name = "Status_%s" % instance.data.id
		icon.position = Vector2.from_angle(angle) * ring_radius - Vector2(12, 12)
		icon.size = Vector2(24, 24)
		icon.custom_minimum_size = Vector2(24, 24)
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		icon.tooltip_text = get_status_tooltip(instance)
		var style := StyleBoxFlat.new()
		style.bg_color = get_status_color(instance.data.status_kind)
		style.border_color = Color("f8fafc")
		style.set_border_width_all(2)
		style.set_corner_radius_all(12)
		icon.add_theme_stylebox_override("panel", style)
		var content := Control.new()
		content.name = "Content"
		content.custom_minimum_size = Vector2(24, 24)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.add_child(content)
		if instance.data.icon_texture != null:
			var texture := TextureRect.new()
			texture.name = "Texture"
			texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			texture.offset_left = 3.0
			texture.offset_top = 3.0
			texture.offset_right = -3.0
			texture.offset_bottom = -3.0
			texture.texture = instance.data.icon_texture
			texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.add_child(texture)
		var label := Label.new()
		label.name = "StackOrFallback"
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.text = str(instance.stack_count) if instance.stack_count > 1 else (get_status_abbreviation(instance.data.status_kind) if instance.data.icon_texture == null else "")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		content.add_child(label)
		status_icon_layer.add_child(icon)


func get_status_tooltip(instance: EffectInstance) -> String:
	var stack_text := " · %d stacks" % instance.stack_count if instance.stack_count > 1 else ""
	return "%s%s · %d turn(s) remaining" % [instance.data.display_name, stack_text, instance.remaining_turns]


func get_status_abbreviation(status_kind: EffectData.StatusKind) -> String:
	var abbreviations := {
		EffectData.StatusKind.BLEEDING: "BL", EffectData.StatusKind.BURNING: "BU",
		EffectData.StatusKind.POISONED: "PO", EffectData.StatusKind.SLOWED: "SL",
		EffectData.StatusKind.ROOTED: "RO", EffectData.StatusKind.DAZED: "DA",
		EffectData.StatusKind.STUNNED: "ST", EffectData.StatusKind.SILENCED: "SI",
		EffectData.StatusKind.FRIGHTENED: "FR", EffectData.StatusKind.WEAKENED: "WE",
		EffectData.StatusKind.SURPRISE: "SU", EffectData.StatusKind.HIDDEN: "HI",
		EffectData.StatusKind.HASTE: "HA",
		EffectData.StatusKind.DYING: "DY",
	}
	return abbreviations.get(status_kind, "?")


func get_status_color(status_kind: EffectData.StatusKind) -> Color:
	var colors := {
		EffectData.StatusKind.BLEEDING: Color("b91c1c"), EffectData.StatusKind.BURNING: Color("ea580c"),
		EffectData.StatusKind.POISONED: Color("65a30d"), EffectData.StatusKind.SLOWED: Color("0891b2"),
		EffectData.StatusKind.ROOTED: Color("854d0e"), EffectData.StatusKind.DAZED: Color("7c3aed"),
		EffectData.StatusKind.STUNNED: Color("ca8a04"), EffectData.StatusKind.SILENCED: Color("475569"),
		EffectData.StatusKind.FRIGHTENED: Color("581c87"), EffectData.StatusKind.WEAKENED: Color("9f1239"),
		EffectData.StatusKind.SURPRISE: Color("334155"), EffectData.StatusKind.HIDDEN: Color("0f172a"),
		EffectData.StatusKind.HASTE: Color("2563eb"),
		EffectData.StatusKind.DYING: Color("7f1d1d"),
	}
	return colors.get(status_kind, Color("64748b"))


func _draw() -> void:
	draw_set_transform(visual_offset)
	var fill_color: Color = Color("4A90E2")
	if state != null and state.team == 2:
		fill_color = Color("D95D5D")

	var radius := 30.0
	if state != null:
		radius = state.collision_radius_feet * 12.0
	if state != null and state.token_texture != null:
		var image_size: Vector2 = state.token_texture.get_size()
		if image_size.x > 0.0 and image_size.y > 0.0:
			var fitted_size := image_size * (radius * 2.0 * state.token_scale / maxf(image_size.x, image_size.y))
			draw_texture_rect(state.token_texture, Rect2(state.token_offset - fitted_size * 0.5, fitted_size), false)
	else:
		draw_circle(Vector2.ZERO, radius, fill_color)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color.WHITE, 2.0)
