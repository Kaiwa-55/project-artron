extends Node3D

var particles: GPUParticles3D
var dust_haze: MeshInstance3D

const HAZE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, cull_disabled;
uniform vec4 sand_color : source_color;
uniform vec2 wind = vec2(1.0, 0.0);
uniform float drift_speed = 1.0;
uniform float haze_alpha = 0.1;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	vec2 flow = normalize(wind + vec2(0.0001));
	vec2 p = UV * 14.0 - flow * TIME * drift_speed * 0.45;
	float billow = noise(p * vec2(0.7, 2.0)) * 0.6 + noise(p * 2.1) * 0.4;
	float gust = smoothstep(0.42, 0.76, billow);
	ALBEDO = sand_color.rgb;
	ALPHA = haze_alpha * (0.25 + gust * 0.75);
}
"""


func configure(encounter: EncounterData) -> void:
	var strength := clampf(encounter.desert_storm_intensity, 0.0, 1.0)
	if particles == null:
		particles = GPUParticles3D.new()
		particles.name = "BlowingSand"
		particles.position = Vector3(0.0, 0.0, -22.0)
		particles.visibility_aabb = AABB(Vector3(-160.0, -160.0, -20.0), Vector3(320.0, 320.0, 40.0))
		particles.lifetime = 3.0
		particles.explosiveness = 0.0
		particles.local_coords = true
		var mesh := QuadMesh.new()
		mesh.size = Vector2.ONE
		var sand := StandardMaterial3D.new()
		sand.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sand.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sand.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		sand.no_depth_test = true
		mesh.material = sand
		particles.draw_pass_1 = mesh
		add_child(particles)
	if dust_haze == null:
		dust_haze = MeshInstance3D.new()
		dust_haze.name = "DriftingDust"
		dust_haze.position = Vector3(0.0, 0.0, -20.0)
		var haze_mesh := QuadMesh.new()
		haze_mesh.size = Vector2(1000.0, 1000.0)
		var haze_material := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = HAZE_SHADER
		haze_material.shader = shader
		haze_mesh.material = haze_material
		dust_haze.mesh = haze_mesh
		add_child(dust_haze)
	var mesh := particles.draw_pass_1 as QuadMesh
	mesh.size = Vector2.ONE * encounter.desert_storm_particle_size * 0.18
	var sand := mesh.material as StandardMaterial3D
	sand.albedo_color = Color(encounter.desert_storm_color.r, encounter.desert_storm_color.g, encounter.desert_storm_color.b, encounter.desert_storm_opacity)
	var wind := encounter.desert_storm_wind
	var direction := wind.normalized() if wind.length_squared() > 0.0001 else Vector2.RIGHT
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(90.0, 55.0, 2.0)
	process.direction = Vector3(direction.x, -direction.y, 0.0)
	process.spread = 12.0
	process.initial_velocity_min = (12.0 + strength * 15.0) * encounter.desert_storm_speed
	process.initial_velocity_max = (20.0 + strength * 30.0) * encounter.desert_storm_speed
	process.gravity = Vector3.ZERO
	process.scale_min = 0.5
	process.scale_max = 1.5
	particles.process_material = process
	particles.amount = maxi(1, int(300.0 * strength * encounter.desert_storm_density))
	particles.emitting = strength > 0.0 and encounter.desert_storm_density > 0.0 and encounter.desert_storm_opacity > 0.0 and encounter.desert_storm_particle_size > 0.0
	particles.preprocess = particles.lifetime
	var haze_material := (dust_haze.mesh as QuadMesh).material as ShaderMaterial
	haze_material.set_shader_parameter("sand_color", encounter.desert_storm_color)
	haze_material.set_shader_parameter("wind", direction)
	haze_material.set_shader_parameter("drift_speed", encounter.desert_storm_speed)
	haze_material.set_shader_parameter("haze_alpha", strength * encounter.desert_storm_opacity * 0.45)
	dust_haze.visible = strength > 0.0 and encounter.desert_storm_density > 0.0 and encounter.desert_storm_opacity > 0.0
