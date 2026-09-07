extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var attacker := make_combatant("attacker", 1, Vector2.ZERO)
	var target := make_combatant("target", 2, Vector2(60, 0))
	var attack := AttackData.new()
	attack.id = "penalty_attack"
	attack.display_name = "Penalty Attack"
	attack.ap_cost = 0
	attack.base_damage = 0
	attack.range_feet = 20.0
	var system := CombatSystem.new()
	system.start_combat([attacker, target])
	system.combat_state.current_actor_id = attacker.id
	attacker.ap = 10
	var expected := [0, -2, -4, -4]
	for expected_penalty in expected:
		var request := ActionRequest.new(attacker.id, ActionTypes.Type.ATTACK)
		request.target_id = target.id
		request.attack_data = attack
		var result := system.execute_action(request)
		var event = result.events.filter(func(entry): return entry.type in [EventTypes.Type.ATTACK_HIT, EventTypes.Type.ATTACK_MISS]).front()
		check(int(event.data.get("repeated_attack_penalty", 99)) == expected_penalty, "Attack declaration uses expected Repeated Attack Penalty %d" % expected_penalty, failures)
	check(attacker.attacks_declared_this_turn == 4, "Hit or Miss declarations are counted immediately", failures)

	# A direct Reaction roll does not declare a turn Action and receives no penalty.
	var before_reaction := attacker.attacks_declared_this_turn
	var reaction_result := system.attack_system.resolve_attack(attacker, target, attack)
	check(reaction_result.repeated_attack_penalty == 0 and attacker.attacks_declared_this_turn == before_reaction, "Reaction Attack neither receives nor increases the penalty", failures)

	# One Area Action may roll against several targets but declares only once.
	var area_actor := make_combatant("area_actor", 1, Vector2.ZERO)
	var area_a := make_combatant("area_a", 2, Vector2(60, 0))
	var area_b := make_combatant("area_b", 2, Vector2(90, 0))
	var area_ability := AbilityData.new()
	area_ability.id = "penalty_area"
	area_ability.display_name = "Penalty Area"
	area_ability.ap_cost = 0
	area_ability.target_mode = AbilityData.TargetMode.GROUND
	area_ability.target_filter = AbilityData.TargetFilter.ENEMIES
	area_ability.area_shape = AbilityData.AreaShape.CIRCLE
	area_ability.targeting_range_feet = 20.0
	area_ability.area_radius_feet = 10.0
	area_ability.attack_source = AbilityData.AttackSource.CONFIGURED_ATTACK
	area_ability.attack_data = attack
	area_actor.available_abilities.append(area_ability)
	area_actor.equipped_abilities.append(area_ability.id)
	var area_system := CombatSystem.new()
	area_system.start_combat([area_actor, area_a, area_b])
	area_system.combat_state.current_actor_id = area_actor.id
	area_actor.ap = 10
	var first_area := area_system.execute_ground_ability(area_actor.id, area_ability.id, Vector2(75, 0))
	check(first_area.success and area_actor.attacks_declared_this_turn == 1, "Area Attack with multiple targets counts as one declaration", failures)
	var second_area := area_system.execute_ground_ability(area_actor.id, area_ability.id, Vector2(75, 0))
	var second_rolls := second_area.events.filter(func(entry): return entry.type in [EventTypes.Type.ATTACK_HIT, EventTypes.Type.ATTACK_MISS])
	check(area_actor.attacks_declared_this_turn == 2 and second_rolls.all(func(entry): return entry.data.get("repeated_attack_penalty") == -2), "Every roll in the second Area Attack shares one -2 penalty", failures)

	area_system.turn_system.start_turn(area_system.combat_state)
	check(area_actor.attacks_declared_this_turn == 0, "Repeated Attack count resets at the start of the turn", failures)
	for failure in failures:
		push_error(failure)
	print("REPEATED_ATTACK_PENALTY_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func make_combatant(id: String, team: int, position: Vector2) -> CombatantState:
	var combatant := CombatantState.new()
	combatant.id = id
	combatant.display_name = id.capitalize()
	combatant.team = team
	combatant.position = position
	combatant.max_hp = 100
	combatant.hp = 100
	combatant.max_ap = 10
	combatant.ap = 10
	combatant.reflex = 100
	combatant.fortitude = 100
	combatant.will = 100
	return combatant


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
