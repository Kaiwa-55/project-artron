extends SceneTree

const TestScene := preload("res://scenes/prototype/StalkerInTheDimTest.tscn")

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var combat := TestScene.instantiate()
	root.add_child(combat)
	var encounter: EncounterData = combat.get_active_encounter_data()
	var passed := encounter != null and encounter.id == "event_stalker_in_the_dim"
	passed = passed and encounter.building_map != null and encounter.building_map.map_id == &"stalker_in_the_dim"
	passed = passed and combat.combat_system.map_rules.light_level == 2
	passed = passed and combat.dungeon_world != null and combat.dungeon_world.visual_light_level == 2
	combat.queue_free()
	if not passed:
		push_error("Stalker test scene did not load the intended encounter, map, and light level")
	print("STALKER_SCENE_TEST: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
