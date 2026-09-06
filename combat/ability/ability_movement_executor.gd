class_name AbilityMovementExecutor
extends RefCounted

var combat_system
var actor_id: String = ""
var ability_id: String = ""


func _init(p_combat_system) -> void:
	combat_system = p_combat_system


func has_pending() -> bool:
	return not actor_id.is_empty() and not ability_id.is_empty()


func clear_pending() -> void:
	actor_id = ""
	ability_id = ""


func begin(combatant_id: String, requested_ability_id: String) -> ActionResult:
	if combat_system.combat_state == null or combat_system.combat_state.is_finished():
		return ActionResult.failure("Combat is not active.")
	if combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or has_pending():
		return ActionResult.failure("Finish the pending choice first.")
	var actor: CombatantState = combat_system.combat_state.get_combatant(combatant_id)
	if actor == null or combat_system.combat_state.current_actor_id != combatant_id:
		return ActionResult.failure("This Ability can only be used during the character's turn.")
	var ability = combat_system.ability_system.get_available_ability(actor, requested_ability_id)
	var validation: ActionResult = combat_system.ability_system.validate_active_use(actor, ability, actor)
	if not validation.success:
		return validation
	var movement_effect = combat_system.ability_system.get_movement_effect(ability)
	if movement_effect == null or movement_effect.movement_distance_feet <= 0.0:
		return ActionResult.failure("This Ability does not provide movement.")
	if actor.has_status("rooted"):
		return ActionResult.failure("Rooted characters cannot Move.")
	actor_id = actor.id
	ability_id = ability.id
	return ActionResult.success_result()


func execute(destination: Vector2) -> ActionResult:
	if not has_pending():
		return ActionResult.failure("There is no Ability movement waiting for a destination.")
	var actor: CombatantState = combat_system.combat_state.get_combatant(actor_id)
	var ability = combat_system.ability_system.get_available_ability(actor, ability_id) if actor != null else null
	var movement_effect = combat_system.ability_system.get_movement_effect(ability)
	if actor == null or ability == null or movement_effect == null or actor.is_dying() or actor.has_status("rooted"):
		clear_pending()
		return ActionResult.failure("The character cannot complete this movement.")
	var maximum_distance: float = movement_effect.movement_distance_feet * combat_system.map_rules.world_units_per_foot
	var clamped_destination := destination
	if actor.position.distance_to(destination) > maximum_distance:
		clamped_destination = actor.position + actor.position.direction_to(destination) * maximum_distance
	var validation: ActionResult = combat_system.map_rules.validate_movement_path(actor, clamped_destination, combat_system.combat_state.combatants)
	if not validation.success:
		return validation
	if not actor.spend_ap(ability.ap_cost):
		return ActionResult.failure("Not enough AP.")
	combat_system.cancel_remaining_movement(actor)
	var origin := actor.position
	actor.position = clamped_destination
	actor.ability_uses_this_turn[ability.id] = int(actor.ability_uses_this_turn.get(ability.id, 0)) + 1
	combat_system.ability_system.start_cooldown(actor, ability)
	clear_pending()
	var result := ActionResult.success_result()
	var event_data := {"ability_name": ability.display_name, "triggers_reactions": movement_effect.movement_triggers_reactions}
	result.events.append(CombatEvent.new(EventTypes.Type.ABILITY_TRIGGERED, actor.id, "", event_data))
	result.events.append(CombatEvent.new(EventTypes.Type.MOVE_STARTED, actor.id, "", event_data))
	result.events.append(CombatEvent.new(EventTypes.Type.POSITION_CHANGED, actor.id, "", {"from": origin, "to": actor.position, "distance": origin.distance_to(actor.position), "distance_feet": origin.distance_to(actor.position) / combat_system.map_rules.world_units_per_foot, "remaining_speed_feet": 0.0, "ability_name": ability.display_name}))
	result.events.append(CombatEvent.new(EventTypes.Type.MOVE_COMPLETED, actor.id, "", event_data))
	combat_system.emit_events(result.events)
	return result
