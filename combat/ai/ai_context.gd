class_name AIContext
extends RefCounted

var actor: CombatantState
var combat_state
var map_rules
var allies: Array[CombatantState] = []
var enemies: Array[CombatantState] = []
var available_ap: int = 0
var available_mana: int = 0
var movement_remaining_feet: float = 0.0
var current_round: int = 0


func setup(system: CombatSystem, acting_combatant: CombatantState) -> void:
	actor = acting_combatant
	combat_state = system.get_combat_state()
	map_rules = system.map_rules
	available_ap = acting_combatant.ap
	available_mana = acting_combatant.mana
	movement_remaining_feet = acting_combatant.movement_remaining_feet
	current_round = combat_state.current_round
	for combatant in combat_state.combatants.values():
		if combatant == null or combatant.is_dying():
			continue
		if combatant.team == acting_combatant.team:
			allies.append(combatant)
		else:
			enemies.append(combatant)


func get_closest_enemy() -> CombatantState:
	var result: CombatantState
	var best_distance := INF
	for enemy in enemies:
		var distance := actor.position.distance_squared_to(enemy.position)
		if distance < best_distance:
			best_distance = distance
			result = enemy
	return result
