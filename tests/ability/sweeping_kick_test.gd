extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var actor: CombatantState = load("res://data/character/player.tres").create_combatant_state()
	var enemy_a: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	var enemy_b: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	var enemy_outside: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	actor.position = Vector2.ZERO
	enemy_a.position = Vector2(60, 0)
	enemy_b.id = "enemy_b"
	enemy_b.position = Vector2(-60, 0)
	enemy_outside.id = "enemy_outside"
	enemy_outside.position = Vector2(180, 0)
	for enemy in [enemy_a, enemy_b, enemy_outside]:
		enemy.active_reactions.clear()

	actor.level = 3
	var ability: AbilityData = load("res://data/ability/sweeping_kick.tres").duplicate(true)
	ability.required_trait_ids.clear()
	ability.attack_data = ability.attack_data.duplicate(true)
	ability.attack_data.requires_to_hit = false
	actor.available_abilities.append(ability)
	actor.equipped_abilities.append(ability.id)

	var system := CombatSystem.new()
	system.start_combat([actor, enemy_a, enemy_b, enemy_outside])
	system.combat_state.current_actor_id = actor.id
	actor.ap = 10
	var ap_before := actor.ap
	var hp_a := enemy_a.hp
	var hp_b := enemy_b.hp
	var hp_outside := enemy_outside.hp
	var result := system.use_active_ability(actor.id, actor.id, ability.id)

	check(result.success, "Sweeping Kick should resolve immediately as a self-centered Area Ability", failures)
	check(actor.ap == ap_before - 2, "Sweeping Kick should spend 2 AP once", failures)
	check(system.ability_system.get_remaining_cooldown(actor, ability.id) == 2, "Sweeping Kick should start a 2-turn cooldown", failures)
	check(enemy_a.hp < hp_a and enemy_b.hp < hp_b, "Every enemy in the 5-foot Area should take Unarmed damage", failures)
	check(enemy_outside.hp == hp_outside, "Enemies outside the Area should not take damage", failures)
	for target_id in [enemy_a.id, enemy_b.id]:
		var damage_events := result.events.filter(func(event): return event.type == EventTypes.Type.DAMAGE_APPLIED and event.target_id == target_id)
		check(damage_events.size() == 1, "Each target should receive damage exactly once", failures)

	var defense_target := CombatantState.new()
	defense_target.reflex = 7
	defense_target.fortitude = 11
	check(system.defense_system.get_defense(defense_target, DefenseTypes.Type.HIGHEST_REFLEX_FORTITUDE) == 11, "Sweeping Kick should challenge the higher of Reflex and Fortitude", failures)

	if failures.is_empty():
		print("SWEEPING_KICK_TEST: PASS")
		quit(0)
	for failure in failures:
		push_error(failure)
	quit(1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
