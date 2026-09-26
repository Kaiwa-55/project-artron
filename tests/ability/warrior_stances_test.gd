extends SceneTree

const Warrior = preload("res://data/class/warrior.tres")
const Catalog = preload("res://data/creation/default_creation_catalog.tres")
const Sword = preload("res://data/attack/sword.tres")

var failures: Array[String] = []


func _init() -> void:
	var names := ["opening_strike", "relentless_pursuit", "sweeping_assault", "shield_brace", "interpose", "hold_the_line", "evasive_step", "riposte_rhythm", "duels_end"]
	for name in names:
		var ability = load("res://data/ability/%s.tres" % name)
		check(ability != null and Catalog.abilities.has(ability), "%s is selectable" % name)
	var data: CharacterData = load("res://data/character/player.tres").duplicate()
	data.character_class = Warrior
	var actor: CombatantState = data.create_combatant_state()
	var enemy: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	var system := CombatSystem.new()
	system.start_combat([actor, enemy])
	for stance_id in ["assault_stance", "bulwark_stance", "duelist_stance"]:
		check(actor.granted_ability_ids.has(stance_id) and actor.equipped_abilities.has(stance_id), "%s is granted" % stance_id)
	actor.ap = actor.max_ap
	system.combat_state.current_actor_id = actor.id
	var opening = load("res://data/ability/opening_strike.tres")
	check(not system.ability_system.validate_active_use(actor, opening, enemy).success, "Opening Strike requires Assault Stance")
	check(system.use_active_ability(actor.id, actor.id, "assault_stance").success, "Assault Stance activates")
	check(system.ability_system.stance_matches(actor, opening), "Opening Strike unlocks in Assault Stance")
	var pursuit = load("res://data/ability/relentless_pursuit.tres")
	actor.level = 2
	actor.available_abilities.append(pursuit)
	actor.equipped_abilities.append(pursuit.id)
	check(system.ability_system.get_on_kill_movement(actor).get("distance_feet", 0.0) == 5.0, "Relentless Pursuit offers a free 5 ft move")
	actor.ability_uses_this_turn[pursuit.id] = 1
	check(system.ability_system.get_on_kill_movement(actor).is_empty(), "Relentless Pursuit is limited to once per turn")
	check(system.ability_system.validate_active_use(actor, load("res://data/ability/duelist_stance.tres"), actor).success, "Warrior can switch stances")
	actor.ap = actor.max_ap
	check(system.use_active_ability(actor.id, actor.id, "duelist_stance").success and not actor.has_status("assault_stance") and actor.has_status("duelist_stance"), "Switching replaces the previous stance")
	var evasive = load("res://data/ability/evasive_step.tres")
	actor.available_abilities.append(evasive)
	actor.equipped_abilities.append(evasive.id)
	system.ability_system.sync_granted_reactions(actor)
	var miss := AttackResult.new()
	miss.hit = false
	var misses: Array = system.reaction_system.get_miss_counter_reactions(enemy, actor, Sword, miss, system.combat_state.current_round)
	var evasion = evasive.granted_reactions[0]
	check(misses.has(evasion), "A missed melee attack offers Evasive Step in Duelist Stance")
	var move_result := ActionResult.success_result()
	system.reaction_resolver.resolve_counterattack(actor, enemy, evasion, move_result)
	check(system.has_pending_step_back_move() and system.reaction_resolver.move_distance_feet == 10.0, "Evasive Step opens a 10 ft move")
	system.reaction_resolver.cancel_move()
	var riposte = load("res://data/ability/riposte_rhythm.tres")
	actor.level = 2
	actor.available_abilities.append(riposte)
	actor.equipped_abilities.append(riposte.id)
	var damage_bonuses: Array[Dictionary] = system.ability_system.get_conditional_damage_bonuses(actor, enemy, Sword, system.combat_state.current_round)
	check(damage_bonuses.any(func(bonus): return bonus.get("source") == "Riposte Rhythm" and bonus.get("amount") == 2), "Evasive Step enables Riposte Rhythm")
	actor.ap = actor.max_ap
	check(system.use_active_ability(actor.id, actor.id, "bulwark_stance").success, "Bulwark Stance activates")
	check(not system.ability_system.get_conditional_damage_bonuses(actor, enemy, Sword, system.combat_state.current_round).any(func(bonus): return bonus.get("source") == "Riposte Rhythm"), "Riposte Rhythm stops outside Duelist Stance")
	var brace = load("res://data/ability/shield_brace.tres")
	actor.available_abilities.append(brace)
	actor.equipped_abilities.append(brace.id)
	actor.equipped_items.erase(2)
	check(not system.ability_system.validate_active_use(actor, brace, actor).success, "Shield Brace requires a shield")
	actor.equipped_items[2] = load("res://data/equipment/buckler.tres")
	check(system.ability_system.validate_active_use(actor, brace, actor).success, "Shield Brace works with a shield")
	check(load("res://data/ability/interpose.tres").granted_reactions[0].reach_feet == 5.0, "Interpose reaches 5 ft")
	check(load("res://data/ability/evasive_step.tres").granted_reactions[0].effects[0].distance_feet == 10.0, "Evasive Step moves 10 ft")
	check(load("res://data/ability/sweeping_assault.tres").max_area_targets == 2, "Sweeping Assault hits at most two enemies")
	var duels_end = load("res://data/ability/duels_end.tres")
	enemy.hp = enemy.max_hp
	check(system.active_ability_executor.get_active_damage_bonus(actor, enemy, duels_end) == 0, "Duel's End has no bonus above half HP")
	enemy.hp = enemy.max_hp / 2
	check(system.active_ability_executor.get_active_damage_bonus(actor, enemy, duels_end) == 4, "Duel's End gains +4 damage at half HP")
	var hit_events: Array[CombatEvent] = [CombatEvent.new(EventTypes.Type.ATTACK_HIT, actor.id, enemy.id)]
	var extra_events: Array[CombatEvent] = []
	system.active_ability_executor.apply_effects(actor, enemy, opening, hit_events, extra_events)
	check(actor.next_attack_target_id == enemy.id and actor.next_attack_to_hit_bonus == 1, "Opening Strike marks the hit target")
	var other_target: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	other_target.id = "other_target"
	system.ability_system.get_to_hit_bonus(actor, Sword, 5.0, other_target)
	check(actor.next_attack_target_id == enemy.id, "Attacking another target preserves the Opening Strike mark")
	check(system.ability_system.get_to_hit_bonus(actor, Sword, 5.0, enemy) >= 1 and actor.next_attack_target_id.is_empty(), "Opening Strike bonus applies once")
	for failure in failures:
		push_error(failure)
	print("WARRIOR_STANCES_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
