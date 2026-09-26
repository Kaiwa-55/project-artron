extends SceneTree

const WorldScene = preload("res://scenes/world3d/DungeonWorld3D.tscn")
const AIScript = preload("res://combat/ai/enemy_ai_system.gd")
const AIContextScript = preload("res://combat/ai/ai_context.gd")
const EditorPluginScript = preload("res://addons/building_map_editor/building_map_editor_plugin.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func run() -> void:
	check(EditorPluginScript != null, "Map editor loads with the door tool")
	var map := BuildingMapData.new()
	map.source_size = Vector2(300, 300)
	map.pixels_per_foot = 10.0
	var surface := BuildingSurfaceData.new()
	surface.surface_id = &"ground"
	surface.display_name = "Ground"
	surface.walkable_rects = [Rect2(0, 0, 300, 300)]
	surface.wall_rects = [Rect2(145, 0, 10, 300)]
	var door := BuildingDoorData.new()
	door.door_id = &"entry"
	door.rect = Rect2(145, 0, 10, 300)
	surface.doors = [door]
	map.surfaces = [surface]
	var system := CombatSystem.new()
	system.map_rules.configure_building_map(map)
	var world: DungeonWorld3D = WorldScene.instantiate()
	root.add_child(world)
	world.build(map)
	system.map_rules.spatial_world = world
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 30.0
	camera.position = Vector3(0, 100, 0)
	camera.rotation_degrees = Vector3(-90, 0, 0)
	camera.current = true
	root.add_child(camera)
	var actor := CombatantState.new()
	actor.spatial_units_per_foot = map.pixels_per_foot
	actor.id = "enemy"
	actor.team = 1
	actor.position = Vector2(-100, 0)
	actor.ap = 4
	actor.speed = 15.0
	var target := CombatantState.new()
	target.spatial_units_per_foot = map.pixels_per_foot
	target.id = "player"
	target.team = 0
	target.position = Vector2(100, 0)
	var state := CombatState.new()
	state.add_combatant(actor)
	state.add_combatant(target)
	state.current_actor_id = actor.id
	system.combat_state = state
	await physics_frame
	await physics_frame
	var body: StaticBody3D = world.get_node_or_null("ground/Door_entry")
	check(body != null and body.collision_layer == (DungeonWorld3D.WALL_LAYER | DungeonWorld3D.DOOR_INTERACTION_LAYER), "Closed door blocks 3D visibility and is clickable")
	var door_screen := camera.unproject_position(Vector3(0, 4, 0))
	check(world.pick_door(camera, door_screen).get("door_id", &"") == &"entry", "Player can click the closed door")
	check(not world.has_line_of_sight(Vector3(-10, 2, 0), Vector3(10, 2, 0)), "Closed door blocks sight")
	check(not system.map_rules.has_line_of_sight(actor.position, target.position), "Closed door blocks planar sight")
	check(system.map_rules.spatial_navigation.path(actor, target.position, &"ground").is_empty(), "Closed door blocks route")
	var ai = AIScript.new()
	var context = AIContextScript.new()
	context.setup(system, actor)
	var candidates: Array = []
	ai.collect_door_candidates(system, context, candidates)
	check(candidates.any(func(candidate): return candidate.type == AIActionCandidate.Type.MOVE and candidate.door_id == &"entry"), "AI approaches a useful closed door")
	check(not system.interact_door(actor.id, &"ground", &"entry").success, "Distant actor cannot open door")
	actor.position = Vector2(-45, 0)
	context = AIContextScript.new()
	context.setup(system, actor)
	candidates.clear()
	ai.collect_door_candidates(system, context, candidates)
	var open_candidate = candidates.filter(func(candidate): return candidate.type == AIActionCandidate.Type.OPEN_DOOR).front() if not candidates.is_empty() else null
	check(open_candidate != null, "Nearby AI chooses to open door")
	if open_candidate != null:
		check(ai.execute_decision(system, open_candidate.to_decision()).success, "AI opens door for 1 AP")
	check(actor.ap == 3 and system.map_rules.door_is_open(&"ground", &"entry"), "Open state and AP update")
	check(body.collision_layer == DungeonWorld3D.DOOR_INTERACTION_LAYER, "Open door stops blocking movement and sight")
	check(world.pick_door(camera, door_screen).get("door_id", &"") == &"entry", "Player can click the open door to close it")
	check(system.map_rules.spatial_navigation.path(actor, target.position, &"ground").size() >= 2, "Open door allows route")
	await physics_frame
	check(world.has_line_of_sight(Vector3(-10, 2, 0), Vector3(10, 2, 0)), "Open door allows sight")
	check(system.interact_door(actor.id, &"ground", &"entry").success, "Actor can close door again")
	check(not system.map_rules.door_is_open(&"ground", &"entry"), "Door returns to closed state")
	door.rect = Rect2(145, 100, 10, 100)
	check(surface.wall_solid_rects().size() == 2, "Door opening cuts the wall into two solid pieces")
	world.build(map)
	system.map_rules.configure_building_map(map)
	await physics_frame
	await physics_frame
	check(system.map_rules.spatial_navigation.path(actor, target.position, &"ground").is_empty(), "Closed doorway remains blocked within a wall")
	system.map_rules.set_door_open(&"ground", &"entry", true)
	check(system.map_rules.spatial_navigation.path(actor, target.position, &"ground").size() >= 2, "Opening the door makes the wall gap walkable")
	var canvas := MapAuthoringCanvas.new()
	canvas.set_tool(&"door")
	canvas.door_starts_open = true
	canvas.drag_start = Vector2(10, 10)
	canvas._commit_drag(Vector2(30, 20))
	check(canvas.shapes[&"ground"].door.size() == 1 and canvas.shapes[&"ground"].door[0].starts_open, "2D authoring stores the initial door state")
	canvas.free()
	door.rect = Rect2(145, 130, 10, 40)
	surface.wall_rects.clear()
	system.map_rules.configure_building_map(map)
	var alternate: PackedVector3Array = system.map_rules.spatial_navigation.path(actor, target.position, &"ground")
	check(alternate.size() >= 2, "AI navigation finds a route around a short closed door")
	context = AIContextScript.new()
	context.setup(system, actor)
	candidates.clear()
	ai.collect_door_candidates(system, context, candidates)
	check(candidates.is_empty(), "AI does not open a door when the detour is short")
	ai.collect_move_candidates(system, context, candidates)
	check(candidates.any(func(candidate): return candidate.type == AIActionCandidate.Type.MOVE), "AI uses the available route around the door")
	world.queue_free()
	camera.queue_free()
	await process_frame
	print("DOOR_SYSTEM_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
