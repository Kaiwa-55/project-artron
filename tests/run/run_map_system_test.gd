extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var generator := RunGenerator.new()
	var catalog: RunEncounterCatalog = load("res://data/run/prototype_encounter_catalog.tres")
	check(catalog.combat_encounters.size() == 3, "The Run catalog should contain three normal Combat encounters.", failures)
	check(catalog.elite_encounters.size() == 2, "The Run catalog should contain two Elite encounters.", failures)
	check(catalog.boss_encounters.size() == 1, "The Run catalog should contain one Boss encounter.", failures)
	check_encounter_levels(catalog.combat_encounters, 3, 4, "Combat", failures)
	check_encounter_levels(catalog.elite_encounters, 4, 5, "Elite", failures)
	check_encounter_levels(catalog.boss_encounters, 6, 6, "Boss", failures)
	var first := generator.generate(424242, RunGenerator.DEFAULT_FLOORS, catalog)
	var second := generator.generate(424242, RunGenerator.DEFAULT_FLOORS, catalog)
	var state := RunState.new()
	state.setup(424242, first)
	var comparison := RunState.new()
	comparison.setup(424242, second)
	check(state.get_signature() == comparison.get_signature(), "The same Seed must generate the same map.", failures)
	check(first.front().node_type == MapNodeData.NodeType.START, "The map must begin at Start.", failures)
	check(first.back().node_type == MapNodeData.NodeType.BOSS, "The map must end at Boss.", failures)
	check(not state.get_available_node_ids().is_empty(), "Start must offer at least one route.", failures)
	var first_choice: String = String(state.get_available_node_ids().front())
	check(state.enter_node(first_choice), "An available connected Node should be enterable.", failures)
	check(not state.enter_node("boss"), "A disconnected Node must not be enterable.", failures)
	for node in first:
		if node.node_type != MapNodeData.NodeType.BOSS:
			check(not node.next_node_ids.is_empty(), "%s must have a route forward." % node.id, failures)
		if not node.encounter_pool_id.is_empty():
			check(node.encounter_data != null, "%s must resolve its EncounterData from the catalog." % node.id, failures)
	for failure in failures:
		push_error(failure)
	print("RUN_MAP_SYSTEM_TEST: PASS" if failures.is_empty() else "RUN_MAP_SYSTEM_TEST: FAIL (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func check_encounter_levels(encounters: Array[EncounterData], minimum: int, maximum: int, tier: String, failures: Array[String]) -> void:
	for encounter in encounters:
		var total_level := 0
		for enemy in encounter.enemies:
			total_level += enemy.level
		check(total_level >= minimum and total_level <= maximum, "%s encounter %s has total monster level %d; expected %d-%d." % [tier, encounter.id, total_level, minimum, maximum], failures)
