class_name TurnSystem
extends RefCounted


func start_turn(
	combat_state: CombatState
) -> void:

	var actor := combat_state.get_current_actor()

	if actor == null:
		return

	combat_state.turn_state = \
		CombatEnums.TurnState.START

	actor.clear_temporary_defense()
	actor.movement_in_progress = false
	actor.movement_remaining_feet = 0.0
	actor.movement_distance_this_turn = 0.0
	actor.ability_uses_this_turn.clear()
	# AP reset behavior ยังไม่ได้กำหนดเป็น Rule Lock
	# จึงไม่เติม logic เอง




func activate_turn(
	combat_state: CombatState,
	effective_max_ap: int
) -> void:
	var actor := combat_state.get_current_actor()
	if actor == null:
		return

	actor.effective_max_ap = max(0, effective_max_ap)
	actor.ap = actor.effective_max_ap
	combat_state.turn_state = \
		CombatEnums.TurnState.ACTIVE


func end_turn(
	combat_state: CombatState
) -> void:
	var actor := combat_state.get_current_actor()
	if actor != null:
		actor.movement_in_progress = false
		actor.movement_remaining_feet = 0.0

	combat_state.turn_state = \
		CombatEnums.TurnState.END

func next_actor(
	combat_state: CombatState
) -> CombatantState:

	if combat_state.turn_order.is_empty():
		return null

	var current_index := \
		combat_state.turn_order.find(
			combat_state.current_actor_id
		)

	for step in range(1, combat_state.turn_order.size() + 1):
		var next_index := (current_index + step) % combat_state.turn_order.size()
		var next_actor := combat_state.get_combatant(combat_state.turn_order[next_index])
		if next_actor != null and not next_actor.is_dying():
			if current_index + step >= combat_state.turn_order.size():
				combat_state.current_round += 1
			combat_state.current_actor_id = next_actor.id
			return next_actor

	return null
