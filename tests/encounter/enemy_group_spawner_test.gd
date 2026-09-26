extends SceneTree

const Group = preload("res://data/encounter/enemy_group_data.gd")
const Goblin = preload("res://data/character/goblin_shiv.tres")
var failures: Array[String] = []

func _init() -> void:
	var group := Group.new()
	group.enemy = Goblin
	group.count = 4
	group.spawn_center_feet = Vector2(20, 30)
	group.spacing_feet = 10.0
	group.min_party_level = 3
	group.required_run_flags = {"alarm": true}
	check(not group.is_active(2, {"alarm": true}), "Level gate blocks the group")
	check(not group.is_active(3, {"alarm": false}), "Run flag gate blocks the group")
	check(group.is_active(3, {"alarm": true}), "Matching conditions activate the group")
	check(group.get_spawn_position(0) == Vector2(20, 30), "First spawn uses group center")
	check(group.get_spawn_position(1).distance_to(Vector2(20, 30)) == 10.0, "Additional spawns use authored spacing")
	group.spawn_area_feet = Rect2(-20, 5, 25, 30)
	var encounter := EncounterData.new()
	encounter.player_spawn_positions_feet = [Vector2(99, 99)]
	encounter.player_spawn_areas_feet = [Rect2(-50, -40, 10, 15)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for index in range(25):
		check(group.spawn_area_feet.has_point(group.get_spawn_position(index, rng)), "Enemy group spawns inside its authored area")
		check(encounter.player_spawn_areas_feet[0].has_point(encounter.get_player_spawn_position_feet(0, {}, rng)), "Player spawns inside the authored area")
	check(encounter.get_player_spawn_position_feet(1) == Vector2(-56, -65.3333), "Other party members keep their legacy fallback")
	group.spawn_area_feet = Rect2()
	check(group.get_spawn_position(0) == group.spawn_center_feet, "Empty group area keeps fixed formation")
	var locked_groups: Array[Resource] = [group]
	locked_groups.make_read_only()
	encounter.enemy_groups = locked_groups
	var editable_groups: Array[Resource] = []
	editable_groups.assign(encounter.enemy_groups)
	editable_groups.append(Group.new())
	encounter.enemy_groups = editable_groups
	check(encounter.enemy_groups.size() == 2 and encounter.enemy_groups[0] == group, "Adding to a loaded read-only group list preserves existing groups")
	var locked_areas: Array[Rect2] = [Rect2(1, 2, 3, 4)]
	locked_areas.make_read_only()
	encounter.player_spawn_areas_feet = locked_areas
	var editable_areas: Array[Rect2] = []
	editable_areas.assign(encounter.player_spawn_areas_feet)
	editable_areas.append(Rect2(5, 6, 7, 8))
	encounter.player_spawn_areas_feet = editable_areas
	check(encounter.player_spawn_areas_feet.size() == 2, "Adding a spawn area works with read-only loaded data")
	print("ENEMY_GROUP_SPAWNER_TEST: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
