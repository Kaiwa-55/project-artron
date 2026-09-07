class_name ActiveAbilityExecutor
extends RefCounted

const AbilityUseEffectDataScript = preload("res://data/ability/ability_use_effect_data.gd")

var combat_system
var pending_context: Dictionary = {}


func _init(p_combat_system) -> void:
	combat_system = p_combat_system


func execute(combatant_id: String, target_id: String, ability_id: String) -> ActionResult:
	if combat_system.combat_state == null or combat_system.combat_state.is_finished():
		return ActionResult.failure("Combat is not active.")
	if combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement():
		return ActionResult.failure("Finish the pending choice first.")
	var actor: CombatantState = combat_system.combat_state.get_combatant(combatant_id)
	if actor == null or combat_system.combat_state.current_actor_id != combatant_id:
		return ActionResult.failure("This Ability can only be used during the character's turn.")
	var ability = combat_system.ability_system.get_available_ability(actor, ability_id)
	if ability != null and ability.target_mode == AbilityData.TargetMode.SELF and ability.area_shape == AbilityData.AreaShape.CIRCLE:
		return combat_system.execute_ground_ability(combatant_id, ability_id, actor.position)
	var target: CombatantState = actor if ability != null and ability.target_mode == AbilityData.TargetMode.SELF else combat_system.combat_state.get_combatant(target_id)
	var validation: ActionResult = combat_system.ability_system.validate_active_use(actor, ability, target)
	if not validation.success:
		return validation
	if ability.execution_mode == AbilityData.ExecutionMode.ATTACK_SEQUENCE:
		return combat_system.attack_sequence_executor.execute_dual_weapon(actor, target, ability)
	if ability.target_mode == AbilityData.TargetMode.SINGLE_COMBATANT \
		and ability.targeting_range_feet > 0.0 \
		and not combat_system.map_rules.is_target_in_range(actor, target, ability.targeting_range_feet):
		return ActionResult.failure("Target is out of range.")
	if ability.target_mode == AbilityData.TargetMode.SINGLE_COMBATANT \
		and ability.requires_line_of_sight \
		and not combat_system.map_rules.has_line_of_sight(actor.position, target.position):
		return ActionResult.failure("Line of sight to the target is blocked.")
	var source_attack: AttackData = combat_system.ability_system.get_attack_data(actor, ability)
	var result: ActionResult
	if source_attack != null:
		var ability_attack: AttackData = source_attack.duplicate()
		ability_attack.ap_cost = ability.ap_cost
		if ability.animation_template != null:
			ability_attack.animation_template = ability.animation_template
		ability_attack.active_damage_bonus = ability.active_attack_flat_damage_bonus + ability.active_attack_damage_bonus_per_level * actor.level
		ability_attack.active_damage_bonus_source = ability.display_name
		var request := ActionRequest.new(combatant_id, ActionTypes.Type.ATTACK)
		request.target_id = target.id
		request.attack_data = ability_attack
		result = combat_system.execute_action(request)
		if result.success and not actor.spend_faith(ability.faith_cost):
			return ActionResult.failure("Not enough Faith.")
	else:
		if not actor.spend_ap(ability.ap_cost):
			return ActionResult.failure("Not enough AP.")
		if not actor.spend_faith(ability.faith_cost):
			actor.change_ap(ability.ap_cost)
			return ActionResult.failure("Not enough Faith.")
		combat_system.cancel_remaining_movement(actor)
		result = ActionResult.success_result()
	if not result.success:
		return result
	actor.ability_uses_this_turn[ability.id] = int(actor.ability_uses_this_turn.get(ability.id, 0)) + 1
	var cooldown: int = combat_system.ability_system.start_cooldown(actor, ability)
	var ability_events: Array[CombatEvent] = []
	if ability.faith_cost > 0:
		ability_events.append(CombatEvent.new(EventTypes.Type.FAITH_CHANGED, actor.id, actor.id, {
			"ability_name": ability.display_name,
			"faith_spent": ability.faith_cost,
			"faith": actor.faith,
			"temporary_faith": actor.temporary_faith,
		}))
	var defer_conditional: bool = result.requires_reaction_choice and result.reaction_prompt.has("prepared_attack")
	apply_effects(actor, target, ability, result.events, ability_events, true, not defer_conditional)
	var trigger_data := {"ability_name": ability.display_name, "ap_cost": ability.ap_cost, "cooldown": cooldown}
	# Attacking Abilities carry their animation on ATTACK_HIT / ATTACK_MISS so it
	# resolves after defensive Reactions. Effect-only Abilities animate here.
	if source_attack == null and ability.animation_template != null:
		trigger_data["animation_template"] = ability.animation_template
		trigger_data["animation_origin"] = actor.position
		trigger_data["animation_target"] = target.position if target != null else actor.position
	ability_events.push_front(CombatEvent.new(EventTypes.Type.ABILITY_TRIGGERED, actor.id, target_id, trigger_data))
	result.events.append_array(ability_events)
	combat_system.emit_events(ability_events)
	if defer_conditional:
		pending_context = {"actor": actor, "target": target, "ability": ability}
	return result


func apply_effects(actor: CombatantState, target: CombatantState, ability, attack_events: Array[CombatEvent], output_events: Array[CombatEvent], include_always: bool = true, include_conditional: bool = true) -> void:
	var hit := attack_events.any(func(event): return event.type == EventTypes.Type.ATTACK_HIT)
	var missed := attack_events.any(func(event): return event.type == EventTypes.Type.ATTACK_MISS)
	for entry in combat_system.ability_system.get_use_effects(ability):
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
			apply_dynamic_effect(actor, target, ability, entry, output_events)
			continue
		var recipient: CombatantState = actor if entry.recipient == AbilityUseEffectDataScript.Recipient.CASTER else target
		var applied_effect: EffectData = build_scaled_effect(actor, entry)
		if applied_effect != null and recipient != null and combat_system.effect_system.apply_effect(recipient, applied_effect):
			output_events.append(CombatEvent.new(EventTypes.Type.EFFECT_APPLIED, actor.id, recipient.id, {"effect_name": applied_effect.display_name, "ability_name": ability.display_name}))


func build_scaled_effect(actor: CombatantState, entry) -> EffectData:
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


func apply_dynamic_effect(actor: CombatantState, target: CombatantState, ability, entry, output_events: Array[CombatEvent]) -> void:
	match entry.dynamic_effect:
		AbilityUseEffectDataScript.DynamicEffect.GAIN_FAITH_FROM_WISDOM_MODIFIER:
			var amount := maxi(0, actor.get_modifier(actor.wisdom))
			var gained := actor.gain_faith(amount)
			output_events.append(CombatEvent.new(EventTypes.Type.FAITH_CHANGED, actor.id, actor.id, {"ability_name": ability.display_name, "faith_gained": gained.faith, "temporary_faith_gained": gained.temporary_faith, "faith": actor.faith, "temporary_faith": actor.temporary_faith}))
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


func apply_pending_conditional_effects(attack_events: Array[CombatEvent], output_events: Array[CombatEvent]) -> void:
	if pending_context.is_empty():
		return
	apply_effects(pending_context.get("actor"), pending_context.get("target"), pending_context.get("ability"), attack_events, output_events, false, true)
	pending_context = {}
