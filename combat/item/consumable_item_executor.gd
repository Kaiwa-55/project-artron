class_name ConsumableItemExecutor
extends RefCounted

var combat_system


func _init(p_combat_system) -> void:
	combat_system = p_combat_system


func execute(combatant_id: String, item_id: String, target_id: String = "", target_position: Vector2 = Vector2.INF, target_world: Vector3 = Vector3.INF) -> ActionResult:
	var validation := validate(combatant_id, item_id, target_id, target_position, target_world)
	if not validation.success:
		return validation
	var actor: CombatantState = combat_system.combat_state.get_combatant(combatant_id)
	var stack := find_stack(actor, item_id)
	var item: ConsumableData = stack.item
	var target: CombatantState = actor
	if item.target_mode == ConsumableData.TargetMode.SINGLE_COMBATANT:
		target = combat_system.combat_state.get_combatant(target_id)

	var targets: Array[CombatantState] = [target]
	if item.target_mode == ConsumableData.TargetMode.GROUND:
		targets = combat_system.targeting_system.collect_targets(actor, target_position, item, combat_system.combat_state, combat_system.map_rules, item.targeting_range_feet, target_world)
	actor.spend_ap(item.ap_cost)
	combat_system.cancel_remaining_movement(actor)
	var result := ActionResult.success_result()
	if item.target_mode == ConsumableData.TargetMode.GROUND and item.light_level_penalty > 0 and item.light_duration_rounds > 0:
		var target_surface: StringName = actor.surface_id
		if target_world != Vector3.INF and combat_system.map_rules.spatial_navigation != null:
			target_surface = combat_system.map_rules.spatial_navigation.surface_at(target_world, actor.surface_id)
		combat_system.map_rules.add_temporary_light_area(target_position, item.area_radius_feet, item.light_level_penalty, combat_system.combat_state.current_round + item.light_duration_rounds, target_surface)
	for affected in targets:
		for effect in item.effects:
			apply_effect(actor, affected, item, effect, result.events)
	if item.grants_next_skill_accuracy_bonus > 0:
		actor.focus_draught_ready_bonus = item.grants_next_skill_accuracy_bonus
	var healing_done := 0
	var damage_done := 0
	for effect_event in result.events:
		if effect_event.type == EventTypes.Type.EFFECT_HEAL_APPLIED:
			healing_done += int(effect_event.data.get("amount", 0))
		elif effect_event.type == EventTypes.Type.EFFECT_DAMAGE_APPLIED:
			damage_done += int(effect_event.data.get("amount", 0))
	if item.consume_on_use:
		stack.consume()
		if stack.quantity <= 0:
			actor.item_inventory.erase(stack)
	result.events.push_front(CombatEvent.new(EventTypes.Type.ITEM_USED, actor.id, target.id, {
		"item_id": item.id,
		"item_name": item.display_name,
		"ap_cost": item.ap_cost,
		"quantity_remaining": stack.quantity,
		"healing": healing_done,
		"damage": damage_done,
		"target_position": target_position if item.target_mode == ConsumableData.TargetMode.GROUND else Vector2.INF,
	}))
	combat_system.emit_events(result.events)
	combat_system.check_for_combat_end()
	return result


func validate(combatant_id: String, item_id: String, target_id: String = "", target_position: Vector2 = Vector2.INF, target_world: Vector3 = Vector3.INF) -> ActionResult:
	if combat_system.combat_state == null:
		return ActionResult.failure("Combat has not started.")
	if combat_system.combat_state.is_finished():
		return ActionResult.failure("Combat has already ended.")
	if combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement():
		return ActionResult.failure("Resolve the pending action first.")
	if combat_system.pending_area_context != null:
		return ActionResult.failure("Resolve the pending Area Action first.")
	var actor: CombatantState = combat_system.combat_state.get_combatant(combatant_id)
	if actor == null:
		return ActionResult.failure("Combatant does not exist.")
	if actor.id != combat_system.combat_state.current_actor_id:
		return ActionResult.failure("Items can only be used during this character's turn.")
	if actor.is_dying():
		return ActionResult.failure("A Dying character cannot use Items.")
	var stack := find_stack(actor, item_id)
	if stack == null or stack.quantity <= 0 or not (stack.item is ConsumableData):
		return ActionResult.failure("Consumable Item is not in this character's inventory.")
	var item: ConsumableData = stack.item
	if item.reaction_only:
		return ActionResult.failure("This Item is used as a Reaction when hit.")
	if item.grants_next_skill_accuracy_bonus > 0 and actor.focus_draught_ready_bonus > 0:
		return ActionResult.failure("A Skill accuracy bonus is already prepared.")
	if actor.ap < item.ap_cost:
		return ActionResult.failure("Not enough AP.")
	if item.target_mode == ConsumableData.TargetMode.GROUND:
		if not target_position.is_finite():
			return ActionResult.success_result()
		return combat_system.targeting_system.validate_target_point(actor, target_position, item, combat_system.map_rules, item.targeting_range_feet, target_world)
	var target: CombatantState = actor
	if item.target_mode == ConsumableData.TargetMode.SINGLE_COMBATANT:
		target = combat_system.combat_state.get_combatant(target_id)
	if target == null or not target_filter_matches(actor, target, item):
		return ActionResult.failure("Choose a valid target for this Item.")
	if item.cannot_target_dying and target.is_dying():
		return ActionResult.failure("This Item cannot target a Dying character.")
	if item.requires_missing_hp and target.hp >= target.max_hp:
		return ActionResult.failure("Target is already at full HP.")
	if item.requires_missing_mana and target.mana >= target.max_mana:
		return ActionResult.failure("Target is already at full Mana.")
	if not item.required_status_id.is_empty() and not target.has_status(item.required_status_id):
		return ActionResult.failure("Target does not have the required status.")
	for effect in item.effects:
		if not is_consumable_buff(effect):
			continue
		for instance in target.effects:
			if instance.has_meta("consumable_buff") and instance.data.id != effect.id and buffs_overlap(effect, instance.data):
				return ActionResult.failure("A consumable buff with the same bonus is already active.")
	if item.target_mode == ConsumableData.TargetMode.SINGLE_COMBATANT:
		if not combat_system.map_rules.is_target_in_range(actor, target, item.range_feet):
			return ActionResult.failure("Target is outside this Item's range.")
		if item.requires_line_of_sight and not combat_system.map_rules.has_line_of_sight_between(actor, target):
			return ActionResult.failure("Target is not visible.")
	return ActionResult.success_result()


func find_stack(actor: CombatantState, item_id: String) -> ItemStack:
	if actor == null:
		return null
	for stack in actor.item_inventory:
		if stack != null and stack.item != null and stack.item.id == item_id:
			return stack
	return null


func target_filter_matches(actor: CombatantState, target: CombatantState, item: ConsumableData) -> bool:
	match item.target_filter:
		ConsumableData.TargetFilter.SELF_ONLY:
			return target == actor
		ConsumableData.TargetFilter.ALLIES:
			return target.team == actor.team
		ConsumableData.TargetFilter.ENEMIES:
			return target.team != actor.team
		_:
			return true


func apply_effect(actor: CombatantState, target: CombatantState, item: ConsumableData, effect: EffectData, events: Array[CombatEvent]) -> void:
	if effect == null:
		return
	match effect.effect_type:
		EffectData.Type.HEAL:
			var healed := target.heal(effect.amount)
			events.append(CombatEvent.new(EventTypes.Type.EFFECT_HEAL_APPLIED, actor.id, target.id, {"effect_name": item.display_name, "item_id": item.id, "amount": healed}))
		EffectData.Type.DAMAGE:
			var immune := target.is_immune_to_damage(effect.damage_type)
			var resistance := target.get_damage_resistance(effect.damage_type)
			var damage: int = 0 if immune else maxi(0, effect.amount - resistance)
			target.apply_damage(damage)
			events.append(CombatEvent.new(EventTypes.Type.EFFECT_DAMAGE_APPLIED, actor.id, target.id, {"effect_name": item.display_name, "item_id": item.id, "amount": damage, "damage_type": effect.damage_type, "immune": immune}))
		EffectData.Type.RESOURCE:
			var resolution: Dictionary = combat_system.effect_system.resolve_resource_effect(target, effect)
			events.append(CombatEvent.new(EventTypes.Type.EFFECT_RESOURCE_CHANGED, actor.id, target.id, resolution))
		EffectData.Type.CLEANSE:
			var removed: int = combat_system.effect_system.cleanse_statuses(target, effect.cleanse_status_ids, effect.cleanse_status_tags, effect.cleanse_all)
			events.append(CombatEvent.new(EventTypes.Type.EFFECT_EXPIRED, actor.id, target.id, {"effect_name": item.display_name, "removed_count": removed}))
		_:
			var applied_effect := effect
			if is_consumable_buff(effect):
				applied_effect = effect.duplicate()
				applied_effect.stack_mode = EffectData.StackMode.REFRESH_DURATION
				applied_effect.stacks_on_apply = 1
				applied_effect.max_stacks = 1
			if combat_system.effect_system.apply_effect(target, applied_effect, item.id, item.display_name, false, actor):
				if applied_effect != effect:
					for instance in target.effects:
						if instance.data.id == applied_effect.id:
							instance.stack_count = 1
							instance.set_meta("consumable_buff", true)
							break
				events.append(CombatEvent.new(EventTypes.Type.EFFECT_APPLIED, actor.id, target.id, {"effect_name": effect.display_name, "item_name": item.display_name}))


func is_consumable_buff(effect: EffectData) -> bool:
	if effect == null:
		return false
	return effect.effect_type == EffectData.Type.STAT and (
		effect.attack_bonus > 0 or effect.damage_bonus > 0 or effect.reflex_bonus > 0
		or effect.fortitude_bonus > 0 or effect.will_bonus > 0 or effect.speed_bonus_per_stack > 0.0
		or effect.max_ap_bonus_per_stack > 0 or effect.vision_bonus > 0
		or effect.dark_vision_bonus > 0 or effect.concealment_bonus > 0
	)


func buffs_overlap(first: EffectData, second: EffectData) -> bool:
	for property_name in ["attack_bonus", "damage_bonus", "reflex_bonus", "fortitude_bonus", "will_bonus", "speed_bonus_per_stack", "max_ap_bonus_per_stack", "vision_bonus", "dark_vision_bonus", "concealment_bonus"]:
		if float(first.get(property_name)) > 0.0 and float(second.get(property_name)) > 0.0:
			return true
	return false
