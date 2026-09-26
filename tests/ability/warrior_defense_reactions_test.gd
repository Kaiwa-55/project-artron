extends SceneTree

const Warrior = preload("res://data/class/warrior.tres")
const Catalog = preload("res://data/creation/default_creation_catalog.tres")
const Sword = preload("res://data/attack/sword.tres")
const Shortbow = preload("res://data/attack/shortbow.tres")

var failures: Array[String] = []


func _init() -> void:
	var data: CharacterData = load("res://data/character/player.tres").duplicate()
	data.character_class = Warrior
	var actor: CombatantState = data.create_combatant_state()
	actor.position = Vector2.ZERO
	var enemy: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	enemy.position = Vector2(60, 0)
	var system := CombatSystem.new()
	system.start_combat([actor, enemy])
	actor.ability_points = 3
	var progression := ProgressionSystem.new()
	for id in ["guarded_parry", "brace_for_impact", "tactical_retreat"]:
		var ability: AbilityData = Catalog.find_ability(id)
		check(ability != null and ability.required_level == 1 and not actor.granted_ability_ids.has(id), "%s is a selectable Level 1 Ability" % id)
		if ability != null:
			check(progression.learn_ability(actor, ability).success, "%s can be learned" % id)
	system.ability_system.sync_granted_reactions(actor)
	var parry = Catalog.find_ability("guarded_parry").granted_reactions[0]
	var brace = Catalog.find_ability("brace_for_impact").granted_reactions[0]
	var retreat = Catalog.find_ability("tactical_retreat").granted_reactions[0]
	var hit := AttackResult.new()
	hit.hit = true
	actor.ap = 10
	check(system.reaction_system.get_post_hit_prompt(enemy, actor, Sword, hit, 1).get("reactions", []).has(parry), "Guarded Parry is offered against a melee hit")
	check(not system.reaction_system.get_post_hit_prompt(enemy, actor, Shortbow, hit, 1).get("reactions", []).has(parry), "Guarded Parry excludes ranged hits")
	actor.active_reactions.erase(parry)
	var brace_prompt: Dictionary = system.reaction_system.get_ally_damage_reaction_prompt(enemy, actor, Sword, hit, system.combat_state)
	check(not brace_prompt.is_empty() and brace_prompt.get("reactions", []).has(brace), "Brace for Impact is offered when the Warrior is hit")
	var incoming: AttackData = Sword.duplicate()
	incoming.to_hit_bonus = 1000
	incoming.base_damage = 8
	incoming.ap_cost = 1
	system.combat_state.current_actor_id = enemy.id
	enemy.ap = 10
	var request := ActionRequest.new(enemy.id, ActionTypes.Type.ATTACK)
	request.target_id = actor.id
	request.attack_data = incoming
	var attack_result: ActionResult = system.execute_action(request)
	check(attack_result.requires_reaction_choice and attack_result.reaction_prompt.get("damage_intervention", false), "Brace for Impact opens a damage Reaction choice")
	if attack_result.requires_reaction_choice:
		var prepared: AttackResult = attack_result.reaction_prompt.get("prepared_attack")
		var ap_before: int = actor.ap
		system.resolve_pending_reaction(0)
		check(prepared.reaction_damage_reduction == 3 and actor.ap == ap_before - 1, "Brace for Impact reduces damage by 3 for 1 AP")
		check(actor.reaction_last_used_round.get(brace.id, 0) == system.combat_state.current_round, "Brace for Impact records its round use")
	actor.active_reactions.erase(brace)
	var retreat_result := ActionResult.success_result()
	system.reaction_resolver.offer_step_back(request, enemy, actor, retreat_result)
	check(retreat_result.requires_reaction_choice and retreat_result.reaction_prompt.get("reactions", []).has(retreat), "Tactical Retreat appears among post-attack movement choices")
	if retreat_result.requires_reaction_choice:
		var ap_before: int = actor.ap
		var index: int = retreat_result.reaction_prompt["reactions"].find(retreat)
		system.resolve_pending_reaction(index)
		check(system.has_pending_step_back_move() and system.step_back_move_distance_feet == 5.0 and actor.ap == ap_before, "Tactical Retreat offers a 5 ft move without AP")
	for failure in failures:
		push_error(failure)
	print("WARRIOR_DEFENSE_REACTIONS_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
