class_name EquipmentActionExecutor
extends RefCounted

var combat_system


func _init(p_combat_system) -> void:
	combat_system = p_combat_system


func toggle(combatant_id: String, item, target_slot: int = -1) -> ActionResult:
	var validation := validate_change(combatant_id, "Equipment")
	if not validation.success:
		return validation
	var combatant: CombatantState = combat_system.combat_state.get_combatant(combatant_id)
	var result: ActionResult = combat_system.equipment_system.toggle_equipment(combatant, item, target_slot)
	if result.success:
		combat_system.cancel_remaining_movement(combatant)
		combat_system.equipment_system.refresh_equipment(combatant)
		combat_system.stat_system.refresh_combatant(combatant)
		result.events.append(CombatEvent.new(EventTypes.Type.EQUIPMENT_CHANGED, combatant.id, "", {"item_name": item.display_name}))
	return result


func set_active_weapon_slot(combatant_id: String, target_slot: int) -> ActionResult:
	var validation := validate_change(combatant_id, "Weapon")
	if not validation.success:
		return validation
	var combatant: CombatantState = combat_system.combat_state.get_combatant(combatant_id)
	var result: ActionResult = combat_system.equipment_system.set_active_weapon_slot(combatant, target_slot)
	if result.success:
		combat_system.cancel_remaining_movement(combatant)
		combat_system.equipment_system.refresh_equipment(combatant)
		result.events.append(CombatEvent.new(EventTypes.Type.EQUIPMENT_CHANGED, combatant.id, "", {"item_name": combat_system.equipment_system.get_equipment_name(combatant, target_slot)}))
	return result


func validate_change(combatant_id: String, item_kind: String) -> ActionResult:
	if combat_system.combat_state == null:
		return ActionResult.failure("Combat has not started.")
	if combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement():
		return ActionResult.failure("%s cannot be changed while a Reaction or movement is pending." % item_kind)
	var combatant: CombatantState = combat_system.combat_state.get_combatant(combatant_id)
	if combatant == null:
		return ActionResult.failure("Combatant does not exist.")
	if combat_system.combat_state.is_finished() or combat_system.combat_state.current_actor_id != combatant.id:
		return ActionResult.failure("%s can only be changed during this character's turn." % item_kind)
	return ActionResult.success_result()
