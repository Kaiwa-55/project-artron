class_name SearchActionExecutor
extends RefCounted

var combat_system


func _init(p_combat_system) -> void:
	combat_system = p_combat_system


func execute(actor_id: String, target_id: String) -> ActionResult:
	var validation := validate(actor_id, target_id)
	if not validation.success:
		return validation
	var actor: CombatantState = combat_system.combat_state.get_combatant(actor_id)
	var target: CombatantState = combat_system.combat_state.get_combatant(target_id)
	combat_system.cancel_remaining_movement(actor)
	actor.spend_ap(1)
	var roll: int = combat_system.dice_system.roll_3d8()
	var perception: int = actor.get_skill_rank("perception")
	var total: int = roll + perception
	var stealth: int = target.get_skill_rank("stealth")
	var dc: int = 10 + stealth
	var succeeded: bool = total >= dc
	var concealment_reduced := false
	if succeeded:
		var previous_reduction := target.get_concealment_reduction_against(actor.id)
		concealment_reduced = target.reveal_concealment_against(actor.id, 1) > previous_reduction
	var result := ActionResult.success_result()
	result.events.append(CombatEvent.new(EventTypes.Type.MANEUVER_USED, actor.id, target.id, {
		"maneuver": "Search",
		"succeeded": succeeded,
		"roll": roll,
		"perception": perception,
		"stealth": stealth,
		"total": total,
		"dc": dc,
		"concealment_reduced": concealment_reduced,
		"ap_cost": 1,
	}))
	if concealment_reduced:
		result.events.append(CombatEvent.new(EventTypes.Type.EFFECT_APPLIED, actor.id, target.id, {"effect_name": "Concealment -1 against %s" % actor.display_name, "ability_name": "Search"}))
	combat_system.emit_events(result.events)
	return result


func validate(actor_id: String, target_id: String) -> ActionResult:
	if combat_system.combat_state == null or combat_system.combat_state.is_finished():
		return ActionResult.failure("Combat is not active.")
	if combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement():
		return ActionResult.failure("Resolve the pending action first.")
	var actor: CombatantState = combat_system.combat_state.get_combatant(actor_id)
	var target: CombatantState = combat_system.combat_state.get_combatant(target_id)
	if actor == null or actor.id != combat_system.combat_state.current_actor_id:
		return ActionResult.failure("Actor is not the current actor.")
	if actor.is_dying():
		return ActionResult.failure("Actor is Dying.")
	if target == null or target.is_dying() or target.team == actor.team:
		return ActionResult.failure("Choose a living enemy to Search.")
	if actor.ap < 1:
		return ActionResult.failure("Not enough AP.")
	return ActionResult.success_result()
