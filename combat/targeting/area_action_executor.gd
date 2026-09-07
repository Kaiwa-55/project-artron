class_name AreaActionExecutor
extends RefCounted

const AreaActionContextScript = preload("res://combat/targeting/area_action_context.gd")
const SkillDataScript = preload("res://data/skill/skill_data.gd")

var combat_system
var pending_context


func _init(p_combat_system) -> void:
	combat_system = p_combat_system


func execute_skill(combatant_id: String, skill_id: String, target_point: Vector2) -> ActionResult:
	var start_validation := validate_skill_start(combatant_id, skill_id)
	if not start_validation.success:
		return start_validation
	var actor: CombatantState = combat_system.combat_state.get_combatant(combatant_id)
	var skill = get_skill(actor, skill_id)
	var point_validation: ActionResult = combat_system.targeting_system.validate_target_point(actor, target_point, skill, combat_system.map_rules)
	if not point_validation.success:
		return point_validation
	var targets: Array[CombatantState] = combat_system.targeting_system.collect_targets(actor, target_point, skill, combat_system.combat_state, combat_system.map_rules)
	if targets.is_empty():
		return ActionResult.failure("There are no valid targets in the selected area.")
	if not actor.spend_ap(skill.ap_cost):
		return ActionResult.failure("Not enough AP.")
	combat_system.skill_system.consume_skill_costs(actor, skill)
	combat_system.cancel_remaining_movement(actor)
	combat_system.clear_hidden(actor, "Offensive Skill used")
	var area_attack: AttackData = skill.attack_data.duplicate()
	area_attack.ap_cost = 0
	pending_context = AreaActionContextScript.new()
	pending_context.setup_skill(actor, skill, target_point, area_attack, targets)
	pending_context.repeated_attack_penalty = combat_system.attack_system.declare_attack_action(actor, area_attack)
	pending_context.costs_consumed = true
	pending_context.cooldown_started = combat_system.skill_system.get_remaining_cooldown(actor, skill.id) > 0
	return continue_action()


func execute_ability(combatant_id: String, ability_id: String, target_point: Vector2) -> ActionResult:
	var start_validation := validate_ability_start(combatant_id, ability_id)
	if not start_validation.success:
		return start_validation
	var actor: CombatantState = combat_system.combat_state.get_combatant(combatant_id)
	var ability = combat_system.ability_system.get_available_ability(actor, ability_id)
	var point_validation: ActionResult = combat_system.targeting_system.validate_target_point(actor, target_point, ability, combat_system.map_rules)
	if not point_validation.success:
		return point_validation
	var targets: Array[CombatantState] = combat_system.targeting_system.collect_targets(actor, target_point, ability, combat_system.combat_state, combat_system.map_rules)
	if targets.is_empty():
		return ActionResult.failure("There are no valid targets in the selected area.")
	var source_attack: AttackData = combat_system.ability_system.get_attack_data(actor, ability)
	var unarmed_validation: ActionResult = combat_system.equipment_system.validate_unarmed_attack(actor, source_attack)
	if not unarmed_validation.success:
		return unarmed_validation
	var area_attack: AttackData
	if source_attack != null:
		area_attack = source_attack.duplicate()
	else:
		area_attack = AttackData.new()
		area_attack.id = "%s_area_effect" % ability.id
		area_attack.display_name = ability.display_name
		area_attack.requires_to_hit = false
		area_attack.base_damage = 0
	if ability.animation_template != null and ability.animation_template.animation_type != AttackAnimationData.Type.ATTACHED_DIRECTIONAL:
		area_attack.animation_template = ability.animation_template
	area_attack.ap_cost = 0
	if not actor.spend_ap(ability.ap_cost):
		return ActionResult.failure("Not enough AP.")
	if not actor.spend_faith(ability.faith_cost):
		actor.change_ap(ability.ap_cost)
		return ActionResult.failure("Not enough Faith.")
	combat_system.cancel_remaining_movement(actor)
	actor.ability_uses_this_turn[ability.id] = int(actor.ability_uses_this_turn.get(ability.id, 0)) + 1
	var cooldown: int = combat_system.ability_system.start_cooldown(actor, ability)
	pending_context = AreaActionContextScript.new()
	pending_context.setup_ability(actor, ability, target_point, area_attack, targets)
	pending_context.repeated_attack_penalty = combat_system.attack_system.declare_attack_action(actor, area_attack)
	pending_context.costs_consumed = true
	pending_context.cooldown_started = cooldown > 0
	var result := continue_action()
	if ability.faith_cost > 0:
		var faith_event := CombatEvent.new(EventTypes.Type.FAITH_CHANGED, actor.id, actor.id, {"ability_name": ability.display_name, "faith_spent": ability.faith_cost, "faith": actor.faith, "temporary_faith": actor.temporary_faith})
		result.events.push_front(faith_event)
		combat_system.event_system.emit(faith_event)
	return result


func get_skill(actor: CombatantState, skill_id: String):
	if actor == null:
		return null
	for skill in actor.available_skills:
		if skill != null and skill.id == skill_id:
			return skill
	return null


func validate_skill_start(combatant_id: String, skill_id: String) -> ActionResult:
	if combat_system.combat_state == null or combat_system.combat_state.is_finished():
		return ActionResult.failure("Combat is not active.")
	if combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement():
		return ActionResult.failure("Resolve the pending Reaction or movement first.")
	var actor: CombatantState = combat_system.combat_state.get_combatant(combatant_id)
	if actor == null or combat_system.combat_state.current_actor_id != combatant_id:
		return ActionResult.failure("This Skill can only be used during the character's turn.")
	var skill = get_skill(actor, skill_id)
	if skill == null or skill.target_mode != SkillDataScript.TargetMode.GROUND or skill.area_shape == SkillDataScript.AreaShape.NONE:
		return ActionResult.failure("Ground-targeted Skill is not available.")
	if actor.has_status("silenced") and skill.mana_cost > 0:
		return ActionResult.failure("Silenced characters cannot use Mana Skills.")
	if actor.ap < skill.ap_cost:
		return ActionResult.failure("Not enough AP: %s requires %d AP." % [skill.display_name, skill.ap_cost])
	if actor.mana < skill.mana_cost:
		return ActionResult.failure("Not enough Mana: %s requires %d Mana." % [skill.display_name, skill.mana_cost])
	var cooldown: int = combat_system.skill_system.get_remaining_cooldown(actor, skill.id)
	if cooldown > 0:
		return ActionResult.failure("%s is on cooldown (%d turn(s))." % [skill.display_name, cooldown])
	if skill.attack_data == null:
		return ActionResult.failure("%s has no action data." % skill.display_name)
	return ActionResult.success_result()


func validate_ability_start(combatant_id: String, ability_id: String) -> ActionResult:
	if combat_system.combat_state == null or combat_system.combat_state.is_finished():
		return ActionResult.failure("Combat is not active.")
	if combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement():
		return ActionResult.failure("Resolve the pending Reaction or movement first.")
	var actor: CombatantState = combat_system.combat_state.get_combatant(combatant_id)
	if actor == null or combat_system.combat_state.current_actor_id != combatant_id:
		return ActionResult.failure("This Ability can only be used during the character's turn.")
	var ability = combat_system.ability_system.get_available_ability(actor, ability_id)
	var is_ground_area: bool = ability != null and ability.target_mode == AbilityData.TargetMode.GROUND
	var is_self_circle: bool = ability != null and ability.target_mode == AbilityData.TargetMode.SELF and ability.area_shape == AbilityData.AreaShape.CIRCLE
	if ability == null or (not is_ground_area and not is_self_circle) or ability.area_shape == AbilityData.AreaShape.NONE:
		return ActionResult.failure("Ground-targeted Ability is not available.")
	return combat_system.ability_system.validate_active_use(actor, ability)


func continue_action(carried_events: Array[CombatEvent] = []) -> ActionResult:
	var result := ActionResult.success_result()
	result.events.append_array(carried_events)
	if pending_context == null:
		return ActionResult.failure("There is no Area Action waiting to resolve.")
	var context = pending_context
	var actor: CombatantState = context.actor
	var skill = context.skill_data
	var ability = context.ability_data
	var attack: AttackData = context.attack
	if actor == null or actor.is_dying():
		context.cancel(AreaActionContextScript.CancelScope.ENTIRE_ACTION, "The Area Action user is Dying.")
		context.finish()
		pending_context = null
		result.success = false
		result.failure_reason = context.cancellation_reason
		combat_system.emit_events(result.events)
		return result
	while context.has_remaining_targets():
		var target: CombatantState = context.take_next_target()
		if target == null or target.is_dying():
			if target != null:
				context.record_skipped_target(target, "Target is Dying before its Area resolution.")
			continue
		var area_conditional_bonuses: Array[Dictionary] = []
		var prepared: AttackResult = combat_system.attack_system.resolve_attack(actor, target, attack, true, area_conditional_bonuses, context.repeated_attack_penalty)
		var defense_prompt: Dictionary = combat_system.reaction_system.get_post_hit_prompt(actor, target, attack, prepared, combat_system.combat_state.current_round) if attack.requires_to_hit or attack.base_damage > 0 else {}
		if not defense_prompt.is_empty():
			if target.id == "player":
				defense_prompt["area_action_continuation"] = true
				if skill != null:
					defense_prompt["skill_data"] = skill
				else:
					defense_prompt["ability_data"] = ability
				var area_request := ActionRequest.new(actor.id, ActionTypes.Type.SKILL if skill != null else ActionTypes.Type.ATTACK)
				if not combat_system.open_reaction_prompt(area_request, defense_prompt):
					combat_system.attack_system.finalize_attack(actor, target, attack, prepared)
					result.events.append_array(combat_system.action_system.build_attack_result(actor, target, attack, prepared).events)
					continue
				result.requires_reaction_choice = true
				result.reaction_prompt = defense_prompt
				for reaction in defense_prompt["reactions"]:
					result.events.append(CombatEvent.new(EventTypes.Type.REACTION_AVAILABLE, target.id, actor.id, {"reaction_name": reaction.display_name}))
				combat_system.emit_events(result.events)
				return result
			combat_system.apply_ai_defensive_reaction(defense_prompt, 0, result)
		combat_system.attack_system.finalize_attack(actor, target, attack, prepared)
		context.record_target_result(target, prepared)
		var target_events: Array[CombatEvent] = combat_system.action_system.build_attack_result(actor, target, attack, prepared).events
		result.events.append_array(target_events)
		if ability != null:
			combat_system.active_ability_executor.apply_effects(actor, target, ability, target_events, result.events)
		if actor.is_dying():
			context.cancel(AreaActionContextScript.CancelScope.REMAINING_TARGETS, "The Area Action user became Dying during resolution.")
			break
	context.finish()
	if skill != null:
		result.events.push_front(CombatEvent.new(EventTypes.Type.SKILL_CAST, actor.id, "", {"skill_name": skill.display_name, "mana_cost": skill.mana_cost, "cooldown": combat_system.skill_system.get_effective_cooldown_turns(actor, skill), "area_target_count": context.targets.size(), "area_resolved_count": context.target_results.size(), "target_point": context.target_point}))
	else:
		var ability_event_data := {"ability_name": ability.display_name, "ap_cost": ability.ap_cost, "cooldown": ability.cooldown_turns, "area_target_count": context.targets.size(), "area_resolved_count": context.target_results.size(), "target_point": context.target_point}
		if ability.animation_template != null and ability.animation_template.animation_type == AttackAnimationData.Type.ATTACHED_DIRECTIONAL:
			ability_event_data["animation_template"] = ability.animation_template
			ability_event_data["animation_origin"] = actor.position
			ability_event_data["animation_target"] = context.target_point
		result.events.push_front(CombatEvent.new(EventTypes.Type.ABILITY_TRIGGERED, actor.id, "", ability_event_data))
	pending_context = null
	combat_system.emit_events(result.events)
	combat_system.check_for_combat_end()
	return result


func resume_after_reaction(reactor: CombatantState, prepared: AttackResult, action_events: Array[CombatEvent], carried_events: Array[CombatEvent]) -> ActionResult:
	if pending_context != null:
		pending_context.record_target_result(reactor, prepared)
		if pending_context.ability_data != null:
			combat_system.active_ability_executor.apply_effects(pending_context.actor, reactor, pending_context.ability_data, action_events, carried_events)
	return continue_action(carried_events)
