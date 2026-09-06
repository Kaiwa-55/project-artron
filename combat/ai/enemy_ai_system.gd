class_name EnemyAISystem
extends RefCounted

enum DecisionType { END_TURN, ATTACK, MOVE, SKILL, ABILITY }

const StandardProfile = preload("res://data/ai/standard_ai_profile.tres")
const AIContextScript = preload("res://combat/ai/ai_context.gd")
const CandidateScript = preload("res://combat/ai/ai_action_candidate.gd")
const GridlessPathfinderScript = preload("res://combat/ai/gridless_pathfinder.gd")

var profile = StandardProfile
var pathfinder = GridlessPathfinderScript.new()
var boss_combo_states: Dictionary = {}


func choose_decision(system: CombatSystem, actor: CombatantState) -> Dictionary:
	if system == null or actor == null or actor.is_dying():
		return end_turn_decision("Actor cannot act.")
	var state = system.get_combat_state()
	if state == null or state.is_finished() or state.current_actor_id != actor.id:
		return end_turn_decision("It is not this actor's turn.")
	if system.has_pending_reaction() or system.has_pending_step_back_move() or system.has_pending_ability_movement():
		return end_turn_decision("Another action is waiting to resolve.")
	profile = actor.ai_profile if actor.ai_profile != null else StandardProfile
	var context = AIContextScript.new()
	context.setup(system, actor)
	var candidates: Array = collect_candidates(system, context)
	if candidates.is_empty():
		return end_turn_decision("No candidate action is available.")
	score_candidates(candidates, context)
	apply_boss_phase_and_combo_scores(candidates, context)
	candidates.sort_custom(compare_candidates)
	var decision: Dictionary = candidates[0].to_decision()
	decision["boss_phase"] = get_boss_phase(context.actor)
	decision["combo_step"] = get_combo_step(context.actor.id, context.current_round)
	return decision


func collect_candidates(system: CombatSystem, context) -> Array:
	var candidates: Array = []
	collect_attack_candidates(system, context, candidates)
	collect_skill_candidates(system, context, candidates)
	collect_ability_candidates(system, context, candidates)
	collect_ground_ability_candidates(system, context, candidates)
	collect_movement_ability_candidates(system, context, candidates)
	collect_move_candidates(system, context, candidates)
	var end_turn = CandidateScript.new()
	end_turn.type = CandidateScript.Type.END_TURN
	end_turn.actor_id = context.actor.id
	end_turn.score = profile.end_turn_score
	end_turn.reason = "End turn."
	candidates.append(end_turn)
	return candidates


func collect_attack_candidates(system: CombatSystem, context, candidates: Array) -> void:
	var attack: AttackData = context.actor.equipped_weapon_attack
	if attack == null or not can_spend_for_action(context, attack.ap_cost):
		return
	for target in context.enemies:
		if not system.map_rules.is_target_in_range(context.actor, target, attack.range_feet):
			continue
		if not system.attack_system.validate_attack(context.actor, target, attack).success:
			continue
		var candidate = CandidateScript.new()
		candidate.type = CandidateScript.Type.ATTACK
		candidate.actor_id = context.actor.id
		candidate.target_id = target.id
		candidate.source_data = attack
		candidate.expected_damage = maxf(0.0, float(attack.base_damage))
		candidate.kill_value = 1.0 if target.hp <= attack.base_damage else 0.0
		candidate.status_value = evaluate_effects_status_value(attack.effects_on_hit, target)
		candidate.resource_cost = attack.ap_cost * profile.ap_cost_weight
		candidate.reason = "Attack %s with %s." % [target.display_name, attack.display_name]
		candidates.append(candidate)


func collect_move_candidates(system: CombatSystem, context, candidates: Array) -> void:
	var move_ap_cost: int = 0 if context.actor.movement_in_progress else 1
	if not can_spend_for_action(context, move_ap_cost) or context.actor.get_effective_speed() <= 0.0 or context.actor.has_status("rooted"):
		return
	for target in context.enemies:
		var attack: AttackData = context.actor.equipped_weapon_attack
		var preferred_range: float = attack.range_feet if attack != null else 5.0
		var destination := choose_move_destination(system, context.actor, target, preferred_range)
		if destination == context.actor.position:
			continue
		destination = choose_path_waypoint(system, context.actor, target, destination, context.combat_state.combatants)
		if destination == context.actor.position:
			continue
		var candidate = CandidateScript.new()
		candidate.type = CandidateScript.Type.MOVE
		candidate.actor_id = context.actor.id
		candidate.target_id = target.id
		candidate.target_position = destination
		var distance_before: float = system.map_rules.get_edge_distance_world_units(context.actor, target)
		var distance_after: float = get_edge_distance_from_position(system, context.actor, target, destination)
		candidate.position_value = clampf((distance_before - distance_after) / maxf(1.0, distance_before), 0.0, 1.0)
		candidate.resource_cost = move_ap_cost * profile.ap_cost_weight
		var ap_after_move: int = context.available_ap - move_ap_cost
		if attack != null and ap_after_move >= attack.ap_cost and is_attack_in_range_from_position(system, context.actor, target, destination, attack.range_feet):
			candidate.follow_up_value = maxf(1.0, float(attack.base_damage))
			candidate.reason = "Move toward %s, then attack with %s." % [target.display_name, attack.display_name]
		else:
			candidate.reason = "Move toward %s to improve the next action." % target.display_name
		candidates.append(candidate)


func collect_skill_candidates(system: CombatSystem, context, candidates: Array) -> void:
	for skill in context.actor.available_skills:
		if skill == null or skill.target_mode != SkillData.TargetMode.SINGLE_COMBATANT:
			continue
		if not can_spend_for_action(context, skill.ap_cost):
			continue
		for target in context.enemies:
			if not skill_target_matches(context.actor, target, skill):
				continue
			var validation: ActionResult = system.skill_system.validate_skill(context.actor, target, skill, system.attack_system)
			if not validation.success:
				continue
			var attack: AttackData = system.skill_system.get_attack_data(skill)
			var candidate = CandidateScript.new()
			candidate.type = CandidateScript.Type.SKILL
			candidate.actor_id = context.actor.id
			candidate.target_id = target.id
			candidate.source_data = skill
			candidate.expected_damage = maxf(0.0, float(attack.base_damage))
			candidate.kill_value = 1.0 if target.hp <= attack.base_damage else 0.0
			candidate.status_value = evaluate_effects_status_value(attack.effects_on_hit, target)
			candidate.resource_cost = skill.ap_cost * profile.ap_cost_weight + skill.mana_cost * profile.mana_cost_weight
			candidate.reason = "Use %s on %s." % [skill.display_name, target.display_name]
			candidates.append(candidate)


func collect_ability_candidates(system: CombatSystem, context, candidates: Array) -> void:
	for ability in system.ability_system.get_active_abilities(context.actor):
		if ability == null or ability.is_passive or ability.reaction_only or ability.target_mode != AbilityData.TargetMode.SINGLE_COMBATANT:
			continue
		if not can_spend_for_action(context, ability.ap_cost):
			continue
		for target in context.enemies:
			var validation: ActionResult = system.ability_system.validate_active_use(context.actor, ability, target)
			if not validation.success:
				continue
			var attack: AttackData = system.ability_system.get_attack_data(context.actor, ability)
			var range_feet: float = ability.targeting_range_feet if ability.targeting_range_feet > 0.0 else (attack.range_feet if attack != null else 0.0)
			if range_feet > 0.0 and not system.map_rules.is_target_in_range(context.actor, target, range_feet):
				continue
			var candidate = CandidateScript.new()
			candidate.type = CandidateScript.Type.ABILITY
			candidate.actor_id = context.actor.id
			candidate.target_id = target.id
			candidate.source_data = ability
			candidate.expected_damage = maxf(0.0, float(attack.base_damage)) if attack != null else 0.0
			candidate.kill_value = 1.0 if attack != null and target.hp <= attack.base_damage else 0.0
			candidate.status_value = evaluate_ability_status_value(ability, attack, target)
			candidate.resource_cost = ability.ap_cost * profile.ap_cost_weight
			candidate.reason = "Use %s on %s." % [ability.display_name, target.display_name]
			candidates.append(candidate)


func collect_ground_ability_candidates(system: CombatSystem, context, candidates: Array) -> void:
	for ability in system.ability_system.get_active_abilities(context.actor):
		if ability == null or ability.is_passive or ability.reaction_only or ability.target_mode != AbilityData.TargetMode.GROUND:
			continue
		if not can_spend_for_action(context, ability.ap_cost):
			continue
		if not system.validate_ground_ability_start(context.actor.id, ability.id).success:
			continue
		var attack: AttackData = system.ability_system.get_attack_data(context.actor, ability)
		for target_point in get_area_candidate_points(context):
			if not system.targeting_system.validate_target_point(context.actor, target_point, ability, system.map_rules).success:
				continue
			var affected: Array[CombatantState] = system.targeting_system.collect_targets(context.actor, target_point, ability, context.combat_state, system.map_rules)
			if affected.is_empty():
				continue
			var candidate = CandidateScript.new()
			candidate.type = CandidateScript.Type.ABILITY
			candidate.actor_id = context.actor.id
			candidate.target_id = affected[0].id
			candidate.target_position = target_point
			candidate.source_data = ability
			candidate.expected_damage = float(attack.base_damage * affected.size()) if attack != null else 0.0
			for target in affected:
				candidate.status_value += evaluate_ability_status_value(ability, attack, target)
			candidate.position_value = float(maxi(0, affected.size() - 1)) * profile.area_target_bonus / maxf(1.0, profile.position_weight)
			candidate.follow_up_value = estimate_follow_up_value(system, context, ability.ap_cost, affected[0])
			candidate.resource_cost = ability.ap_cost * profile.ap_cost_weight
			candidate.reason = "Use %s on an area affecting %d target(s)." % [ability.display_name, affected.size()]
			candidates.append(candidate)


func collect_movement_ability_candidates(system: CombatSystem, context, candidates: Array) -> void:
	if context.actor.has_status("rooted"):
		return
	var target: CombatantState = context.get_closest_enemy()
	if target == null:
		return
	for ability in system.ability_system.get_active_abilities(context.actor):
		var movement = system.ability_system.get_movement_effect(ability)
		if movement == null or movement.movement_triggers_reactions:
			continue
		if not can_spend_for_action(context, ability.ap_cost):
			continue
		if not system.ability_system.validate_active_use(context.actor, ability, context.actor).success:
			continue
		var destination := choose_move_destination(system, context.actor, target)
		var maximum: float = movement.movement_distance_feet * system.map_rules.world_units_per_foot
		if context.actor.position.distance_to(destination) > maximum:
			destination = context.actor.position.move_toward(destination, maximum)
		if destination.is_equal_approx(context.actor.position):
			continue
		if not system.map_rules.validate_movement_path(context.actor, destination, system.combat_state.combatants).success:
			continue
		var candidate = CandidateScript.new()
		candidate.type = CandidateScript.Type.ABILITY
		candidate.actor_id = context.actor.id
		candidate.target_id = context.actor.id
		candidate.target_position = destination
		candidate.source_data = ability
		candidate.position_value = 1.2
		candidate.resource_cost = ability.ap_cost * profile.ap_cost_weight
		candidate.reason = "Use %s to approach %s safely." % [ability.display_name, target.display_name]
		candidates.append(candidate)


func skill_target_matches(actor: CombatantState, target: CombatantState, skill) -> bool:
	match skill.target_filter:
		SkillData.TargetFilter.ENEMIES:
			return actor.team != target.team
		SkillData.TargetFilter.ALLIES:
			return actor.team == target.team
	return true


func get_reaction_ap_reserve(context) -> int:
	var configured_reserve: int = profile.reaction_ap_reserve
	if get_boss_phase(context.actor) == 3 and profile.phase_three_reaction_ap_reserve >= 0:
		configured_reserve = profile.phase_three_reaction_ap_reserve
	if configured_reserve <= 0:
		return 0
	for reaction in context.actor.active_reactions:
		if reaction == null or reaction.ap_cost <= 0:
			continue
		if reaction.uses_per_round > 0 and int(context.actor.reaction_last_used_round.get(reaction.id, 0)) == context.current_round:
			continue
		return mini(configured_reserve, reaction.ap_cost)
	return 0


func can_spend_for_action(context, ap_cost: int) -> bool:
	return context.available_ap - ap_cost >= get_reaction_ap_reserve(context)


func get_area_candidate_points(context) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for enemy in context.enemies:
		points.append(enemy.position)
	for left_index in range(context.enemies.size()):
		for right_index in range(left_index + 1, context.enemies.size()):
			var midpoint: Vector2 = (context.enemies[left_index].position + context.enemies[right_index].position) * 0.5
			if not points.any(func(point: Vector2): return point.is_equal_approx(midpoint)):
				points.append(midpoint)
	return points


func estimate_follow_up_value(system: CombatSystem, context, spent_ap: int, target: CombatantState) -> float:
	var remaining_ap: int = context.available_ap - spent_ap - get_reaction_ap_reserve(context)
	var attack: AttackData = context.actor.equipped_weapon_attack
	if attack != null and remaining_ap >= attack.ap_cost and system.map_rules.is_target_in_range(context.actor, target, attack.range_feet):
		return maxf(1.0, float(attack.base_damage))
	if remaining_ap >= 1:
		for ability in system.ability_system.get_active_abilities(context.actor):
			if ability != null and system.ability_system.get_movement_effect(ability) != null and ability.ap_cost <= remaining_ap:
				return 1.5
	return 0.0


func score_candidates(candidates: Array, context) -> void:
	var has_useful_action := candidates.any(func(candidate): return candidate.type != CandidateScript.Type.END_TURN)
	var low_hp: bool = context.actor.max_hp > 0 and context.actor.hp * 2 <= context.actor.max_hp
	var damage_multiplier: float = profile.low_hp_damage_multiplier if low_hp else 1.0
	var status_multiplier: float = profile.low_hp_status_multiplier if low_hp else 1.0
	for candidate in candidates:
		if candidate.type == CandidateScript.Type.END_TURN:
			candidate.score = profile.end_turn_score - (profile.useful_action_end_turn_penalty if has_useful_action else 0.0)
			continue
		candidate.score = candidate.expected_damage * profile.damage_weight * damage_multiplier \
			+ candidate.kill_value * profile.kill_bonus \
			+ candidate.position_value * profile.position_weight \
			+ candidate.follow_up_value * profile.planning_weight \
			+ candidate.status_value * profile.status_weight * status_multiplier \
			- candidate.resource_cost \
			- candidate.risk * profile.risk_weight


func get_boss_phase(actor: CombatantState) -> int:
	if actor == null or actor.max_hp <= 0:
		return 1
	var hp_ratio: float = float(actor.hp) / float(actor.max_hp)
	if hp_ratio <= profile.phase_three_hp_ratio:
		return 3
	if hp_ratio <= profile.phase_two_hp_ratio:
		return 2
	return 1


func get_phase_source_id(phase: int) -> String:
	match phase:
		2:
			return profile.phase_two_source_id
		3:
			return profile.phase_three_source_id
	return profile.phase_one_source_id


func get_combo_step(actor_id: String, current_round: int) -> int:
	var state: Dictionary = boss_combo_states.get(actor_id, {})
	if state.is_empty():
		return 0
	# The finisher can carry into the following round; older plans are stale.
	if current_round - int(state.get("round", current_round)) > 1:
		boss_combo_states.erase(actor_id)
		return 0
	return int(state.get("step", 0))


func apply_boss_phase_and_combo_scores(candidates: Array, context) -> void:
	if profile.combo_opener_source_id.is_empty() and profile.phase_one_source_id.is_empty():
		return
	var phase: int = get_boss_phase(context.actor)
	var preferred_source: String = get_phase_source_id(phase)
	var combo_step: int = get_combo_step(context.actor.id, context.current_round)
	var combo_state: Dictionary = boss_combo_states.get(context.actor.id, {})
	var combo_target_id: String = combo_state.get("target_id", "")
	var combo_source := ""
	if combo_step == 1:
		combo_source = profile.combo_approach_source_id
	elif combo_step == 2:
		combo_source = profile.combo_finisher_source_id
	for candidate in candidates:
		var source_id: String = candidate.get_source_id()
		if not preferred_source.is_empty() and source_id == preferred_source:
			candidate.score += profile.phase_preference_bonus
			candidate.reason += " Boss Phase %d preference." % phase
		elif phase != 1 and source_id == profile.phase_one_source_id:
			candidate.score -= profile.phase_preference_bonus
			candidate.reason += " Deprioritized outside control phase."
		if not combo_source.is_empty() and source_id == combo_source and (combo_source != profile.combo_finisher_source_id or combo_target_id.is_empty() or candidate.target_id == combo_target_id):
			candidate.score += profile.combo_step_bonus
			candidate.reason += " Continue combo step %d." % (combo_step + 1)
		elif combo_step == 1 and source_id == profile.combo_finisher_source_id and (combo_target_id.is_empty() or candidate.target_id == combo_target_id):
			# If the Web already caught someone in melee reach, skip the approach
			# step and capitalize immediately instead of moving unnecessarily.
			candidate.score += profile.combo_step_bonus
			candidate.reason += " Combo target is already in finisher range."


func compare_candidates(left, right) -> bool:
	if not is_equal_approx(left.score, right.score):
		return left.score > right.score
	return left.stable_key() < right.stable_key()


func evaluate_ability_status_value(ability, attack: AttackData, target: CombatantState) -> float:
	var value := evaluate_effects_status_value(attack.effects_on_hit, target) if attack != null else 0.0
	for use_effect in ability.use_effects:
		if use_effect == null or use_effect.effect == null:
			continue
		if use_effect.recipient == AbilityUseEffectData.Recipient.TARGET:
			value += evaluate_status_value(use_effect.effect, target)
	return value


func evaluate_effects_status_value(effects: Array, target: CombatantState) -> float:
	var value := 0.0
	for effect in effects:
		if effect != null:
			value += evaluate_status_value(effect, target)
	return value


func evaluate_status_value(effect: EffectData, target: CombatantState) -> float:
	if effect.status_kind == EffectData.StatusKind.NONE:
		return 0.0
	var base_value: float = float(profile.status_values.get(effect.id, 0.0))
	if base_value <= 0.0:
		return 0.0
	var current = get_active_effect(target, effect.id)
	if current != null:
		match effect.stack_mode:
			EffectData.StackMode.ADD_STACKS:
				if current.stack_count >= effect.max_stacks:
					return 0.0
				base_value *= minf(1.0, float(effect.stacks_on_apply) / float(maxi(1, effect.max_stacks)))
			EffectData.StackMode.KEEP_STRONGER:
				if current.data.potency >= effect.potency:
					return 0.0
				base_value *= float(effect.potency - current.data.potency) / float(maxi(1, effect.potency))
			_:
				if current.remaining_turns >= effect.duration_turns:
					return 0.0
				base_value *= 0.35
	var potency_multiplier: float = maxf(1.0, float(maxi(effect.potency, effect.stacks_on_apply)))
	var duration_multiplier: float = 1.0 + 0.15 * float(maxi(0, effect.duration_turns - 1))
	return base_value * potency_multiplier * duration_multiplier


func get_active_effect(target: CombatantState, effect_id: String):
	for active_effect in target.effects:
		if active_effect != null and active_effect.data.id == effect_id:
			return active_effect
	return null


func choose_target(state, actor: CombatantState) -> CombatantState:
	var best_target: CombatantState
	var best_distance := INF
	for candidate in state.combatants.values():
		if candidate == null or candidate.team == actor.team or candidate.is_dying():
			continue
		var distance := actor.position.distance_squared_to(candidate.position)
		if distance < best_distance:
			best_distance = distance
			best_target = candidate
	return best_target


func choose_move_destination(system: CombatSystem, actor: CombatantState, target: CombatantState, preferred_range_feet: float = 5.0) -> Vector2:
	var units_per_foot: float = system.map_rules.world_units_per_foot
	var combined_radii: float = system.map_rules.get_combatant_radius_world_units(actor) + system.map_rules.get_combatant_radius_world_units(target)
	var preferred_gap: float = maxf(0.0, preferred_range_feet) * units_per_foot
	var desired_distance: float = combined_radii + preferred_gap
	var available_distance: float = system.movement_system.get_available_distance_feet(actor) * units_per_foot
	var move_distance: float = minf(available_distance, maxf(0.0, actor.position.distance_to(target.position) - desired_distance))
	if move_distance <= 0.0:
		return actor.position
	return actor.position + actor.position.direction_to(target.position) * move_distance


func get_edge_distance_from_position(system: CombatSystem, actor: CombatantState, target: CombatantState, position: Vector2) -> float:
	var combined_radii: float = system.map_rules.get_combatant_radius_world_units(actor) + system.map_rules.get_combatant_radius_world_units(target)
	return maxf(0.0, position.distance_to(target.position) - combined_radii)


func is_attack_in_range_from_position(system: CombatSystem, actor: CombatantState, target: CombatantState, position: Vector2, range_feet: float) -> bool:
	return get_edge_distance_from_position(system, actor, target, position) <= system.map_rules.get_attack_range_world_units(range_feet)


func choose_unblocked_move_destination(system: CombatSystem, actor: CombatantState, target: CombatantState, direct_destination: Vector2, combatants: Dictionary) -> Vector2:
	var movement_delta := direct_destination - actor.position
	if movement_delta.is_zero_approx():
		return actor.position
	var current_distance := actor.position.distance_to(target.position)
	# Try deterministic side steps so an ally standing in the direct lane does
	# not make the AI give up its whole turn.
	for degrees in [30.0, -30.0, 60.0, -60.0, 90.0, -90.0]:
		var candidate := actor.position + movement_delta.rotated(deg_to_rad(degrees))
		if candidate.distance_to(target.position) >= current_distance:
			continue
		if system.map_rules.validate_movement_path(actor, candidate, combatants).success:
			return candidate
	return actor.position


func choose_path_waypoint(system: CombatSystem, actor: CombatantState, target: CombatantState, goal: Vector2, combatants: Dictionary) -> Vector2:
	var path: PackedVector2Array = pathfinder.find_path(system, actor, goal, combatants)
	var destination := actor.position
	if path.size() >= 2:
		destination = path[1]
	else:
		destination = choose_unblocked_move_destination(system, actor, target, goal, combatants)
	if destination == actor.position:
		return destination
	var available_world_distance: float = system.movement_system.get_available_distance_feet(actor) * system.map_rules.world_units_per_foot
	if actor.position.distance_to(destination) > available_world_distance:
		destination = actor.position.move_toward(destination, available_world_distance)
	return destination


func build_action_request(system: CombatSystem, decision: Dictionary) -> ActionRequest:
	match int(decision.get("type", DecisionType.END_TURN)):
		DecisionType.ATTACK:
			var attack_request := ActionRequest.new(decision.get("actor_id", ""), ActionTypes.Type.ATTACK)
			attack_request.target_id = decision.get("target_id", "")
			attack_request.attack_data = decision.get("attack_data")
			return attack_request
		DecisionType.MOVE:
			var move_request := ActionRequest.new(decision.get("actor_id", ""), ActionTypes.Type.MOVE)
			move_request.target_id = decision.get("target_id", "")
			move_request.target_position = decision.get("target_position", Vector2.ZERO)
			var movement := MovementData.new()
			movement.ap_cost = 1
			movement.world_units_per_foot = system.map_rules.world_units_per_foot
			move_request.movement_data = movement
			return move_request
		DecisionType.SKILL:
			var skill_request := ActionRequest.new(decision.get("actor_id", ""), ActionTypes.Type.SKILL)
			skill_request.target_id = decision.get("target_id", "")
			skill_request.skill_data = decision.get("candidate").source_data
			return skill_request
	return null


func execute_decision(system: CombatSystem, decision: Dictionary) -> ActionResult:
	var result: ActionResult
	if int(decision.get("type", DecisionType.END_TURN)) == DecisionType.ABILITY:
		var candidate = decision.get("candidate")
		if candidate.source_data.target_mode == AbilityData.TargetMode.GROUND:
			result = system.execute_ground_ability(candidate.actor_id, candidate.source_data.id, candidate.target_position)
		elif system.ability_system.get_movement_effect(candidate.source_data) != null:
			var started := system.begin_ability_movement(candidate.actor_id, candidate.source_data.id)
			if not started.success:
				return started
			var moved := system.execute_pending_ability_movement(candidate.target_position)
			if not moved.success:
				system.ability_move_actor_id = ""
				system.ability_move_id = ""
			result = moved
		else:
			result = system.use_active_ability(decision.get("actor_id", ""), decision.get("target_id", ""), candidate.source_data.id)
	else:
		var request := build_action_request(system, decision)
		result = system.execute_action(request) if request != null else ActionResult.failure("AI decision cannot be executed.")
	if result.success:
		advance_boss_combo(system, decision)
	return result


func advance_boss_combo(system: CombatSystem, decision: Dictionary) -> void:
	if profile.combo_opener_source_id.is_empty():
		return
	var candidate = decision.get("candidate")
	if candidate == null:
		return
	var source_id: String = candidate.get_source_id()
	var actor_id: String = decision.get("actor_id", "")
	var round_number: int = system.get_combat_state().current_round
	if source_id == profile.combo_opener_source_id:
		boss_combo_states[actor_id] = {"step": 1, "round": round_number, "target_id": decision.get("target_id", "")}
	elif source_id == profile.combo_approach_source_id and get_combo_step(actor_id, round_number) == 1:
		boss_combo_states[actor_id] = {"step": 2, "round": round_number, "target_id": boss_combo_states[actor_id].get("target_id", "")}
	elif source_id == profile.combo_finisher_source_id and get_combo_step(actor_id, round_number) in [1, 2]:
		boss_combo_states.erase(actor_id)


func end_turn_decision(reason: String) -> Dictionary:
	return {"type": DecisionType.END_TURN, "reason": reason}
