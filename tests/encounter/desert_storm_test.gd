extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var encounter := EncounterData.new()
	encounter.desert_storm_enabled = true
	encounter.desert_storm_intensity = 0.7
	encounter.desert_storm_wind = Vector2(-2.0, 1.0)
	encounter.desert_storm_speed = 2.0
	encounter.desert_storm_density = 0.5
	encounter.desert_storm_color = Color(0.3, 0.5, 0.7)
	encounter.desert_storm_opacity = 0.3
	encounter.desert_storm_particle_size = 2.0
	var path := "user://desert_storm_test.tres"
	var saved := ResourceSaver.save(encounter, path) == OK
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EncounterData
	var data_ok := saved and loaded != null and loaded.desert_storm_enabled and is_equal_approx(loaded.desert_storm_intensity, 0.7) and loaded.desert_storm_wind == Vector2(-2.0, 1.0) and is_equal_approx(loaded.desert_storm_speed, 2.0) and is_equal_approx(loaded.desert_storm_density, 0.5) and loaded.desert_storm_color == Color(0.3, 0.5, 0.7) and is_equal_approx(loaded.desert_storm_opacity, 0.3) and is_equal_approx(loaded.desert_storm_particle_size, 2.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var storm := preload("res://scenes/world3d/desert_storm_3d.gd").new()
	root.add_child(storm)
	storm.configure(encounter)
	var mesh := storm.particles.draw_pass_1 as QuadMesh
	var material := mesh.material as StandardMaterial3D
	var process := storm.particles.process_material as ParticleProcessMaterial
	var visual_ok := storm.particles.emitting and storm.particles.amount == 105 and is_equal_approx(mesh.size.x, 0.36) and is_equal_approx(material.albedo_color.a, 0.3) and is_equal_approx(process.initial_velocity_min, 45.0) and storm.dust_haze != null and storm.dust_haze.visible
	encounter.desert_storm_density = 20.0
	storm.configure(encounter)
	visual_ok = visual_ok and storm.particles.amount == 4200
	storm.queue_free()
	var preview := preload("res://addons/encounter_builder/encounter_preview.gd").new()
	root.add_child(preview)
	preview.set_encounter(encounter)
	preview._process(0.25)
	var preview_ok := is_equal_approx(preview.storm_time, 0.25)
	var dust_field := preview._update_dust_field(encounter.desert_storm_wind.normalized())
	preview_ok = preview_ok and dust_field.get_size() == Vector2i(96, 72) and dust_field.get_pixel(20, 20).a != dust_field.get_pixel(70, 50).a
	var first_frame := dust_field.get_data()
	preview.storm_time += 1.0 / 60.0
	var next_frame := preview._update_dust_field(encounter.desert_storm_wind.normalized())
	preview_ok = preview_ok and next_frame.get_data() != first_frame
	preview_ok = preview_ok and preview._grain_random(0, 1.0) != preview._grain_random(1, 1.0) and preview._grain_random(0, 1.0) != preview._grain_random(0, 2.0)
	encounter.desert_storm_enabled = false
	preview._process(0.25)
	preview_ok = preview_ok and is_equal_approx(preview.storm_time, 0.25 + 1.0 / 60.0)
	preview.queue_free()
	if not data_ok:
		push_error("Storm settings did not survive resource save and load")
	if not visual_ok:
		push_error("Storm particles did not use encounter intensity")
	if not preview_ok:
		push_error("Preview animation did not follow the storm enabled setting")
	print("DESERT_STORM_TEST: " + ("PASS" if data_ok and visual_ok and preview_ok else "FAIL"))
	quit(0 if data_ok and visual_ok and preview_ok else 1)
