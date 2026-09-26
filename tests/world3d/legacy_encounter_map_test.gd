extends SceneTree

const CombatScene := preload("res://scenes/prototype/PrototypeCombat.tscn")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	remove_meta("use_dungeondraft_combat")
	remove_meta("active_encounter_data")
	remove_meta("dungeon_combat_return")
	var combat = CombatScene.instantiate()
	root.add_child(combat)
	await process_frame
	var encounter: EncounterData = combat.get_active_encounter_data()
	var surface: BuildingSurfaceData = encounter.building_map.get_surface(&"ground")
	var passed := String(encounter.building_map.map_id).begins_with("legacy_") \
		and surface != null \
		and surface.texture != null \
		and surface.texture.resource_path.ends_with("Desert 1.png") \
		and encounter.building_map.surfaces.size() == 1
	print("LEGACY_ENCOUNTER_MAP_TEST: " + ("PASS" if passed else "FAIL"))
	combat.queue_free()
	await process_frame
	quit(0 if passed else 1)
