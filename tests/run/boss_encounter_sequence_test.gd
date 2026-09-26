extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	var catalog := load("res://data/run/prototype_encounter_catalog.tres") as RunEncounterCatalog
	check(catalog != null and catalog.boss_encounters.size() == 1, "The final Run node should start one authored boss sequence.")
	if catalog != null and catalog.boss_encounters.size() == 1:
		var expected_ids := ["run_boss_goblin_entrance", "run_boss_goblin_road", "run_boss_goblin_village"]
		var encounter: EncounterData = catalog.pick_encounter("boss", 123, "final_boss")
		var used_textures: Dictionary = {}
		var used_cutscenes: Dictionary = {}
		for expected_id in expected_ids:
			check(encounter != null, "Boss sequence ends before %s." % expected_id)
			if encounter == null:
				break
			check(encounter.id == expected_id, "Expected %s, got %s." % [expected_id, encounter.id])
			check(encounter.building_map != null, "%s needs a 3D battle map." % expected_id)
			if encounter.building_map != null:
				var surface := encounter.building_map.get_surface(&"ground")
				check(surface != null and surface.texture != null, "%s needs visible ground art." % expected_id)
				if surface != null and surface.texture != null:
					used_textures[surface.texture.resource_path] = true
			check(not encounter.enemy_groups.is_empty(), "%s needs enemies." % expected_id)
			check(encounter.cutscene_image != null, "%s needs a cutscene image." % expected_id)
			if encounter.cutscene_image != null:
				used_cutscenes[encounter.cutscene_image.resource_path] = true
			encounter = encounter.next_encounter
		check(encounter == null, "Rewards should follow the third encounter.")
		check(used_textures.size() == 3, "Each boss encounter should use its own map art.")
		check(used_cutscenes.size() == 3, "Each boss encounter should use its own cutscene art.")

	for failure in failures:
		push_error(failure)
	print("BOSS_ENCOUNTER_SEQUENCE_TEST: PASS" if failures.is_empty() else "BOSS_ENCOUNTER_SEQUENCE_TEST: FAIL (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
