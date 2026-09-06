class_name ReactionSystem
extends RefCounted

const ReactionDataScript = preload("res://data/reaction/reaction_data.gd")
const ReactionEffectDataScript = preload("res://data/reaction/reaction_effect_data.gd")

var attack_system: AttackSystem
var action_system: ActionSystem
var map_rules


func _init(p_attack_system: AttackSystem, p_action_system: ActionSystem, p_map_rules) -> void:
	attack_system = p_attack_system
	action_system = p_action_system
	map_rules = p_map_rules


func resolve_interruptions(request: ActionRequest, combat_state: CombatState) -> ActionResult:
	var result := ActionResult.success_result()
	if request.action_type != ActionTypes.Type.MOVE:
		return result

	var moving_actor := combat_state.get_combatant(request.actor_id)
	if moving_actor == null:
		return result

	for reactor in combat_state.combatants.values():
		if reactor.is_dying() or reactor.team == moving_actor.team:
			continue
		for reaction in reactor.active_reactions:
			if reaction == null:
				continue
			if reactor.has_status("surprise") and reaction_has_trait(reaction, "reactive"):
				continue
			if not should_interrupt_movement(reaction, reactor, moving_actor, request.target_position):
				continue
			# Player-controlled Opportunity Attacks always wait for a choice. Enemy
			# reactions keep their current automatic behavior.
			if reactor.id == "player":
				result.requires_reaction_choice = true
				result.reaction_prompt = {
					"opportunity_choice": true,
					"reaction": reaction,
					"reactor": reactor,
					"attacker": moving_actor,
				}
				result.events.append(CombatEvent.new(EventTypes.Type.REACTION_AVAILABLE, reactor.id, moving_actor.id, {"reaction_name": reaction.display_name}))
				return result
			if not reaction.auto_resolve:
				continue
			var reaction_attack: AttackData = get_reaction_attack_data(reaction, reactor)
			var prepared: AttackResult = attack_system.resolve_attack(reactor, moving_actor, reaction_attack, true)
			if reaction_has_trait(reaction, "reactive"):
				reactor.remove_status("hidden")
			var defense_prompt: Dictionary = get_post_hit_prompt(reactor, moving_actor, reaction_attack, prepared)
			if not defense_prompt.is_empty():
				defense_prompt["opportunity_attack"] = true
				result.requires_reaction_choice = true
				result.reaction_prompt = defense_prompt
				for available_reaction in defense_prompt["reactions"]:
					result.events.append(CombatEvent.new(
						EventTypes.Type.REACTION_AVAILABLE,
						defense_prompt["reactor"].id,
						reactor.id,
						{"reaction_name": available_reaction.display_name}
					))
				return result
			attack_system.finalize_attack(reactor, moving_actor, reaction_attack, prepared)
			result.events.append_array(action_system.build_attack_result(reactor, moving_actor, reaction_attack, prepared).events)
			if moving_actor.is_dying():
				result.success = false
				result.failure_reason = "Movement was interrupted because the actor is Dying."
				return result
	return result


# Collect first, resolve later. This prevents a player prompt from causing
# reactions belonging to later combatants to be skipped.
func collect_interruptions(request: ActionRequest, combat_state: CombatState) -> Array[Dictionary]:
	var queue: Array[Dictionary] = []
	if request == null or request.action_type != ActionTypes.Type.MOVE:
		return queue
	var moving_actor := combat_state.get_combatant(request.actor_id)
	if moving_actor == null:
		return queue
	for reactor_id in combat_state.turn_order:
		var reactor = combat_state.get_combatant(reactor_id)
		if reactor == null or reactor.is_dying() or reactor.team == moving_actor.team:
			continue
		for reaction in reactor.active_reactions:
			if reaction == null:
				continue
			if reactor.has_status("surprise") and reaction_has_trait(reaction, "reactive"):
				continue
			if should_interrupt_movement(reaction, reactor, moving_actor, request.target_position):
				queue.append({"reaction": reaction, "reactor": reactor, "trigger_actor": moving_actor})
	return queue


func get_player_reaction_prompt(request: ActionRequest, combat_state: CombatState) -> Dictionary:
	if request.action_type != ActionTypes.Type.ATTACK:
		return {}

	var attacker := combat_state.get_combatant(request.actor_id)
	var target := combat_state.get_combatant(request.target_id)
	return get_player_reaction_prompt_for_attack(attacker, target)


func get_player_reaction_prompt_for_attack(attacker, target) -> Dictionary:
	if attacker == null or target == null or target.is_dying() or attacker.team == target.team:
		return {}
	# Player-facing choices are deliberately limited to the player's character.
	if target.id != "player":
		return {}

	for reaction in target.active_reactions:
		if reaction == null or reaction.auto_resolve:
			continue
		if target.has_status("surprise") and reaction_has_trait(reaction, "reactive"):
			continue
		if reaction.trigger != ReactionDataScript.Trigger.ENEMY_ATTACKS_SELF:
			continue
		if get_effect(reaction, ReactionEffectDataScript.Type.DEFENSE_BONUS) == null:
			continue
		if target.ap < reaction.ap_cost:
			continue
		return {
			"reaction": reaction,
			"reactor": target,
			"attacker": attacker
		}
	return {}


func get_post_hit_prompt(attacker, target, attack: AttackData, attack_result, current_round: int = 0) -> Dictionary:
	if attacker == null or target == null or not attack_result.hit:
		return {}
	var available_reactions: Array = []
	for reaction in target.active_reactions:
		if reaction == null or (reaction.auto_resolve and target.id == "player"):
			continue
		if target.has_status("surprise") and reaction_has_trait(reaction, "reactive"):
			continue
		if reaction.trigger != ReactionDataScript.Trigger.ENEMY_ATTACKS_SELF:
			continue
		if target.ap < reaction.ap_cost or (reaction.required_trait_id != "" and not has_trait(target, reaction.required_trait_id)):
			continue
		if reaction.uses_per_round > 0 and current_round > 0 and int(target.reaction_last_used_round.get(reaction.id, 0)) == current_round:
			continue
		if reaction.melee_only and not attack_has_melee_trait(attack):
			continue
		var defense_effect = get_effect(reaction, ReactionEffectDataScript.Type.DEFENSE_BONUS)
		var miss_effect = get_effect(reaction, ReactionEffectDataScript.Type.TURN_HIT_TO_MISS)
		var movement_effect = get_effect(reaction, ReactionEffectDataScript.Type.MOVEMENT)
		if defense_effect != null:
			# Parry is available whenever the incoming attack hits. The player
			# may still choose it even when its bonus will not turn the hit into a miss.
			pass
		elif miss_effect != null:
			# Martial Sense starts at Defense + 1. Its configured maximum
			# decides how much farther above Defense the reaction can stop.
			if attack_result.margin < miss_effect.minimum_margin or attack_result.margin > miss_effect.maximum_margin:
				continue
		elif movement_effect == null:
			continue
		available_reactions.append(reaction)
	if available_reactions.is_empty():
		return {}
	return {
		"reactions": available_reactions,
		"reactor": target,
		"attacker": attacker,
		"prepared_attack": attack_result,
		"prepared_attack_data": attack
	}


func get_ally_damage_reaction_prompt(attacker, target, attack: AttackData, attack_result, combat_state: CombatState) -> Dictionary:
	if attacker == null or target == null or attack == null or attack_result == null or not attack_result.hit:
		return {}
	for reactor_id in combat_state.turn_order:
		var reactor: CombatantState = combat_state.get_combatant(reactor_id)
		if reactor == null or reactor.is_dying() or reactor.team != target.team:
			continue
		for reaction in reactor.active_reactions:
			if reaction == null or reaction.trigger != ReactionDataScript.Trigger.ALLY_ATTACKED:
				continue
			if not reaction.can_target_self and reactor == target:
				continue
			if reactor.has_status("surprise") and reaction_has_trait(reaction, "reactive"):
				continue
			if reactor.ap < reaction.ap_cost or reactor.get_total_faith() < reaction.faith_cost:
				continue
			if reaction.required_trait_id != "" and not has_trait(reactor, reaction.required_trait_id):
				continue
			if map_rules.get_edge_distance_world_units(reactor, target) > reaction.reach_feet * map_rules.world_units_per_foot:
				continue
			if reaction.requires_line_of_sight and not map_rules.has_line_of_sight(reactor.position, target.position):
				continue
			if get_effect(reaction, ReactionEffectDataScript.Type.DAMAGE_MODIFIER) == null:
				continue
			return {
				"damage_intervention": true,
				"reactions": [reaction],
				"reactor": reactor,
				"attacker": attacker,
				"attack_target": target,
				"prepared_attack": attack_result,
				"prepared_attack_data": attack,
			}
	return {}


func get_post_attack_reactions(attacker, target, current_round: int) -> Array:
	var available: Array = []
	if attacker == null or target == null or attacker.team == target.team or target.is_dying():
		return available
	for reaction in target.active_reactions:
		if reaction == null or reaction.trigger != ReactionDataScript.Trigger.AFTER_ENEMY_ATTACKS_SELF:
			continue
		if target.has_status("surprise") and reaction_has_trait(reaction, "reactive"):
			continue
		if target.ap < reaction.ap_cost:
			continue
		if reaction.uses_per_round > 0 and int(target.reaction_last_used_round.get(reaction.id, 0)) == current_round:
			continue
		available.append(reaction)
	return available


func get_post_ranged_hit_reactions(attacker, attack: AttackData, attack_hit: bool) -> Array:
	var available: Array = []
	if attacker == null or not attack_hit or not attack_has_trait(attack, "ranged"):
		return available
	for reaction in attacker.active_reactions:
		if reaction == null or reaction.trigger != ReactionDataScript.Trigger.AFTER_SELF_RANGED_ATTACK_HIT:
			continue
		if attacker.has_status("surprise") and reaction_has_trait(reaction, "reactive"):
			continue
		if attacker.ap < reaction.ap_cost or int(attacker.ability_uses_this_turn.get(reaction.id, 0)) >= 1:
			continue
		if reaction.required_trait_id != "" and not has_trait(attacker, reaction.required_trait_id):
			continue
		available.append(reaction)
	return available


func get_effect(reaction, effect_type: int):
	if reaction == null:
		return null
	for effect in reaction.effects:
		if effect != null and effect.effect_type == effect_type:
			return effect
	return null


func get_defense_bonus(reaction) -> int:
	var effect = get_effect(reaction, ReactionEffectDataScript.Type.DEFENSE_BONUS)
	return effect.amount if effect != null else 0


func has_trait(combatant, trait_id: String) -> bool:
	for trait_data in combatant.active_traits:
		if trait_data != null and trait_data.id == trait_id:
			return true
	return false


func reaction_has_trait(reaction, trait_id: String) -> bool:
	if reaction == null:
		return false
	for trait_data in reaction.traits:
		if trait_data != null and trait_data.id == trait_id:
			return true
	return false


func attack_has_melee_trait(attack: AttackData) -> bool:
	return attack_has_trait(attack, "melee")


func attack_has_trait(attack: AttackData, trait_id: String) -> bool:
	for trait_data in attack.traits:
		if trait_data != null and trait_data.id == trait_id:
			return true
	return false


func should_interrupt_movement(reaction, reactor, moving_actor, destination: Vector2) -> bool:
	if reaction.trigger != ReactionDataScript.Trigger.ENEMY_LEAVES_REACH:
		return false
	if reactor.ap < reaction.ap_cost:
		return false
	if reaction.required_trait_id != "" and not has_trait(reactor, reaction.required_trait_id):
		return false
	var movement_effect = get_effect(reaction, ReactionEffectDataScript.Type.MOVEMENT)
	var attack: AttackData = get_reaction_attack_data(reaction, reactor)
	if attack == null and movement_effect == null:
		return false
	for required_trait_id in reaction.required_weapon_trait_ids:
		if attack == null or not attack_has_trait(attack, required_trait_id):
			return false
	var reach_feet: float = attack.range_feet if attack != null and reaction.attack_source == ReactionDataScript.AttackSource.EQUIPPED_WEAPON else reaction.reach_feet
	var reach_world_units: float = reach_feet * map_rules.world_units_per_foot
	var combined_radii: float = map_rules.get_combatant_radius_world_units(reactor) + map_rules.get_combatant_radius_world_units(moving_actor)
	var origin_distance: float = maxf(0.0, reactor.position.distance_to(moving_actor.position) - combined_radii)
	var destination_distance: float = maxf(0.0, reactor.position.distance_to(destination) - combined_radii)
	return origin_distance <= reach_world_units and destination_distance > reach_world_units


func resolve_reaction(result: ActionResult, reaction, reactor, target) -> void:
	if reaction_has_trait(reaction, "reactive"):
		reactor.remove_status("hidden")
	result.events.append(
		CombatEvent.new(
			EventTypes.Type.INTERRUPTION_STARTED,
			reactor.id,
			target.id,
			{"reaction_name": reaction.display_name}
		)
	)
	var attack: AttackData = get_reaction_attack_data(reaction, reactor)
	var validation := attack_system.validate_attack(reactor, target, attack)
	if validation.success:
		var attack_result := attack_system.resolve_attack(reactor, target, attack)
		var attack_action_result := action_system.build_attack_result(reactor, target, attack, attack_result)
		result.events.append_array(attack_action_result.events)
		result.events.append(
			CombatEvent.new(
				EventTypes.Type.REACTION_TRIGGERED,
				reactor.id,
				target.id,
				{"reaction_name": reaction.display_name}
			)
		)
	result.events.append(
		CombatEvent.new(
			EventTypes.Type.INTERRUPTION_ENDED,
			reactor.id,
			target.id,
			{"reaction_name": reaction.display_name}
		)
	)


func get_reaction_attack_data(reaction, reactor) -> AttackData:
	if reaction == null or reactor == null:
		return null
	var attack_source: int = reaction.attack_source
	var configured_attack: AttackData = reaction.attack_data
	var attack_effect = get_effect(reaction, ReactionEffectDataScript.Type.ATTACK)
	if attack_effect != null:
		attack_source = attack_effect.attack_source
		if attack_effect.attack_data != null:
			configured_attack = attack_effect.attack_data
	if attack_source == ReactionDataScript.AttackSource.EQUIPPED_WEAPON:
		return reactor.equipped_weapon_attack
	return configured_attack
