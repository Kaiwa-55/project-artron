extends SceneTree

const RedirectForce = preload("res://data/reaction/redirect_force_reaction.tres")
const MeleeTrait = preload("res://data/trait/melee.tres")
const MartialArtistClass = preload("res://data/class/martial_artist.tres")

var failures: Array[String] = []


func _init() -> void:
	var character = load("res://data/character/player.tres").duplicate(true)
	character.character_class = MartialArtistClass
	character.level = 3
	var defender: CombatantState = character.create_combatant_state()
	var attacker: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	defender.position = Vector2(100, 100)
	attacker.position = Vector2(0, 100)
	var system := CombatSystem.new()
	system.start_combat([attacker, defender])
	defender.active_reactions = [RedirectForce]
	defender.ap = 3
	system.combat_state.current_actor_id = attacker.id

	var attack := AttackData.new()
	attack.id = "redirect_force_test_attack"
	attack.display_name = "Melee Test Attack"
	attack.ap_cost = 0
	attack.base_damage = 1
	attack.range_feet = 5.0
	attack.traits = [MeleeTrait]
	var prepared := make_prepared_attack(2)
	var prompt: Dictionary = system.reaction_system.get_post_hit_prompt(attacker, defender, attack, prepared, system.combat_state.current_round)
	check(not prompt.is_empty(), "Redirect Force should trigger on a Melee Hit with Margin 2", failures)
	check(system.reaction_system.get_post_hit_prompt(attacker, defender, attack, make_prepared_attack(3), system.combat_state.current_round).is_empty(), "Redirect Force should not trigger above Margin 2", failures)
	var ranged_attack := attack.duplicate()
	ranged_attack.traits = []
	check(system.reaction_system.get_post_hit_prompt(attacker, defender, ranged_attack, make_prepared_attack(1), system.combat_state.current_round).is_empty(), "Redirect Force should require a Melee Attack", failures)

	var request := ActionRequest.new(attacker.id, ActionTypes.Type.ATTACK)
	request.target_id = defender.id
	request.attack_data = attack
	check(system.open_reaction_prompt(request, prompt), "Redirect Force prompt should enter the Reaction stack", failures)
	var accepted := system.resolve_pending_reaction(0)
	check(accepted.success and system.has_pending_step_back_move(), "Accepting Redirect Force should wait for a movement destination", failures)
	check(defender.ap == 2, "Accepting Redirect Force should immediately spend 1 AP", failures)
	check(int(defender.reaction_last_used_round.get(RedirectForce.id, 0)) == system.combat_state.current_round, "Accepting Redirect Force should immediately consume its Round limit", failures)
	var origin := defender.position
	var moved := system.execute_step_back_move(origin + Vector2.RIGHT * 9999.0)
	check(moved.success and not system.has_pending_step_back_move(), "A valid Redirect Force movement should resume the pending Attack", failures)
	check(is_equal_approx(origin.distance_to(defender.position) / system.map_rules.world_units_per_foot, 5.0), "Redirect Force movement should clamp to 5 ft", failures)
	check(moved.events.any(func(event): return event.type == EventTypes.Type.ATTACK_MISS), "Leaving the prepared Attack's range should turn it into a Miss", failures)

	# Invalid movement keeps the choice pending; cancelling then resolves the
	# original Hit without refunding AP or the once-per-Round use.
	system.combat_state.current_round += 1
	defender.position = Vector2(100, 100)
	defender.ap = 3
	prepared = make_prepared_attack(1)
	prompt = system.reaction_system.get_post_hit_prompt(attacker, defender, attack, prepared, system.combat_state.current_round)
	check(system.open_reaction_prompt(request, prompt), "Redirect Force should become available next Round", failures)
	system.resolve_pending_reaction(0)
	system.map_rules.add_circular_obstacle(Vector2(130, 100), 20.0, "Blocking Stone")
	var blocked := system.execute_step_back_move(Vector2(160, 100))
	check(not blocked.success and system.has_pending_step_back_move(), "A blocked path should keep Redirect Force waiting for another destination", failures)
	var cancelled := system.cancel_step_back_move()
	check(cancelled.success and not system.has_pending_step_back_move(), "Cancelling movement should resume and finish the original Attack", failures)
	check(cancelled.events.any(func(event): return event.type == EventTypes.Type.ATTACK_HIT), "Cancelling movement should leave the original Hit unchanged", failures)
	check(defender.ap == 2 and int(defender.reaction_last_used_round.get(RedirectForce.id, 0)) == system.combat_state.current_round, "Cancelling movement should not refund AP or the Round limit", failures)

	if failures.is_empty():
		print("REDIRECT_FORCE_TEST: PASS")
		quit(0)
	for failure in failures:
		push_error(failure)
	quit(1)


func make_prepared_attack(margin: int) -> AttackResult:
	var result := AttackResult.new()
	result.hit = true
	result.deferred = true
	result.roll = 10 + margin
	result.attack_modifier = 0
	result.defense = 10
	result.original_defense = 10
	result.margin = margin
	return result


func check(condition: bool, message: String, output: Array[String]) -> void:
	if not condition:
		output.append(message)
