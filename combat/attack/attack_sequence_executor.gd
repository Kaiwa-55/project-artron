class_name AttackSequenceExecutor
extends RefCounted

var combat_system
var pending_context: Dictionary = {}


func _init(p_combat_system) -> void:
	combat_system = p_combat_system


func execute_dual_weapon(actor: CombatantState, target: CombatantState, ability: AbilityData) -> ActionResult:
	var setup: ActionResult = combat_system.equipment_system.validate_dual_weapon_setup(actor)
	if not setup.success:
		return setup
	var main_item = actor.equipped_items.get(EquipmentSystem.WEAPON_SLOT_1)
	var off_item = actor.equipped_items.get(EquipmentSystem.WEAPON_SLOT_2)
	var main_attack: AttackData = main_item.weapon_attack.duplicate(true)
	var off_attack: AttackData = off_item.weapon_attack.duplicate(true)
	main_attack.ap_cost = 0
	off_attack.ap_cost = 0
	if not combat_system.trait_system.attack_has_trait(off_attack, "light"):
		off_attack.to_hit_bonus -= 2
	if combat_system.trait_system.attack_has_trait(main_attack, "paired") and combat_system.trait_system.attack_has_trait(off_attack, "paired"):
		off_attack.base_damage += 1
	var range_feet: float = minf(main_attack.range_feet, off_attack.range_feet)
	if not combat_system.map_rules.is_target_in_range(actor, target, range_feet):
		return ActionResult.failure("Target is out of Dual Strike range (%.0f ft)." % range_feet)
	if not actor.spend_ap(ability.ap_cost):
		return ActionResult.failure("Not enough AP.")
	if not actor.spend_faith(ability.faith_cost):
		actor.change_ap(ability.ap_cost)
		return ActionResult.failure("Not enough Faith.")
	combat_system.cancel_remaining_movement(actor)
	actor.ability_uses_this_turn[ability.id] = int(actor.ability_uses_this_turn.get(ability.id, 0)) + 1
	var cooldown: int = combat_system.ability_system.start_cooldown(actor, ability)
	pending_context = {
		"actor_id": actor.id,
		"target_id": target.id,
		"ability": ability,
		"attacks": [main_attack, off_attack],
		"index": 0,
	}
	var opening_events: Array[CombatEvent] = [CombatEvent.new(EventTypes.Type.ABILITY_TRIGGERED, actor.id, target.id, {
		"ability_name": ability.display_name,
		"ap_cost": ability.ap_cost,
		"cooldown": cooldown,
		"attack_count": 2,
	})]
	combat_system.emit_events(opening_events)
	return _continue(opening_events)


func resume_after_reaction(carried_events: Array[CombatEvent]) -> ActionResult:
	return _continue(carried_events)


func _continue(carried_events: Array[CombatEvent]) -> ActionResult:
	var combined := ActionResult.success_result()
	combined.events.append_array(carried_events)
	while not pending_context.is_empty():
		var actor: CombatantState = combat_system.combat_state.get_combatant(pending_context.get("actor_id", ""))
		var target: CombatantState = combat_system.combat_state.get_combatant(pending_context.get("target_id", ""))
		var attacks: Array = pending_context.get("attacks", [])
		var index: int = int(pending_context.get("index", 0))
		if actor == null or target == null or actor.is_dying() or target.is_dying() or index >= attacks.size():
			pending_context = {}
			return combined
		var request := ActionRequest.new(actor.id, ActionTypes.Type.ATTACK)
		request.target_id = target.id
		request.attack_data = attacks[index]
		request.attack_sequence_continuation = true
		pending_context["index"] = index + 1
		var step: ActionResult = combat_system.combat_action_executor.execute(request)
		combined.success = step.success
		combined.failure_reason = step.failure_reason
		combined.events.append_array(step.events)
		if not step.success:
			pending_context = {}
			return combined
		if step.requires_reaction_choice:
			combined.requires_reaction_choice = true
			combined.reaction_prompt = step.reaction_prompt
			return combined
	pending_context = {}
	return combined
