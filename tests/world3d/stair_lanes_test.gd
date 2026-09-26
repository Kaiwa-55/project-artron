extends SceneTree

var failures: Array[String] = []
var checks := 0

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func make_map(width: float) -> BuildingMapData:
	var map := BuildingMapData.new()
	map.source_size = Vector2(400, 400)
	var ground := BuildingSurfaceData.new()
	ground.surface_id = &"ground"
	ground.walkable_rects = [Rect2(0, 0, 400, 400)]
	var upper := BuildingSurfaceData.new()
	upper.surface_id = &"level_1"
	upper.elevation_feet = 10.0
	upper.walkable_rects = [Rect2(100, 50, 200, 150)]
	var stairs := BuildingTransitionData.new()
	stairs.transition_id = &"stairs"
	stairs.from_surface_id = &"ground"
	stairs.to_surface_id = &"level_1"
	stairs.from_position = Vector2(200, 250)
	stairs.to_position = Vector2(200, 150)
	stairs.width_feet = width
	map.surfaces = [ground, upper]
	map.transitions = [stairs]
	return map

func make_actor(map: BuildingMapData, id: String) -> CombatantState:
	var actor := CombatantState.new()
	actor.id = id
	actor.display_name = id
	actor.position = map.map_to_logic(Vector2(200, 270))
	actor.speed = 100.0
	actor.ap = 2
	actor.requested_surface_id = &"stairs"
	return actor

func run() -> void:
	var map := make_map(12.0)
	var rules := MapRules.new()
	rules.configure_building_map(map)
	var ground_start := map.logic_to_world(map.map_to_logic(Vector2(80, 300)), 0.0)
	var ground_end := map.logic_to_world(map.map_to_logic(Vector2(120, 300)), 0.0)
	check(rules.spatial_navigation.clear_segment(ground_start, ground_end, &"ground", 2.5), "An open floor segment remains walkable")
	var opening_map := make_map(12.0)
	opening_map.surfaces[0].opening_rects = [Rect2(190, 0, 20, 400)]
	var opening_rules := MapRules.new()
	opening_rules.configure_building_map(opening_map)
	var opening_start := opening_map.logic_to_world(opening_map.map_to_logic(Vector2(160, 300)), 0.0)
	var opening_end := opening_map.logic_to_world(opening_map.map_to_logic(Vector2(240, 300)), 0.0)
	check(not opening_rules.spatial_navigation.clear_segment(opening_start, opening_end, &"ground", 2.5), "The floor shortcut still rejects a segment crossing an opening")
	var movement := MovementSystem.new()
	movement.map_rules = rules
	var parameters := MovementData.new()
	parameters.world_units_per_foot = 12.0
	var side_walker := make_actor(map, "side_walker")
	side_walker.position = map.map_to_logic(Vector2(236, 270))
	side_walker.requested_surface_id = &"level_1"
	var upper_goal := map.map_to_logic(Vector2(164, 130))
	var cross_floor_route: PackedVector3Array = movement.spatial_path(side_walker, upper_goal)
	check(cross_floor_route.size() >= 4 and absf(cross_floor_route[1].x) > 1.0 and absf(cross_floor_route[1].x - side_walker.world_position.x) < 2.0, "A cross-floor route can enter near the clicked side instead of through the stair center")
	var cross_floor_result := movement.execute_move(side_walker, upper_goal, parameters)
	check(cross_floor_result.success and side_walker.surface_id == &"level_1" and side_walker.position.is_equal_approx(upper_goal), "A character can cross the ramp diagonally and exit at an arbitrary point on the upper floor")
	var world := DungeonWorld3D.new()
	world.map_data = map
	var lateral_click := map.map_to_logic(Vector2(236, 205))
	var clicked_world := map.logic_to_world(lateral_click, rules.spatial_navigation.height_at(lateral_click, &"stairs"))
	var picked := world.resolve_transition_pick({"surface_id": &"stairs", "world_position": clicked_world}, side_walker)
	var picked_logic: Vector2 = picked.logic_position
	var picked_world: Vector3 = picked.world_position
	check(picked_logic.is_equal_approx(lateral_click) and picked_world.is_equal_approx(clicked_world), "Clicking the side of a stair keeps the exact lateral destination and slope height")
	world.free()
	var first := make_actor(map, "first")
	var second := make_actor(map, "second")
	var state := CombatState.new()
	state.add_combatant(first)
	var first_goal := map.map_to_logic(Vector2(236, 205))
	var first_result := movement.execute_move(first, first_goal, parameters, state)
	check(first_result.success and first.surface_id == &"stairs" and first.position.is_equal_approx(first_goal), "Clicking anywhere across a wide staircase stops at that exact position")
	first.requested_surface_id = &"stairs"
	var sideways_goal := map.map_to_logic(Vector2(164, 205))
	var sideways_result := movement.execute_move(first, sideways_goal, parameters, state)
	check(sideways_result.success and first.position.is_equal_approx(sideways_goal), "A character can move freely sideways while already on the stairs")
	first.requested_surface_id = &"stairs"
	var return_result := movement.execute_move(first, first_goal, parameters, state)
	check(return_result.success and first.position.is_equal_approx(first_goal), "A character can reverse sideways on the stairs")
	state.add_combatant(second)
	var second_goal := map.map_to_logic(Vector2(164, 185))
	var second_result := movement.execute_move(second, second_goal, parameters, state)
	check(second_result.success and second.surface_id == &"stairs" and second.position.is_equal_approx(second_goal), "A second character navigates freely around the first without shifting the clicked destination: %s" % second_result.failure_reason)
	check(second.movement_path_3d.size() > 3, "The route bends around the occupied part of the stair instead of using a fixed lane")
	check(first.world_position.distance_to(second.world_position) >= first.collision_radius_feet + second.collision_radius_feet + 0.5, "Stair lanes do not overlap character bodies")
	check(first.world_position.x * second.world_position.x < 0.0, "Characters occupy different positions across the stair width")
	second.requested_surface_id = &"stairs"
	var outside_result := movement.validate_move(second, map.map_to_logic(Vector2(248, 185)), parameters, state)
	check(not outside_result.success, "A click outside the usable stair width is rejected")
	state.combatants.erase(second.id)
	var slow := make_actor(map, "slow")
	slow.speed = 15.0
	state.add_combatant(slow)
	var slow_stop := movement.clamp_destination_to_remaining_speed(slow, second_goal, parameters, state)
	var slow_result := movement.execute_move(slow, slow_stop, parameters, state)
	check(slow_result.success and slow.movement_distance_this_turn <= 15.01 and slow.surface_id == &"stairs", "A speed-limited detour stops safely partway along the staircase")
	var narrow_map := make_map(9.0)
	var narrow_rules := MapRules.new()
	narrow_rules.configure_building_map(narrow_map)
	var narrow_movement := MovementSystem.new()
	narrow_movement.map_rules = narrow_rules
	var narrow_first := make_actor(narrow_map, "narrow_first")
	var narrow_second := make_actor(narrow_map, "narrow_second")
	var narrow_state := CombatState.new()
	narrow_state.add_combatant(narrow_first)
	var narrow_first_result := narrow_movement.execute_move(narrow_first, narrow_map.map_to_logic(Vector2(200, 205)), parameters, narrow_state)
	narrow_state.add_combatant(narrow_second)
	var narrow_second_result := narrow_movement.execute_move(narrow_second, narrow_map.map_to_logic(Vector2(200, 185)), parameters, narrow_state)
	check(narrow_first_result.success and not narrow_second_result.success, "Narrow stairs do not allow characters to pass through each other")
	var broad_map := make_map(20.0)
	var broad_rules := MapRules.new()
	broad_rules.configure_building_map(broad_map)
	var broad_movement := MovementSystem.new()
	broad_movement.map_rules = broad_rules
	var center_blocker := make_actor(broad_map, "center_blocker")
	center_blocker.position = broad_map.map_to_logic(Vector2(200, 240))
	center_blocker.elevation_feet = broad_rules.spatial_navigation.height_at(center_blocker.position, &"stairs")
	center_blocker.surface_id = &"stairs"
	var approaching := make_actor(broad_map, "approaching")
	approaching.position = broad_map.map_to_logic(Vector2(200, 330))
	approaching.requested_surface_id = &"level_1"
	var broad_state := CombatState.new()
	broad_state.add_combatant(center_blocker)
	broad_state.add_combatant(approaching)
	var broad_goal := broad_map.map_to_logic(Vector2(200, 130))
	var navigation = broad_rules.spatial_navigation
	var first_preview: PackedVector3Array = navigation.path(approaching, broad_goal, &"level_1", "", broad_state.combatants)
	check(not first_preview.is_empty() and navigation.graph_cache.size() == 1, "A blocked route builds one occupant-aware graph")
	var cached_graph: AStar3D = navigation.graph_cache.values()[0].graph
	var nearby_preview: PackedVector3Array = navigation.path(approaching, broad_map.map_to_logic(Vector2(205, 130)), &"level_1", "", broad_state.combatants)
	check(not nearby_preview.is_empty() and navigation.graph_cache.size() == 1 and navigation.graph_cache.values()[0].graph == cached_graph, "Nearby cursor positions reuse the occupant-aware graph")
	center_blocker.position += Vector2(12, 0)
	var moved_preview: PackedVector3Array = navigation.path(approaching, broad_goal, &"level_1", "", broad_state.combatants)
	check(not moved_preview.is_empty() and navigation.graph_cache.size() == 2, "Moving a blocker rebuilds the graph")
	center_blocker.position -= Vector2(12, 0)
	var broad_result := broad_movement.execute_move(approaching, broad_goal, parameters, broad_state)
	check(broad_result.success and approaching.position.is_equal_approx(broad_goal), "A wide staircase offers another entrance when someone blocks its center near the landing: %s" % broad_result.failure_reason)
	var entered_side := false
	var ramp_start: Vector3 = broad_rules.spatial_navigation.ramp_point(broad_map.transitions[0], false)
	for waypoint in approaching.movement_path_3d:
		if absf(waypoint.z - ramp_start.z) < 0.05 and absf(waypoint.y - ramp_start.y) < 0.05 and absf(waypoint.x) > 5.0:
			entered_side = true
	check(entered_side, "The alternate route enters at the free side of the landing")
	print("STAIR_LANES: %d/%d passed" % [checks - failures.size(), checks])
	print("STAIR_LANES_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
