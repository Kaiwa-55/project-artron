class_name ReactionResolver
extends RefCounted

const ReactionEffectDataScript = preload("res://data/reaction/reaction_effect_data.gd")
const ResolutionContextScript = preload("res://combat/reaction/resolution_context.gd")

var combat_system
var pending_action: ActionRequest
var pending_reaction: Dictionary = {}
var pending_queue: Array[Dictionary] = []
var resolution_context
var move_actor_id: String = ""
var move_distance_feet: float = 0.0
var move_name: String = ""
var move_resumes_action: bool = false
var pending_defensive_move: Dictionary = {}


func _init(p_combat_system) -> void:
	combat_system = p_combat_system
	resolution_context = ResolutionContextScript.new()


func open_prompt(request: ActionRequest, prompt: Dictionary) -> bool:
	if resolution_context.root_action == null or (resolution_context.current_frame() == null and not has_pending() and pending_action == null):
		resolution_context.begin(request)
	var frame = resolution_context.open_frame(request, prompt)
	if frame == null:
		combat_system.event_system.emit(CombatEvent.new(EventTypes.Type.ACTION_CANCELLED, request.actor_id if request != null else "", "", {"reason": "Reaction chain safety limit reached; further Reactions were skipped."}))
		return false
	prompt["reaction_frame_id"] = frame.id
	prompt["reaction_depth"] = frame.depth
	pending_action = request
	pending_reaction = prompt
	return true


func get_depth() -> int:
	return resolution_context.get_open_depth()


func has_pending() -> bool:
	return pending_action != null and not pending_reaction.is_empty()


func has_pending_move() -> bool:
	return not move_actor_id.is_empty() and move_distance_feet > 0.0


func execute_move(destination: Vector2) -> ActionResult:
	if not has_pending_move():
		return ActionResult.failure("There is no Reaction movement waiting for a destination.")
	var actor: CombatantState = combat_system.combat_state.get_combatant(move_actor_id)
	if actor == null or actor.is_dying():
		clear_move()
		return ActionResult.failure("The character cannot use this Reaction movement.")
	var maximum_distance: float = move_distance_feet * combat_system.map_rules.world_units_per_foot
	var clamped_destination := destination
	if actor.position.distance_to(destination) > maximum_distance:
		clamped_destination = actor.position + actor.position.direction_to(destination) * maximum_distance
	var validation: ActionResult = combat_system.map_rules.validate_movement_path(actor, clamped_destination, combat_system.combat_state.combatants)
	if not validation.success:
		return validation
	var origin := actor.position
	actor.position = clamped_destination
	var resolved_name := move_name if not move_name.is_empty() else "Step Back"
	var should_resume := move_resumes_action
	clear_move(false)
	var result := ActionResult.success_result()
	result.events.append(CombatEvent.new(EventTypes.Type.MOVE_STARTED, actor.id, "", {"ability_name": resolved_name}))
	result.events.append(CombatEvent.new(EventTypes.Type.POSITION_CHANGED, actor.id, "", {"from": origin, "to": actor.position, "distance": origin.distance_to(actor.position), "distance_feet": origin.distance_to(actor.position) / combat_system.map_rules.world_units_per_foot, "remaining_speed_feet": 0.0, "ability_name": resolved_name}))
	result.events.append(CombatEvent.new(EventTypes.Type.MOVE_COMPLETED, actor.id, "", {"ability_name": resolved_name}))
	if not pending_defensive_move.is_empty():
		return finish_defensive_move(result.events)
	if should_resume:
		return continue_queue(result.events)
	combat_system.emit_events(result.events)
	return result


func cancel_move() -> ActionResult:
	if not has_pending_move():
		return ActionResult.failure("There is no Reaction movement to cancel.")
	clear_move(false)
	if not pending_defensive_move.is_empty():
		return finish_defensive_move([])
	return ActionResult.success_result()


func clear_move(clear_defensive: bool = true) -> void:
	move_actor_id = ""
	move_distance_feet = 0.0
	move_name = ""
	move_resumes_action = false
	if clear_defensive:
		pending_defensive_move = {}


func finish_defensive_move(movement_events: Array[CombatEvent]) -> ActionResult:
	var context := pending_defensive_move
	pending_defensive_move = {}
	var request: ActionRequest = context.get("request")
	var prompt: Dictionary = context.get("prompt", {})
	prompt["movement_completed"] = true
	prompt["resolved_reaction"] = context.get("reaction")
	pending_action = request
	pending_reaction = prompt
	if not movement_events.is_empty():
		combat_system.emit_events(movement_events)
	var resumed: ActionResult = combat_system.resolve_pending_reaction(-1)
	var combined_events: Array[CombatEvent] = []
	combined_events.append_array(movement_events)
	combined_events.append_array(resumed.events)
	resumed.events = combined_events
	return resumed


func continue_queue(carried_events: Array[CombatEvent] = []) -> ActionResult:
	var result := ActionResult.success_result()
	result.events.append_array(carried_events)
	while not pending_queue.is_empty():
		var item: Dictionary = pending_queue.pop_front()
		var reaction = item.get("reaction")
		var reactor: CombatantState = item.get("reactor")
		var trigger_actor: CombatantState = item.get("trigger_actor")
		if reaction == null or reactor == null or trigger_actor == null or reactor.is_dying() or trigger_actor.is_dying():
			continue
		if reactor.id == "player" and not item.get("approved", false):
			item["approved"] = true
			var opportunity_prompt := {"opportunity_choice": true, "reaction": reaction, "reactor": reactor, "attacker": trigger_actor, "queue_item": item}
			if not open_prompt(pending_action, opportunity_prompt):
				continue
			result.requires_reaction_choice = true
			result.reaction_prompt = pending_reaction
			result.events.append(CombatEvent.new(EventTypes.Type.REACTION_AVAILABLE, reactor.id, trigger_actor.id, {"reaction_name": reaction.display_name}))
			combat_system.emit_events(result.events)
			return result
		var reaction_attack: AttackData = combat_system.reaction_system.get_reaction_attack_data(reaction, reactor)
		var reaction_movement = combat_system.reaction_system.get_effect(reaction, ReactionEffectDataScript.Type.MOVEMENT)
		if reaction_movement != null and reaction_attack == null:
			if not reactor.spend_ap(reaction.ap_cost):
				continue
			combat_system.clear_hidden(reactor, "Reactive Ability used")
			move_actor_id = reactor.id
			move_distance_feet = reaction_movement.distance_feet if reaction_movement.distance_mode == ReactionEffectDataScript.DistanceMode.FIXED_FEET else reactor.get_effective_speed() * reaction_movement.speed_multiplier
			move_name = reaction.display_name
			move_resumes_action = true
			result.events.append(CombatEvent.new(EventTypes.Type.REACTION_TRIGGERED, reactor.id, trigger_actor.id, {"reaction_name": reaction.display_name, "distance_feet": move_distance_feet, "resolved_from_queue": true}))
			combat_system.emit_events(result.events)
			return result
		var validation: ActionResult = combat_system.attack_system.validate_attack(reactor, trigger_actor, reaction_attack)
		if not validation.success:
			continue
		var prepared: AttackResult = combat_system.attack_system.resolve_attack(reactor, trigger_actor, reaction_attack, true)
		combat_system.clear_hidden(reactor, "Reactive Ability used")
		result.events.append(CombatEvent.new(EventTypes.Type.REACTION_TRIGGERED, reactor.id, trigger_actor.id, {"reaction_name": reaction.display_name, "resolved_from_queue": true}))
		var defense_prompt: Dictionary = combat_system.reaction_system.get_post_hit_prompt(reactor, trigger_actor, reaction_attack, prepared, combat_system.combat_state.current_round)
		if not defense_prompt.is_empty():
			if trigger_actor.id == "player":
				defense_prompt["reaction_queue_continuation"] = true
				if not open_prompt(pending_action, defense_prompt):
					combat_system.attack_system.finalize_attack(reactor, trigger_actor, reaction_attack, prepared)
					result.events.append_array(combat_system.action_system.build_attack_result(reactor, trigger_actor, reaction_attack, prepared).events)
					continue
				result.requires_reaction_choice = true
				result.reaction_prompt = defense_prompt
				for available_reaction in defense_prompt["reactions"]:
					result.events.append(CombatEvent.new(EventTypes.Type.REACTION_AVAILABLE, trigger_actor.id, reactor.id, {"reaction_name": available_reaction.display_name}))
				combat_system.emit_events(result.events)
				return result
			apply_ai_defensive(defense_prompt, 0, result)
		combat_system.attack_system.finalize_attack(reactor, trigger_actor, reaction_attack, prepared)
		result.events.append_array(combat_system.action_system.build_attack_result(reactor, trigger_actor, reaction_attack, prepared).events)
		if trigger_actor.is_dying():
			pending_queue.clear()
			pending_action = null
			result.success = false
			result.failure_reason = "The original Action was interrupted because its actor is Dying."
			combat_system.emit_events(result.events)
			combat_system.check_for_combat_end()
			return result
	var resumed_action := pending_action
	pending_action = null
	if resumed_action != null:
		var resumed_result: ActionResult = combat_system.action_system.execute(resumed_action, combat_system.combat_state)
		result.success = resumed_result.success
		result.failure_reason = resumed_result.failure_reason
		result.events.append_array(resumed_result.events)
	combat_system.emit_events(result.events)
	combat_system.check_for_combat_end()
	return result


func apply_ai_defensive(prompt: Dictionary, reaction_index: int, result: ActionResult) -> void:
	var reactions: Array = prompt.get("reactions", [])
	if reaction_index < 0 or reaction_index >= reactions.size():
		return
	var reaction = reactions[reaction_index]
	var reactor: CombatantState = prompt.get("reactor")
	var prepared: AttackResult = prompt.get("prepared_attack")
	if reactor == null or prepared == null:
		return
	if reaction.uses_per_round > 0 and int(reactor.reaction_last_used_round.get(reaction.id, 0)) == combat_system.combat_state.current_round:
		return
	var movement_effect = combat_system.reaction_system.get_effect(reaction, ReactionEffectDataScript.Type.MOVEMENT)
	if movement_effect != null:
		var attacker: CombatantState = prompt.get("attacker")
		var distance_feet: float = movement_effect.distance_feet if movement_effect.distance_mode == ReactionEffectDataScript.DistanceMode.FIXED_FEET else reactor.get_effective_speed() * movement_effect.speed_multiplier
		var destination := choose_ai_destination(reactor, attacker, distance_feet)
		if destination == reactor.position or not reactor.spend_ap(reaction.ap_cost):
			return
		var origin := reactor.position
		reactor.position = destination
		reactor.reaction_last_used_round[reaction.id] = combat_system.combat_state.current_round
		var attack: AttackData = prompt.get("prepared_attack_data")
		if attack != null and attacker != null and not combat_system.map_rules.is_target_in_range(attacker, reactor, attack.range_feet):
			prepared.hit = false
			prepared.deferred = false
		result.events.append(CombatEvent.new(EventTypes.Type.REACTION_TRIGGERED, reactor.id, attacker.id if attacker != null else "", {"reaction_name": reaction.display_name, "selected_by_ai": true, "distance_feet": origin.distance_to(destination) / combat_system.map_rules.world_units_per_foot}))
		result.events.append(CombatEvent.new(EventTypes.Type.POSITION_CHANGED, reactor.id, "", {"from": origin, "to": destination, "distance_feet": origin.distance_to(destination) / combat_system.map_rules.world_units_per_foot, "reaction_name": reaction.display_name}))
		return
	if not reactor.spend_ap(reaction.ap_cost):
		return
	reactor.reaction_last_used_round[reaction.id] = combat_system.combat_state.current_round
	var defense_bonus: int = combat_system.reaction_system.get_defense_bonus(reaction)
	if combat_system.reaction_system.get_effect(reaction, ReactionEffectDataScript.Type.TURN_HIT_TO_MISS) != null:
		prepared.hit = false
		prepared.deferred = false
	else:
		prepared.defense = prepared.original_defense + defense_bonus
		prepared.margin = prepared.roll + prepared.attack_modifier - prepared.defense
		prepared.hit = prepared.margin >= 0
	result.events.append(CombatEvent.new(EventTypes.Type.REACTION_TRIGGERED, reactor.id, prompt.get("attacker").id, {"reaction_name": reaction.display_name, "defense_bonus": defense_bonus, "selected_by_ai": true}))


func choose_ai_destination(reactor: CombatantState, attacker: CombatantState, distance_feet: float) -> Vector2:
	if reactor == null or attacker == null or distance_feet <= 0.0 or reactor.has_status("rooted"):
		return reactor.position if reactor != null else Vector2.ZERO
	var distance_world: float = distance_feet * combat_system.map_rules.world_units_per_foot
	var away := attacker.position.direction_to(reactor.position)
	if away.is_zero_approx():
		away = Vector2.RIGHT
	var best := reactor.position
	var best_distance := reactor.position.distance_squared_to(attacker.position)
	for degrees in [0.0, 45.0, -45.0, 90.0, -90.0, 135.0, -135.0]:
		var candidate := reactor.position + away.rotated(deg_to_rad(degrees)) * distance_world
		if candidate.distance_squared_to(attacker.position) <= best_distance:
			continue
		if combat_system.map_rules.validate_movement_path(reactor, candidate, combat_system.combat_state.combatants).success:
			best = candidate
			best_distance = candidate.distance_squared_to(attacker.position)
	return best


func offer_step_back(request: ActionRequest, attacker: CombatantState, target: CombatantState, result: ActionResult) -> void:
	if request == null or attacker == null or target == null or target.id != "player":
		return
	var reactions: Array = combat_system.reaction_system.get_post_attack_reactions(attacker, target, combat_system.combat_state.current_round)
	if reactions.is_empty():
		return
	var reaction = reactions[0]
	var movement_effect = combat_system.reaction_system.get_effect(reaction, ReactionEffectDataScript.Type.MOVEMENT)
	if movement_effect == null or target.has_status("rooted"):
		return
	var distance_feet: float = movement_effect.distance_feet
	if movement_effect.distance_mode == ReactionEffectDataScript.DistanceMode.SPEED_MULTIPLIER:
		distance_feet = target.get_effective_speed() * movement_effect.speed_multiplier
	var prompt := {
		"step_back": true,
		"post_attack_reaction": true,
		"reactor": target,
		"attacker": attacker,
		"reaction": reaction,
		"distance_feet": distance_feet,
		"movement_effect": movement_effect,
	}
	if not open_prompt(request, prompt):
		return
	result.requires_reaction_choice = true
	result.reaction_prompt = prompt
	result.events.append(CombatEvent.new(EventTypes.Type.REACTION_AVAILABLE, target.id, attacker.id, {"reaction_name": reaction.display_name}))


func offer_mobile_shooter(request: ActionRequest, attacker: CombatantState, attack: AttackData, attack_result: AttackResult, result: ActionResult) -> void:
	if request == null or attacker == null or attacker.id != "player" or result.requires_reaction_choice:
		return
	var reactions: Array = combat_system.reaction_system.get_post_ranged_hit_reactions(attacker, attack, attack_result.hit)
	if reactions.is_empty():
		return
	var reaction = reactions[0]
	var movement_effect = combat_system.reaction_system.get_effect(reaction, ReactionEffectDataScript.Type.MOVEMENT)
	if movement_effect == null or attacker.has_status("rooted"):
		return
	# The first qualifying hit is the trigger; declining does not defer the limit.
	attacker.ability_uses_this_turn[reaction.id] = 1
	var prompt := {"step_back": true, "post_attack_reaction": true, "reactor": attacker, "attacker": attacker, "reaction": reaction, "distance_feet": movement_effect.distance_feet, "movement_effect": movement_effect}
	if not open_prompt(request, prompt):
		return
	result.requires_reaction_choice = true
	result.reaction_prompt = prompt
	result.events.append(CombatEvent.new(EventTypes.Type.REACTION_AVAILABLE, attacker.id, "", {"reaction_name": reaction.display_name}))


func resolve_choice(reaction_index: int) -> ActionResult:
	if not has_pending():
		return ActionResult.failure("There is no reaction waiting for a choice.")

	var request := pending_action
	var prompt := pending_reaction
	var prompt_reactions: Array = prompt.get("reactions", [])
	if prompt_reactions.is_empty() and prompt.has("reaction"):
		prompt_reactions.append(prompt["reaction"])
	var selected_reaction = prompt_reactions[reaction_index] if reaction_index >= 0 and reaction_index < prompt_reactions.size() else null
	var selected_reactor = prompt.get("reactor")
	if not resolution_context.complete_current(selected_reactor.id if selected_reactor != null else "", selected_reaction.id if selected_reaction != null else ""):
		reaction_index = -1
	pending_action = null
	pending_reaction = {}
	if prompt.get("damage_intervention", false):
		return resolve_damage_intervention_choice(request, prompt, selected_reaction)
	if prompt.get("step_back", false):
		var step_result := ActionResult.success_result()
		var step_reactor: CombatantState = prompt.get("reactor")
		var step_reaction = prompt.get("reaction")
		if reaction_index >= 0 and step_reactor != null and step_reaction != null and not step_reactor.is_dying() and step_reactor.spend_ap(step_reaction.ap_cost):
			combat_system.clear_hidden(step_reactor, "Reactive Ability used")
			step_reactor.reaction_last_used_round[step_reaction.id] = combat_system.combat_state.current_round
			if step_reaction.id == "step_back":
				step_reactor.last_step_back_round = combat_system.combat_state.current_round
			move_actor_id = step_reactor.id
			move_distance_feet = float(prompt.get("distance_feet", 0.0))
			move_name = step_reaction.display_name
			step_result.events.append(CombatEvent.new(EventTypes.Type.REACTION_TRIGGERED, step_reactor.id, request.actor_id, {"reaction_name": step_reaction.display_name, "distance_feet": move_distance_feet}))
		else:
			step_result.events.append(CombatEvent.new(EventTypes.Type.REACTION_DECLINED, step_reactor.id if step_reactor != null else "", request.actor_id, {"reaction_name": step_reaction.display_name if step_reaction != null else "Post-attack Reaction"}))
		combat_system.emit_events(step_result.events)
		return step_result
	if prompt.get("opportunity_choice", false):
		pending_action = request
		var opportunity_reactor: CombatantState = prompt.get("reactor")
		var opportunity_reaction = prompt.get("reaction")
		var choice_events: Array[CombatEvent] = []
		if reaction_index >= 0 and opportunity_reactor != null and opportunity_reaction != null:
			pending_queue.push_front(prompt.get("queue_item", {}))
		else:
			choice_events.append(CombatEvent.new(EventTypes.Type.REACTION_DECLINED, opportunity_reactor.id if opportunity_reactor != null else "", request.actor_id, {"reaction_name": opportunity_reaction.display_name if opportunity_reaction != null else "Opportunity Attack"}))
		return continue_queue(choice_events)
	var reactor: CombatantState = prompt["reactor"]
	var reactions: Array = prompt.get("reactions", [])
	if reactions.is_empty() and prompt.has("reaction"):
		reactions.append(prompt["reaction"])
	var reaction = reactions[reaction_index] if reaction_index >= 0 and reaction_index < reactions.size() else null
	var result := ActionResult.success_result()
	var bonus_applied := false
	var movement_applied := false
	var defense_bonus: int = combat_system.reaction_system.get_defense_bonus(reaction)
	var movement_effect = combat_system.reaction_system.get_effect(reaction, ReactionEffectDataScript.Type.MOVEMENT)
	var movement_completed: bool = bool(prompt.get("movement_completed", false))
	if movement_completed:
		reaction = prompt.get("resolved_reaction")
		movement_effect = combat_system.reaction_system.get_effect(reaction, ReactionEffectDataScript.Type.MOVEMENT)
		movement_applied = true

	if movement_completed:
		pass
	elif reaction != null and reactor != null and reactor.id == "player" and not reactor.is_dying() and movement_effect != null:
		if not reactor.spend_ap(reaction.ap_cost):
			return ActionResult.failure("Not enough AP.")
		combat_system.clear_hidden(reactor, "Reactive Ability used")
		reactor.reaction_last_used_round[reaction.id] = combat_system.combat_state.current_round
		move_actor_id = reactor.id
		move_distance_feet = movement_effect.distance_feet if movement_effect.distance_mode == ReactionEffectDataScript.DistanceMode.FIXED_FEET else reactor.get_effective_speed() * movement_effect.speed_multiplier
		move_name = reaction.display_name
		pending_defensive_move = {"request": request, "prompt": prompt, "reaction": reaction}
		result.events.append(CombatEvent.new(EventTypes.Type.REACTION_TRIGGERED, reactor.id, request.actor_id, {"reaction_name": reaction.display_name, "distance_feet": move_distance_feet}))
		combat_system.emit_events(result.events)
		return result
	elif reaction != null and reactor != null and reactor.id != "player" and not reactor.is_dying() and movement_effect != null:
		var reaction_attacker: CombatantState = prompt.get("attacker")
		var distance_feet: float = movement_effect.distance_feet if movement_effect.distance_mode == ReactionEffectDataScript.DistanceMode.FIXED_FEET else reactor.get_effective_speed() * movement_effect.speed_multiplier
		var destination := choose_ai_destination(reactor, reaction_attacker, distance_feet)
		if destination != reactor.position and reactor.spend_ap(reaction.ap_cost):
			var origin := reactor.position
			reactor.position = destination
			reactor.reaction_last_used_round[reaction.id] = combat_system.combat_state.current_round
			movement_applied = true
			combat_system.clear_hidden(reactor, "Reactive Ability used")
			result.events.append(CombatEvent.new(EventTypes.Type.REACTION_TRIGGERED, reactor.id, request.actor_id, {"reaction_name": reaction.display_name, "selected_by_ai": true, "distance_feet": origin.distance_to(destination) / combat_system.map_rules.world_units_per_foot}))
			result.events.append(CombatEvent.new(EventTypes.Type.POSITION_CHANGED, reactor.id, "", {"from": origin, "to": destination, "distance_feet": origin.distance_to(destination) / combat_system.map_rules.world_units_per_foot, "reaction_name": reaction.display_name}))
	elif reaction != null and reactor != null and not reactor.is_dying() and reactor.spend_ap(reaction.ap_cost):
		if combat_system.ability_system.ability_has_trait(reaction, "reactive") or combat_system.reaction_has_trait(reaction, "reactive"):
			combat_system.clear_hidden(reactor, "Reactive Ability used")
		reactor.defense_bonus += defense_bonus
		bonus_applied = true
		result.events.append(CombatEvent.new(
			EventTypes.Type.REACTION_TRIGGERED,
			reactor.id,
			request.actor_id,
			{"reaction_name": reaction.display_name, "defense_bonus": defense_bonus}
		))
	else:
		var declined_name := "all reactions"
		if reactions.size() == 1:
			declined_name = reactions[0].display_name
		result.events.append(CombatEvent.new(
			EventTypes.Type.REACTION_DECLINED,
			reactor.id if reactor != null else "",
			request.actor_id,
			{"reaction_name": declined_name}
		))

	var action_result: ActionResult
	if prompt.has("prepared_attack"):
		var prepared: AttackResult = prompt["prepared_attack"]
		var prepared_attack: AttackData = prompt["prepared_attack_data"]
		var prepared_attacker: CombatantState = prompt["attacker"]
		if bonus_applied:
			if combat_system.reaction_system.get_effect(reaction, ReactionEffectDataScript.Type.TURN_HIT_TO_MISS) != null:
				prepared.hit = false
				prepared.deferred = false
			else:
				prepared.defense = prepared.original_defense + defense_bonus
				prepared.margin = prepared.roll + prepared.attack_modifier - prepared.defense
				prepared.hit = prepared.margin >= 0
		elif movement_applied and not combat_system.map_rules.is_target_in_range(prepared_attacker, reactor, prepared_attack.range_feet):
			prepared.hit = false
			prepared.deferred = false
		if prepared.hit:
			var intervention_prompt: Dictionary = combat_system.reaction_system.get_ally_damage_reaction_prompt(prepared_attacker, reactor, prepared_attack, prepared, combat_system.combat_state)
			if not intervention_prompt.is_empty() and open_prompt(request, intervention_prompt):
				if prompt.get("attack_sequence_continuation", false):
					intervention_prompt["attack_sequence_continuation"] = true
				result.requires_reaction_choice = true
				result.reaction_prompt = intervention_prompt
				for available_reaction in intervention_prompt["reactions"]:
					result.events.append(CombatEvent.new(EventTypes.Type.REACTION_AVAILABLE, intervention_prompt["reactor"].id, reactor.id, {"reaction_name": available_reaction.display_name}))
				combat_system.emit_events(result.events)
				return result
			combat_system.attack_system.finalize_attack(prepared_attacker, reactor, prepared_attack, prepared)
		else:
			prepared.deferred = false
		action_result = combat_system.action_system.build_attack_result(prepared_attacker, reactor, prepared_attack, prepared)
		if prompt.has("skill_data") and not prompt.get("area_skill_continuation", false) and not prompt.get("area_action_continuation", false) and not prompt.get("attack_sequence_continuation", false):
			var resolved_skill = prompt["skill_data"]
			action_result.events.push_front(CombatEvent.new(EventTypes.Type.SKILL_CAST, prepared_attacker.id, reactor.id, {"skill_name": resolved_skill.display_name, "mana_cost": resolved_skill.mana_cost, "cooldown": combat_system.skill_system.get_effective_cooldown_turns(prepared_attacker, resolved_skill)}))
		if prompt.has("opportunity_attack") and not reactor.is_dying():
			var move_result: ActionResult = combat_system.action_system.execute(request, combat_system.combat_state)
			action_result.events.append_array(move_result.events)
			action_result.success = move_result.success
	elif prompt.has("interrupting_reaction"):
		var interrupting_reaction = prompt["interrupting_reaction"]
		var attacker: CombatantState = prompt["attacker"]
		combat_system.reaction_system.resolve_reaction(result, interrupting_reaction, attacker, reactor)
		if reactor.is_dying():
			action_result = ActionResult.failure("Movement was interrupted because the actor is Dying.")
		else:
			action_result = combat_system.action_system.execute(request, combat_system.combat_state)
	else:
		action_result = combat_system.action_system.execute(request, combat_system.combat_state)
	if bonus_applied:
		reactor.defense_bonus -= defense_bonus
	result.success = action_result.success
	result.failure_reason = action_result.failure_reason
	result.events.append_array(action_result.events)
	if prompt.has("prepared_attack") and not prompt.get("area_skill_continuation", false) and not prompt.get("area_action_continuation", false) and not prompt.get("attack_sequence_continuation", false):
		offer_step_back(request, prompt.get("attacker"), reactor, result)
		offer_mobile_shooter(request, prompt.get("attacker"), prompt.get("prepared_attack_data"), prompt.get("prepared_attack"), result)
	if prompt.get("reaction_queue_continuation", false):
		pending_action = request
		return continue_queue(result.events)
	if prompt.get("area_action_continuation", false) or prompt.get("area_skill_continuation", false):
		return combat_system.area_action_executor.resume_after_reaction(reactor, prompt.get("prepared_attack"), action_result.events, result.events)
	if prompt.get("attack_sequence_continuation", false):
		return combat_system.attack_sequence_executor.resume_after_reaction(result.events)
	if not combat_system.pending_active_ability_context.is_empty():
		var ability_events: Array[CombatEvent] = []
		combat_system.active_ability_executor.apply_pending_conditional_effects(result.events, ability_events)
		result.events.append_array(ability_events)
	combat_system.emit_events(result.events)
	combat_system.check_for_combat_end()
	return result


func resolve_damage_intervention_choice(request: ActionRequest, prompt: Dictionary, reaction) -> ActionResult:
	var result := ActionResult.success_result()
	var reactor: CombatantState = prompt.get("reactor")
	var attacker: CombatantState = prompt.get("attacker")
	var target: CombatantState = prompt.get("attack_target")
	var prepared: AttackResult = prompt.get("prepared_attack")
	var attack: AttackData = prompt.get("prepared_attack_data")
	if reactor == null or attacker == null or target == null or prepared == null or attack == null:
		return ActionResult.failure("The pending damage Reaction is no longer valid.")
	if reaction != null and not reactor.is_dying() and reactor.ap >= reaction.ap_cost and reactor.get_total_faith() >= reaction.faith_cost:
		var effect = combat_system.reaction_system.get_effect(reaction, ReactionEffectDataScript.Type.DAMAGE_MODIFIER)
		var faith_before := reactor.get_total_faith()
		var reduction: int = effect.amount if effect != null else 0
		if effect != null and effect.faith_divisor > 0:
			reduction += floori(float(faith_before) / float(effect.faith_divisor))
		if effect != null:
			reduction = maxi(effect.minimum_amount, reduction)
		reactor.spend_ap(reaction.ap_cost)
		reactor.spend_faith(reaction.faith_cost)
		prepared.reaction_damage_reduction += reduction
		combat_system.clear_hidden(reactor, "Reactive Ability used")
		result.events.append(CombatEvent.new(EventTypes.Type.REACTION_TRIGGERED, reactor.id, target.id, {"reaction_name": reaction.display_name, "damage_reduction": reduction, "faith_cost": reaction.faith_cost}))
		result.events.append(CombatEvent.new(EventTypes.Type.FAITH_CHANGED, reactor.id, reactor.id, {"ability_name": reaction.display_name, "faith_spent": reaction.faith_cost, "faith": reactor.faith, "temporary_faith": reactor.temporary_faith}))
	else:
		result.events.append(CombatEvent.new(EventTypes.Type.REACTION_DECLINED, reactor.id, target.id, {"reaction_name": reaction.display_name if reaction != null else "Divine Intervention"}))
	combat_system.attack_system.finalize_attack(attacker, target, attack, prepared)
	result.events.append_array(combat_system.action_system.build_attack_result(attacker, target, attack, prepared).events)
	if prompt.get("attack_sequence_continuation", false):
		return combat_system.attack_sequence_executor.resume_after_reaction(result.events)
	if not combat_system.pending_active_ability_context.is_empty():
		var ability_events: Array[CombatEvent] = []
		combat_system.active_ability_executor.apply_pending_conditional_effects(result.events, ability_events)
		result.events.append_array(ability_events)
	offer_step_back(request, attacker, target, result)
	offer_mobile_shooter(request, attacker, attack, prepared, result)
	combat_system.emit_events(result.events)
	combat_system.check_for_combat_end()
	return result
