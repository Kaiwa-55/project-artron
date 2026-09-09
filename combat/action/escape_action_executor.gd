class_name EscapeActionExecutor
extends RefCounted

var combat_system


func _init(p_combat_system) -> void:
	combat_system = p_combat_system


func execute(combatant_id: String, status_id: String) -> ActionResult:
	var validation := validate(combatant_id, status_id)
	if not validation.success:
		return validation
	var actor: CombatantState = combat_system.combat_state.get_combatant(combatant_id)
	var instance: EffectInstance = find_effect(actor, status_id)
	combat_system.cancel_remaining_movement(actor)
	actor.spend_ap(instance.data.escape_ap_cost)
	var roll: int = combat_system.dice_system.roll_3d8()
	var modifier: int = actor.get_modifier(actor.strength)
	var total := roll + modifier
	var dc: int = instance.source_class_dc if instance.source_class_dc > 0 else instance.data.default_escape_dc
	var succeeded := total >= dc
	if succeeded:
		actor.remove_status(status_id)
	var result := ActionResult.success_result()
	result.events.append(CombatEvent.new(EventTypes.Type.ESCAPE_ATTEMPTED, actor.id, instance.source_combatant_id, {
		"effect_name": instance.data.display_name,
		"roll": roll,
		"strength_modifier": modifier,
		"total": total,
		"dc": dc,
		"succeeded": succeeded,
		"ap_cost": instance.data.escape_ap_cost,
	}))
	combat_system.emit_events(result.events)
	return result


func validate(combatant_id: String, status_id: String) -> ActionResult:
	if combat_system.combat_state == null:
		return ActionResult.failure("Combat has not started.")
	if combat_system.combat_state.is_finished():
		return ActionResult.failure("Combat has already ended.")
	if combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement():
		return ActionResult.failure("Resolve the pending action first.")
	var actor: CombatantState = combat_system.combat_state.get_combatant(combatant_id)
	if actor == null:
		return ActionResult.failure("Combatant does not exist.")
	if actor.id != combat_system.combat_state.current_actor_id:
		return ActionResult.failure("Actor is not the current actor.")
	if actor.is_dying():
		return ActionResult.failure("Actor is Dying.")
	var instance := find_effect(actor, status_id)
	if instance == null:
		return ActionResult.failure("Choose a Status that can be escaped.")
	if actor.ap < instance.data.escape_ap_cost:
		return ActionResult.failure("Not enough AP.")
	return ActionResult.success_result()


func find_effect(actor: CombatantState, status_id: String) -> EffectInstance:
	if actor == null:
		return null
	for instance in actor.effects:
		if instance != null and instance.data != null and instance.data.id == status_id and instance.data.can_escape:
			return instance
	return null
