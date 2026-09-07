extends SceneTree

const StalkerData = preload("res://data/character/crimson_spine_stalker.tres")

var failures: Array[String] = []


func _init() -> void:
	var stalker: CombatantState = StalkerData.create_combatant_state()
	check(stalker.id == "crimson_spine_stalker" and stalker.level == 4, "Crimson Spine Stalker resource creates a Level 4 Enemy")
	check(stalker.max_hp == 38 and stalker.max_ap == 4 and stalker.get_effective_speed() == 35.0, "HP, AP, and Speed match the design")
	check(stalker.strength == 16 and stalker.dexterity == 18 and stalker.constitution == 14 and stalker.intelligence == 8 and stalker.wisdom == 12 and stalker.charisma == 8, "Attributes match the design")
	check(stalker.initiative_bonus == 4 and stalker.reflex_stat_bonus == 3 and stalker.fortitude_stat_bonus == 1 and stalker.will_stat_bonus == 0, "Initiative and Defense bonuses match the design")
	check(stalker.active_traits.any(func(trait_data): return trait_data != null and trait_data.id == "demon"), "Demon trait is present")
	var talon: AttackData = stalker.natural_attack
	check(talon != null and talon.id == "rending_talon" and talon.ap_cost == 1 and talon.to_hit_bonus == 3 and talon.range_feet == 8.0 and talon.base_damage == 7, "Rending Talon uses the requested attack profile")
	check(talon.is_unarmed and has_attack_trait(talon, "melee") and has_attack_trait(talon, "unarmed"), "Rending Talon is Melee and Unarmed")
	check(has_ability(stalker, "blood_claw") and has_ability(stalker, "predator_rush"), "Blood Claw and Predator Rush are available")
	check(stalker.active_reactions.any(func(reaction): return reaction != null and reaction.id == "skitter_dodge" and reaction.ap_cost == 1 and reaction.uses_per_round == 1), "Skitter Dodge is a once-per-round 1 AP Reaction")

	var target := make_target()
	stalker.position = Vector2.ZERO
	target.position = Vector2(80, 0)
	var system := CombatSystem.new()
	system.start_combat([stalker, target])
	system.combat_state.current_actor_id = stalker.id
	stalker.ap = 4
	target.reflex = -100
	target.fortitude = -100
	target.will = -100
	var claw_result := system.use_active_ability(stalker.id, target.id, "blood_claw")
	var bleeding = target.effects.filter(func(instance): return instance != null and instance.data.id == "bleeding")
	check(claw_result.success and stalker.ap == 2, "Blood Claw spends 2 AP")
	check(not bleeding.is_empty() and bleeding[0].stack_count == 5, "Blood Claw applies Bleeding 5 on Hit")
	check(system.ability_system.get_remaining_cooldown(stalker, "blood_claw") == 2, "Blood Claw starts its 2-turn cooldown")

	stalker.ap = 4
	system.ability_system.set_remaining_cooldown(stalker, "predator_rush", 0)
	var rush_origin := stalker.position
	check(system.begin_ability_movement(stalker.id, "predator_rush").success, "Predator Rush begins through Ability Movement")
	var rush_result := system.execute_pending_ability_movement(rush_origin + Vector2.LEFT * 9999.0)
	var rush_distance: float = rush_origin.distance_to(stalker.position) / system.map_rules.world_units_per_foot
	check(rush_result.success and is_equal_approx(rush_distance, 20.0) and stalker.ap == 3, "Predator Rush moves 20 ft for 1 AP")

	var reactor: CombatantState = StalkerData.create_combatant_state()
	var attacker := make_target()
	attacker.id = "attacker"
	attacker.position = Vector2.ZERO
	reactor.position = Vector2(80, 0)
	var reaction_system := CombatSystem.new()
	reaction_system.start_combat([attacker, reactor])
	reaction_system.combat_state.current_actor_id = attacker.id
	attacker.ap = 4
	reactor.ap = 4
	var attack := AttackData.new()
	attack.id = "skitter_dodge_test"
	attack.display_name = "Skitter Dodge Test"
	attack.requires_to_hit = false
	attack.can_critical = false
	attack.ap_cost = 0
	attack.base_damage = 1
	attack.range_feet = 5.0
	var request := ActionRequest.new(attacker.id, ActionTypes.Type.ATTACK)
	request.target_id = reactor.id
	request.attack_data = attack
	var reaction_result := reaction_system.execute_action(request)
	check(reaction_result.events.any(func(event): return event.type == EventTypes.Type.REACTION_TRIGGERED and event.data.get("reaction_name") == "Skitter Dodge"), "Skitter Dodge triggers before the Attack resolves")
	check(reaction_result.events.any(func(event): return event.type == EventTypes.Type.ATTACK_MISS), "Leaving the real attack range changes the Attack to Miss")
	check(reactor.ap == 3 and int(reactor.reaction_last_used_round.get("skitter_dodge", 0)) == reaction_system.combat_state.current_round, "Skitter Dodge spends AP and records its round limit")

	for failure in failures: push_error(failure)
	print("CRIMSON_SPINE_STALKER_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func make_target() -> CombatantState:
	var target := CombatantState.new()
	target.id = "target"
	target.display_name = "Target"
	target.team = 1
	target.base_max_hp = 100
	target.base_max_ap = 4
	return target


func has_attack_trait(attack: AttackData, trait_id: String) -> bool:
	return attack.traits.any(func(trait_data): return trait_data != null and trait_data.id == trait_id)


func has_ability(actor: CombatantState, ability_id: String) -> bool:
	return actor.available_abilities.any(func(ability): return ability != null and ability.id == ability_id)


func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
