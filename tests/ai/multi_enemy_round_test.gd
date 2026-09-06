extends SceneTree

const PlayerData = preload("res://data/character/player.tres")
const SpiderData = preload("res://data/character/spider.tres")
const GiantSpiderData = preload("res://data/character/giant_spider.tres")
const EnemyAI = preload("res://combat/ai/enemy_ai_system.gd")


func _init() -> void:
	var player: CombatantState = PlayerData.create_combatant_state()
	var ally: CombatantState = PlayerData.create_combatant_state()
	ally.id = "ally"
	ally.position = Vector2(390, 370)
	var spider: CombatantState = SpiderData.create_combatant_state()
	spider.id = "enemy"
	var giant: CombatantState = GiantSpiderData.create_combatant_state()
	giant.id = "giantspider"
	var system := CombatSystem.new()
	system.start_combat([player, ally, spider, giant])
	var ai = EnemyAI.new()
	var actions_by_round: Dictionary = {}
	var safety := 0
	while system.combat_state.current_round <= 2 and not system.combat_state.is_finished() and safety < 200:
		safety += 1
		var actor: CombatantState = system.combat_state.get_current_actor()
		if actor.team == player.team:
			system.advance_turn()
			continue
		var decision: Dictionary = ai.choose_decision(system, actor)
		if int(decision.get("type", EnemyAI.DecisionType.END_TURN)) == EnemyAI.DecisionType.END_TURN:
			system.advance_turn()
			continue
		var key := "%d:%s" % [system.combat_state.current_round, actor.id]
		if not actions_by_round.has(key):
			actions_by_round[key] = []
		var candidate = decision.get("candidate")
		actions_by_round[key].append(candidate.source_data.id if candidate.source_data != null else "move")
		var result: ActionResult = ai.execute_decision(system, decision)
		while result.requires_reaction_choice:
			result = system.resolve_pending_reaction(-1)

	var failures: Array[String] = []
	for round_number in range(1, 3):
		if not actions_by_round.has("%d:enemy" % round_number):
			failures.append("Spider took no action in round %d" % round_number)
	if not actions_by_round.values().any(func(actions): return actions.has("venomous_bite")):
		failures.append("Giant Spider never used Venomous Bite")
	for failure in failures:
		push_error(failure)
	print("MULTI_ENEMY_ROUND_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	print(actions_by_round)
	quit(0 if failures.is_empty() else 1)
