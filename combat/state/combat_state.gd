class_name CombatState
extends RefCounted


var combatants: Dictionary = {}

var turn_order: Array[String] = []

var current_round: int = 1
var current_actor_id: String = ""

var turn_state: CombatEnums.TurnState = \
	CombatEnums.TurnState.START

var combat_result: CombatEnums.CombatResult = \
	CombatEnums.CombatResult.IN_PROGRESS
var winner_team: int = 0


func add_combatant(
	combatant: CombatantState
) -> void:
	combatants[combatant.id] = combatant


func get_combatant(
	combatant_id: String
) -> CombatantState:

	return combatants.get(combatant_id, null)


func has_combatant(
	combatant_id: String
) -> bool:

	return combatants.has(combatant_id)


func get_current_actor() -> CombatantState:
	return get_combatant(current_actor_id)


func is_finished() -> bool:
	return combat_result != CombatEnums.CombatResult.IN_PROGRESS
