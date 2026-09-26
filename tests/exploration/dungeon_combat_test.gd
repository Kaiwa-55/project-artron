extends SceneTree

const DungeonScene = preload("res://scenes/exploration/DungeonExploration.tscn")
const CombatScene = preload("res://scenes/prototype/PrototypeCombat.tscn")
const Layout = preload("res://scenes/exploration/dungeon_layout.gd")
const BuildingMap: BuildingMapData = preload("res://data/world/artron_keep/artron_keep_map.tres")
const MapRulesScript = preload("res://combat/map/map_rules.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run_test")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func run_test() -> void:
	var run_state := RunState.new()
	set_meta("active_run_state", run_state)
	var rules := MapRulesScript.new()
	rules.add_rectangular_obstacle(Rect2(20,20,20,80), "Test Wall")
	check(not rules.has_line_of_sight(Vector2(0,60),Vector2(100,60)), "Rectangular wall blocks line of sight")
	check(rules.has_line_of_sight(Vector2(0,10),Vector2(100,10)), "Sight remains clear around rectangular wall")
	var actor := CombatantState.new()
	actor.collision_radius_feet = 1.0
	actor.position = Vector2(0,60)
	var blocked := rules.validate_movement_path(actor,Vector2(100,60),{})
	check(not blocked.success and blocked.failure_reason.contains("Test Wall"), "Rectangular wall blocks movement")
	var open := rules.validate_movement_path(actor,Vector2(0,10),{})
	check(open.success, "Movement remains clear around rectangular wall")
	set_meta("use_dungeondraft_combat", true)
	set_meta("active_encounter_data", load("res://data/encounter/run_normal_goblin_patrol.tres"))
	var run_combat = CombatScene.instantiate()
	root.add_child(run_combat)
	await process_frame
	var adapted: EncounterData = run_combat.get_active_encounter_data()
	check(adapted.building_map == BuildingMap, "Run Map combat uses the shared 2.5D building map")
	check(run_combat.dungeon_world != null and run_combat.dungeon_world.surface_nodes.size() == 3, "Combat builds every authored map surface")
	check(run_combat.combat_system.map_rules.building_map == BuildingMap, "Combat rules and presentation share one map source")
	run_combat.queue_free()
	await process_frame
	remove_meta("active_encounter_data")
	remove_meta("use_dungeondraft_combat")
	var dungeon = DungeonScene.instantiate()
	root.add_child(dungeon)
	await process_frame
	dungeon.player.set_physics_process(false)
	dungeon.player.position = Layout.HOSTILE_AREA.get_center()
	dungeon.update_view(0.1)
	check(dungeon.engage_button.visible, "Hall guards are interactable in their room")
	dungeon.start_hostile_combat()
	await process_frame
	check(current_scene != dungeon, "Engaging guards opens Combat Arena")
	check(current_scene.scene_file_path.ends_with("PrototypeCombat.tscn"), "Uses the existing Combat Arena")
	var combat = current_scene
	var encounter: EncounterData = combat.get_active_encounter_data()
	check(encounter.id == Layout.HOSTILE_ID and encounter.building_map == BuildingMap, "Combat uses the shared building map")
	check(encounter.enemies.size() == 2, "Combat spawns the two visible hall guards")
	check(combat.combat_system.map_rules.obstacles.size() >= BuildingMap.get_surface(&"ground").wall_rects.size(), "Combat imports multi-floor wall geometry")
	var test_wall: Rect2 = Layout.sight_walls(0)[0]
	var wall_center := test_wall.get_center() - Layout.SIZE * 0.5
	check(not combat.combat_system.map_rules.has_line_of_sight(wall_center + Vector2(-100,0),wall_center + Vector2(100,0)), "Imported building wall blocks combat sight")
	check(has_meta("dungeon_combat_return"), "Combat return context is retained")
	combat.return_to_dungeon_exploration(CombatEnums.CombatResult.VICTORY)
	await create_timer(0.9).timeout
	check(current_scene.scene_file_path.ends_with("DungeonExploration.tscn"), "Finished dungeon combat returns to exploration")
	check(not has_meta("active_encounter_data") and not has_meta("dungeon_combat_return"), "Combat context is cleaned after return")
	check(bool(run_state.get_meta("dungeon_defeated_encounters", {}).get(Layout.HOSTILE_ID, false)), "Victory clears the hall guards for this run")
	remove_meta("active_run_state")
	print("DUNGEON_COMBAT_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
