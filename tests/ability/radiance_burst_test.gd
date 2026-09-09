extends SceneTree

const PlayerTemplate := preload("res://data/character/player.tres")
const Devotee := preload("res://data/class/devotee.tres")
const RadianceBurst := preload("res://data/ability/radiance_burst.tres")
const Catalog := preload("res://data/creation/default_creation_catalog.tres")


func _init() -> void:
	var failures: Array[String] = []
	var character = PlayerTemplate.duplicate(true)
	character.character_class = Devotee
	character.level = 3
	character.class_attribute_choices.assign([AttributeTypes.Type.CONSTITUTION])
	var devotee: CombatantState = character.create_combatant_state()
	devotee.id = "player"; devotee.team = 0
	var visible := make_target("visible", Vector2(240, 0))
	var blocked := make_target("blocked", Vector2(330, 0))
	var outside := make_target("outside", Vector2(500, 0))

	var system := CombatSystem.new()
	system.start_combat([devotee, visible, blocked, outside])
	system.combat_state.current_actor_id = devotee.id
	devotee.position = Vector2.ZERO
	devotee.ap = 5
	devotee.faith = 11
	system.map_rules.add_circular_obstacle(Vector2(285, 0), 12.0, "Area Wall")
	var visible_hp_before: int = visible.hp
	var blocked_hp_before: int = blocked.hp
	var outside_hp_before: int = outside.hp

	var result := system.execute_ground_ability(devotee.id, RadianceBurst.id, Vector2(240, 0))
	check(result.success, "Radiance Burst can select a visible point within 30 feet", failures)
	check(visible.hp == visible_hp_before - 5, "Faith 11 deals floor(Faith / 2) = 5 Light Damage", failures)
	check(blocked.hp == blocked_hp_before, "The Circle area does not pass through an obstacle", failures)
	check(outside.hp == outside_hp_before, "Targets outside the 10-foot radius are unaffected", failures)
	check(devotee.ap == 2 and devotee.faith == 9, "Radiance Burst costs 3 AP and 2 Faith after snapshotting damage", failures)

	system.map_rules.clear_obstacles()
	system.map_rules.add_circular_obstacle(Vector2(120, 0), 20.0, "Center Wall")
	devotee.ap = 5
	devotee.faith = 11
	var blocked_center := system.execute_ground_ability(devotee.id, RadianceBurst.id, Vector2(240, 0))
	check(not blocked_center.success and devotee.ap == 5 and devotee.faith == 11, "A hidden center point is rejected before spending resources", failures)

	check(RadianceBurst.required_level == 3 and RadianceBurst.targeting_range_feet == 30.0 and RadianceBurst.area_radius_feet == 10.0, "Radiance Burst has the specified level, range, and 10-foot area", failures)
	check(RadianceBurst.requires_line_of_sight and RadianceBurst.area_blocked_by_obstacles, "Radiance Burst requires center sight and obstacle blocking", failures)
	check(["devotee", "divine", "circle"].all(func(id): return RadianceBurst.traits.any(func(trait_data): return trait_data != null and trait_data.id == id)), "Radiance Burst has Devotee, Divine, and Circle traits", failures)
	check(Catalog.abilities.has(RadianceBurst) and Devotee.get_progression_entry(3).granted_abilities.has(RadianceBurst), "Radiance Burst is registered in Character Creation and Level 3 progression", failures)

	for failure in failures:
		push_error(failure)
	print("RADIANCE_BURST_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func make_target(id: String, position: Vector2) -> CombatantState:
	var target := CombatantState.new()
	target.id = id
	target.team = 1
	target.base_max_hp = 30
	target.position = position
	return target


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
