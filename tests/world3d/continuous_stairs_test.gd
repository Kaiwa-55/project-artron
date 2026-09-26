extends SceneTree

const Map = preload("res://data/world/artron_keep/artron_keep_map.tres")
const ActiveMap = preload("res://data/world/new_building/new_building_map.tres")
const World = preload("res://scenes/world3d/dungeon_world_3d.gd")
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
	var rules := MapRules.new()
	rules.configure_building_map(Map)
	var actor := CombatantState.new()
	actor.id = "walker"
	actor.position = Map.map_to_logic(Vector2(235, 830))
	actor.speed = 18.0
	actor.ap = 3
	actor.max_ap = 3
	actor.requested_surface_id = &"level_1"
	var destination := Map.map_to_logic(Vector2(235, 500))
	var route: PackedVector3Array = rules.spatial_navigation.path(actor, destination, &"level_1")
	check(route.size() >= 4, "Route joins the lower landing, ramp and upper landing")
	var movement := MovementSystem.new()
	movement.map_rules = rules
	var reaction_state := CombatState.new()
	reaction_state.add_combatant(actor)
	var bounded_plan := movement.plan_bounded_move(actor, destination, 18.0, reaction_state)
	check(bounded_plan.validation.success and is_equal_approx(float(bounded_plan.distance_feet), 18.0), "Reaction movement uses the 3D route length as its distance limit")
	var evasive_plan := movement.plan_bounded_move(actor, destination, 10.0, reaction_state)
	check(evasive_plan.validation.success and is_equal_approx(float(evasive_plan.distance_feet), 10.0), "Evasive Step stops after 10 feet of the same route")
	var parameters := MovementData.new()
	parameters.world_units_per_foot = 12.0
	var approach_actor := CombatantState.new()
	approach_actor.id = "approaching_walker"
	approach_actor.position = Map.map_to_logic(Vector2(235, 1100))
	approach_actor.speed = 5.0
	approach_actor.ap = 1
	approach_actor.requested_surface_id = &"level_1"
	var approach_stop := movement.clamp_destination_to_remaining_speed(approach_actor, destination, parameters)
	check(approach_actor.requested_surface_id == &"ground", "A speed-limited approach remains assigned to Ground before reaching the stairs")
	var approach_result := movement.execute_move(approach_actor, approach_stop, parameters)
	check(approach_result.success and approach_actor.surface_id == &"ground" and is_zero_approx(approach_actor.elevation_feet), "A distant character can walk toward the stairs without a false cross-floor route")
	var stop := movement.clamp_destination_to_remaining_speed(actor, destination, parameters)
	var result := movement.execute_move(actor, stop, parameters)
	check(result.success, "Walk onto stairs through ordinary Move")
	check(result.success and actor.world_position.is_equal_approx(bounded_plan.world_position), "Ordinary Move and bounded reaction movement stop at the same route position")
	check(actor.elevation_feet > 0.0 and actor.elevation_feet < 10.0, "Short Move stops partway up the slope")
	check(actor.surface_id == &"west_stairs", "Mid-ramp state is explicit")
	check(actor.ap == 2 and is_equal_approx(actor.movement_distance_this_turn, 18.0), "AP and distance use actual 3D path length")
	actor.requested_surface_id = &"level_1"
	stop = movement.clamp_destination_to_remaining_speed(actor, destination, parameters)
	result = movement.execute_move(actor, stop, parameters)
	check(result.success and actor.surface_id == &"level_1" and is_equal_approx(actor.elevation_feet, 10.0), "Resume reaches upper floor continuously")
	actor.requested_surface_id = &"ground"
	actor.movement_in_progress = false
	actor.speed = 60.0
	result = movement.execute_move(actor, Map.map_to_logic(Vector2(235, 830)), parameters)
	check(result.success and is_zero_approx(actor.elevation_feet), "Same route supports descent")
	var active_rules := MapRules.new()
	active_rules.configure_building_map(ActiveMap)
	var active_movement := MovementSystem.new()
	active_movement.map_rules = active_rules
	var active_actor := CombatantState.new()
	active_actor.id = "active_map_walker"
	active_actor.position = ActiveMap.map_to_logic(Vector2(780, 1128))
	active_actor.speed = 15.0
	active_actor.ap = 4
	active_actor.max_ap = 4
	var active_destination := ActiveMap.map_to_logic(Vector2(240, 700))
	active_actor.requested_surface_id = &"level_1"
	var active_route: PackedVector3Array = active_rules.spatial_navigation.path(active_actor, active_destination, &"level_1")
	check(active_route.size() >= 3, "The active New Building map connects its lower landing to Level 1")
	var active_stop := active_movement.clamp_destination_to_remaining_speed(active_actor, active_destination, parameters)
	var active_result := active_movement.execute_move(active_actor, active_stop, parameters)
	check(active_result.success and active_actor.elevation_feet > 0.0, "A Speed 15 character starts climbing the active map stairs: %s" % active_result.failure_reason)
	var click_world := World.new()
	click_world.map_data = ActiveMap
	active_actor.world_position = active_rules.spatial_navigation.ramp_point(ActiveMap.transitions[0], false)
	active_actor.surface_id = &"ground"
	active_actor.movement_in_progress = false
	active_actor.ap = 4
	for fraction in [0.25, 0.4, 0.2]:
		var clicked_map: Vector2 = ActiveMap.transitions[0].from_position.lerp(ActiveMap.transitions[0].to_position, fraction)
		var picked := click_world.resolve_transition_pick({"surface_id": &"stairs_1", "world_position": ActiveMap.logic_to_world(ActiveMap.map_to_logic(clicked_map), 10.0 * fraction)}, active_actor)
		active_actor.requested_surface_id = picked.surface_id
		# Give each click a fresh action allowance, so the test proves the
		# chosen intermediate stop is respected even with Speed to spare.
		active_actor.movement_in_progress = false
		var click_result := active_movement.execute_move(active_actor, picked.logic_position, parameters)
		var picked_world: Vector3 = picked.world_position
		check(click_result.success and active_actor.world_position.is_equal_approx(picked_world), "Clicking tread %.2f stops at the clicked position, including reversing" % fraction)
		check(active_actor.movement_remaining_feet > 0.0, "Stopping mid-stair preserves unused movement")
	var side_map_position: Vector2 = ActiveMap.transitions[0].from_position.lerp(ActiveMap.transitions[0].to_position, 0.55) + Vector2(0, 24)
	var side_logic := ActiveMap.map_to_logic(side_map_position)
	var side_world := ActiveMap.logic_to_world(side_logic, active_rules.spatial_navigation.height_at(side_logic, &"stairs_1"))
	var side_pick := click_world.resolve_transition_pick({"surface_id": &"stairs_1", "world_position": side_world}, active_actor)
	active_actor.requested_surface_id = side_pick.surface_id
	active_actor.movement_in_progress = false
	var side_result := active_movement.execute_move(active_actor, side_pick.logic_position, parameters)
	check(side_result.success and active_actor.world_position.is_equal_approx(side_world), "The active map lets a character walk to the clicked side of a stair tread")
	click_world.free()
	var world := World.new()
	root.add_child(world)
	world.build(Map)
	await physics_frame
	await physics_frame
	check(not world.has_line_of_sight(Vector3(0, 5, 0), Vector3(0, 15, 0)), "Solid upper floor blocks inter-floor sight")
	var gap := Map.logic_to_world(Map.map_to_logic(Vector2(295, 650)), 5.0)
	check(world.has_line_of_sight(gap, gap + Vector3.UP * 10.0), "Unobstructed opening permits inter-floor sight")
	check(world.get_node_or_null("west_stairs_ramp") is StaticBody3D, "Stairs have real 3D collision")
	world.queue_free()
	await process_frame
	print("CONTINUOUS_STAIRS: %d/%d passed" % [checks - failures.size(), checks])
	print("CONTINUOUS_STAIRS_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
