extends SceneTree

const EnemyAIScript = preload("res://combat/ai/enemy_ai_system.gd")
const VelkariaData = preload("res://data/character/velkaria.tres")
const PlayerData = preload("res://data/character/player.tres")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var system := CombatSystem.new()
	var boss: CombatantState = VelkariaData.create_combatant_state()
	boss.position = Vector2(800, 250)
	var first: CombatantState = PlayerData.create_combatant_state()
	first.id = "target_a"
	first.position = Vector2(540, 250)
	var second: CombatantState = PlayerData.create_combatant_state()
	second.id = "target_b"
	second.position = Vector2(700, 250)
	system.start_combat([boss, first, second])
	system.combat_state.current_actor_id = boss.id
	system.start_current_turn()
	var ai = EnemyAIScript.new()
	var first_decision: Dictionary = ai.choose_decision(system, boss)
	var first_candidate = first_decision.get("candidate")
	var chose_royal_web: bool = first_candidate != null and first_candidate.get_source_id() == "royal_web"
	var midpoint := (first.position + second.position) * 0.5
	var used_multi_target_placement: bool = chose_royal_web and first_candidate.target_position.is_equal_approx(midpoint)
	var sequence: Array[String] = [first_candidate.get_source_id() if first_candidate != null else ""]
	var result: ActionResult = ai.execute_decision(system, first_decision)
	var safety := 0
	while result.success and not system.has_pending_reaction() and boss.ap > 1 and safety < 8:
		safety += 1
		var decision: Dictionary = ai.choose_decision(system, boss)
		if int(decision.get("type", EnemyAIScript.DecisionType.END_TURN)) == EnemyAIScript.DecisionType.END_TURN:
			break
		sequence.append(decision.get("candidate").get_source_id())
		result = ai.execute_decision(system, decision)
	var saved_reaction_ap: bool = boss.ap >= 1
	var continued_combo: bool = sequence.size() >= 2 and sequence[0] == "royal_web" and sequence[1] == "matriarch_fangs"
	var phase_one: bool = int(first_decision.get("boss_phase", 0)) == 1

	# Phase 2 favors closing distance, while Phase 3 drops the Reaction reserve
	# and commits to its damaging finisher.
	var phase_system := CombatSystem.new()
	var phase_boss: CombatantState = VelkariaData.create_combatant_state()
	var phase_target: CombatantState = PlayerData.create_combatant_state()
	phase_target.id = "phase_target"
	phase_boss.position = Vector2(800, 250)
	phase_target.position = Vector2(580, 250)
	phase_system.start_combat([phase_boss, phase_target])
	phase_system.combat_state.current_actor_id = phase_boss.id
	phase_system.start_current_turn()
	var phase_ai = EnemyAIScript.new()
	phase_boss.hp = floori(float(phase_boss.max_hp) * 0.60)
	var phase_two_decision: Dictionary = phase_ai.choose_decision(phase_system, phase_boss)
	var phase_two_approaches: bool = int(phase_two_decision.get("boss_phase", 0)) == 2 and phase_two_decision.get("candidate").get_source_id() == "brood_rush"
	phase_boss.hp = floori(float(phase_boss.max_hp) * 0.30)
	phase_target.position = Vector2(620, 250)
	var phase_three_decision: Dictionary = phase_ai.choose_decision(phase_system, phase_boss)
	var phase_three_finishes: bool = int(phase_three_decision.get("boss_phase", 0)) == 3 and phase_three_decision.get("candidate").get_source_id() == "matriarch_fangs"
	var success := chose_royal_web and used_multi_target_placement and saved_reaction_ap and continued_combo and phase_one and phase_two_approaches and phase_three_finishes
	if not success:
		push_error("Velkaria must change phases, execute its Web combo, and reserve Reaction AP outside Phase 3.")
		print("SEQUENCE=", sequence, " PHASE2=", phase_two_decision.get("candidate").get_source_id(), " PHASE3=", phase_three_decision.get("candidate").get_source_id())
	print("VELKARIA_BOSS_AI_TEST: " + ("PASS" if success else "FAIL") + " sequence=" + str(sequence) + " AP=" + str(boss.ap))
	quit(0 if success else 1)
