class_name CombatSystem
extends RefCounted

const StatsSystemScript = preload("res://combat/stat/stat_system.gd")
const AbilitySystemScript = preload("res://combat/ability/ability_system.gd")
const MapRulesScript = preload("res://combat/map/map_rules.gd")
const TraitSystemScript = preload("res://combat/trait/trait_system.gd")
const ReactionSystemScript = preload("res://combat/reaction/reaction_system.gd")
const SkillSystemScript = preload("res://combat/skill/skill_system.gd")
const EquipmentSystemScript = preload("res://combat/equipment/equipment_system.gd")
const AncestrySystemScript = preload("res://combat/ancestry/ancestry_system.gd")
const ClassSystemScript = preload("res://combat/class/class_system.gd")
const ReactionEffectDataScript = preload("res://data/reaction/reaction_effect_data.gd")
const TargetingSystemScript = preload("res://combat/targeting/targeting_system.gd")
const SkillDataScript = preload("res://data/skill/skill_data.gd")
const AbilityUseEffectDataScript = preload("res://data/ability/ability_use_effect_data.gd")
const ResolutionContextScript = preload("res://combat/reaction/resolution_context.gd")
const AreaActionExecutorScript = preload("res://combat/targeting/area_action_executor.gd")
const ProgressionSystemScript = preload("res://combat/progression/progression_system.gd")

var combat_state: CombatState

var dice_system: DiceSystem
var attribute_system: AttributeSystem
var defense_system: DefenseSystem
var damage_system: DamageSystem
var effect_system: EffectSystem
var stat_system
var ability_system
var map_rules
var trait_system
var targeting_system

var attack_system: AttackSystem
var movement_system: MovementSystem
var initiative_system: InitiativeSystem

var turn_system: TurnSystem
var action_system: ActionSystem
var reaction_system
var skill_system
var equipment_system
var ancestry_system
var class_system
var progression_system

var event_system: EventSystem
var pending_action: ActionRequest
var pending_reaction: Dictionary = {}
var pending_reaction_queue: Array[Dictionary] = []
var area_action_executor
var pending_area_context:
	get:
		return area_action_executor.pending_context if area_action_executor != null else null
	set(value):
		if area_action_executor != null:
			area_action_executor.pending_context = value
var step_back_move_actor_id: String = ""
var step_back_move_distance_feet: float = 0.0
var pending_reaction_move_name: String = ""
var reaction_move_resumes_action: bool = false
var pending_defensive_reaction_move: Dictionary = {}
var ability_move_actor_id: String = ""
var ability_move_id: String = ""
var pending_active_ability_context: Dictionary = {}
var resolution_context


func _init() -> void:

	dice_system = DiceSystem.new()

	attribute_system = AttributeSystem.new()
	stat_system = StatsSystemScript.new()
	ability_system = AbilitySystemScript.new()
	map_rules = MapRulesScript.new()
	trait_system = TraitSystemScript.new()
	targeting_system = TargetingSystemScript.new()
	effect_system = EffectSystem.new()

	defense_system = DefenseSystem.new(effect_system)

	damage_system = DamageSystem.new(
		attribute_system,
		effect_system
	)

	attack_system = AttackSystem.new(
		dice_system,
		defense_system,
		damage_system,
		effect_system,
		ability_system,
		trait_system
	)

	movement_system = MovementSystem.new()
	movement_system.map_rules = map_rules
	movement_system.ability_system = ability_system
	attack_system.map_rules = map_rules

	initiative_system = InitiativeSystem.new(
		dice_system
	)

	turn_system = TurnSystem.new()
	skill_system = SkillSystemScript.new(ability_system)
	equipment_system = EquipmentSystemScript.new()
	ancestry_system = AncestrySystemScript.new()
	class_system = ClassSystemScript.new()
	progression_system = ProgressionSystemScript.new()

	action_system = ActionSystem.new(
		attack_system,
		movement_system,
		skill_system
	)
	reaction_system = ReactionSystemScript.new(
		attack_system,
		action_system,
		map_rules
	)

	event_system = EventSystem.new()
	resolution_context = ResolutionContextScript.new()
	area_action_executor = AreaActionExecutorScript.new(self)

func start_combat(
	combatants: Array[CombatantState]
) -> void:

	combat_state = CombatState.new()

	for combatant in combatants:
		combatant.last_attack_declared_round = 0
		combatant.last_step_back_round = 0
		ancestry_system.apply_ancestry(combatant)
		class_system.apply_class(combatant)
		if combatant.has_meta("class_data"):
			progression_system.initialize_character(combatant)
		ability_system.sync_granted_reactions(combatant)
		equipment_system.initialize_combatant(combatant)
		equipment_system.refresh_equipment(combatant)
		# Ancestry, Class and Equipment have now changed the derived stats, so
		# initialize resources only after every modifier has been applied.
		stat_system.initialize_combatant(combatant)
		if combatant.max_faith > 0:
			combatant.faith = combatant.max_faith
			combatant.temporary_faith = 0
		combat_state.add_combatant(
			combatant
		)

	combat_state.turn_order = \
		initiative_system.build_turn_order(
			combatants
		)

	if not combat_state.turn_order.is_empty():

		combat_state.current_actor_id = \
			combat_state.turn_order[0]

	event_system.emit(
		CombatEvent.new(
			EventTypes.Type.COMBAT_STARTED
		)
	)
	if not combat_state.current_actor_id.is_empty():
		start_current_turn()

func execute_action(
	request: ActionRequest
) -> ActionResult:

	if combat_state == null:
		return ActionResult.failure(
			"Combat has not started."
		)
	if combat_state.is_finished():
		return ActionResult.failure("Combat has already ended.")
	if has_pending_reaction():
		return ActionResult.failure("Choose whether to use the pending reaction first.")
	if has_pending_ability_movement():
		return ActionResult.failure("Choose the pending Ability movement destination first.")
	# Invalid movement must not trigger an Opportunity Attack. Otherwise the
	# reaction window opens first and the original Move silently fails afterward.
	if request.action_type == ActionTypes.Type.MOVE:
		request.target_position = movement_system.clamp_destination_to_remaining_speed(
			combat_state.get_combatant(request.actor_id),
			request.target_position,
			request.movement_data
		)
		var move_validation := action_system.validate(request, combat_state)
		if not move_validation.success:
			return move_validation

	if request.action_type == ActionTypes.Type.MOVE:
		pending_reaction_queue = reaction_system.collect_interruptions(request, combat_state)
		if not pending_reaction_queue.is_empty():
			pending_action = request
			return continue_reaction_queue()
	if request.action_type == ActionTypes.Type.ATTACK:
		var unarmed_validation: ActionResult = equipment_system.validate_unarmed_attack(combat_state.get_combatant(request.actor_id), request.attack_data)
		if not unarmed_validation.success:
			return unarmed_validation
		if request.attack_data != null and request.attack_data.thrown_item != null:
			var throw_validation: ActionResult = equipment_system.validate_throw(combat_state.get_combatant(request.actor_id), request.attack_data)
			if not throw_validation.success:
				return throw_validation
		@warning_ignore("confusable_local_declaration")
		var validation := action_system.validate(request, combat_state)
		if not validation.success:
			return validation
		var attacker: CombatantState = combat_state.get_combatant(request.actor_id)
		cancel_remaining_movement(attacker)
		var target: CombatantState = combat_state.get_combatant(request.target_id)
		var conditional_damage_bonuses: Array[Dictionary] = ability_system.get_conditional_damage_bonuses(attacker, target, request.attack_data, combat_state.current_round)
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
		target.last_attack_declared_round = combat_state.current_round
		var prepared: AttackResult = attack_system.resolve_attack(attacker, target, request.attack_data, true, conditional_damage_bonuses)
		if request.attack_data.thrown_item != null:
			var consumed: bool = equipment_system.consume_thrown_weapon(attacker, request.attack_data)
			ability_system.sync_granted_reactions(attacker)
			event_system.emit(CombatEvent.new(EventTypes.Type.EQUIPMENT_CHANGED, attacker.id, "", {"item_name": "%s (%s)" % [request.attack_data.thrown_item.display_name, "consumed by throw" if consumed else "Returning"]}))
		if attacker_was_hidden:
			attacker.remove_status("hidden")
			event_system.emit(CombatEvent.new(EventTypes.Type.EFFECT_EXPIRED, attacker.id, "", {"effect_name": "Hidden", "reason": "Attack declared"}))
		var post_prompt: Dictionary = reaction_system.get_post_hit_prompt(attacker, target, request.attack_data, prepared, combat_state.current_round)
		if not post_prompt.is_empty():
			if not open_reaction_prompt(request, post_prompt):
				attack_system.finalize_attack(attacker, target, request.attack_data, prepared)
				return action_system.build_attack_result(attacker, target, request.attack_data, prepared)
			var pending_result := ActionResult.success_result()
			pending_result.requires_reaction_choice = true
			pending_result.reaction_prompt = post_prompt
			for reaction in post_prompt["reactions"]:
				pending_result.events.append(CombatEvent.new(EventTypes.Type.REACTION_AVAILABLE, target.id, attacker.id, {"reaction_name": reaction.display_name}))
			emit_events(pending_result.events)
			if target.id == "player":
				return pending_result
			# Enemy AI currently selects the first legal defensive Reaction.
			return resolve_pending_reaction(0)
		var intervention_prompt: Dictionary = reaction_system.get_ally_damage_reaction_prompt(attacker, target, request.attack_data, prepared, combat_state)
		if not intervention_prompt.is_empty():
			if open_reaction_prompt(request, intervention_prompt):
				var intervention_result := ActionResult.success_result()
				intervention_result.requires_reaction_choice = true
				intervention_result.reaction_prompt = intervention_prompt
				for reaction in intervention_prompt["reactions"]:
					intervention_result.events.append(CombatEvent.new(EventTypes.Type.REACTION_AVAILABLE, intervention_prompt["reactor"].id, target.id, {"reaction_name": reaction.display_name}))
				emit_events(intervention_result.events)
				if intervention_prompt["reactor"].id == "player":
					return intervention_result
				return resolve_pending_reaction(0)
		attack_system.finalize_attack(attacker, target, request.attack_data, prepared)
		var prepared_result := action_system.build_attack_result(attacker, target, request.attack_data, prepared)
		offer_step_back(request, attacker, target, prepared_result)
		offer_mobile_shooter(request, attacker, request.attack_data, prepared, prepared_result)
		emit_events(prepared_result.events)
		check_for_combat_end()
		return prepared_result
	if request.action_type == ActionTypes.Type.SKILL:
		if request.skill_data != null and request.skill_data.target_mode == SkillDataScript.TargetMode.SELF:
			request.target_id = request.actor_id
		elif request.skill_data != null and request.skill_data.target_mode == SkillDataScript.TargetMode.GROUND:
			return ActionResult.failure("Ground-targeted Skills require a target point.")
		var skill_validation := action_system.validate(request, combat_state)
		if not skill_validation.success:
			return skill_validation
		var skill_actor: CombatantState = combat_state.get_combatant(request.actor_id)
		var skill_target: CombatantState = combat_state.get_combatant(request.target_id)
		cancel_remaining_movement(skill_actor)
		skill_system.consume_skill_costs(skill_actor, request.skill_data)
		var skill_attack: AttackData = skill_system.get_attack_data(request.skill_data)
		var skill_prepared: AttackResult = attack_system.resolve_attack(skill_actor, skill_target, skill_attack, true)
		clear_hidden(skill_actor, "Offensive Skill used")
		var skill_prompt: Dictionary = reaction_system.get_post_hit_prompt(skill_actor, skill_target, skill_attack, skill_prepared, combat_state.current_round)
		if not skill_prompt.is_empty():
			skill_prompt["skill_data"] = request.skill_data
			if not open_reaction_prompt(request, skill_prompt):
				attack_system.finalize_attack(skill_actor, skill_target, skill_attack, skill_prepared)
				return action_system.build_attack_result(skill_actor, skill_target, skill_attack, skill_prepared)
			var skill_pending := ActionResult.success_result()
			skill_pending.requires_reaction_choice = true
			skill_pending.reaction_prompt = skill_prompt
			for reaction in skill_prompt["reactions"]:
				skill_pending.events.append(CombatEvent.new(EventTypes.Type.REACTION_AVAILABLE, skill_target.id, skill_actor.id, {"reaction_name": reaction.display_name}))
			emit_events(skill_pending.events)
			if skill_target.id == "player":
				return skill_pending
			return resolve_pending_reaction(0)
		attack_system.finalize_attack(skill_actor, skill_target, skill_attack, skill_prepared)
		var skill_result := action_system.build_attack_result(skill_actor, skill_target, skill_attack, skill_prepared)
		skill_result.events.push_front(CombatEvent.new(EventTypes.Type.SKILL_CAST, skill_actor.id, skill_target.id, {"skill_name": request.skill_data.display_name, "mana_cost": request.skill_data.mana_cost, "cooldown": skill_system.get_effective_cooldown_turns(skill_actor, request.skill_data)}))
		offer_step_back(request, skill_actor, skill_target, skill_result)
		offer_mobile_shooter(request, skill_actor, skill_attack, skill_prepared, skill_result)
		emit_events(skill_result.events)
		check_for_combat_end()
		return skill_result

	var reaction_prompt: Dictionary = reaction_system.get_player_reaction_prompt(request, combat_state)
	if not reaction_prompt.is_empty():
		if not open_reaction_prompt(request, reaction_prompt):
			return action_system.execute(request, combat_state)
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
		emit_events(pending_result.events)
		return pending_result

	var validation := action_system.validate(request, combat_state)
	if not validation.success:
		return validation
	var actor: CombatantState = combat_state.get_combatant(request.actor_id)
	if request.action_type != ActionTypes.Type.MOVE:
		cancel_remaining_movement(actor)
	var result := action_system.execute(
		request,
		combat_state
	)
	if request.action_type == ActionTypes.Type.SKILL and result.success:
		clear_hidden(actor, "Offensive Skill used")

	emit_events(result.events)

	check_for_combat_end()

	return result


func cancel_remaining_movement(combatant: CombatantState) -> void:
	if combatant == null or not combatant.movement_in_progress:
		return
	combatant.movement_in_progress = false
	combatant.movement_remaining_feet = 0.0


func execute_ground_skill(combatant_id: String, skill_id: String, target_point: Vector2) -> ActionResult:
	return area_action_executor.execute_skill(combatant_id, skill_id, target_point)


func execute_ground_ability(combatant_id: String, ability_id: String, target_point: Vector2) -> ActionResult:
	return area_action_executor.execute_ability(combatant_id, ability_id, target_point)


func get_ground_skill(actor: CombatantState, skill_id: String):
	return area_action_executor.get_skill(actor, skill_id)


func validate_ground_skill_start(combatant_id: String, skill_id: String) -> ActionResult:
	return area_action_executor.validate_skill_start(combatant_id, skill_id)


func validate_ground_ability_start(combatant_id: String, ability_id: String) -> ActionResult:
	return area_action_executor.validate_ability_start(combatant_id, ability_id)


func continue_area_skill(carried_events: Array[CombatEvent] = []) -> ActionResult:
	return area_action_executor.continue_action(carried_events)


func continue_area_action(carried_events: Array[CombatEvent] = []) -> ActionResult:
	return area_action_executor.continue_action(carried_events)


func open_reaction_prompt(request: ActionRequest, prompt: Dictionary) -> bool:
	if resolution_context.root_action == null or (resolution_context.current_frame() == null and not has_pending_reaction() and pending_action == null):
		resolution_context.begin(request)
	var frame = resolution_context.open_frame(request, prompt)
	if frame == null:
		event_system.emit(CombatEvent.new(EventTypes.Type.ACTION_CANCELLED, request.actor_id if request != null else "", "", {"reason": "Reaction chain safety limit reached; further Reactions were skipped."}))
		return false
	prompt["reaction_frame_id"] = frame.id
	prompt["reaction_depth"] = frame.depth
	pending_action = request
	pending_reaction = prompt
	return true


func get_reaction_depth() -> int:
	return resolution_context.get_open_depth() if resolution_context != null else 0


func has_pending_reaction() -> bool:
	return pending_action != null and not pending_reaction.is_empty()


func continue_reaction_queue(carried_events: Array[CombatEvent] = []) -> ActionResult:
	var result := ActionResult.success_result()
	result.events.append_array(carried_events)
	while not pending_reaction_queue.is_empty():
		var item: Dictionary = pending_reaction_queue.pop_front()
		var reaction = item.get("reaction")
		var reactor: CombatantState = item.get("reactor")
		var trigger_actor: CombatantState = item.get("trigger_actor")
		if reaction == null or reactor == null or trigger_actor == null or reactor.is_dying() or trigger_actor.is_dying():
			continue
		if reactor.id == "player" and not item.get("approved", false):
			item["approved"] = true
			var opportunity_prompt := {"opportunity_choice": true, "reaction": reaction, "reactor": reactor, "attacker": trigger_actor, "queue_item": item}
			if not open_reaction_prompt(pending_action, opportunity_prompt):
				continue
			result.requires_reaction_choice = true
			result.reaction_prompt = pending_reaction
			result.events.append(CombatEvent.new(EventTypes.Type.REACTION_AVAILABLE, reactor.id, trigger_actor.id, {"reaction_name": reaction.display_name}))
			emit_events(result.events)
			return result
		var reaction_attack: AttackData = reaction_system.get_reaction_attack_data(reaction, reactor)
		var reaction_movement = reaction_system.get_effect(reaction, ReactionEffectDataScript.Type.MOVEMENT)
		if reaction_movement != null and reaction_attack == null:
			if not reactor.spend_ap(reaction.ap_cost):
				continue
			clear_hidden(reactor, "Reactive Ability used")
			step_back_move_actor_id = reactor.id
			step_back_move_distance_feet = reaction_movement.distance_feet if reaction_movement.distance_mode == ReactionEffectDataScript.DistanceMode.FIXED_FEET else reactor.get_effective_speed() * reaction_movement.speed_multiplier
			pending_reaction_move_name = reaction.display_name
			reaction_move_resumes_action = true
			result.events.append(CombatEvent.new(EventTypes.Type.REACTION_TRIGGERED, reactor.id, trigger_actor.id, {"reaction_name": reaction.display_name, "distance_feet": step_back_move_distance_feet, "resolved_from_queue": true}))
			emit_events(result.events)
			return result
		var validation := attack_system.validate_attack(reactor, trigger_actor, reaction_attack)
		if not validation.success:
			continue
		var prepared: AttackResult = attack_system.resolve_attack(reactor, trigger_actor, reaction_attack, true)
		clear_hidden(reactor, "Reactive Ability used")
		result.events.append(CombatEvent.new(EventTypes.Type.REACTION_TRIGGERED, reactor.id, trigger_actor.id, {"reaction_name": reaction.display_name, "resolved_from_queue": true}))
		var defense_prompt: Dictionary = reaction_system.get_post_hit_prompt(reactor, trigger_actor, reaction_attack, prepared, combat_state.current_round)
		if not defense_prompt.is_empty():
			if trigger_actor.id == "player":
				defense_prompt["reaction_queue_continuation"] = true
				if not open_reaction_prompt(pending_action, defense_prompt):
					attack_system.finalize_attack(reactor, trigger_actor, reaction_attack, prepared)
					result.events.append_array(action_system.build_attack_result(reactor, trigger_actor, reaction_attack, prepared).events)
					continue
				result.requires_reaction_choice = true
				result.reaction_prompt = defense_prompt
				for available_reaction in defense_prompt["reactions"]:
					result.events.append(CombatEvent.new(EventTypes.Type.REACTION_AVAILABLE, trigger_actor.id, reactor.id, {"reaction_name": available_reaction.display_name}))
				emit_events(result.events)
				return result
			apply_ai_defensive_reaction(defense_prompt, 0, result)
		attack_system.finalize_attack(reactor, trigger_actor, reaction_attack, prepared)
		result.events.append_array(action_system.build_attack_result(reactor, trigger_actor, reaction_attack, prepared).events)
		if trigger_actor.is_dying():
			pending_reaction_queue.clear()
			pending_action = null
			result.success = false
			result.failure_reason = "The original Action was interrupted because its actor is Dying."
			emit_events(result.events)
			check_for_combat_end()
			return result
	var resumed_action := pending_action
	pending_action = null
	if resumed_action != null:
		var resumed_result := action_system.execute(resumed_action, combat_state)
		result.success = resumed_result.success
		result.failure_reason = resumed_result.failure_reason
		result.events.append_array(resumed_result.events)
	emit_events(result.events)
	check_for_combat_end()
	return result


func apply_ai_defensive_reaction(prompt: Dictionary, reaction_index: int, result: ActionResult) -> void:
	var reactions: Array = prompt.get("reactions", [])
	if reaction_index < 0 or reaction_index >= reactions.size():
		return
	var reaction = reactions[reaction_index]
	var reactor: CombatantState = prompt.get("reactor")
	var prepared: AttackResult = prompt.get("prepared_attack")
	if reactor == null or prepared == null:
		return
	if reaction.uses_per_round > 0 and int(reactor.reaction_last_used_round.get(reaction.id, 0)) == combat_state.current_round:
		return
	var movement_effect = reaction_system.get_effect(reaction, ReactionEffectDataScript.Type.MOVEMENT)
	if movement_effect != null:
		var attacker: CombatantState = prompt.get("attacker")
		var distance_feet: float = movement_effect.distance_feet if movement_effect.distance_mode == ReactionEffectDataScript.DistanceMode.FIXED_FEET else reactor.get_effective_speed() * movement_effect.speed_multiplier
		var destination := choose_ai_reaction_destination(reactor, attacker, distance_feet)
		if destination == reactor.position or not reactor.spend_ap(reaction.ap_cost):
			return
		var origin := reactor.position
		reactor.position = destination
		reactor.reaction_last_used_round[reaction.id] = combat_state.current_round
		var attack: AttackData = prompt.get("prepared_attack_data")
		if attack != null and attacker != null and not map_rules.is_target_in_range(attacker, reactor, attack.range_feet):
			prepared.hit = false
			prepared.deferred = false
		result.events.append(CombatEvent.new(EventTypes.Type.REACTION_TRIGGERED, reactor.id, attacker.id if attacker != null else "", {"reaction_name": reaction.display_name, "selected_by_ai": true, "distance_feet": origin.distance_to(destination) / map_rules.world_units_per_foot}))
		result.events.append(CombatEvent.new(EventTypes.Type.POSITION_CHANGED, reactor.id, "", {"from": origin, "to": destination, "distance_feet": origin.distance_to(destination) / map_rules.world_units_per_foot, "reaction_name": reaction.display_name}))
		return
	if not reactor.spend_ap(reaction.ap_cost):
		return
	reactor.reaction_last_used_round[reaction.id] = combat_state.current_round
	var defense_bonus: int = reaction_system.get_defense_bonus(reaction)
	if reaction_system.get_effect(reaction, ReactionEffectDataScript.Type.TURN_HIT_TO_MISS) != null:
		prepared.hit = false
		prepared.deferred = false
	else:
		prepared.defense = prepared.original_defense + defense_bonus
		prepared.margin = prepared.roll + prepared.attack_modifier - prepared.defense
		prepared.hit = prepared.margin >= 0
	result.events.append(CombatEvent.new(EventTypes.Type.REACTION_TRIGGERED, reactor.id, prompt.get("attacker").id, {"reaction_name": reaction.display_name, "defense_bonus": defense_bonus, "selected_by_ai": true}))


func choose_ai_reaction_destination(reactor: CombatantState, attacker: CombatantState, distance_feet: float) -> Vector2:
	if reactor == null or attacker == null or distance_feet <= 0.0 or reactor.has_status("rooted"):
		return reactor.position if reactor != null else Vector2.ZERO
	var distance_world: float = distance_feet * map_rules.world_units_per_foot
	var away := attacker.position.direction_to(reactor.position)
	if away.is_zero_approx():
		away = Vector2.RIGHT
	var best := reactor.position
	var best_distance := reactor.position.distance_squared_to(attacker.position)
	for degrees in [0.0, 45.0, -45.0, 90.0, -90.0, 135.0, -135.0]:
		var candidate := reactor.position + away.rotated(deg_to_rad(degrees)) * distance_world
		if candidate.distance_squared_to(attacker.position) <= best_distance:
			continue
		if map_rules.validate_movement_path(reactor, candidate, combat_state.combatants).success:
			best = candidate
			best_distance = candidate.distance_squared_to(attacker.position)
	return best


func has_pending_step_back_move() -> bool:
	return not step_back_move_actor_id.is_empty() and step_back_move_distance_feet > 0.0


func has_pending_ability_movement() -> bool:
	return not ability_move_actor_id.is_empty() and not ability_move_id.is_empty()


func begin_ability_movement(combatant_id: String, ability_id: String) -> ActionResult:
	if combat_state == null or combat_state.is_finished():
		return ActionResult.failure("Combat is not active.")
	if has_pending_reaction() or has_pending_step_back_move() or has_pending_ability_movement():
		return ActionResult.failure("Finish the pending choice first.")
	var actor: CombatantState = combat_state.get_combatant(combatant_id)
	if actor == null or combat_state.current_actor_id != combatant_id:
		return ActionResult.failure("This Ability can only be used during the character's turn.")
	var ability = ability_system.get_available_ability(actor, ability_id)
	var validation: ActionResult = ability_system.validate_active_use(actor, ability, actor)
	if not validation.success:
		return validation
	var movement_effect = ability_system.get_movement_effect(ability)
	if movement_effect == null or movement_effect.movement_distance_feet <= 0.0:
		return ActionResult.failure("This Ability does not provide movement.")
	if actor.has_status("rooted"):
		return ActionResult.failure("Rooted characters cannot Move.")
	ability_move_actor_id = actor.id
	ability_move_id = ability.id
	return ActionResult.success_result()


func execute_pending_ability_movement(destination: Vector2) -> ActionResult:
	if not has_pending_ability_movement():
		return ActionResult.failure("There is no Ability movement waiting for a destination.")
	var actor: CombatantState = combat_state.get_combatant(ability_move_actor_id)
	var ability = ability_system.get_available_ability(actor, ability_move_id) if actor != null else null
	var movement_effect = ability_system.get_movement_effect(ability)
	if actor == null or ability == null or movement_effect == null or actor.is_dying() or actor.has_status("rooted"):
		ability_move_actor_id = ""
		ability_move_id = ""
		return ActionResult.failure("The character cannot complete this movement.")
	var maximum_distance: float = movement_effect.movement_distance_feet * map_rules.world_units_per_foot
	var clamped_destination := destination
	if actor.position.distance_to(destination) > maximum_distance:
		clamped_destination = actor.position + actor.position.direction_to(destination) * maximum_distance
	var validation: ActionResult = map_rules.validate_movement_path(actor, clamped_destination, combat_state.combatants)
	if not validation.success:
		return validation
	if not actor.spend_ap(ability.ap_cost):
		return ActionResult.failure("Not enough AP.")
	cancel_remaining_movement(actor)
	var origin := actor.position
	actor.position = clamped_destination
	actor.ability_uses_this_turn[ability.id] = int(actor.ability_uses_this_turn.get(ability.id, 0)) + 1
	ability_system.start_cooldown(actor, ability)
	ability_move_actor_id = ""
	ability_move_id = ""
	var result := ActionResult.success_result()
	var event_data := {"ability_name": ability.display_name, "triggers_reactions": movement_effect.movement_triggers_reactions}
	result.events.append(CombatEvent.new(EventTypes.Type.ABILITY_TRIGGERED, actor.id, "", event_data))
	result.events.append(CombatEvent.new(EventTypes.Type.MOVE_STARTED, actor.id, "", event_data))
	result.events.append(CombatEvent.new(EventTypes.Type.POSITION_CHANGED, actor.id, "", {"from": origin, "to": actor.position, "distance": origin.distance_to(actor.position), "distance_feet": origin.distance_to(actor.position) / map_rules.world_units_per_foot, "remaining_speed_feet": 0.0, "ability_name": ability.display_name}))
	result.events.append(CombatEvent.new(EventTypes.Type.MOVE_COMPLETED, actor.id, "", event_data))
	emit_events(result.events)
	return result


func use_weapon_ability(combatant_id: String, target_id: String, ability_id: String) -> ActionResult:
	return use_active_ability(combatant_id, target_id, ability_id)


func use_active_ability(combatant_id: String, target_id: String, ability_id: String) -> ActionResult:
	if combat_state == null or combat_state.is_finished():
		return ActionResult.failure("Combat is not active.")
	if has_pending_reaction() or has_pending_step_back_move() or has_pending_ability_movement():
		return ActionResult.failure("Finish the pending choice first.")
	var actor: CombatantState = combat_state.get_combatant(combatant_id)
	if actor == null or combat_state.current_actor_id != combatant_id:
		return ActionResult.failure("This Ability can only be used during the character's turn.")
	var ability = ability_system.get_available_ability(actor, ability_id)
	if ability != null and ability.target_mode == AbilityData.TargetMode.SELF and ability.area_shape == AbilityData.AreaShape.CIRCLE:
		return execute_ground_ability(combatant_id, ability_id, actor.position)
	var target: CombatantState = actor if ability != null and ability.target_mode == AbilityData.TargetMode.SELF else combat_state.get_combatant(target_id)
	var validation: ActionResult = ability_system.validate_active_use(actor, ability, target)
	if not validation.success:
		return validation
	if ability.target_mode == AbilityData.TargetMode.SINGLE_COMBATANT \
		and ability.targeting_range_feet > 0.0 \
		and not map_rules.is_target_in_range(actor, target, ability.targeting_range_feet):
		return ActionResult.failure("Target is out of range.")
	if ability.target_mode == AbilityData.TargetMode.SINGLE_COMBATANT \
		and ability.requires_line_of_sight \
		and not map_rules.has_line_of_sight(actor.position, target.position):
		return ActionResult.failure("Line of sight to the target is blocked.")
	var source_attack: AttackData = ability_system.get_attack_data(actor, ability)
	var result: ActionResult
	if source_attack != null:
		var ability_attack: AttackData = source_attack.duplicate()
		ability_attack.ap_cost = ability.ap_cost
		ability_attack.active_damage_bonus = ability.active_attack_flat_damage_bonus + ability.active_attack_damage_bonus_per_level * actor.level
		ability_attack.active_damage_bonus_source = ability.display_name
		var request := ActionRequest.new(combatant_id, ActionTypes.Type.ATTACK)
		request.target_id = target.id
		request.attack_data = ability_attack
		result = execute_action(request)
		if result.success and not actor.spend_faith(ability.faith_cost):
			# Active-use validation checks Faith before the Attack starts. Keep this
			# guard in case another resolver changes the resource unexpectedly.
			return ActionResult.failure("Not enough Faith.")
	else:
		if not actor.spend_ap(ability.ap_cost):
			return ActionResult.failure("Not enough AP.")
		if not actor.spend_faith(ability.faith_cost):
			actor.change_ap(ability.ap_cost)
			return ActionResult.failure("Not enough Faith.")
		cancel_remaining_movement(actor)
		result = ActionResult.success_result()
	if not result.success:
		return result
	actor.ability_uses_this_turn[ability.id] = int(actor.ability_uses_this_turn.get(ability.id, 0)) + 1
	var cooldown: int = ability_system.start_cooldown(actor, ability)
	var ability_events: Array[CombatEvent] = []
	if ability.faith_cost > 0:
		ability_events.append(CombatEvent.new(EventTypes.Type.FAITH_CHANGED, actor.id, actor.id, {
			"ability_name": ability.display_name,
			"faith_spent": ability.faith_cost,
			"faith": actor.faith,
			"temporary_faith": actor.temporary_faith,
		}))
	var defer_conditional: bool = result.requires_reaction_choice and result.reaction_prompt.has("prepared_attack")
	apply_active_ability_effects(actor, target, ability, result.events, ability_events, true, not defer_conditional)
	ability_events.push_front(CombatEvent.new(EventTypes.Type.ABILITY_TRIGGERED, actor.id, target_id, {"ability_name": ability.display_name, "ap_cost": ability.ap_cost, "cooldown": cooldown}))
	result.events.append_array(ability_events)
	emit_events(ability_events)
	if defer_conditional:
		pending_active_ability_context = {"actor": actor, "target": target, "ability": ability}
	return result


func apply_active_ability_effects(actor: CombatantState, target: CombatantState, ability, attack_events: Array[CombatEvent], output_events: Array[CombatEvent], include_always: bool = true, include_conditional: bool = true) -> void:
	var hit := attack_events.any(func(event): return event.type == EventTypes.Type.ATTACK_HIT)
	var missed := attack_events.any(func(event): return event.type == EventTypes.Type.ATTACK_MISS)
	for entry in ability_system.get_use_effects(ability):
		if entry == null:
			continue
		if entry.timing == AbilityUseEffectDataScript.Timing.ALWAYS and not include_always:
			continue
		if entry.timing != AbilityUseEffectDataScript.Timing.ALWAYS and not include_conditional:
			continue
		if entry.timing == AbilityUseEffectDataScript.Timing.ON_HIT and not hit:
			continue
		if entry.timing == AbilityUseEffectDataScript.Timing.ON_MISS and not missed:
			continue
		if entry.dynamic_effect != AbilityUseEffectDataScript.DynamicEffect.NONE:
			apply_dynamic_ability_effect(actor, target, ability, entry, output_events)
			continue
		var recipient: CombatantState = actor if entry.recipient == AbilityUseEffectDataScript.Recipient.CASTER else target
		var applied_effect: EffectData = build_scaled_ability_effect(actor, entry)
		if applied_effect != null and recipient != null and effect_system.apply_effect(recipient, applied_effect):
			output_events.append(CombatEvent.new(EventTypes.Type.EFFECT_APPLIED, actor.id, recipient.id, {"effect_name": applied_effect.display_name, "ability_name": ability.display_name}))


func build_scaled_ability_effect(actor: CombatantState, entry) -> EffectData:
	if entry == null or entry.effect == null:
		return null
	if not entry.scale_stat_bonuses_with_attribute:
		return entry.effect
	var scaled: EffectData = entry.effect.duplicate(true)
	var amount: int = actor.get_attribute_modifier(entry.scaling_attribute) * entry.scaling_multiplier
	if entry.scale_reflex_bonus:
		scaled.reflex_bonus += amount
	if entry.scale_fortitude_bonus:
		scaled.fortitude_bonus += amount
	if entry.scale_will_bonus:
		scaled.will_bonus += amount
	return scaled


func apply_dynamic_ability_effect(actor: CombatantState, target: CombatantState, ability, entry, output_events: Array[CombatEvent]) -> void:
	match entry.dynamic_effect:
		AbilityUseEffectDataScript.DynamicEffect.GAIN_FAITH_FROM_WISDOM_MODIFIER:
			var amount := maxi(0, actor.get_modifier(actor.wisdom))
			var gained := actor.gain_faith(amount)
			output_events.append(CombatEvent.new(EventTypes.Type.FAITH_CHANGED, actor.id, actor.id, {
				"ability_name": ability.display_name,
				"faith_gained": gained.faith,
				"temporary_faith_gained": gained.temporary_faith,
				"faith": actor.faith,
				"temporary_faith": actor.temporary_faith,
			}))
		AbilityUseEffectDataScript.DynamicEffect.HEAL_OR_HARM_BY_FAITH:
			if target == null:
				return
			var power := actor.get_total_faith()
			if actor.team == target.team:
				var healed := target.heal(power)
				output_events.append(CombatEvent.new(EventTypes.Type.EFFECT_HEAL_APPLIED, actor.id, target.id, {"effect_name": ability.display_name, "amount": healed, "faith_power": power}))
			else:
				var harm_power := floori(float(power) / 2.0)
				var immune := target.is_immune_to_damage(entry.damage_type)
				var resistance := target.get_damage_resistance(entry.damage_type)
				var damage := 0 if immune else maxi(0, harm_power - resistance)
				target.apply_damage(damage)
				output_events.append(CombatEvent.new(EventTypes.Type.DAMAGE_APPLIED, actor.id, target.id, {"ability_name": ability.display_name, "damage": damage, "damage_type": entry.damage_type, "faith_power": power, "harm_power": harm_power, "immune": immune, "resistance": resistance}))
		AbilityUseEffectDataScript.DynamicEffect.SMITE_LIGHT_BY_FAITH:
			if target == null:
				return
			# Smite is declared using the Faith available before its activation cost,
			# consistent with other Faith-scaled abilities such as Shared Blessing.
			var faith_power: int = actor.get_total_faith() + int(ability.faith_cost)
			var smite_power := floori(float(faith_power) / 2.0)
			var immune := target.is_immune_to_damage(entry.damage_type)
			var resistance := target.get_damage_resistance(entry.damage_type)
			var damage := 0 if immune else maxi(0, smite_power - resistance)
			target.apply_damage(damage)
			output_events.append(CombatEvent.new(EventTypes.Type.DAMAGE_APPLIED, actor.id, target.id, {"ability_name": ability.display_name, "damage": damage, "damage_type": entry.damage_type, "faith_power": faith_power, "smite_power": smite_power, "immune": immune, "resistance": resistance}))
		AbilityUseEffectDataScript.DynamicEffect.HEAL_BY_FAITH:
			if target == null or target.is_dying():
				return
			var faith_before_cost: int = actor.get_total_faith() + ability.faith_cost
			var healing: int = floori(float(faith_before_cost) / float(maxi(1, entry.faith_divisor)))
			var healed := target.heal(healing)
			output_events.append(CombatEvent.new(EventTypes.Type.EFFECT_HEAL_APPLIED, actor.id, target.id, {"effect_name": ability.display_name, "amount": healed, "faith_power": faith_before_cost}))


func offer_step_back(request: ActionRequest, attacker: CombatantState, target: CombatantState, result: ActionResult) -> void:
	if request == null or attacker == null or target == null or target.id != "player":
		return
	var reactions: Array = reaction_system.get_post_attack_reactions(attacker, target, combat_state.current_round)
	if reactions.is_empty():
		return
	var reaction = reactions[0]
	var movement_effect = reaction_system.get_effect(reaction, ReactionEffectDataScript.Type.MOVEMENT)
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
	if not open_reaction_prompt(request, prompt):
		return
	result.requires_reaction_choice = true
	result.reaction_prompt = prompt
	result.events.append(CombatEvent.new(EventTypes.Type.REACTION_AVAILABLE, target.id, attacker.id, {"reaction_name": reaction.display_name}))


func offer_mobile_shooter(request: ActionRequest, attacker: CombatantState, attack: AttackData, attack_result: AttackResult, result: ActionResult) -> void:
	if request == null or attacker == null or attacker.id != "player" or result.requires_reaction_choice:
		return
	var reactions: Array = reaction_system.get_post_ranged_hit_reactions(attacker, attack, attack_result.hit)
	if reactions.is_empty():
		return
	var reaction = reactions[0]
	var movement_effect = reaction_system.get_effect(reaction, ReactionEffectDataScript.Type.MOVEMENT)
	if movement_effect == null or attacker.has_status("rooted"):
		return
	# The first qualifying hit is the trigger; declining does not defer the limit.
	attacker.ability_uses_this_turn[reaction.id] = 1
	var prompt := {"step_back": true, "post_attack_reaction": true, "reactor": attacker, "attacker": attacker, "reaction": reaction, "distance_feet": movement_effect.distance_feet, "movement_effect": movement_effect}
	if not open_reaction_prompt(request, prompt):
		return
	result.requires_reaction_choice = true
	result.reaction_prompt = prompt
	result.events.append(CombatEvent.new(EventTypes.Type.REACTION_AVAILABLE, attacker.id, "", {"reaction_name": reaction.display_name}))


func resolve_pending_reaction(reaction_index: int) -> ActionResult:
	if not has_pending_reaction():
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
			clear_hidden(step_reactor, "Reactive Ability used")
			step_reactor.reaction_last_used_round[step_reaction.id] = combat_state.current_round
			if step_reaction.id == "step_back":
				step_reactor.last_step_back_round = combat_state.current_round
			step_back_move_actor_id = step_reactor.id
			step_back_move_distance_feet = float(prompt.get("distance_feet", 0.0))
			pending_reaction_move_name = step_reaction.display_name
			step_result.events.append(CombatEvent.new(EventTypes.Type.REACTION_TRIGGERED, step_reactor.id, request.actor_id, {"reaction_name": step_reaction.display_name, "distance_feet": step_back_move_distance_feet}))
		else:
			step_result.events.append(CombatEvent.new(EventTypes.Type.REACTION_DECLINED, step_reactor.id if step_reactor != null else "", request.actor_id, {"reaction_name": step_reaction.display_name if step_reaction != null else "Post-attack Reaction"}))
		emit_events(step_result.events)
		return step_result
	if prompt.get("opportunity_choice", false):
		pending_action = request
		var opportunity_reactor: CombatantState = prompt.get("reactor")
		var opportunity_reaction = prompt.get("reaction")
		var choice_events: Array[CombatEvent] = []
		if reaction_index >= 0 and opportunity_reactor != null and opportunity_reaction != null:
			pending_reaction_queue.push_front(prompt.get("queue_item", {}))
		else:
			choice_events.append(CombatEvent.new(EventTypes.Type.REACTION_DECLINED, opportunity_reactor.id if opportunity_reactor != null else "", request.actor_id, {"reaction_name": opportunity_reaction.display_name if opportunity_reaction != null else "Opportunity Attack"}))
		return continue_reaction_queue(choice_events)
	var reactor: CombatantState = prompt["reactor"]
	var reactions: Array = prompt.get("reactions", [])
	if reactions.is_empty() and prompt.has("reaction"):
		reactions.append(prompt["reaction"])
	var reaction = reactions[reaction_index] if reaction_index >= 0 and reaction_index < reactions.size() else null
	var result := ActionResult.success_result()
	var bonus_applied := false
	var movement_applied := false
	var defense_bonus: int = reaction_system.get_defense_bonus(reaction)
	var movement_effect = reaction_system.get_effect(reaction, ReactionEffectDataScript.Type.MOVEMENT)
	var movement_completed: bool = bool(prompt.get("movement_completed", false))
	if movement_completed:
		reaction = prompt.get("resolved_reaction")
		movement_effect = reaction_system.get_effect(reaction, ReactionEffectDataScript.Type.MOVEMENT)
		movement_applied = true

	if movement_completed:
		pass
	elif reaction != null and reactor != null and reactor.id == "player" and not reactor.is_dying() and movement_effect != null:
		if not reactor.spend_ap(reaction.ap_cost):
			return ActionResult.failure("Not enough AP.")
		clear_hidden(reactor, "Reactive Ability used")
		reactor.reaction_last_used_round[reaction.id] = combat_state.current_round
		step_back_move_actor_id = reactor.id
		step_back_move_distance_feet = movement_effect.distance_feet if movement_effect.distance_mode == ReactionEffectDataScript.DistanceMode.FIXED_FEET else reactor.get_effective_speed() * movement_effect.speed_multiplier
		pending_reaction_move_name = reaction.display_name
		pending_defensive_reaction_move = {"request": request, "prompt": prompt, "reaction": reaction}
		result.events.append(CombatEvent.new(EventTypes.Type.REACTION_TRIGGERED, reactor.id, request.actor_id, {"reaction_name": reaction.display_name, "distance_feet": step_back_move_distance_feet}))
		emit_events(result.events)
		return result
	elif reaction != null and reactor != null and reactor.id != "player" and not reactor.is_dying() and movement_effect != null:
		var reaction_attacker: CombatantState = prompt.get("attacker")
		var distance_feet: float = movement_effect.distance_feet if movement_effect.distance_mode == ReactionEffectDataScript.DistanceMode.FIXED_FEET else reactor.get_effective_speed() * movement_effect.speed_multiplier
		var destination := choose_ai_reaction_destination(reactor, reaction_attacker, distance_feet)
		if destination != reactor.position and reactor.spend_ap(reaction.ap_cost):
			var origin := reactor.position
			reactor.position = destination
			reactor.reaction_last_used_round[reaction.id] = combat_state.current_round
			movement_applied = true
			clear_hidden(reactor, "Reactive Ability used")
			result.events.append(CombatEvent.new(EventTypes.Type.REACTION_TRIGGERED, reactor.id, request.actor_id, {"reaction_name": reaction.display_name, "selected_by_ai": true, "distance_feet": origin.distance_to(destination) / map_rules.world_units_per_foot}))
			result.events.append(CombatEvent.new(EventTypes.Type.POSITION_CHANGED, reactor.id, "", {"from": origin, "to": destination, "distance_feet": origin.distance_to(destination) / map_rules.world_units_per_foot, "reaction_name": reaction.display_name}))
	elif reaction != null and reactor != null and not reactor.is_dying() and reactor.spend_ap(reaction.ap_cost):
		if ability_system.ability_has_trait(reaction, "reactive") or reaction_has_trait(reaction, "reactive"):
			clear_hidden(reactor, "Reactive Ability used")
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
			if reaction_system.get_effect(reaction, ReactionEffectDataScript.Type.TURN_HIT_TO_MISS) != null:
				prepared.hit = false
				prepared.deferred = false
			else:
				prepared.defense = prepared.original_defense + defense_bonus
				prepared.margin = prepared.roll + prepared.attack_modifier - prepared.defense
				prepared.hit = prepared.margin >= 0
		elif movement_applied and not map_rules.is_target_in_range(prepared_attacker, reactor, prepared_attack.range_feet):
			prepared.hit = false
			prepared.deferred = false
		if prepared.hit:
			var intervention_prompt: Dictionary = reaction_system.get_ally_damage_reaction_prompt(prepared_attacker, reactor, prepared_attack, prepared, combat_state)
			if not intervention_prompt.is_empty() and open_reaction_prompt(request, intervention_prompt):
				result.requires_reaction_choice = true
				result.reaction_prompt = intervention_prompt
				for available_reaction in intervention_prompt["reactions"]:
					result.events.append(CombatEvent.new(EventTypes.Type.REACTION_AVAILABLE, intervention_prompt["reactor"].id, reactor.id, {"reaction_name": available_reaction.display_name}))
				emit_events(result.events)
				return result
			attack_system.finalize_attack(prepared_attacker, reactor, prepared_attack, prepared)
		else:
			prepared.deferred = false
		action_result = action_system.build_attack_result(prepared_attacker, reactor, prepared_attack, prepared)
		if prompt.has("skill_data") and not prompt.get("area_skill_continuation", false) and not prompt.get("area_action_continuation", false):
			var resolved_skill = prompt["skill_data"]
			action_result.events.push_front(CombatEvent.new(EventTypes.Type.SKILL_CAST, prepared_attacker.id, reactor.id, {"skill_name": resolved_skill.display_name, "mana_cost": resolved_skill.mana_cost, "cooldown": skill_system.get_effective_cooldown_turns(prepared_attacker, resolved_skill)}))
		if prompt.has("opportunity_attack") and not reactor.is_dying():
			var move_result := action_system.execute(request, combat_state)
			action_result.events.append_array(move_result.events)
			action_result.success = move_result.success
	elif prompt.has("interrupting_reaction"):
		var interrupting_reaction = prompt["interrupting_reaction"]
		var attacker: CombatantState = prompt["attacker"]
		reaction_system.resolve_reaction(result, interrupting_reaction, attacker, reactor)
		if reactor.is_dying():
			action_result = ActionResult.failure("Movement was interrupted because the actor is Dying.")
		else:
			action_result = action_system.execute(request, combat_state)
	else:
		action_result = action_system.execute(request, combat_state)
	if bonus_applied:
		reactor.defense_bonus -= defense_bonus
	result.success = action_result.success
	result.failure_reason = action_result.failure_reason
	result.events.append_array(action_result.events)
	if prompt.has("prepared_attack") and not prompt.get("area_skill_continuation", false) and not prompt.get("area_action_continuation", false):
		offer_step_back(request, prompt.get("attacker"), reactor, result)
		offer_mobile_shooter(request, prompt.get("attacker"), prompt.get("prepared_attack_data"), prompt.get("prepared_attack"), result)
	if prompt.get("reaction_queue_continuation", false):
		pending_action = request
		return continue_reaction_queue(result.events)
	if prompt.get("area_action_continuation", false) or prompt.get("area_skill_continuation", false):
		return area_action_executor.resume_after_reaction(reactor, prompt.get("prepared_attack"), action_result.events, result.events)
	if not pending_active_ability_context.is_empty():
		var ability_events: Array[CombatEvent] = []
		apply_active_ability_effects(
			pending_active_ability_context.get("actor"),
			pending_active_ability_context.get("target"),
			pending_active_ability_context.get("ability"),
			result.events,
			ability_events,
			false,
			true
		)
		pending_active_ability_context = {}
		result.events.append_array(ability_events)
	emit_events(result.events)
	check_for_combat_end()
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
		var effect = reaction_system.get_effect(reaction, ReactionEffectDataScript.Type.DAMAGE_MODIFIER)
		var faith_before := reactor.get_total_faith()
		var reduction: int = effect.amount if effect != null else 0
		if effect != null and effect.faith_divisor > 0:
			reduction += floori(float(faith_before) / float(effect.faith_divisor))
		if effect != null:
			reduction = maxi(effect.minimum_amount, reduction)
		reactor.spend_ap(reaction.ap_cost)
		reactor.spend_faith(reaction.faith_cost)
		prepared.reaction_damage_reduction += reduction
		clear_hidden(reactor, "Reactive Ability used")
		result.events.append(CombatEvent.new(EventTypes.Type.REACTION_TRIGGERED, reactor.id, target.id, {"reaction_name": reaction.display_name, "damage_reduction": reduction, "faith_cost": reaction.faith_cost}))
		result.events.append(CombatEvent.new(EventTypes.Type.FAITH_CHANGED, reactor.id, reactor.id, {"ability_name": reaction.display_name, "faith_spent": reaction.faith_cost, "faith": reactor.faith, "temporary_faith": reactor.temporary_faith}))
	else:
		result.events.append(CombatEvent.new(EventTypes.Type.REACTION_DECLINED, reactor.id, target.id, {"reaction_name": reaction.display_name if reaction != null else "Divine Intervention"}))
	attack_system.finalize_attack(attacker, target, attack, prepared)
	result.events.append_array(action_system.build_attack_result(attacker, target, attack, prepared).events)
	if not pending_active_ability_context.is_empty():
		var ability_events: Array[CombatEvent] = []
		apply_active_ability_effects(pending_active_ability_context.get("actor"), pending_active_ability_context.get("target"), pending_active_ability_context.get("ability"), result.events, ability_events, false, true)
		pending_active_ability_context = {}
		result.events.append_array(ability_events)
	offer_step_back(request, attacker, target, result)
	offer_mobile_shooter(request, attacker, attack, prepared, result)
	emit_events(result.events)
	check_for_combat_end()
	return result


func execute_step_back_move(destination: Vector2) -> ActionResult:
	if not has_pending_step_back_move():
		return ActionResult.failure("There is no Step Back movement waiting for a destination.")
	var actor: CombatantState = combat_state.get_combatant(step_back_move_actor_id)
	if actor == null or actor.is_dying():
		step_back_move_actor_id = ""
		step_back_move_distance_feet = 0.0
		return ActionResult.failure("The character cannot use Step Back.")
	var maximum_distance: float = step_back_move_distance_feet * map_rules.world_units_per_foot
	var clamped_destination: Vector2 = destination
	if actor.position.distance_to(destination) > maximum_distance:
		clamped_destination = actor.position + actor.position.direction_to(destination) * maximum_distance
	var validation: ActionResult = map_rules.validate_movement_path(actor, clamped_destination, combat_state.combatants)
	if not validation.success:
		return validation
	var origin: Vector2 = actor.position
	actor.position = clamped_destination
	var movement_name := pending_reaction_move_name if not pending_reaction_move_name.is_empty() else "Step Back"
	var resume_action := reaction_move_resumes_action
	step_back_move_actor_id = ""
	step_back_move_distance_feet = 0.0
	pending_reaction_move_name = ""
	reaction_move_resumes_action = false
	var result := ActionResult.success_result()
	result.events.append(CombatEvent.new(EventTypes.Type.MOVE_STARTED, actor.id, "", {"ability_name": movement_name}))
	result.events.append(CombatEvent.new(EventTypes.Type.POSITION_CHANGED, actor.id, "", {"from": origin, "to": actor.position, "distance": origin.distance_to(actor.position), "distance_feet": origin.distance_to(actor.position) / map_rules.world_units_per_foot, "remaining_speed_feet": 0.0, "ability_name": movement_name}))
	result.events.append(CombatEvent.new(EventTypes.Type.MOVE_COMPLETED, actor.id, "", {"ability_name": movement_name}))
	if not pending_defensive_reaction_move.is_empty():
		return finish_defensive_reaction_move(result.events)
	if resume_action:
		return continue_reaction_queue(result.events)
	emit_events(result.events)
	return result


func cancel_step_back_move() -> ActionResult:
	if not has_pending_step_back_move():
		return ActionResult.failure("There is no Reaction movement to cancel.")
	step_back_move_actor_id = ""
	step_back_move_distance_feet = 0.0
	pending_reaction_move_name = ""
	reaction_move_resumes_action = false
	if not pending_defensive_reaction_move.is_empty():
		return finish_defensive_reaction_move([])
	return ActionResult.success_result()


func finish_defensive_reaction_move(movement_events: Array[CombatEvent]) -> ActionResult:
	var context := pending_defensive_reaction_move
	pending_defensive_reaction_move = {}
	var request: ActionRequest = context.get("request")
	var prompt: Dictionary = context.get("prompt", {})
	prompt["movement_completed"] = true
	prompt["resolved_reaction"] = context.get("reaction")
	pending_action = request
	pending_reaction = prompt
	if not movement_events.is_empty():
		emit_events(movement_events)
	var resumed := resolve_pending_reaction(-1)
	var combined_events: Array[CombatEvent] = []
	combined_events.append_array(movement_events)
	combined_events.append_array(resumed.events)
	resumed.events = combined_events
	return resumed


func emit_events(events: Array[CombatEvent]) -> void:
	for event in events:
		event_system.emit(event)

func get_combat_state() -> CombatState:
	return combat_state


func refresh_stats(combatant: CombatantState) -> void:
	stat_system.refresh_combatant(combatant)


func toggle_ability(combatant_id: String, ability_id: String) -> ActionResult:
	if combat_state == null:
		return ActionResult.failure("Combat has not started.")
	if has_pending_ability_movement():
		return ActionResult.failure("Choose the pending Ability movement destination first.")

	var combatant := combat_state.get_combatant(combatant_id)
	if combatant == null:
		return ActionResult.failure("Combatant does not exist.")
	if combat_state.is_finished() or combat_state.current_actor_id != combatant.id:
		return ActionResult.failure("Abilities can only be changed during this character's turn.")
	var result: ActionResult = ability_system.toggle_ability(combatant, ability_id)
	if result.success:
		ability_system.sync_granted_reactions(combatant)
		cancel_remaining_movement(combatant)
	return result


func toggle_equipment(combatant_id: String, item, target_slot: int = -1) -> ActionResult:
	if combat_state == null:
		return ActionResult.failure("Combat has not started.")
	if has_pending_reaction() or has_pending_ability_movement():
		return ActionResult.failure("Equipment cannot be changed while a Reaction is pending.")
	var combatant := combat_state.get_combatant(combatant_id)
	if combatant == null:
		return ActionResult.failure("Combatant does not exist.")
	if combat_state.is_finished() or combat_state.current_actor_id != combatant.id:
		return ActionResult.failure("Equipment can only be changed during this character's turn.")
	var result: ActionResult = equipment_system.toggle_equipment(combatant, item, target_slot)
	if result.success:
		cancel_remaining_movement(combatant)
		equipment_system.refresh_equipment(combatant)
		stat_system.refresh_combatant(combatant)
		result.events.append(CombatEvent.new(EventTypes.Type.EQUIPMENT_CHANGED, combatant.id, "", {"item_name": item.display_name}))
	return result


func set_active_weapon_slot(combatant_id: String, target_slot: int) -> ActionResult:
	if combat_state == null:
		return ActionResult.failure("Combat has not started.")
	if has_pending_reaction() or has_pending_ability_movement():
		return ActionResult.failure("Weapon cannot be changed while a Reaction is pending.")
	var combatant := combat_state.get_combatant(combatant_id)
	if combatant == null:
		return ActionResult.failure("Combatant does not exist.")
	if combat_state.is_finished() or combat_state.current_actor_id != combatant.id:
		return ActionResult.failure("Weapon can only be changed during this character's turn.")
	var result: ActionResult = equipment_system.set_active_weapon_slot(combatant, target_slot)
	if result.success:
		cancel_remaining_movement(combatant)
		equipment_system.refresh_equipment(combatant)
		result.events.append(CombatEvent.new(EventTypes.Type.EQUIPMENT_CHANGED, combatant.id, "", {"item_name": equipment_system.get_equipment_name(combatant, target_slot)}))
	return result


func advance_turn() -> void:
	if combat_state == null or combat_state.is_finished():
		return
	# Ending the turn cancels destination selection without spending the Ability.
	ability_move_actor_id = ""
	ability_move_id = ""

	var previous_actor := combat_state.get_current_actor()
	clear_hidden(previous_actor, "Turn ended")
	for cooldown in skill_system.reduce_cooldowns(previous_actor):
		event_system.emit(CombatEvent.new(EventTypes.Type.SKILL_COOLDOWN_REDUCED, previous_actor.id, "", cooldown))
	for cooldown in ability_system.reduce_cooldowns(previous_actor):
		event_system.emit(CombatEvent.new(EventTypes.Type.ABILITY_COOLDOWN_REDUCED, previous_actor.id, "", cooldown))
	emit_effect_resolutions(
		previous_actor,
		effect_system.resolve_effects(previous_actor, EffectData.Trigger.END_OF_TURN)
	)
	var temporary_faith_lost := previous_actor.decay_temporary_faith(2)
	if temporary_faith_lost > 0:
		event_system.emit(CombatEvent.new(EventTypes.Type.FAITH_CHANGED, previous_actor.id, previous_actor.id, {"temporary_faith_lost": temporary_faith_lost, "faith": previous_actor.faith, "temporary_faith": previous_actor.temporary_faith}))
	for effect in effect_system.decay_end_turn_stacks(previous_actor):
		event_system.emit(CombatEvent.new(EventTypes.Type.EFFECT_EXPIRED, previous_actor.id, "", {"effect_name": effect.data.display_name}))
	turn_system.end_turn(combat_state)
	event_system.emit(CombatEvent.new(EventTypes.Type.TURN_ENDED, previous_actor.id))
	for effect in effect_system.expire_turn_end_effects(previous_actor):
		event_system.emit(
			CombatEvent.new(
				EventTypes.Type.EFFECT_EXPIRED,
				previous_actor.id,
				"",
				{"effect_name": effect.data.display_name}
			)
		)

	for cleared_ability in ability_system.clear_end_turn_bonuses(previous_actor):
		event_system.emit(
			CombatEvent.new(
				EventTypes.Type.ABILITY_STACKS_CLEARED,
				previous_actor.id,
				"",
				cleared_ability
			)
		)

	if check_for_combat_end():
		return

	var next_actor := turn_system.next_actor(combat_state)
	if next_actor == null:
		check_for_combat_end()
		return
	start_current_turn()


func start_current_turn() -> void:
	if combat_state == null or combat_state.is_finished():
		return

	var actor := combat_state.get_current_actor()
	if actor == null or actor.is_dying():
		return

	turn_system.start_turn(combat_state)
	for effect in effect_system.expire_start_turn_effects(actor):
		event_system.emit(CombatEvent.new(EventTypes.Type.EFFECT_EXPIRED, actor.id, "", {"effect_name": effect.data.display_name}))
	event_system.emit(CombatEvent.new(EventTypes.Type.TURN_STARTED, actor.id))
	emit_effect_resolutions(
		actor,
		effect_system.resolve_effects(actor, EffectData.Trigger.START_OF_TURN)
	)
	if check_for_combat_end():
		return

	turn_system.activate_turn(
		combat_state,
		actor.max_ap + effect_system.get_max_ap_bonus(actor) - effect_system.get_max_ap_penalty(actor)
	)


func reaction_has_trait(reaction, trait_id: String) -> bool:
	if reaction == null:
		return false
	for trait_data in reaction.traits:
		if trait_data != null and trait_data.id == trait_id:
			return true
	return false


func clear_hidden(combatant: CombatantState, reason: String) -> void:
	if combatant != null and combatant.remove_status("hidden"):
		event_system.emit(CombatEvent.new(EventTypes.Type.EFFECT_EXPIRED, combatant.id, "", {"effect_name": "Hidden", "reason": reason}))


func check_for_combat_end() -> bool:
	if combat_state == null or combat_state.is_finished():
		return combat_state != null and combat_state.is_finished()

	var living_teams: Dictionary = {}
	for combatant in combat_state.combatants.values():
		if not combatant.is_dying():
			living_teams[combatant.team] = true

	if living_teams.size() > 1:
		return false

	var winning_team := 0
	if living_teams.size() == 1:
		winning_team = int(living_teams.keys()[0])
	combat_state.winner_team = winning_team
	combat_state.turn_state = CombatEnums.TurnState.END
	for combatant in combat_state.combatants.values():
		effect_system.clear_all_effects(combatant)

	if winning_team == 1:
		combat_state.combat_result = CombatEnums.CombatResult.VICTORY
		event_system.emit(CombatEvent.new(EventTypes.Type.COMBAT_VICTORY, "", "", {"winner_team": winning_team}))
	else:
		combat_state.combat_result = CombatEnums.CombatResult.DEFEAT
		event_system.emit(CombatEvent.new(EventTypes.Type.COMBAT_DEFEAT, "", "", {"winner_team": winning_team}))
	return true


func emit_effect_resolutions(
	target: CombatantState,
	resolutions: Array[Dictionary]
) -> void:
	for resolution in resolutions:
		var event_type := EventTypes.Type.EFFECT_RESOURCE_CHANGED
		if resolution["type"] == "damage":
			event_type = EventTypes.Type.EFFECT_DAMAGE_APPLIED
		elif resolution["type"] == "heal":
			event_type = EventTypes.Type.EFFECT_HEAL_APPLIED

		event_system.emit(
			CombatEvent.new(event_type, "", target.id, resolution)
		)
