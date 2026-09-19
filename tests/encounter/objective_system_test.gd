extends SceneTree

const EncounterObjectiveScript := preload("res://data/encounter/encounter_objective.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	test_defeat_all()
	test_defeat_target()
	test_survive_turns()
	test_reach_area()
	test_default_combat_end()
	if failures.is_empty():
		print("OBJECTIVE_SYSTEM_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("OBJECTIVE_SYSTEM_TEST: FAIL (%d)" % failures.size())
		quit(1)


func test_defeat_all() -> void:
	var setup := create_combat_setup()
	var system: CombatSystem = setup.system
	var enemy: CombatantState = setup.enemy
	var objective := EncounterObjectiveScript.new()
	objective.id = "defeat_all"
	objective.type = EncounterObjectiveScript.Type.DEFEAT_ALL
	objective.target_team = 2
	var encounter := EncounterData.new()
	encounter.objectives.append(objective)
	system.configure_encounter_objectives(encounter)
	check(not system.combat_state.is_finished(), "DefeatAll should wait while a target-team member is alive.")
	enemy.life_state = CombatEnums.LifeState.DYING
	system.event_system.emit(CombatEvent.new(EventTypes.Type.DAMAGE_APPLIED, "player", enemy.id))
	check(system.combat_state.combat_result == CombatEnums.CombatResult.VICTORY, "DefeatAll should complete after every target-team member is Dying.")


func test_defeat_target() -> void:
	var setup := create_combat_setup(true)
	var system: CombatSystem = setup.system
	var target: CombatantState = setup.enemy
	var other: CombatantState = setup.other_enemy
	var objective := EncounterObjectiveScript.new()
	objective.id = "defeat_leader"
	objective.type = EncounterObjectiveScript.Type.DEFEAT_TARGET
	objective.target_id = target.id
	system.encounter_objective_system.setup(system, [objective])
	target.life_state = CombatEnums.LifeState.DYING
	system.event_system.emit(CombatEvent.new(EventTypes.Type.DAMAGE_APPLIED, "player", target.id))
	check(not other.is_dying() and system.combat_state.combat_result == CombatEnums.CombatResult.VICTORY, "DefeatTarget should win when the configured target falls even if other enemies remain.")


func test_survive_turns() -> void:
	var setup := create_combat_setup()
	var system: CombatSystem = setup.system
	var objective := EncounterObjectiveScript.new()
	objective.id = "survive_three"
	objective.type = EncounterObjectiveScript.Type.SURVIVE_TURNS
	objective.turn_count = 3
	system.encounter_objective_system.setup(system, [objective])
	system.combat_state.current_round = 3
	system.event_system.emit(CombatEvent.new(EventTypes.Type.TURN_STARTED, "player"))
	check(not system.combat_state.is_finished(), "SurviveTurns should not complete before the requested full rounds have elapsed.")
	system.combat_state.current_round = 4
	system.event_system.emit(CombatEvent.new(EventTypes.Type.TURN_STARTED, "player"))
	check(system.combat_state.combat_result == CombatEnums.CombatResult.VICTORY, "SurviveTurns should complete at the start of the round after the requested turns.")


func test_reach_area() -> void:
	var setup := create_combat_setup()
	var system: CombatSystem = setup.system
	var player: CombatantState = setup.player
	var objective := EncounterObjectiveScript.new()
	objective.id = "reach_exit"
	objective.type = EncounterObjectiveScript.Type.REACH_AREA
	objective.actor_team = 1
	objective.area_center_feet = Vector2(20, 5)
	objective.area_radius_feet = 3.0
	system.encounter_objective_system.setup(system, [objective])
	check(not system.combat_state.is_finished(), "ReachArea should wait while eligible units are outside its radius.")
	player.position = objective.area_center_feet * system.map_rules.world_units_per_foot
	system.event_system.emit(CombatEvent.new(EventTypes.Type.POSITION_CHANGED, player.id))
	check(system.combat_state.combat_result == CombatEnums.CombatResult.VICTORY, "ReachArea should complete when a living eligible unit enters the authored area.")


func test_default_combat_end() -> void:
	var setup := create_combat_setup()
	var system: CombatSystem = setup.system
	var enemy: CombatantState = setup.enemy
	enemy.life_state = CombatEnums.LifeState.DYING
	check(system.check_for_combat_end(), "Default team-elimination Combat should still detect its end.")
	check(system.combat_state.combat_result == CombatEnums.CombatResult.VICTORY and system.event_system.event_history.back().type == EventTypes.Type.COMBAT_VICTORY, "Default Combat end should retain its Victory result and event.")


func create_combat_setup(include_other_enemy: bool = false) -> Dictionary:
	var system := CombatSystem.new()
	system.combat_state = CombatState.new()
	var player := create_member("player", 1, Vector2.ZERO)
	var enemy := create_member("enemy_leader", 2, Vector2(500, 0))
	system.combat_state.add_combatant(player)
	system.combat_state.add_combatant(enemy)
	var result := {"system": system, "player": player, "enemy": enemy}
	if include_other_enemy:
		var other_enemy := create_member("enemy_guard", 2, Vector2(600, 0))
		system.combat_state.add_combatant(other_enemy)
		result["other_enemy"] = other_enemy
	return result


func create_member(id: String, team: int, position: Vector2) -> CombatantState:
	var member := CombatantState.new()
	member.id = id
	member.team = team
	member.position = position
	member.max_hp = 10
	member.hp = 10
	return member


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
