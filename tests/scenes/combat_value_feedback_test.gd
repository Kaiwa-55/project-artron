extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var failures: Array[String] = []
	var arena = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var presenter = arena.movement_presentation
	presenter.set_process(false)
	while presenter.sync_movement():
		await process_frame
	presenter.collect_attack_animations()
	presenter.event_cursor = arena.combat_system.event_system.event_history.size()
	presenter.attack_queue.clear()
	var target: Combatant = arena.get_node("BattlefieldWorld/PlayerCharacter")
	arena.combat_system.event_system.emit(CombatEvent.new(EventTypes.Type.DAMAGE_APPLIED, "enemy", "player", {"amount": 7}))
	presenter.sync_movement()
	check(target.floating_value_labels.size() == 1 and target.floating_value_labels[0].text == "-7", "Damage event displays a red negative number", failures)
	arena.combat_system.event_system.emit(CombatEvent.new(EventTypes.Type.EFFECT_HEAL_APPLIED, "ally", "player", {"amount": 4}))
	presenter.sync_movement()
	check(target.floating_value_labels.size() == 2 and target.floating_value_labels[1].text == "+4", "Heal event displays a green positive number", failures)
	arena.combat_system.event_system.emit(CombatEvent.new(EventTypes.Type.EFFECT_DAMAGE_APPLIED, "", "player", {"amount": 0}))
	presenter.sync_movement()
	check(target.floating_value_labels.size() == 2, "Zero damage does not display a number", failures)
	await create_timer(1.0).timeout
	check(target.floating_value_labels.is_empty(), "Combat values float upward and clean themselves up", failures)
	arena.queue_free()
	for failure in failures:
		push_error(failure)
	print("COMBAT_VALUE_FEEDBACK_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
