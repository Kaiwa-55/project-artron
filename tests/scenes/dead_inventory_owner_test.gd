extends SceneTree

const PrototypeCombatScript := preload("res://scenes/prototype/prototype_combat.gd")

var failures: Array[String] = []


func _init() -> void:
	var prototype = PrototypeCombatScript.new()
	prototype.combat_system = CombatSystem.new()
	prototype.combat_system.combat_state = CombatState.new()
	var state: CombatState = prototype.combat_system.combat_state

	var player := make_combatant("player", 1)
	var ally := make_combatant("ally", 1)
	var enemy := make_combatant("enemy", 2)
	for combatant in [player, ally, enemy]:
		state.add_combatant(combatant)
	state.turn_order = [player.id, ally.id, enemy.id]
	state.current_actor_id = enemy.id

	ally.life_state = CombatEnums.LifeState.DYING
	prototype.selected_character_id = ally.id
	check(prototype.get_displayed_party_member() == player, "Inventory ignores a dead selected party member")

	ally.life_state = CombatEnums.LifeState.ALIVE
	player.life_state = CombatEnums.LifeState.DYING
	prototype.selected_character_id = player.id
	check(prototype.get_displayed_party_member() == ally, "Inventory falls back to a living Ally when the primary character dies")

	for failure in failures:
		push_error(failure)
	print("DEAD_INVENTORY_OWNER_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func make_combatant(id: String, team: int) -> CombatantState:
	var combatant := CombatantState.new()
	combatant.id = id
	combatant.team = team
	combatant.life_state = CombatEnums.LifeState.ALIVE
	return combatant


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
