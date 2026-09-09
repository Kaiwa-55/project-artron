extends SceneTree

const Rooted := preload("res://data/status/rooted.tres")


func _init() -> void:
	var failures: Array[String] = []
	var system := CombatSystem.new()
	var source := make_actor("source", 2, 5, 10)
	var target := make_actor("target", 1, 1, 210)
	system.start_combat([target, source])
	system.combat_state.current_actor_id = target.id
	system.effect_system.apply_effect(target, Rooted, "test_root", "Test Root", false, source)
	var rooted_instance: EffectInstance = target.effects.filter(func(instance): return instance.data.id == "rooted")[0]
	check(rooted_instance.source_class_dc == 17, "Rooted captures the source's Class DC when applied", failures)
	source.level = 10
	check(rooted_instance.source_class_dc == 17, "A captured Escape DC does not change later", failures)
	var before_ap := target.ap
	var success: ActionResult = system.execute_escape(target.id, "rooted")
	check(success.success and not target.has_status("rooted"), "A successful Escape removes Rooted", failures)
	check(target.ap == before_ap - 1, "Escape costs 1 AP", failures)
	check(success.events.size() == 1 and success.events[0].data.succeeded, "Escape emits its roll result", failures)

	var hard_source := make_actor("hard_source", 2, 100, 10)
	target.strength = 1
	target.ap = 4
	system.effect_system.apply_effect(target, Rooted, "hard_root", "Hard Root", false, hard_source)
	before_ap = target.ap
	var failure: ActionResult = system.execute_escape(target.id, "rooted")
	check(failure.success and target.has_status("rooted"), "A failed Escape leaves Rooted active", failures)
	check(target.ap == before_ap - 1, "A failed Escape still costs AP", failures)
	check(not failure.events[0].data.succeeded, "Failed Escape is reported", failures)

	if failures.is_empty():
		print("ESCAPE_ACTION_TEST: PASS")
		quit(0)
	for item in failures:
		push_error(item)
	quit(1)


func make_actor(id: String, team: int, level: int, strength: int) -> CombatantState:
	var actor := CombatantState.new()
	actor.id = id
	actor.display_name = id.capitalize()
	actor.team = team
	actor.level = level
	actor.strength = strength
	actor.max_hp = 20
	actor.hp = 20
	actor.max_ap = 4
	actor.base_max_ap = 4
	actor.ap = 4
	return actor


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
