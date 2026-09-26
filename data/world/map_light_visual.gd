@tool
extends RefCounted

const MASK_SIZE := 256
const SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;
uniform sampler2D map_image : source_color, filter_linear;
uniform sampler2D light_mask : filter_nearest;
void fragment() {
	vec4 art = texture(map_image, UV);
	float level = texture(light_mask, UV).r * 3.0;
	float brightness = level < 1.0 ? mix(1.2, 1.0, level) : (level < 2.0 ? mix(1.0, 0.65, level - 1.0) : mix(0.65, 0.32, level - 2.0));
	ALBEDO = art.rgb * brightness;
	ALPHA = art.a;
}
"""

static func level_at(position: Vector2, points: Array[Dictionary], surface_id: StringName, pixels_per_foot: float, base_level: int = 1) -> int:
	for index in range(points.size() - 1, -1, -1):
		var point := points[index]
		if point.get("surface_id", &"ground") != surface_id or not point.has("rect"):
			continue
		if Rect2(point.rect).has_point(position):
			return clampi(int(point.get("level", base_level)), 0, 3)
	var nearest := INF
	var result := clampi(base_level, 0, 3)
	for point in points:
		if point.get("surface_id", &"ground") != surface_id or point.has("rect"):
			continue
		var distance := position.distance_to(Vector2(point.get("position", Vector2.ZERO)))
		var radius := maxf(0.0, float(point.get("radius_feet", 0.0))) * pixels_per_foot
		if distance <= radius and distance < nearest:
			nearest = distance
			result = clampi(int(point.get("level", base_level)), 0, 3)
	return result

static func create_material(map_texture: Texture2D, source_size: Vector2, points: Array[Dictionary], surface_id: StringName, pixels_per_foot: float, base_level: int = 1) -> ShaderMaterial:
	var mask := Image.create(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_L8)
	for y in range(MASK_SIZE):
		for x in range(MASK_SIZE):
			var position := Vector2((float(x) + 0.5) / MASK_SIZE * source_size.x, (float(y) + 0.5) / MASK_SIZE * source_size.y)
			var level := level_at(position, points, surface_id, pixels_per_foot, base_level)
			mask.set_pixel(x, y, Color(float(level) / 3.0, 0.0, 0.0))
	var shader := Shader.new()
	shader.code = SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("map_image", map_texture)
	material.set_shader_parameter("light_mask", ImageTexture.create_from_image(mask))
	return material
