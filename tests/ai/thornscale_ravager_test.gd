extends SceneTree

const RavagerData = preload("res://data/character/thornscale_ravager.tres")
const EncounterData = preload("res://data/encounter/prototype_encounter.tres")

var failures: Array[String] = []


func _init() -> void:
	var ravager: CombatantState = RavagerData.create_combatant_state()
	check(ravager.id == "thornscale_ravager" and ravager.level == 3, "Thornscale Ravager is a Level 3 Enemy")
	check(ravager.max_hp == 34 and ravager.max_ap == 4 and ravager.get_effective_speed() == 30.0, "HP, AP, and Speed match the design")
	check(ravager.strength == 18 and ravager.dexterity == 14 and ravager.constitution == 16, "Physical Attributes match the design")
	check(ravager.reflex == 13 and ravager.fortitude == 16 and ravager.will == 11, "Final Defenses include the monster's stat bonuses")
	check(ravager.active_traits.any(func(trait_data): return trait_data != null and trait_data.id == "beast"), "Beast trait is present")
	check(ravager.natural_attack != null and ravager.natural_attack.id == "rending_claw" and ravager.natural_attack.base_damage == 6, "Rending Claw is the natural attack")
	for ability_id in ["thorned_tail", "scalebreaker_charge", "coiling_sweep"]:
		check(ravager.available_abilities.any(func(ability): return ability != null and ability.id == ability_id), "%s is available" % ability_id)
	check(ravager.active_reactions.any(func(reaction): return reaction != null and reaction.id == "barbed_retaliation"), "Barbed Retaliation is available")
	check(EncounterData.enemies.any(func(enemy): return enemy != null and enemy.id == "thornscale_ravager"), "Prototype Encounter contains Thornscale Ravager")
	check(EncounterData.battlefield_texture != null and EncounterData.map_size_feet == Vector2(250, 250), "Encounter owns its battlefield background and size")
	check(not EncounterData.map_objects.is_empty() and EncounterData.map_objects[0].get("kind") == "obstacle", "Encounter owns its map objects")

	var attacker := make_attacker()
	ravager.position = Vector2(80, 0)
	var system := CombatSystem.new()
	system.start_combat([attacker, ravager])
	system.combat_state.current_actor_id = attacker.id
	attacker.position = Vector2.ZERO
	ravager.ap = 4
	var attack := AttackData.new()
	attack.id = "reaction_test_attack"
	attack.display_name = "Reaction Test Attack"
	attack.requires_to_hit = false
	attack.can_critical = false
	attack.ap_cost = 0
	attack.base_damage = 1
	attack.range_feet = 5.0
	attack.traits = [load("res://data/trait/melee.tres")]
	var request := ActionRequest.new(attacker.id, ActionTypes.Type.ATTACK)
	request.target_id = ravager.id
	request.attack_data = attack
	var result := system.execute_action(request)
	check(result.success, "Incoming Melee Attack resolves")
	check(ravager.ap == 3, "Barbed Retaliation spends 1 AP")
	check(attacker.hp == attacker.max_hp - 2, "Barbed Retaliation deals 2 Pierce damage (HP %d/%d)" % [attacker.hp, attacker.max_hp])
	check(result.events.any(func(event): return event.type == EventTypes.Type.REACTION_TRIGGERED and event.data.get("reaction_name") == "Barbed Retaliation"), "Barbed Retaliation is recorded in Combat events")

	for failure in failures: push_error(failure)
	print("THORNSCALE_RAVAGER_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func make_attacker() -> CombatantState:
	var attacker := CombatantState.new()
	attacker.id = "player"
	attacker.display_name = "Player"
	attacker.team = 1
	attacker.base_max_hp = 30
	attacker.base_max_ap = 4
	return attacker


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
