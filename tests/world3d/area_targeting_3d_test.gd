extends SceneTree

const TargetingScript = preload("res://combat/targeting/targeting_system.gd")
const MapRulesScript = preload("res://combat/map/map_rules.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var rules = MapRulesScript.new()
	rules.spatial_world = world
	var actor := CombatantState.new()
	actor.id = "actor"
	actor.team = 0
	actor.world_position = Vector3.ZERO
	var same_floor := CombatantState.new()
	same_floor.id = "same_floor"
	same_floor.team = 1
	same_floor.world_position = Vector3(5, 0, 0)
	var upper := CombatantState.new()
	upper.id = "upper"
	upper.team = 1
	upper.world_position = Vector3(0, 10, 0)
	var state := CombatState.new()
	state.add_combatant(actor)
	state.add_combatant(same_floor)
	state.add_combatant(upper)
	var area := SkillData.new()
	area.area_shape = SkillData.AreaShape.CIRCLE
	area.area_radius_feet = 15.0
	area.target_filter = SkillData.TargetFilter.ENEMIES
	area.area_blocked_by_obstacles = true
	var targeting = TargetingScript.new()
	area.area_radius_feet = 6.0
	var upper_targets: Array[CombatantState] = targeting.collect_targets(actor, Vector2.ZERO, area, state, rules, -1.0, upper.world_position)
	var ground_targets: Array[CombatantState] = targeting.collect_targets(actor, Vector2.ZERO, area, state, rules)
	var passed := upper_targets.has(upper) and not upper_targets.has(same_floor) and ground_targets.has(same_floor) and not ground_targets.has(upper)
	passed = passed and targeting.validate_target_point(actor, Vector2.ZERO, area, rules, 15.0, upper.world_position).success
	area.area_shape = SkillData.AreaShape.LINE
	area.line_width_feet = 2.0
	var vertical_line: Array[CombatantState] = targeting.collect_targets(actor, Vector2.ZERO, area, state, rules, 15.0, upper.world_position)
	passed = passed and vertical_line.has(upper) and not vertical_line.has(same_floor)
	area.area_shape = SkillData.AreaShape.CONE
	area.cone_angle_degrees = 60.0
	var vertical_cone: Array[CombatantState] = targeting.collect_targets(actor, Vector2.ZERO, area, state, rules, 15.0, upper.world_position)
	passed = passed and vertical_cone.has(upper) and not vertical_cone.has(same_floor)
	area.area_shape = SkillData.AreaShape.CIRCLE
	area.area_radius_feet = 15.0
	var floor := StaticBody3D.new()
	floor.collision_layer = 1
	floor.position = Vector3(0, 8, 0)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(20, 0.4, 20)
	floor_shape.shape = floor_box
	floor.add_child(floor_shape)
	world.add_child(floor)
	await physics_frame
	await physics_frame
	var targets: Array[CombatantState] = targeting.collect_targets(actor, actor.position, area, state, rules)
	passed = passed and targets.has(same_floor) and not targets.has(upper)
	var wall := StaticBody3D.new()
	wall.collision_layer = 2
	wall.position = Vector3(2.5, 2.5, 0)
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(0.5, 5, 5)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	world.add_child(wall)
	await physics_frame
	await physics_frame
	targets = targeting.collect_targets(actor, actor.position, area, state, rules)
	passed = passed and not targets.has(same_floor)
	wall.collision_layer = 8
	await physics_frame
	await physics_frame
	targets = targeting.collect_targets(actor, actor.position, area, state, rules)
	passed = passed and targets.has(same_floor)
	world.free()
	print("AREA_TARGETING_3D_TEST: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
