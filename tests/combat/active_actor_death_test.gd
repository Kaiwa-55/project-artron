extends SceneTree

const PlayerData = preload("res://data/character/player.tres")
const EnemyData = preload("res://data/character/enemy.tres")

var failures: Array[String] = []


func _init() -> void:
	test_death_during_active_turn()
	test_death_from_start_of_turn_effect()
	if failures.is_empty():
		print("ACTIVE_ACTOR_DEATH_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("ACTIVE_ACTOR_DEATH_TEST: FAIL (%d)" % failures.size())
		quit(1)


func test_death_during_active_turn() -> void:
	var system := create_system()
	var actor: CombatantState = system.combat_state.get_combatant("player")
	actor.apply_damage(actor.hp)
	system.check_for_combat_end()
	check(system.combat_state.current_actor_id == "ally", "A surviving ally should take over after the active actor dies.")
	check(system.combat_state.turn_state == CombatEnums.TurnState.ACTIVE, "The next actor's turn should become active.")
	check(system.combat_state.get_current_actor().ap > 0, "The next actor should receive AP.")


func test_death_from_start_of_turn_effect() -> void:
	var system := create_system()
	var actor: CombatantState = system.combat_state.get_combatant("player")
	var damage := EffectData.new()
	damage.id = "fatal_start_turn_test"
	damage.display_name = "Fatal start turn"
	damage.effect_type = EffectData.Type.DAMAGE
	damage.trigger = EffectData.Trigger.START_OF_TURN
	damage.amount = actor.hp
	actor.add_effect(damage)
	system.combat_state.turn_state = CombatEnums.TurnState.END
	system.start_current_turn()
	check(system.combat_state.current_actor_id == "ally", "A fatal start-turn effect should skip the dead actor.")
	check(system.combat_state.turn_state == CombatEnums.TurnState.ACTIVE, "Start-turn death should not leave combat in START state.")


func create_system() -> CombatSystem:
	var player: CombatantState = PlayerData.create_combatant_state()
	var ally: CombatantState = PlayerData.create_combatant_state()
	ally.id = "ally"
	ally.display_name = "Ally"
	var enemy: CombatantState = EnemyData.create_combatant_state()
	var system := CombatSystem.new()
	system.start_combat([player, ally, enemy])
	system.combat_state.turn_order = [player.id, ally.id, enemy.id]
	system.combat_state.current_actor_id = player.id
	system.combat_state.turn_state = CombatEnums.TurnState.ACTIVE
	return system


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
