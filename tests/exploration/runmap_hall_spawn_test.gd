extends SceneTree

var failures: Array[String] = []
var checks := 0

func _init() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func run() -> void:
	# Start exactly like F6 on RunMap, without Create Character metadata.
	change_scene_to_file("res://scenes/run/RunMap.tscn")
	await scene_changed
	check(not has_meta("created_character_data"), "Direct RunMap start has no created character")
	current_scene.open_building_exploration()
	await scene_changed
	var dungeon = current_scene
	dungeon.player.set_physics_process(false)
	dungeon.player.position = Vector2(765, 675)
	dungeon.update_view(0.1)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	key.pressed = true
	dungeon._unhandled_input(key)
	await scene_changed
	var combat = current_scene
	check(combat.scene_file_path.ends_with("PrototypeCombat.tscn"), "F opens the hall combat")
	var actors: Array = combat.combat_system.combat_state.combatants.values()
	for i in range(actors.size()):
		for j in range(i + 1, actors.size()):
			var first: CombatantState = actors[i]
			var second: CombatantState = actors[j]
			if first.surface_id != second.surface_id:
				continue
			var required := first.collision_radius_feet + second.collision_radius_feet + 0.5
			check(first.world_position.distance_to(second.world_position) + 0.001 >= required, "F-entry spawn spacing: %s / %s" % [first.id, second.id])
	for visual in combat.spatial_combatants:
		check(visual.position.is_equal_approx(visual.proxy.state.world_position), "Visual starts at resolved spawn")
	print("RUNMAP_HALL_SPAWN: %d/%d passed" % [checks - failures.size(), checks])
	print("RUNMAP_HALL_SPAWN_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
