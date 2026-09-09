extends SceneTree

const Airborne := preload("res://data/status/airborne.tres")


func _init() -> void:
	var failures: Array[String] = []
	var effects := EffectSystem.new()
	var actor := CombatantState.new()
	actor.id = "actor"
	actor.base_max_hp = 20
	actor.hp = 20

	var airborne_three: EffectData = Airborne.duplicate(true)
	airborne_three.stacks_on_apply = 3
	check(effects.apply_effect(actor, airborne_three), "Airborne can be applied to a non-immune target", failures)
	check(get_airborne_stacks(actor) == 3, "An Ability can apply its configured number of Airborne Stacks", failures)

	var airborne_large: EffectData = Airborne.duplicate(true)
	airborne_large.stacks_on_apply = 99
	for index in range(11):
		effects.apply_effect(actor, airborne_large)
	check(get_airborne_stacks(actor) == 1092, "Airborne has no system Stack limit", failures)

	var removed := effects.decay_start_turn_stacks(actor)
	check(removed.is_empty() and get_airborne_stacks(actor) == 1091, "Airborne loses exactly 1 Stack at the target's Turn start", failures)
	actor.effects[0].stack_count = 1
	removed = effects.decay_start_turn_stacks(actor)
	check(removed.size() == 1 and not actor.has_status("airborne"), "Airborne expires when its final Stack is removed", failures)

	var immune_by_status := CombatantState.new()
	immune_by_status.status_immunities = ["airborne"]
	check(not effects.apply_effect(immune_by_status, Airborne) and not immune_by_status.has_status("airborne"), "Airborne immunity blocks the status", failures)
	var immune_by_tag := CombatantState.new()
	immune_by_tag.status_immunities = ["wind"]
	check(not effects.apply_effect(immune_by_tag, Airborne) and not immune_by_tag.has_status("airborne"), "Wind status immunity blocks Airborne", failures)

	check(Airborne.stackable and Airborne.max_stacks == 0 and Airborne.stack_decay_at_start_turn == 1, "Airborne data declares unlimited stacking and Turn-start decay", failures)
	check(Airborne.status_tags.has("wind"), "Airborne has the Wind tag", failures)

	for failure in failures:
		push_error(failure)
	print("AIRBORNE_STATUS_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func get_airborne_stacks(actor: CombatantState) -> int:
	for instance in actor.effects:
		if instance != null and instance.data != null and instance.data.id == "airborne":
			return instance.stack_count
	return 0


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
