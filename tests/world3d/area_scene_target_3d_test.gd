extends SceneTree

const CombatScene = preload("res://scenes/prototype/PrototypeCombat.tscn")
const Map = preload("res://data/world/artron_keep/artron_keep_map.tres")
const ArcaneBurst = preload("res://data/skill/arcane_burst.tres")

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var encounter: EncounterData = load("res://data/encounter/run_normal_goblin_patrol.tres").duplicate(true)
	encounter.building_map = Map
	encounter.player_spawn_positions_feet = [Map.map_to_logic(Vector2(235, 830)) / 12.0, Vector2(0, 0)]
	set_meta("active_encounter_data", encounter)
	var combat = CombatScene.instantiate()
	root.add_child(combat)
	await physics_frame
	await physics_frame
	combat._set_view_surface(&"level_1")
	await physics_frame
	var upper_position: Vector3 = Map.logic_to_world(Map.map_to_logic(Vector2(700, 700)), 10.0)
	var screen_point: Vector2 = combat.battlefield_camera_3d.unproject_position(upper_position)
	combat.ground_targeting_id = ArcaneBurst.id
	var chosen: Vector2 = combat.get_combat_pointer_position(screen_point)
	var picked_world: Vector3 = combat.get_ground_target_world_position(chosen)
	var passed := chosen.is_equal_approx(Map.world_to_logic(upper_position)) and is_equal_approx(picked_world.y, 10.0)
	combat.ground_targeting_id = ""
	var attacker: Combatant = combat.get_node("BattlefieldWorld/PlayerCharacter")
	var event := CombatEvent.new(EventTypes.Type.SKILL_CAST, "player", "", {
		"animation_template": ArcaneBurst.attack_data.animation_template,
		"animation_target": chosen,
		"animation_world_target": picked_world,
		"area_shape": SkillData.AreaShape.CIRCLE,
		"area_radius_feet": ArcaneBurst.area_radius_feet,
	})
	combat.show_area_animation_3d(event, attacker)
	var effect = combat.dungeon_world.get_node_or_null("AreaEffect3D")
	passed = passed and effect != null and effect.fill.get_aabb().position.y > 10.0 and effect.animation_sprite != null
	if not passed:
		print("AREA_SCENE_TARGET_3D_DETAILS chosen=", chosen, " expected=", Map.world_to_logic(upper_position), " world=", picked_world, " effect=", effect, " bounds=", effect.fill.get_aabb() if effect != null else AABB())
	combat.queue_free()
	await process_frame
	print("AREA_SCENE_TARGET_3D_TEST: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
