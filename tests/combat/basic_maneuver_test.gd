extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var combat := CombatSystem.new()
	var actor := make_combatant("actor", 1, Vector2(120, 120), 100)
	var target := make_combatant("target", 2, Vector2(240, 120), 10)
	actor.unarmed_attack = preload("res://data/attack/unarmed_attack.tres")
	combat.start_combat([actor, target])
	combat.combat_state.current_actor_id = actor.id
	actor.ap = 5

	var grab := combat.use_basic_maneuver(actor.id, target.id, ActionTypes.Maneuver.GRAB)
	check(grab.success and target.has_status("grabbed") and actor.has_status("grabbing"), "Grab should apply linked Grabbed and Grabbing statuses.", failures)
	var movement := MovementData.new()
	movement.ap_cost = 1
	movement.world_units_per_foot = 12.0
	check(not combat.movement_system.validate_move(target, target.position + Vector2(12, 0), movement, combat.combat_state).success, "Grabbed target must not be able to Move.", failures)

	combat.combat_state.current_actor_id = target.id
	target.strength = 100
	target.ap = 5
	var unarmed: AttackData = preload("res://data/attack/unarmed_attack.tres")
	var grabbed_attack := combat.attack_system.resolve_attack(target, actor, unarmed, true)
	var has_grab_penalty := false
	for source in grabbed_attack.to_hit_breakdown:
		if source.get("source") == "Grabbed" and int(source.get("amount", 0)) == -2:
			has_grab_penalty = true
	check(has_grab_penalty, "Grabbed attack breakdown should show a -2 penalty.", failures)
	var escaped := combat.execute_escape(target.id, "grabbed")
	check(escaped.success and not target.has_status("grabbed") and not actor.has_status("grabbing"), "Successful Escape should clear both linked Grab statuses.", failures)
	var freed_attack := combat.attack_system.resolve_attack(target, actor, unarmed, true)
	check(freed_attack.attack_modifier == grabbed_attack.attack_modifier + 2, "Escape should remove the -2 attack penalty.", failures)

	combat.combat_state.current_actor_id = actor.id
	actor.ap = 5
	target.position = Vector2(240, 120)
	var trip := combat.use_basic_maneuver(actor.id, target.id, ActionTypes.Maneuver.TRIP)
	check(trip.success and target.has_status("prone"), "Trip should apply Prone.", failures)
	var stand_target := combat.use_basic_maneuver(actor.id, "", ActionTypes.Maneuver.STAND)
	check(not stand_target.success, "Only the Prone combatant can Stand.", failures)
	combat.combat_state.current_actor_id = target.id
	target.ap = 2
	var stand := combat.use_basic_maneuver(target.id, "", ActionTypes.Maneuver.STAND)
	check(stand.success and not target.has_status("prone") and target.ap == 1, "Stand should remove Prone and cost 1 AP.", failures)

	combat.combat_state.current_actor_id = actor.id
	actor.ap = 5
	target.position = Vector2(240, 120)
	var push_origin := target.position
	var push := combat.use_basic_maneuver(actor.id, target.id, ActionTypes.Maneuver.PUSH)
	check(push.success and target.position.x > push_origin.x, "Push should move the target away from the actor.", failures)
	check(push_origin.distance_to(target.position) / 12.0 > 94.9, "Push distance should be STR modifier × 2 + 5 ft.", failures)

	target.position = Vector2(240, 120)
	target.collision_radius_feet = actor.collision_radius_feet * 4.0
	var ap_before := actor.ap
	var resisted := combat.use_basic_maneuver(actor.id, target.id, ActionTypes.Maneuver.TRIP)
	check(not resisted.success and actor.ap == ap_before, "A target two Size levels larger should resist Trip without spending AP.", failures)

	for failure in failures:
		push_error(failure)
	print("BASIC_MANEUVER_TEST: PASS" if failures.is_empty() else "BASIC_MANEUVER_TEST: FAIL")
	quit(0 if failures.is_empty() else 1)


func make_combatant(id: String, team: int, position: Vector2, strength: int) -> CombatantState:
	var combatant := CombatantState.new()
	combatant.id = id
	combatant.display_name = id.capitalize()
	combatant.team = team
	combatant.position = position
	combatant.strength = strength
	combatant.base_max_hp = 100
	combatant.hp = 100
	combatant.max_hp = 100
	combatant.base_max_ap = 5
	combatant.ap = 5
	combatant.max_ap = 5
	combatant.effective_max_ap = 5
	combatant.base_speed = 30.0
	combatant.speed = 30.0
	return combatant


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
