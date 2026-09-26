@tool
class_name EncounterPreview
extends Control

signal area_drawn(area_feet: Rect2)

var encounter: EncounterData
var selected_group: int = -1 # -1 draws a player area.
var selected_player: int = 0
var drag_start := Vector2.INF
var drag_end := Vector2.INF
var storm_time := 0.0
var dust_field_texture: ImageTexture
var dust_noise := FastNoiseLite.new()
var dust_detail_noise := FastNoiseLite.new()

func _ready() -> void:
	custom_minimum_size = Vector2(700, 500)
	mouse_filter = Control.MOUSE_FILTER_STOP
	dust_noise.seed = 18521
	dust_noise.frequency = 0.035
	dust_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	dust_noise.fractal_octaves = 3
	dust_detail_noise.seed = 8731
	dust_detail_noise.frequency = 0.09

func set_encounter(value: EncounterData) -> void:
	encounter = value
	queue_redraw()

func _process(delta: float) -> void:
	if visible and encounter != null and encounter.desert_storm_enabled and encounter.desert_storm_intensity > 0.0:
		storm_time += delta
		queue_redraw()

func _map_size() -> Vector2:
	return encounter.building_map.source_size if encounter != null and encounter.building_map != null else encounter.map_size_feet * 12.0 if encounter != null else Vector2(3000, 3000)

func _pixels_per_foot() -> float:
	return encounter.building_map.pixels_per_foot if encounter != null and encounter.building_map != null else 12.0

func _image_rect() -> Rect2:
	var source := _map_size()
	var factor := minf(size.x / source.x, size.y / source.y)
	var drawn := source * factor
	return Rect2((size - drawn) * 0.5, drawn)

func _screen_to_feet(point: Vector2) -> Vector2:
	var rect := _image_rect()
	var uv := ((point - rect.position) / rect.size).clamp(Vector2.ZERO, Vector2.ONE)
	return (uv - Vector2.ONE * 0.5) * _map_size() / _pixels_per_foot()

func _feet_to_screen(point: Vector2) -> Vector2:
	return _image_rect().position + (point * _pixels_per_foot() / _map_size() + Vector2.ONE * 0.5) * _image_rect().size

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_start = event.position
			drag_end = event.position
		else:
			if drag_start != Vector2.INF:
				var first := _screen_to_feet(drag_start)
				var last := _screen_to_feet(event.position)
				var area := Rect2(first, last - first).abs()
				if area.has_area():
					area_drawn.emit(area)
			drag_start = Vector2.INF
			drag_end = Vector2.INF
		queue_redraw()
	elif event is InputEventMouseMotion and drag_start != Vector2.INF:
		drag_end = event.position
		queue_redraw()

func _draw() -> void:
	if encounter == null:
		return
	var rect := _image_rect()
	draw_rect(rect, Color("665744") if encounter.desert_storm_enabled else Color("25252c"))
	var texture: Texture2D = encounter.battlefield_texture
	if encounter.building_map != null:
		for surface in encounter.building_map.surfaces:
			if surface != null and surface.surface_id == encounter.starting_surface_id and surface.texture != null:
				texture = surface.texture
				break
	if texture != null:
		draw_texture_rect(texture, rect, false)
	_draw_desert_storm(rect)
	for index in range(encounter.player_spawn_areas_feet.size()):
		_draw_area(encounter.player_spawn_areas_feet[index], Color(0.2, 0.7, 1.0, 0.3), "Player %d" % (index + 1))
	for index in range(encounter.player_spawn_positions_feet.size()):
		if index >= encounter.player_spawn_areas_feet.size() or not encounter.player_spawn_areas_feet[index].has_area():
			_draw_marker(encounter.player_spawn_positions_feet[index], Color("36baff"), "P%d" % (index + 1))
	for index in range(encounter.enemy_groups.size()):
		var group := encounter.enemy_groups[index] as EnemyGroupData
		if group != null:
			_draw_area(group.spawn_area_feet, Color(1.0, 0.35, 0.25, 0.3), group.id)
			if not group.spawn_area_feet.has_area():
				_draw_marker(group.spawn_center_feet, Color("ff684b"), group.id)
	for enemy in encounter.enemies:
		if enemy != null:
			var position_feet := (enemy.position - _map_size() * 0.5) / _pixels_per_foot()
			_draw_marker(position_feet, Color("ff9a5a"), enemy.display_name)
	if drag_start != Vector2.INF:
		var preview := Rect2(drag_start, drag_end - drag_start).abs()
		draw_rect(preview, Color(1, 1, 0.2, 0.25))
		draw_rect(preview, Color.YELLOW, false, 2.0)

func _draw_desert_storm(rect: Rect2) -> void:
	if encounter == null or not encounter.desert_storm_enabled:
		return
	var strength := clampf(encounter.desert_storm_intensity, 0.0, 1.0)
	if strength <= 0.0:
		return
	var sand_color := encounter.desert_storm_color
	var opacity := clampf(encounter.desert_storm_opacity, 0.0, 1.0)
	var wind := encounter.desert_storm_wind.normalized() if encounter.desert_storm_wind.length_squared() > 0.0001 else Vector2.RIGHT
	_update_dust_field(wind)
	draw_rect(rect, Color(sand_color.r, sand_color.g, sand_color.b, strength * opacity * 0.08))
	draw_texture_rect(dust_field_texture, rect, false, Color(sand_color.r, sand_color.g, sand_color.b, strength * opacity * 0.55))
	var grain_count := int(80.0 * strength * encounter.desert_storm_density)
	for index in range(grain_count):
		var speed_scale := 0.55 + _grain_random(index, 3.0) * 0.9
		var center := Vector2(
			fposmod(_grain_random(index, 1.0) * rect.size.x + storm_time * (28.0 + strength * 75.0) * encounter.desert_storm_speed * speed_scale * wind.x, rect.size.x),
			fposmod(_grain_random(index, 2.0) * rect.size.y + storm_time * (28.0 + strength * 75.0) * encounter.desert_storm_speed * speed_scale * wind.y, rect.size.y)
		) + rect.position
		var radius := maxf(0.4, encounter.desert_storm_particle_size * (0.45 + _grain_random(index, 4.0) * 1.1))
		draw_circle(center, radius, Color(sand_color.r, sand_color.g, sand_color.b, opacity * (0.45 + _grain_random(index, 5.0) * 0.55)))

func _grain_random(index: int, salt: float) -> float:
	return fposmod(sin((float(index) + 1.0) * (127.1 + salt * 17.13)) * 43758.5453, 1.0)

func _update_dust_field(wind: Vector2) -> Image:
	var image := Image.create(96, 72, false, Image.FORMAT_RGBA8)
	var crosswind := Vector2(-wind.y, wind.x)
	var drift := storm_time * encounter.desert_storm_speed * 18.0
	for y in range(72):
		for x in range(96):
			var point := Vector2(x, y)
			var sample := Vector2(point.dot(wind) - drift, point.dot(crosswind) * 1.35)
			var broad := dust_noise.get_noise_2d(sample.x, sample.y)
			var detail := dust_detail_noise.get_noise_2d(sample.x, sample.y)
			var density := clampf(0.48 + broad * 0.55 + detail * 0.15, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, density * density))
	if dust_field_texture == null:
		dust_field_texture = ImageTexture.create_from_image(image)
	else:
		dust_field_texture.update(image)
	return image

func _draw_area(area: Rect2, color: Color, label: String) -> void:
	if not area.has_area():
		return
	var screen := Rect2(_feet_to_screen(area.position), _feet_to_screen(area.end) - _feet_to_screen(area.position))
	draw_rect(screen, color)
	draw_rect(screen, color.lightened(0.5), false, 2.0)
	draw_string(ThemeDB.fallback_font, screen.position + Vector2(4, 16), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

func _draw_marker(point_feet: Vector2, color: Color, label: String) -> void:
	var point := _feet_to_screen(point_feet)
	draw_circle(point, 5.0, color)
	draw_string(ThemeDB.fallback_font, point + Vector2(8, -6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
