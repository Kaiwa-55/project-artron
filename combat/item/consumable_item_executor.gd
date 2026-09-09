class_name ConsumableItemExecutor
extends RefCounted

var combat_system


func _init(p_combat_system) -> void:
	combat_system = p_combat_system


func execute(combatant_id: String, item_id: String, target_id: String = "") -> ActionResult:
	var validation := validate(combatant_id, item_id, target_id)
	if not validation.success:
		return validation
	var actor: CombatantState = combat_system.combat_state.get_combatant(combatant_id)
	var stack := find_stack(actor, item_id)
	var item: ConsumableData = stack.item
	var target: CombatantState = actor
	if item.target_mode == ConsumableData.TargetMode.SINGLE_COMBATANT:
		target = combat_system.combat_state.get_combatant(target_id)

	actor.spend_ap(item.ap_cost)
	combat_system.cancel_remaining_movement(actor)
	var result := ActionResult.success_result()
	for effect in item.effects:
		apply_effect(actor, target, item, effect, result.events)
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
	}))
	combat_system.emit_events(result.events)
	combat_system.check_for_combat_end()
	return result


func validate(combatant_id: String, item_id: String, target_id: String = "") -> ActionResult:
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
	if actor.ap < item.ap_cost:
		return ActionResult.failure("Not enough AP.")
	if item.target_mode == ConsumableData.TargetMode.GROUND:
		return ActionResult.failure("This Item requires ground targeting.")
	var target: CombatantState = actor
	if item.target_mode == ConsumableData.TargetMode.SINGLE_COMBATANT:
		target = combat_system.combat_state.get_combatant(target_id)
	if target == null or not target_filter_matches(actor, target, item):
		return ActionResult.failure("Choose a valid target for this Item.")
	if item.cannot_target_dying and target.is_dying():
		return ActionResult.failure("This Item cannot target a Dying character.")
	if item.requires_missing_hp and target.hp >= target.max_hp:
		return ActionResult.failure("Target is already at full HP.")
	if item.target_mode == ConsumableData.TargetMode.SINGLE_COMBATANT:
		if not combat_system.map_rules.is_target_in_range(actor, target, item.range_feet):
			return ActionResult.failure("Target is outside this Item's range.")
		if item.requires_line_of_sight and not combat_system.map_rules.has_line_of_sight(actor.position, target.position):
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
			if combat_system.effect_system.apply_effect(target, effect, item.id, item.display_name, false, actor):
				events.append(CombatEvent.new(EventTypes.Type.EFFECT_APPLIED, actor.id, target.id, {"effect_name": effect.display_name, "item_name": item.display_name}))
