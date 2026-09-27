extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var failures: Array[String] = []
	var saves: Node = root.get_node("SaveGame")
	saves.save_directory = "user://save_test_%d" % Time.get_ticks_usec()
	saves.active_slot = 3
	var generator := RunGenerator.new()
	var run := RunState.new()
	run.setup(721, generator.generate(721, 3))
	run.gold = 147
	run.completed_node_ids.append("start")
	run.game_state.set_flag(&"opened_gate", true)
	run.set_meta("dungeondraft_exploration", {"floor": 1, "position": Vector2(88, 42)})
	var character: CharacterData = preload("res://data/character/player.tres").duplicate(true)
	character.display_name = "Save Hero"
	var portrait_image := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	portrait_image.fill(Color.RED)
	character.portrait = ImageTexture.create_from_image(portrait_image)
	character.token_texture = ImageTexture.create_from_image(portrait_image)
	run.party_character_data.append(character)
	var hero := character.create_combatant_state()
	hero.id = "player"
	hero.display_name = "Save Hero"
	hero.set_meta("ancestry_data", character.ancestry)
	hero.set_meta("class_data", character.character_class)
	hero.base_max_hp = 20
	StatSystem.new().refresh_combatant(hero)
	hero.hp = 9
	var sword: EquipmentData = preload("res://data/equipment/sword.tres").create_enhanced(1)
	hero.equipment_inventory.append(sword)
	hero.equipped_items[0] = sword
	hero.item_inventory.append(ItemStack.new(preload("res://data/item/minor_healing_potion.tres"), 3))
	var bleeding := hero.add_effect(preload("res://data/status/bleeding.tres"))
	bleeding.stack_count = 3
	EquipmentSystem.new().refresh_equipment(hero)
	run.party_progression_states["player"] = hero
	check(saves.save_run(run, "exploration"), "Save writes a Run", failures)
	var snapshot: Dictionary = saves._read_snapshot(3)
	var restored: RunState = saves._load_run(snapshot)
	check(restored != null, "Saved Run loads", failures)
	if restored != null:
		var loaded_hero: CombatantState = restored.party_progression_states.get("player")
		check(restored.seed == 721 and restored.get_signature() == run.get_signature() and restored.gold == 147, "Map and Gold round trip", failures)
		check(restored.game_state.get_flag(&"opened_gate") and restored.get_meta("dungeondraft_exploration").position == Vector2(88, 42), "World and exploration state round trip", failures)
		check(restored.party_character_data.size() == 1 and restored.party_character_data[0].display_name == "Save Hero" and restored.party_character_data[0].portrait != null and restored.party_character_data[0].token_texture != null, "Created character and portrait round trip", failures)
		check(loaded_hero != null and loaded_hero.hp == 9 and loaded_hero.equipment_inventory.has(loaded_hero.equipped_items.get(0)), "HP and equipped item identity round trip", failures)
		check(loaded_hero != null and loaded_hero.equipped_items[0].id == "sword_plus_1", "Enhanced weapon round trips", failures)
		check(loaded_hero != null and loaded_hero.item_inventory.any(func(stack): return stack.item.id == "minor_healing_potion" and stack.quantity == 3), "Consumable quantity round trips", failures)
		check(loaded_hero != null and loaded_hero.has_status("bleeding") and loaded_hero.effects[0].stack_count == 3, "Active status stacks round trip", failures)
	check(saves.load_slot(3), "Load opens the saved Run", failures)
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/exploration/DungeonExploration.tscn", "Load restores the saved exploration scene", failures)
	var active: RunState = get_meta("active_run_state", null)
	check(active != null and active.gold == 147 and active.party_progression_states.has("player"), "Loaded scene receives the restored Run", failures)
	check(saves.save_run(run, "map") and saves.load_slot(3), "Run Map checkpoint loads", failures)
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/run/RunMap.tscn", "Load restores Run Map without starting a new Run", failures)
	run.get_current_node().node_type = MapNodeData.NodeType.TREASURE
	check(saves.save_run(run, "reward") and saves.load_slot(3), "Reward checkpoint loads", failures)
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/run/RewardSelection.tscn", "Load restores an unclaimed reward", failures)
	var path: String = ProjectSettings.globalize_path(saves.slot_path(3))
	var corrupted := FileAccess.open(path, FileAccess.WRITE)
	corrupted.store_string("invalid save")
	corrupted.close()
	check(not saves.get_slot_summary(3).is_empty(), "A damaged save falls back to the previous checkpoint", failures)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".bak")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.save_directory))
	saves.save_directory = saves.SAVE_DIR
	for failure in failures:
		push_error(failure)
	print("SAVE_GAME_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
