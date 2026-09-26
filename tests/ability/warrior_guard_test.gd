extends SceneTree

const Warrior = preload("res://data/class/warrior.tres")
const Interpose = preload("res://data/ability/interpose.tres")
const HoldTheLine = preload("res://data/ability/hold_the_line.tres")
const Sword = preload("res://data/attack/sword.tres")

var failures: Array[String] = []


func _init() -> void:
	var data: CharacterData = load("res://data/character/player.tres").duplicate()
	data.character_class = Warrior
	var actor: CombatantState = data.create_combatant_state()
	actor.level = 3
	actor.position = Vector2.ZERO
	actor.equipped_items[2] = load("res://data/equipment/buckler.tres")
	actor.available_abilities.append(Interpose)
	actor.equipped_abilities.append(Interpose.id)
	actor.available_abilities.append(HoldTheLine)
	actor.equipped_abilities.append(HoldTheLine.id)
	var ally: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	ally.id = "ally"
	ally.team = actor.team
	ally.position = Vector2(60, 0)
	var enemy: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	enemy.position = Vector2(120, 0)
	var system := CombatSystem.new()
	system.start_combat([actor, ally, enemy])
	system.combat_state.current_actor_id = actor.id
	actor.ap = 10
	check(system.use_active_ability(actor.id, actor.id, "bulwark_stance").success, "Bulwark Stance starts")
	system.ability_system.sync_granted_reactions(actor)
	var hit := AttackResult.new()
	hit.hit = true
	var prompt: Dictionary = system.reaction_system.get_ally_damage_reaction_prompt(enemy, ally, Sword, hit, system.combat_state)
	check(not prompt.is_empty() and prompt.get("reactor") == actor and prompt["reactions"].has(Interpose.granted_reactions[0]), "Interpose protects an ally within 5 ft")
	system.combat_state.current_actor_id = enemy.id
	enemy.ap = 10
	var incoming: AttackData = Sword.duplicate()
	incoming.to_hit_bonus = 1000
	incoming.ap_cost = 1
	var wound := EffectData.new()
	wound.id = "interpose_test_wound"
	wound.display_name = "Interpose Test Wound"
	incoming.effects_on_hit.append(wound)
	var ally_hp_before: int = ally.hp
	var actor_hp_before: int = actor.hp
	var request := ActionRequest.new(enemy.id, ActionTypes.Type.ATTACK)
	request.target_id = ally.id
	request.attack_data = incoming
	var attack_result: ActionResult = system.execute_action(request)
	check(attack_result.requires_reaction_choice and attack_result.reaction_prompt.get("damage_intervention", false), "Interpose is offered when the ally is hit")
	if attack_result.requires_reaction_choice and attack_result.reaction_prompt.get("damage_intervention", false):
		var ap_before: int = actor.ap
		system.resolve_pending_reaction(0)
		check(ally.hp == ally_hp_before and actor.hp < actor_hp_before and actor.ap == ap_before - 1, "Interpose redirects damage for 1 AP")
		check(actor.has_status(wound.id) and not ally.has_status(wound.id), "Interpose redirects on-hit effects")
	system.combat_state.current_actor_id = actor.id
	actor.ap = 10
	check(system.use_active_ability(actor.id, actor.id, HoldTheLine.id).success, "Hold the Line activates")
	check(system.ability_system.get_passive_defense_bonus(ally) == 2, "Hold the Line grants +2 Defense nearby")
	ally.position = Vector2(180, 0)
	check(system.reaction_system.get_ally_damage_reaction_prompt(enemy, ally, Sword, hit, system.combat_state).is_empty(), "Interpose does not reach beyond 5 ft")
	check(system.ability_system.get_passive_defense_bonus(ally) == 0, "Hold the Line does not reach beyond 5 ft")
	for failure in failures:
		push_error(failure)
	print("WARRIOR_GUARD_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
