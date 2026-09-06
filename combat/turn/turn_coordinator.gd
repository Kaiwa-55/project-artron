class_name TurnCoordinator
extends RefCounted

var combat_system


func _init(p_combat_system) -> void:
	combat_system = p_combat_system


func start_combat(combatants: Array[CombatantState]) -> void:
	combat_system.combat_state = CombatState.new()
	for combatant in combatants:
		combatant.last_attack_declared_round = 0
		combatant.last_step_back_round = 0
		combat_system.ancestry_system.apply_ancestry(combatant)
		combat_system.class_system.apply_class(combatant)
		if combatant.has_meta("class_data"):
			combat_system.progression_system.initialize_character(combatant)
		combat_system.ability_system.sync_granted_reactions(combatant)
		combat_system.equipment_system.initialize_combatant(combatant)
		combat_system.equipment_system.refresh_equipment(combatant)
		combat_system.stat_system.initialize_combatant(combatant)
		if combatant.max_faith > 0:
			combatant.faith = combatant.max_faith
			combatant.temporary_faith = 0
		combat_system.combat_state.add_combatant(combatant)
	combat_system.combat_state.turn_order = combat_system.initiative_system.build_turn_order(combatants)
	if not combat_system.combat_state.turn_order.is_empty():
		combat_system.combat_state.current_actor_id = combat_system.combat_state.turn_order[0]
	combat_system.event_system.emit(CombatEvent.new(EventTypes.Type.COMBAT_STARTED))
	if not combat_system.combat_state.current_actor_id.is_empty():
		start_current_turn()


func advance_turn() -> void:
	if combat_system.combat_state == null or combat_system.combat_state.is_finished():
		return
	combat_system.ability_movement_executor.clear_pending()
	var previous_actor: CombatantState = combat_system.combat_state.get_current_actor()
	combat_system.clear_hidden(previous_actor, "Turn ended")
	for cooldown in combat_system.skill_system.reduce_cooldowns(previous_actor):
		combat_system.event_system.emit(CombatEvent.new(EventTypes.Type.SKILL_COOLDOWN_REDUCED, previous_actor.id, "", cooldown))
	for cooldown in combat_system.ability_system.reduce_cooldowns(previous_actor):
		combat_system.event_system.emit(CombatEvent.new(EventTypes.Type.ABILITY_COOLDOWN_REDUCED, previous_actor.id, "", cooldown))
	combat_system.emit_effect_resolutions(previous_actor, combat_system.effect_system.resolve_effects(previous_actor, EffectData.Trigger.END_OF_TURN))
	var temporary_faith_lost := previous_actor.decay_temporary_faith(2)
	if temporary_faith_lost > 0:
		combat_system.event_system.emit(CombatEvent.new(EventTypes.Type.FAITH_CHANGED, previous_actor.id, previous_actor.id, {"temporary_faith_lost": temporary_faith_lost, "faith": previous_actor.faith, "temporary_faith": previous_actor.temporary_faith}))
	for effect in combat_system.effect_system.decay_end_turn_stacks(previous_actor):
		combat_system.event_system.emit(CombatEvent.new(EventTypes.Type.EFFECT_EXPIRED, previous_actor.id, "", {"effect_name": effect.data.display_name}))
	combat_system.turn_system.end_turn(combat_system.combat_state)
	combat_system.event_system.emit(CombatEvent.new(EventTypes.Type.TURN_ENDED, previous_actor.id))
	for effect in combat_system.effect_system.expire_turn_end_effects(previous_actor):
		combat_system.event_system.emit(CombatEvent.new(EventTypes.Type.EFFECT_EXPIRED, previous_actor.id, "", {"effect_name": effect.data.display_name}))
	for cleared_ability in combat_system.ability_system.clear_end_turn_bonuses(previous_actor):
		combat_system.event_system.emit(CombatEvent.new(EventTypes.Type.ABILITY_STACKS_CLEARED, previous_actor.id, "", cleared_ability))
	if combat_system.check_for_combat_end():
		return
	var next_actor = combat_system.turn_system.next_actor(combat_system.combat_state)
	if next_actor == null:
		combat_system.check_for_combat_end()
		return
	start_current_turn()


func start_current_turn() -> void:
	if combat_system.combat_state == null or combat_system.combat_state.is_finished():
		return
	var actor: CombatantState = combat_system.combat_state.get_current_actor()
	if actor == null or actor.is_dying():
		return
	combat_system.turn_system.start_turn(combat_system.combat_state)
	for effect in combat_system.effect_system.expire_start_turn_effects(actor):
		combat_system.event_system.emit(CombatEvent.new(EventTypes.Type.EFFECT_EXPIRED, actor.id, "", {"effect_name": effect.data.display_name}))
	combat_system.event_system.emit(CombatEvent.new(EventTypes.Type.TURN_STARTED, actor.id))
	combat_system.emit_effect_resolutions(actor, combat_system.effect_system.resolve_effects(actor, EffectData.Trigger.START_OF_TURN))
	if combat_system.check_for_combat_end():
		return
	combat_system.turn_system.activate_turn(combat_system.combat_state, actor.max_ap + combat_system.effect_system.get_max_ap_bonus(actor) - combat_system.effect_system.get_max_ap_penalty(actor))
