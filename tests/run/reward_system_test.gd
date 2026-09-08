extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var generator := RunGenerator.new()
	var catalog: RunEncounterCatalog = load("res://data/run/prototype_encounter_catalog.tres")
	var run_state := RunState.new()
	run_state.setup(13579, generator.generate(13579, RunGenerator.DEFAULT_FLOORS, catalog))
	var combat_node: MapNodeData
	for candidate in run_state.nodes:
		if candidate.encounter_data != null:
			combat_node = candidate
			break
	check(combat_node != null, "The generated Run needs a reward-bearing Combat Node.", failures)
	var system := RewardSystem.new()
	var first := system.generate_choices(run_state, combat_node)
	var second := system.generate_choices(run_state, combat_node)
	check(first.size() == 4, "Reward Selection should offer four choices, including XP.", failures)
	check(reward_signature(first) == reward_signature(second), "Reward choices must be deterministic for the same Seed and Node.", failures)
	var selected: RewardOptionData
	for reward in first:
		if reward.reward_type == RewardOptionData.RewardType.EXPERIENCE:
			selected = reward
			break
	check(selected != null, "Reward Selection should always include an XP choice.", failures)
	var hero_a := CombatantState.new()
	hero_a.id = "player"
	var hero_b := CombatantState.new()
	hero_b.id = "ally_1"
	ProgressionSystem.new().initialize_character(hero_a)
	ProgressionSystem.new().initialize_character(hero_b)
	run_state.party_progression_states = {"player": hero_a, "ally_1": hero_b}
	check(system.claim(run_state, combat_node.id, selected), "The first reward claim should succeed.", failures)
	check(not system.claim(run_state, combat_node.id, selected), "The same Node must not grant a second reward.", failures)
	check(run_state.reward_history.size() == 1, "A claimed reward should be recorded once.", failures)
	check(hero_a.experience == selected.amount and hero_b.experience == selected.amount, "XP rewards should apply equally to every party member.", failures)
	check(hero_a.level == hero_b.level, "Party members receiving the same XP should progress consistently.", failures)
	for failure in failures:
		push_error(failure)
	print("REWARD_SYSTEM_TEST: PASS" if failures.is_empty() else "REWARD_SYSTEM_TEST: FAIL (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)


func reward_signature(rewards: Array[RewardOptionData]) -> String:
	var entries: Array[String] = []
	for reward in rewards:
		entries.append("%s:%d" % [reward.id, reward.amount])
	return "|".join(entries)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
