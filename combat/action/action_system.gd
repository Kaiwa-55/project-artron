class_name ActionSystem
extends RefCounted


var attack_system: AttackSystem
var movement_system: MovementSystem
var skill_system


func _init(
	p_attack_system: AttackSystem,
	p_movement_system: MovementSystem,
	p_skill_system
) -> void:

	attack_system = p_attack_system
	movement_system = p_movement_system
	skill_system = p_skill_system

func validate(
	request: ActionRequest,
	combat_state: CombatState
) -> ActionResult:

	if request == null:
		return ActionResult.failure(
			"Action request is null."
		)

	var actor := \
		combat_state.get_combatant(
			request.actor_id
		)

	if actor == null:
		return ActionResult.failure(
			"Actor does not exist."
		)

	if actor.is_dying():
		return ActionResult.failure(
			"Actor is Dying."
		)

	if actor.id != combat_state.current_actor_id:
		return ActionResult.failure(
			"Actor is not the current actor."
		)
	match request.action_type:

		ActionTypes.Type.ATTACK:

			var target := \
				combat_state.get_combatant(
					request.target_id
				)

			return attack_system.validate_attack(
				actor,
				target,
				request.attack_data
			)

		ActionTypes.Type.MOVE:

			return movement_system.validate_move(
				actor,
				request.target_position,
				request.movement_data,
				combat_state
			)

		ActionTypes.Type.SKILL:
			var target := combat_state.get_combatant(request.target_id)
			return skill_system.validate_skill(actor, target, request.skill_data, attack_system)

	return ActionResult.failure(
		"Unsupported action type."
	)

func execute(
	request: ActionRequest,
	combat_state: CombatState
) -> ActionResult:

	var validation := validate(
		request,
		combat_state
	)

	if not validation.success:
		return validation

	var actor := \
		combat_state.get_combatant(
			request.actor_id
		)

	match request.action_type:

		ActionTypes.Type.ATTACK:

			var target := \
				combat_state.get_combatant(
					request.target_id
				)

			var attack_result := \
				attack_system.resolve_attack(
					actor,
					target,
					request.attack_data
				)

			return build_attack_result(
				actor,
				target,
				request.attack_data,
				attack_result
			)

		ActionTypes.Type.MOVE:
			var origin := actor.position
			var was_moving: bool = actor.movement_in_progress
			var move_result := movement_system.execute_move(
				actor,
				request.target_position,
				request.movement_data,
				combat_state
			)

			if not move_result.success:
				return move_result

			if not was_moving:
				move_result.events.append(
					CombatEvent.new(EventTypes.Type.MOVE_STARTED, actor.id)
				)
			move_result.events.append(
				CombatEvent.new(
					EventTypes.Type.POSITION_CHANGED,
					actor.id,
					"",
					{
						"from": origin,
						"to": actor.position,
						"distance": origin.distance_to(actor.position),
						"distance_feet": origin.distance_to(actor.position) \
							/ request.movement_data.world_units_per_foot,
						"remaining_speed_feet": actor.movement_remaining_feet
					}
				)
			)
			if movement_system.ability_system != null:
				for passive in movement_system.ability_system.apply_after_move_passives(actor):
					move_result.events.append(CombatEvent.new(EventTypes.Type.EFFECT_APPLIED, actor.id, actor.id, passive))
			if not actor.movement_in_progress:
				move_result.events.append(
					CombatEvent.new(EventTypes.Type.MOVE_COMPLETED, actor.id)
				)
			return move_result

		ActionTypes.Type.SKILL:
			var target := combat_state.get_combatant(request.target_id)
			skill_system.consume_skill_costs(actor, request.skill_data)
			var skill_attack: AttackData = skill_system.get_attack_data(request.skill_data, actor)
			var attack_result := attack_system.resolve_attack(actor, target, skill_attack)
			var skill_result := build_attack_result(actor, target, skill_attack, attack_result)
			skill_result.events.push_front(CombatEvent.new(
				EventTypes.Type.SKILL_CAST,
				actor.id,
			target.id,
				{"skill_name": request.skill_data.display_name, "mana_cost": skill_system.get_effective_mana_cost(actor, request.skill_data), "cooldown": skill_system.get_effective_cooldown_turns(actor, request.skill_data)}
			))
			return skill_result

	return ActionResult.failure(
		"Unsupported action type."
	)

func build_attack_result(
	attacker: CombatantState,
	target: CombatantState,
	attack: AttackData,
	attack_result: AttackResult
) -> ActionResult:

	var result := ActionResult.success_result()

	if attack_result.hit:

		result.events.append(
			CombatEvent.new(
				EventTypes.Type.ATTACK_HIT,
				attacker.id,
				target.id,
				{
					"attack_id": attack.id,
					"attack_name": attack.display_name,
					"roll": attack_result.roll,
					"animation_template": attack.animation_template,
					"is_damaging_attack": attack.base_damage > 0,
					"animation_origin": attacker.position,
					"animation_target": target.position,
					"attack_modifier": attack_result.attack_modifier,
					"repeated_attack_penalty": attack_result.repeated_attack_penalty,
					"attack_total": attack_result.roll + attack_result.attack_modifier,
					"defense": attack_result.defense,
					"damage": attack_result.damage,
					"conditional_damage_bonus": attack_result.conditional_damage_bonus,
					"damage_bonus_source": attack_result.damage_bonus_source,
					"conditional_damage_bonuses": attack_result.conditional_damage_bonuses,
					"critical": attack_result.critical,
					"critical_roll": attack_result.critical_roll,
					"immune": attack_result.immune,
					"damage_type": attack.damage_type,
					"resistance": attack_result.resistance,
					"final_damage": attack_result.final_damage,
					"finishing_gauge_gained": attack_result.finishing_gauge_gained,
					"finishing_gauge": attacker.finishing_gauge,
					"max_finishing_gauge": attacker.max_finishing_gauge
				}
			)
		)

		if attack_result.final_damage > 0:
			var damage_target_id: String = attack_result.redirected_damage_target.id if attack_result.redirected_damage_target != null else target.id

			result.events.append(
				CombatEvent.new(
					EventTypes.Type.DAMAGE_APPLIED,
					attacker.id,
					damage_target_id,
					{
						"amount":
							attack_result.final_damage
					}
				)
			)

		for effect_name in attack_result.applied_effects:
			result.events.append(
				CombatEvent.new(
					EventTypes.Type.EFFECT_APPLIED,
					attacker.id,
					target.id,
					{"effect_name": effect_name}
				)
			)

	else:

		result.events.append(
			CombatEvent.new(
				EventTypes.Type.ATTACK_MISS,
				attacker.id,
				target.id,
				{
					"attack_id": attack.id,
					"attack_name": attack.display_name,
					"roll": attack_result.roll,
					"attack_modifier": attack_result.attack_modifier,
					"repeated_attack_penalty": attack_result.repeated_attack_penalty,
					"attack_total": attack_result.roll + attack_result.attack_modifier,
					"defense": attack_result.defense,
					"animation_template": attack.animation_template,
					"is_damaging_attack": attack.base_damage > 0,
					"animation_origin": attacker.position,
					"animation_target": target.position
				}
			)
		)

		for effect_name in attack_result.applied_effects:
			result.events.append(
				CombatEvent.new(
					EventTypes.Type.EFFECT_APPLIED,
					attacker.id,
					target.id,
					{"effect_name": effect_name}
				)
			)

	for triggered_ability in attack_result.triggered_abilities:
		result.events.append(
			CombatEvent.new(
				EventTypes.Type.ABILITY_TRIGGERED,
				attacker.id,
				"",
				triggered_ability
			)
		)

	return result
