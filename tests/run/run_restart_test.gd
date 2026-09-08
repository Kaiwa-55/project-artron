extends SceneTree

const RunMapScene := preload("res://scenes/run/RunMap.tscn")


func competing_seed() -> int:
	var first := RunState.generate_restart_seed(100)
	var second := RunState.generate_restart_seed(first)
	return second


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var failures: Array[String] = []
	var old_seed := competing_seed()
	var restart_seed := RunState.generate_restart_seed(old_seed)
	check(restart_seed != old_seed, "Restart generates a different Seed", failures)
	set_meta("restart_run_seed", restart_seed)
	set_meta("restart_run_at_level_one", true)
	var run_map = RunMapScene.instantiate()
	root.add_child(run_map)
	await process_frame
	check(run_map.run_state.seed == restart_seed, "Run Map uses the fresh restart Seed", failures)
	check(run_map.run_state.current_node_id == "start" and run_map.run_state.completed_node_ids.is_empty(), "Restart creates a clean route", failures)
	for member in run_map.run_state.party_progression_states.values():
		check(member.level == 1 and member.experience == 0, "Every party member restarts at Level 1 with zero XP", failures)
	check(run_map.run_state.gold == 0 and run_map.run_state.reward_history.is_empty(), "Restart clears Run rewards and Gold", failures)
	run_map.queue_free()
	if failures.is_empty():
		print("RUN_RESTART_TEST: PASS")
		quit(0)
	for failure in failures:
		push_error(failure)
	quit(1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
