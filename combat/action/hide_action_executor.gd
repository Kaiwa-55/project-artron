class_name HideActionExecutor
extends RefCounted

var combat_system


func _init(p_combat_system) -> void:
	combat_system = p_combat_system


func execute(actor_id: String) -> ActionResult:
	var validation := validate(actor_id)
	if not validation.success:
		return validation
	var actor: CombatantState = combat_system.combat_state.get_combatant(actor_id)
	combat_system.cancel_remaining_movement(actor)
	actor.spend_ap(1)
	var roll: int = combat_system.dice_system.roll_3d8()
	var stealth: int = actor.get_skill_rank("stealth")
	var total := roll + stealth
	var checks: Array[Dictionary] = []
	var succeeded := false
	for enemy in combat_system.combat_state.combatants.values():
		if enemy == actor or enemy.is_dying() or enemy.team == actor.team:
			continue
		var has_los: bool = combat_system.map_rules.has_line_of_sight_between(enemy, actor)
		var dc: int = 10 + enemy.get_skill_rank("perception") + (4 if has_los else 0)
		var passed := total >= dc
		checks.append({"enemy_id": enemy.id, "dc": dc, "has_line_of_sight": has_los, "succeeded": passed})
		if passed:
			actor.grant_concealment_against(enemy.id, 1)
			succeeded = true
	var result := ActionResult.success_result()
	result.events.append(CombatEvent.new(EventTypes.Type.MANEUVER_USED, actor.id, "", {
		"maneuver": "Hide",
		"succeeded": succeeded,
		"roll": roll,
		"stealth": stealth,
		"total": total,
		"checks": checks,
		"ap_cost": 1,
	}))
	for check in checks:
		if bool(check.succeeded):
			result.events.append(CombatEvent.new(EventTypes.Type.EFFECT_APPLIED, actor.id, actor.id, {"effect_name": "Concealed against %s" % String(check.enemy_id).capitalize(), "ability_name": "Hide"}))
	combat_system.emit_events(result.events)
	return result


func validate(actor_id: String) -> ActionResult:
	if combat_system.combat_state == null or combat_system.combat_state.is_finished():
		return ActionResult.failure("Combat is not active.")
	if combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement():
		return ActionResult.failure("Resolve the pending action first.")
	var actor: CombatantState = combat_system.combat_state.get_combatant(actor_id)
	if actor == null or actor.id != combat_system.combat_state.current_actor_id:
		return ActionResult.failure("Actor is not the current actor.")
	if actor.is_dying():
		return ActionResult.failure("Actor is Dying.")
	if actor.ap < 1:
		return ActionResult.failure("Not enough AP.")
	return ActionResult.success_result()
