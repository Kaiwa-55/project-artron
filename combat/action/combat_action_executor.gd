class_name CombatActionExecutor
extends RefCounted

const SkillDataScript = preload("res://data/skill/skill_data.gd")

var combat_system


func _init(p_combat_system) -> void:
	combat_system = p_combat_system


func execute(
	request: ActionRequest
) -> ActionResult:

	if combat_system.combat_state == null:
		return ActionResult.failure(
			"Combat has not started."
		)
	if combat_system.combat_state.is_finished():
		return ActionResult.failure("Combat has already ended.")
	if combat_system.has_pending_reaction():
		return ActionResult.failure("Choose whether to use the pending reaction first.")
	if combat_system.has_pending_ability_movement():
		return ActionResult.failure("Choose the pending Ability movement destination first.")
	# Invalid movement must not trigger an Opportunity Attack. Otherwise the
	# reaction window opens first and the original Move silently fails afterward.
	if request.action_type == ActionTypes.Type.MOVE:
		request.target_position = combat_system.movement_system.clamp_destination_to_remaining_speed(
			combat_system.combat_state.get_combatant(request.actor_id),
			request.target_position,
			request.movement_data
		)
		var move_validation: ActionResult = combat_system.action_system.validate(request, combat_system.combat_state)
		if not move_validation.success:
			return move_validation

	if request.action_type == ActionTypes.Type.MOVE:
		combat_system.pending_reaction_queue = combat_system.reaction_system.collect_interruptions(request, combat_system.combat_state)
		if not combat_system.pending_reaction_queue.is_empty():
			combat_system.pending_action = request
			return combat_system.continue_reaction_queue()
	if request.action_type == ActionTypes.Type.ATTACK:
		var unarmed_validation: ActionResult = combat_system.equipment_system.validate_unarmed_attack(combat_system.combat_state.get_combatant(request.actor_id), request.attack_data)
		if not unarmed_validation.success:
			return unarmed_validation
		if request.attack_data != null and request.attack_data.thrown_item != null:
			var throw_validation: ActionResult = combat_system.equipment_system.validate_throw(combat_system.combat_state.get_combatant(request.actor_id), request.attack_data)
			if not throw_validation.success:
				return throw_validation
		@warning_ignore("confusable_local_declaration")
		var validation: ActionResult = combat_system.action_system.validate(request, combat_system.combat_state)
		if not validation.success:
			return validation
		var attacker: CombatantState = combat_system.combat_state.get_combatant(request.actor_id)
		combat_system.cancel_remaining_movement(attacker)
		var target: CombatantState = combat_system.combat_state.get_combatant(request.target_id)
		var conditional_damage_bonuses: Array[Dictionary] = combat_system.ability_system.get_conditional_damage_bonuses(attacker, target, request.attack_data, combat_system.combat_state.current_round)
		if request.attack_data.active_damage_bonus != 0:
			conditional_damage_bonuses.append({
				"ability_id": "",
				"source": request.attack_data.active_damage_bonus_source,
				"amount": request.attack_data.active_damage_bonus,
				"consume_on_hit": false,
			})
		var attacker_was_hidden := attacker.has_status("hidden")
		# An attack counts as declared before To Hit and Reaction resolution, even
		# when it later misses, is parried, or is cancelled by a Reaction.
		target.last_attack_declared_round = combat_system.combat_state.current_round
		var prepared: AttackResult = combat_system.attack_system.resolve_attack(attacker, target, request.attack_data, true, conditional_damage_bonuses)
		if request.attack_data.thrown_item != null:
			var consumed: bool = combat_system.equipment_system.consume_thrown_weapon(attacker, request.attack_data)
			combat_system.ability_system.sync_granted_reactions(attacker)
			combat_system.event_system.emit(CombatEvent.new(EventTypes.Type.EQUIPMENT_CHANGED, attacker.id, "", {"item_name": "%s (%s)" % [request.attack_data.thrown_item.display_name, "consumed by throw" if consumed else "Returning"]}))
		if attacker_was_hidden:
			attacker.remove_status("hidden")
			combat_system.event_system.emit(CombatEvent.new(EventTypes.Type.EFFECT_EXPIRED, attacker.id, "", {"effect_name": "Hidden", "reason": "Attack declared"}))
		var post_prompt: Dictionary = combat_system.reaction_system.get_post_hit_prompt(attacker, target, request.attack_data, prepared, combat_system.combat_state.current_round)
		if not post_prompt.is_empty():
			if not combat_system.open_reaction_prompt(request, post_prompt):
				combat_system.attack_system.finalize_attack(attacker, target, request.attack_data, prepared)
				return combat_system.action_system.build_attack_result(attacker, target, request.attack_data, prepared)
			var pending_result := ActionResult.success_result()
			pending_result.requires_reaction_choice = true
			pending_result.reaction_prompt = post_prompt
			for reaction in post_prompt["reactions"]:
				pending_result.events.append(CombatEvent.new(EventTypes.Type.REACTION_AVAILABLE, target.id, attacker.id, {"reaction_name": reaction.display_name}))
			combat_system.emit_events(pending_result.events)
			if target.id == "player":
				return pending_result
			# Enemy AI currently selects the first legal defensive Reaction.
			return combat_system.resolve_pending_reaction(0)
		var intervention_prompt: Dictionary = combat_system.reaction_system.get_ally_damage_reaction_prompt(attacker, target, request.attack_data, prepared, combat_system.combat_state)
		if not intervention_prompt.is_empty():
			if combat_system.open_reaction_prompt(request, intervention_prompt):
				var intervention_result := ActionResult.success_result()
				intervention_result.requires_reaction_choice = true
				intervention_result.reaction_prompt = intervention_prompt
				for reaction in intervention_prompt["reactions"]:
					intervention_result.events.append(CombatEvent.new(EventTypes.Type.REACTION_AVAILABLE, intervention_prompt["reactor"].id, target.id, {"reaction_name": reaction.display_name}))
				combat_system.emit_events(intervention_result.events)
				if intervention_prompt["reactor"].id == "player":
					return intervention_result
				return combat_system.resolve_pending_reaction(0)
		combat_system.attack_system.finalize_attack(attacker, target, request.attack_data, prepared)
		var prepared_result: ActionResult = combat_system.action_system.build_attack_result(attacker, target, request.attack_data, prepared)
		combat_system.offer_step_back(request, attacker, target, prepared_result)
		combat_system.offer_mobile_shooter(request, attacker, request.attack_data, prepared, prepared_result)
		combat_system.emit_events(prepared_result.events)
		combat_system.check_for_combat_end()
		return prepared_result
	if request.action_type == ActionTypes.Type.SKILL:
		if request.skill_data != null and request.skill_data.target_mode == SkillDataScript.TargetMode.SELF:
			request.target_id = request.actor_id
		elif request.skill_data != null and request.skill_data.target_mode == SkillDataScript.TargetMode.GROUND:
			return ActionResult.failure("Ground-targeted Skills require a target point.")
		var skill_validation: ActionResult = combat_system.action_system.validate(request, combat_system.combat_state)
		if not skill_validation.success:
			return skill_validation
		var skill_actor: CombatantState = combat_system.combat_state.get_combatant(request.actor_id)
		var skill_target: CombatantState = combat_system.combat_state.get_combatant(request.target_id)
		combat_system.cancel_remaining_movement(skill_actor)
		combat_system.skill_system.consume_skill_costs(skill_actor, request.skill_data)
		var skill_attack: AttackData = combat_system.skill_system.get_attack_data(request.skill_data)
		var skill_prepared: AttackResult = combat_system.attack_system.resolve_attack(skill_actor, skill_target, skill_attack, true)
		combat_system.clear_hidden(skill_actor, "Offensive Skill used")
		var skill_prompt: Dictionary = combat_system.reaction_system.get_post_hit_prompt(skill_actor, skill_target, skill_attack, skill_prepared, combat_system.combat_state.current_round)
		if not skill_prompt.is_empty():
			skill_prompt["skill_data"] = request.skill_data
			if not combat_system.open_reaction_prompt(request, skill_prompt):
				combat_system.attack_system.finalize_attack(skill_actor, skill_target, skill_attack, skill_prepared)
				return combat_system.action_system.build_attack_result(skill_actor, skill_target, skill_attack, skill_prepared)
			var skill_pending := ActionResult.success_result()
			skill_pending.requires_reaction_choice = true
			skill_pending.reaction_prompt = skill_prompt
			for reaction in skill_prompt["reactions"]:
				skill_pending.events.append(CombatEvent.new(EventTypes.Type.REACTION_AVAILABLE, skill_target.id, skill_actor.id, {"reaction_name": reaction.display_name}))
			combat_system.emit_events(skill_pending.events)
			if skill_target.id == "player":
				return skill_pending
			return combat_system.resolve_pending_reaction(0)
		combat_system.attack_system.finalize_attack(skill_actor, skill_target, skill_attack, skill_prepared)
		var skill_result: ActionResult = combat_system.action_system.build_attack_result(skill_actor, skill_target, skill_attack, skill_prepared)
		skill_result.events.push_front(CombatEvent.new(EventTypes.Type.SKILL_CAST, skill_actor.id, skill_target.id, {"skill_name": request.skill_data.display_name, "mana_cost": request.skill_data.mana_cost, "cooldown": combat_system.skill_system.get_effective_cooldown_turns(skill_actor, request.skill_data)}))
		combat_system.offer_step_back(request, skill_actor, skill_target, skill_result)
		combat_system.offer_mobile_shooter(request, skill_actor, skill_attack, skill_prepared, skill_result)
		combat_system.emit_events(skill_result.events)
		combat_system.check_for_combat_end()
		return skill_result

	var reaction_prompt: Dictionary = combat_system.reaction_system.get_player_reaction_prompt(request, combat_system.combat_state)
	if not reaction_prompt.is_empty():
		if not combat_system.open_reaction_prompt(request, reaction_prompt):
			return combat_system.action_system.execute(request, combat_system.combat_state)
		var pending_result := ActionResult.success_result()
		pending_result.requires_reaction_choice = true
		pending_result.reaction_prompt = reaction_prompt
		pending_result.events.append(
			CombatEvent.new(
				EventTypes.Type.REACTION_AVAILABLE,
				reaction_prompt["reactor"].id,
				request.actor_id,
				{"reaction_name": reaction_prompt["reaction"].display_name}
			)
		)
		combat_system.emit_events(pending_result.events)
		return pending_result

	var validation: ActionResult = combat_system.action_system.validate(request, combat_system.combat_state)
	if not validation.success:
		return validation
	var actor: CombatantState = combat_system.combat_state.get_combatant(request.actor_id)
	if request.action_type != ActionTypes.Type.MOVE:
		combat_system.cancel_remaining_movement(actor)
	var result: ActionResult = combat_system.action_system.execute(
		request,
		combat_system.combat_state
	)
	if request.action_type == ActionTypes.Type.SKILL and result.success:
		combat_system.clear_hidden(actor, "Offensive Skill used")

	combat_system.emit_events(result.events)

	combat_system.check_for_combat_end()

	return result
