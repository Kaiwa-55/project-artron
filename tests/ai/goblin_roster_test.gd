extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var shiv: CombatantState = load("res://data/character/goblin_shiv.tres").create_combatant_state()
	var slinger: CombatantState = load("res://data/character/goblin_slinger.tres").create_combatant_state()
	var taskmaster: CombatantState = load("res://data/character/goblin_taskmaster.tres").create_combatant_state()
	check(shiv.level == 1 and shiv.max_hp == 10 and shiv.max_ap == 3 and shiv.base_speed == 30.0, "Goblin Shiv stats are loaded", failures)
	check(slinger.level == 1 and slinger.max_hp == 8 and slinger.equipped_weapon_attack.range_feet == 40.0, "Goblin Slinger stats and ranged attack are loaded", failures)
	check(taskmaster.level == 2 and taskmaster.max_hp == 20 and taskmaster.max_ap == 4, "Goblin Taskmaster stats are loaded", failures)
	check(shiv.equipped_abilities.has("goblin_cowardly_jab") and shiv.equipped_abilities.has("goblin_scurry"), "Goblin Shiv has both signature Abilities", failures)
	check(slinger.equipped_abilities.has("goblin_crippling_stone") and slinger.active_reactions.any(func(reaction): return reaction.id == "goblin_scramble_away"), "Goblin Slinger has Crippling Stone and Scramble Away", failures)
	check(taskmaster.equipped_abilities.has("goblin_mark_the_weak") and taskmaster.equipped_abilities.has("goblin_pack_command"), "Goblin Taskmaster has its command Abilities", failures)
	check(taskmaster.active_reactions.any(func(reaction): return reaction.id == "goblin_guard_order"), "Goblin Taskmaster has its ally-protection Reaction", failures)
	check(shiv.ai_profile != null and slinger.ai_profile != null and taskmaster.ai_profile != null, "Every Goblin has a Utility AI profile", failures)
	var training_target := CombatantState.new()
	training_target.id = "training_target"
	training_target.team = 1
	training_target.max_hp = 20
	training_target.hp = 20
	slinger.position = Vector2.ZERO
	training_target.position = Vector2(30, 0)
	var system := CombatSystem.new()
	system.start_combat([slinger, training_target])
	check(system.attack_system.validate_attack(slinger, training_target, slinger.equipped_weapon_attack).failure_reason.contains("too close"), "Stone Sling cannot attack inside its 5 ft minimum range", failures)
	training_target.position = Vector2(180, 0)
	check(system.attack_system.validate_attack(slinger, training_target, slinger.equipped_weapon_attack).success, "Stone Sling can attack at a legal range", failures)
	var encounter = load("res://data/encounter/prototype_encounter.tres")
	var encounter_ids: Array[String] = []
	for enemy in encounter.enemies:
		encounter_ids.append(enemy.id)
	check(encounter_ids.has("goblin_shiv") and encounter_ids.has("goblin_slinger") and encounter_ids.has("goblin_taskmaster"), "Prototype Encounter includes all three Goblins", failures)
	for failure in failures:
		push_error(failure)
	print("GOBLIN_ROSTER_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
