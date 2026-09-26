extends SceneTree

const Catalog = preload("res://data/creation/default_creation_catalog.tres")
const ArcaneShield = preload("res://data/skill/arcane_shield.tres")
const Training = preload("res://data/ability/Spell Training/spell_training_arcane_shield.tres")
const Sword = preload("res://data/attack/sword.tres")

var failures: Array[String] = []


func _init() -> void:
	check(Catalog.abilities.has(Training) and Training.granted_skills.has(ArcaneShield), "Arcane Shield is a selectable Level 1 Arcane spell")
	check(ProgressionSystem.new().spell_training_matches_grantor(Training, load("res://data/ability/arcane_mind.tres")), "Arcane Mind can choose Arcane Shield")
	var data: CharacterData = load("res://data/character/player.tres").duplicate()
	data.character_class = load("res://data/class/arcanist.tres")
	var caster: CombatantState = data.create_combatant_state()
	caster.available_skills.append(ArcaneShield)
	var enemy: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	var system := CombatSystem.new()
	system.start_combat([caster, enemy])
	system.ability_system.sync_granted_reactions(caster)
	var shield_reaction: ReactionData = ArcaneShield.granted_reactions[0]
	check(system.ability_system.has_reaction(caster, shield_reaction.id), "Learning Arcane Shield grants its defensive Reaction")
	system.combat_state.current_actor_id = caster.id
	caster.ap = 5
	caster.mana = 5
	var incoming_hit := AttackResult.new()
	incoming_hit.hit = true
	check(system.reaction_system.get_post_hit_prompt(enemy, caster, Sword, incoming_hit, system.combat_state.current_round).get("reactions", []).has(shield_reaction), "Arcane Shield can respond to a hit")
	var request := ActionRequest.new(caster.id, ActionTypes.Type.SKILL)
	request.target_id = caster.id
	request.skill_data = ArcaneShield
	var ap_before: int = caster.ap
	var mana_before: int = caster.mana
	var result: ActionResult = system.execute_action(request)
	check(result.success and caster.has_status("arcane_shield"), "Arcane Shield applies without an attack roll")
	check(caster.ap == ap_before - 1 and caster.mana == mana_before - 2, "Arcane Shield costs 1 AP and 2 Mana")
	check(system.effect_system.get_reflex_bonus(caster) == 2 and system.effect_system.get_fortitude_bonus(caster) == 2 and system.effect_system.get_will_bonus(caster) == 2, "Shield grants +2 to all defenses")
	check(system.skill_system.get_remaining_cooldown(caster, ArcaneShield.id) == 2 and not system.action_system.validate(request, system.combat_state).success, "Shield cannot be recast during cooldown")
	check(not system.reaction_system.get_post_hit_prompt(enemy, caster, Sword, incoming_hit, system.combat_state.current_round).get("reactions", []).has(shield_reaction), "Active cast blocks the Reaction during shared cooldown")
	system.effect_system.expire_start_turn_effects(caster)
	check(not caster.has_status("arcane_shield") and system.effect_system.get_reflex_bonus(caster) == 0, "Shield expires at the start of the next turn")
	system.skill_system.set_remaining_cooldown(caster, ArcaneShield.id, 0)
	caster.mana = 1
	check(not system.reaction_system.get_post_hit_prompt(enemy, caster, Sword, incoming_hit, system.combat_state.current_round).get("reactions", []).has(shield_reaction), "Reaction is unavailable without enough Mana")
	caster.mana = 5
	caster.max_hp = 100
	caster.hp = 100
	enemy.position = caster.position + Vector2(60, 0)
	enemy.ap = 5
	system.combat_state.current_actor_id = enemy.id
	var incoming: AttackData = Sword.duplicate()
	incoming.to_hit_bonus = 1000
	var enemy_attack := ActionRequest.new(enemy.id, ActionTypes.Type.ATTACK)
	enemy_attack.target_id = caster.id
	enemy_attack.attack_data = incoming
	var hit_result: ActionResult = system.execute_action(enemy_attack)
	check(hit_result.requires_reaction_choice and hit_result.reaction_prompt.get("reactions", []).has(shield_reaction), "Enemy hit offers Arcane Shield as a Reaction")
	if hit_result.requires_reaction_choice:
		var prepared: AttackResult = hit_result.reaction_prompt.get("prepared_attack")
		var reaction_index: int = hit_result.reaction_prompt["reactions"].find(shield_reaction)
		var mana_before_reaction: int = caster.mana
		var ap_before_reaction: int = caster.ap
		system.resolve_pending_reaction(reaction_index)
		check(prepared.defense == prepared.original_defense + 2, "Arcane Shield raises Defense by 2 against the triggering attack")
		check(caster.mana == mana_before_reaction - 2 and caster.ap == ap_before_reaction, "Reaction spends 2 Mana and no AP")
		check(system.skill_system.get_remaining_cooldown(caster, ArcaneShield.id) == 2, "Reaction starts the same Skill cooldown")
	caster.available_skills.erase(ArcaneShield)
	system.ability_system.sync_granted_reactions(caster)
	check(not system.ability_system.has_reaction(caster, shield_reaction.id), "Removing the Skill also removes its Reaction")
	for failure in failures:
		push_error(failure)
	print("ARCANE_SHIELD_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
