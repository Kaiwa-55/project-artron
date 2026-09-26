extends SceneTree

const BuildingMap: BuildingMapData = preload("res://data/world/artron_keep/artron_keep_map.tres")
const WatchtowerMap: BuildingMapData = preload("res://data/world/wooden_watchtower/wooden_watchtower_map.tres")
const NewBuildingMap: BuildingMapData = preload("res://data/world/new_building/new_building_map.tres")
const Catalog: BuildingMapCatalog = preload("res://data/world/map_catalog.tres")
const WorldScene := preload("res://scenes/world3d/DungeonWorld3D.tscn")
const MapRulesScript := preload("res://combat/map/map_rules.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func run_test() -> void:
	check(Catalog.validate().is_empty(), "Map catalog validates")
	check(Catalog.get_map(&"artron_keep") == BuildingMap, "Map is discoverable by stable id")
	check(Catalog.get_map(&"wooden_watchtower") == WatchtowerMap, "Wooden Watchtower is discoverable by stable id")
	check(BuildingMap.get_surface(&"ground") != null and BuildingMap.get_surface(&"level_1") != null, "Ground and Level 1 exist")
	var new_building_upper := NewBuildingMap.get_surface(&"level_1")
	var new_building_solids := new_building_upper.solid_rects()
	check(new_building_solids.any(func(rect: Rect2): return rect.has_point(Vector2(300, 800))), "New Building walkable balcony creates a solid sight-blocking floor")
	check(not new_building_solids.any(func(rect: Rect2): return rect.has_point(Vector2(700, 1050))), "New Building lower opening remains free of hidden floor collision")
	var world: DungeonWorld3D = WorldScene.instantiate()
	root.add_child(world)
	world.build(BuildingMap)
	check(world.surface_nodes.size() == 3, "3D loader builds all surfaces")
	check(world.get_node_or_null("west_stairs") is NavigationLink3D, "Stair transition creates a navigation link")
	var stair_visual: MeshInstance3D = world.get_node_or_null("west_stairs_ramp/TransitionVisual")
	check(stair_visual != null and stair_visual.mesh.surface_get_material(0).albedo_texture == BuildingMap.get_surface(&"level_1").texture, "Ground view uses the connected Level 1 artwork on its stairs")
	world.update_transition_hover(&"ground", BuildingMap.map_to_logic(Vector2(235, 700)), true)
	check(stair_visual.visible and stair_visual.material_overlay != null, "Hover highlights the stairs without hiding their artwork")
	world.update_transition_hover(&"ground", BuildingMap.map_to_logic(Vector2(235, 700)), false)
	check(stair_visual.visible and stair_visual.material_overlay == null, "Stair artwork stays visible after hover ends")
	world.update_transition_hover(&"level_1", BuildingMap.map_to_logic(Vector2(235, 700)), true)
	check(stair_visual.visible and stair_visual.material_overlay != null, "Upper floor also highlights the connected stairs")
	world.update_transition_hover(&"level_1", BuildingMap.map_to_logic(Vector2(235, 700)), false)
	var stair_pick := {
		"surface_id": &"west_stairs",
		"world_position": BuildingMap.logic_to_world(BuildingMap.map_to_logic(Vector2(235, 700)), 5.0),
		"logic_position": BuildingMap.map_to_logic(Vector2(235, 700)),
	}
	var stair_actor := CombatantState.new()
	stair_actor.surface_id = &"ground"
	stair_actor.elevation_feet = 0.0
	var upward_pick: Dictionary = world.resolve_transition_pick(stair_pick, stair_actor)
	check(upward_pick.surface_id == &"west_stairs" and Vector2(upward_pick.logic_position).is_equal_approx(BuildingMap.map_to_logic(Vector2(235, 700))), "Clicking stairs from Ground targets the clicked tread")
	var overlapping_ground_pick := stair_pick.duplicate()
	overlapping_ground_pick.surface_id = &"ground"
	overlapping_ground_pick.world_position = BuildingMap.logic_to_world(BuildingMap.map_to_logic(Vector2(235, 700)), 0.0)
	var ground_hit_upward_pick: Dictionary = world.resolve_transition_pick(overlapping_ground_pick, stair_actor)
	check(ground_hit_upward_pick == upward_pick, "Ground beneath stairs resolves to the same tread and elevation")
	stair_actor.surface_id = &"level_1"
	stair_actor.elevation_feet = 10.0
	var downward_pick: Dictionary = world.resolve_transition_pick(stair_pick, stair_actor)
	check(downward_pick == upward_pick, "Descending targets the clicked tread rather than the lower landing")
	var rules := MapRulesScript.new()
	rules.configure_building_map(BuildingMap)
	var lower := CombatantState.new()
	lower.position = Vector2(-500, -400)
	lower.surface_id = &"ground"
	lower.elevation_feet = 0.0
	var upper := CombatantState.new()
	upper.position = Vector2(-500, -400)
	upper.surface_id = &"level_1"
	upper.elevation_feet = 10.0
	check(rules.is_target_in_range(lower, upper, 15.0), "Range includes vertical distance")
	check(rules.has_line_of_sight_between(lower, upper), "Characters can see across floors when no wall crosses the ray")
	var fall := rules.get_fall_at(upper, BuildingMap.map_to_logic(Vector2(220, 650)))
	check(fall.get("surface_id", &"") == &"ground", "Upper-floor opening resolves a fall to Ground")
	var watchtower_world: DungeonWorld3D = WorldScene.instantiate()
	root.add_child(watchtower_world)
	watchtower_world.build(WatchtowerMap)
	check(watchtower_world.surface_nodes.size() == 3, "Watchtower loader builds all three image layers")
	check(watchtower_world.get_node_or_null("south_stairs_ramp") is StaticBody3D, "Watchtower stairs build as a 3D wedge")
	var watchtower_rules := MapRulesScript.new()
	watchtower_rules.configure_building_map(WatchtowerMap)
	var climber := CombatantState.new()
	climber.position = WatchtowerMap.map_to_logic(Vector2(240, 1090))
	climber.surface_id = &"ground"
	climber.requested_surface_id = &"level_1"
	var watchtower_route: PackedVector3Array = watchtower_rules.spatial_navigation.path(climber, WatchtowerMap.map_to_logic(Vector2(400, 400)), &"level_1")
	check(watchtower_route.size() >= 4, "Watchtower route connects Ground to Level 1 through the stairs")
	watchtower_world.queue_free()
	world.queue_free()
	await process_frame
	print("BUILDING_WORLD_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
