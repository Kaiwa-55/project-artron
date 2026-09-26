extends SceneTree

const CombatScene = preload("res://scenes/prototype/PrototypeCombat.tscn")
const Map = preload("res://data/world/artron_keep/artron_keep_map.tres")
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func run() -> void:
	var encounter: EncounterData = load("res://data/encounter/run_normal_goblin_patrol.tres").duplicate(true)
	encounter.building_map = Map
	encounter.player_spawn_positions_feet = [Map.map_to_logic(Vector2(235, 830)) / 12.0, Vector2(0, 0)]
	set_meta("active_encounter_data", encounter)
	var combat = CombatScene.instantiate()
	root.add_child(combat)
	await physics_frame
	await physics_frame
	check(combat.get_node_or_null("UILayer/Control/UseStairsButton") == null, "No stair action button")
	check(not combat.spatial_combatants.is_empty(), "Combat actors have 3D presentation")
	for token_visual in combat.spatial_combatants:
		var source_scale: float = token_visual.proxy.state.spatial_units_per_foot
		check(token_visual.capture.size == Vector2i(512, 512) and token_visual.capture_camera.zoom == Vector2(4, 4), "3D tokens capture source art at high resolution")
		check(token_visual.sprite.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD, "Transparent token pixels do not render as a dark rectangular quad")
		check(is_equal_approx(token_visual.sprite.pixel_size * source_scale * token_visual.capture_camera.zoom.x, 1.0), "Higher token resolution preserves the original world-space size")
	for first_index in range(combat.spatial_combatants.size()):
		for second_index in range(first_index + 1, combat.spatial_combatants.size()):
			var first: CombatantState = combat.spatial_combatants[first_index].proxy.state
			var second: CombatantState = combat.spatial_combatants[second_index].proxy.state
			if first.surface_id == second.surface_id:
				check(first.position.distance_to(second.position) + 0.01 >= (first.collision_radius_feet + second.collision_radius_feet + 0.5) * combat.combat_system.map_rules.world_units_per_foot, "Spawned combatants leave visible spacing")
	var party_states: Array[CombatantState] = []
	for candidate in combat.combat_system.combat_state.combatants.values():
		if candidate.team == combat.get_player_controlled_actor().team:
			party_states.append(candidate)
	if party_states.size() >= 2:
		party_states[0].life_state = CombatEnums.LifeState.DYING
		var blocked_body: ActionResult = combat.combat_system.map_rules.validate_movement_path(party_states[1], party_states[0].position, combat.combat_system.combat_state.combatants)
		check(not blocked_body.success, "A dying combatant still reserves physical space")
		party_states[0].life_state = CombatEnums.LifeState.ALIVE
	var state: CombatState = combat.combat_system.combat_state
	var actor := state.get_combatant("player")
	state.current_actor_id = actor.id
	var space_event := InputEventKey.new()
	space_event.physical_keycode = KEY_SPACE
	space_event.pressed = true
	combat.prefer_floor_on_stair_overlap = false
	combat._unhandled_input(space_event)
	check(not combat.prefer_floor_on_stair_overlap, "Space does not switch targets outside an overlapping Move destination")
	var actor_visual: Node3D
	for candidate in combat.spatial_combatants:
		if candidate.proxy.state == actor:
			actor_visual = candidate
			break
	var animated_stair_logic := Map.map_to_logic(Vector2(235, 700))
	var animated_stair_height: float = combat.combat_system.map_rules.spatial_navigation.height_at(animated_stair_logic, &"west_stairs")
	var animated_stair_position := Map.logic_to_world(animated_stair_logic, animated_stair_height)
	actor.surface_id = &"level_1"
	actor.elevation_feet = 10.0
	actor.position = Map.map_to_logic(Vector2(235, 500))
	actor_visual.position = animated_stair_position
	actor_visual.target = actor.world_position
	actor_visual.sync_state()
	check(actor_visual.sprite.no_depth_test and actor_visual.label.no_depth_test and actor_visual.sprite.render_priority > 0 and actor_visual.label.render_priority > 0, "The token draws after the transparent upper floor while tweening on stairs")
	actor_visual.position = actor.world_position
	actor_visual.target = actor.world_position
	combat.followed_surface_id = &"level_1"
	combat.dungeon_world.set_focus_surface(&"ground", false)
	combat._process(0.0)
	check(actor_visual.visible, "The controlled character remains visible after reaching an upper floor")
	actor.position = Map.map_to_logic(Vector2(235, 700))
	actor.surface_id = &"ground"
	actor.elevation_feet = 0.0
	combat.followed_surface_id = &"ground"
	combat.dungeon_world.set_focus_surface(&"ground", false)
	actor_visual.position = actor.world_position
	actor_visual.target = actor.world_position
	actor_visual.sync_state()
	check(actor_visual.sprite.no_depth_test and actor_visual.label.no_depth_test and actor_visual.sprite.render_priority > 0, "A Ground token beneath stairs renders after the overhead stair artwork")
	actor.position = Map.map_to_logic(Vector2(700, 700))
	actor_visual.position = actor.world_position
	actor_visual.target = actor.world_position
	actor_visual.sync_state()
	check(not actor_visual.sprite.no_depth_test and not actor_visual.label.no_depth_test, "Depth testing returns to normal after leaving the stairs")
	actor.position = Map.map_to_logic(Vector2(235, 830))
	actor_visual.position = actor.world_position
	actor_visual.target = actor.world_position
	actor_visual.sync_state()
	combat.move_mode = true
	var stair_midpoint := Map.logic_to_world(Map.map_to_logic(Vector2(235, 700)), 5.0)
	var stair_screen_point: Vector2 = combat.battlefield_camera_3d.unproject_position(stair_midpoint)
	combat.prefer_floor_on_stair_overlap = false
	combat.get_combat_pointer_position(stair_screen_point)
	check(actor.requested_surface_id == &"west_stairs", "Clicking visible stairs targets the clicked tread without a mode switch")
	check(combat.get_movement_preview_context().get("ambiguous", false), "Overlapping floor and stairs expose a choice")
	check(combat.cycle_movement_pick(stair_screen_point), "Space choice is available only on the overlap")
	check(actor.requested_surface_id == &"ground", "Overlap choice can target the Ground beneath the stairs")
	check(combat.cycle_movement_pick(stair_screen_point), "Overlap choice can switch back to stairs")
	check(actor.requested_surface_id == &"west_stairs", "Switching back targets the clicked tread")
	check(combat.movement_presentation.tooltip.get_theme_font_size("font_size") == 8, "Movement tooltip uses half-size text")
	var stair_preview: Dictionary = combat.movement_presentation.build_preview(Map.map_to_logic(Vector2(235, 700)))
	check(String(stair_preview.get("text", "")).begins_with("Stairs ") and String(stair_preview.get("text", "")).contains("Space:"), "Movement preview keeps stair height and the overlap choice")
	var preview_route: PackedVector3Array = stair_preview.get("route", PackedVector3Array())
	check(preview_route.size() >= 2 and preview_route[-1].y > 0.0, "Movement preview marks the actual stopping point on the slope")
	var ordinary_floor_screen: Vector2 = combat.battlefield_camera_3d.unproject_position(Map.logic_to_world(Map.map_to_logic(Vector2(300, 830)), 0.0))
	check(not combat.cycle_movement_pick(ordinary_floor_screen), "Space has no floor/stair toggle away from an overlap")
	combat.get_combat_pointer_position(ordinary_floor_screen)
	var floor_preview: Dictionary = combat.movement_presentation.build_preview(Map.map_to_logic(Vector2(300, 830)))
	check(not String(floor_preview.get("text", "")).contains("Ground") and not String(floor_preview.get("text", "")).contains("Speed limit"), "Ordinary floor preview shows only essential movement information")
	combat.move_mode = false
	actor.ap = 3
	actor.speed = 18.0
	actor.requested_surface_id = &"level_1"
	var request := ActionRequest.new(actor.id, ActionTypes.Type.MOVE)
	request.target_position = Map.map_to_logic(Vector2(235, 500))
	request.movement_data = MovementData.new()
	var result: ActionResult = combat.combat_system.execute_action(request)
	check(result.success, "Ordinary combat Move accepts a stair route")
	check(actor.elevation_feet > 0.0 and actor.elevation_feet < 10.0, "Combat stops partway along the real slope")
	await create_timer(1.5).timeout
	var visual: Node3D = combat.spatial_combatants[0]
	check(visual.position.is_equal_approx(actor.world_position), "3D character animation reaches authoritative position")
	check(visual.is_visible_in_tree(), "Character remains visible while on stairs")
	check(visual.sprite.no_depth_test and visual.label.no_depth_test, "A character on stairs renders above the stair artwork")
	check(visual.capture.canvas_cull_mask != root.canvas_cull_mask, "Legacy token graphics render inside the 3D sprite only")
	combat._set_view_surface(&"level_1")
	await physics_frame
	check(combat.dungeon_world.surface_nodes[&"level_1"].visible and combat.dungeon_world.surface_nodes[&"ground"].visible, "Level 1 view keeps Ground visible below it")
	var target := Map.logic_to_world(Map.map_to_logic(Vector2(700, 700)), 10.0)
	var picked: Dictionary = combat.dungeon_world.pick_world(combat.battlefield_camera_3d, combat.battlefield_camera_3d.unproject_position(target))
	check(picked.get("surface_id", &"") == &"level_1", "Click ray picks the actual visible upper floor")
	actor.surface_id = &"ground"
	actor.elevation_feet = 0.0
	actor.position = Map.map_to_logic(Vector2(700, 700))
	actor_visual.position = actor.world_position
	actor_visual.target = actor.world_position
	combat.followed_surface_id = &"ground"
	combat._process(0.0)
	check(not actor_visual.visible, "A Ground token is hidden beneath the visible Level 1 floor")
	actor.position = Map.map_to_logic(Vector2(235, 700))
	actor_visual.position = actor.world_position
	actor_visual.target = actor.world_position
	combat._process(0.0)
	check(actor_visual.visible, "A Ground token remains visible through the Level 1 opening")
	var enemy: CombatantState
	for candidate in state.combatants.values():
		if candidate.team != actor.team:
			enemy = candidate
			break
	check(enemy != null, "Encounter supplies an AI combatant")
	if enemy != null:
		var enemy_visual: Node3D
		for candidate in combat.spatial_combatants:
			if candidate.proxy.state == enemy:
				enemy_visual = candidate
				break
		actor.surface_id = &"ground"
		actor.elevation_feet = 0.0
		actor.position = Map.map_to_logic(Vector2(295, 650))
		enemy.surface_id = &"level_1"
		enemy.elevation_feet = 10.0
		enemy.position = Map.map_to_logic(Vector2(295, 650))
		actor_visual.position = actor.world_position
		actor_visual.target = actor.world_position
		enemy_visual.position = enemy.world_position
		enemy_visual.target = enemy.world_position
		state.current_actor_id = actor.id
		combat.followed_surface_id = &"ground"
		combat._set_view_surface(&"ground")
		combat._process(0.0)
		check(not combat.combat_system.map_rules.get_visibility(actor, enemy).not_visible and enemy_visual.visible, "A visible enemy across the stair opening renders on another floor")
		enemy.surface_id = &"level_1"
		enemy.elevation_feet = 10.0
		enemy.position = Map.map_to_logic(Vector2(235, 500))
		enemy.ap = maxi(enemy.ap, 2)
		enemy.speed = maxf(enemy.speed, 30.0)
		actor.surface_id = &"ground"
		actor.elevation_feet = 0.0
		actor.position = Map.map_to_logic(Vector2(235, 830))
		state.current_actor_id = enemy.id
		var ai_decision: Dictionary = combat.enemy_ai.choose_decision(combat.combat_system, enemy)
		check(int(ai_decision.get("type", -1)) == combat.enemy_ai.DecisionType.MOVE, "AI follows a cross-floor target instead of searching through solid geometry: %s" % ai_decision.get("reason", ""))
		var ai_route: PackedVector3Array = combat.combat_system.map_rules.spatial_navigation.path(enemy, actor.position, actor.surface_id)
		check(ai_route.size() >= 4, "AI navigation source has a descending stair route")
		if int(ai_decision.get("type", -1)) == combat.enemy_ai.DecisionType.MOVE:
			var enemy_start: Vector3 = enemy.world_position
			var move_result: ActionResult = combat.enemy_ai.execute_decision(combat.combat_system, ai_decision)
			check(move_result.success, "AI executes its 3D movement decision: %s" % move_result.failure_reason)
			check(not enemy.world_position.is_equal_approx(enemy_start), "AI advances along the 3D route")
			check(not enemy.movement_path_3d.is_empty(), "AI movement preserves its 3D presentation path")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://work/test-results")
		root.get_texture().get_image().save_png("res://work/test-results/combat-3d-stairs.png")
	combat.queue_free()
	await process_frame
	remove_meta("active_encounter_data")
	print("COMBAT_WORLD_INTEGRATION: %d/%d passed" % [checks - failures.size(), checks])
	print("COMBAT_WORLD_INTEGRATION_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
