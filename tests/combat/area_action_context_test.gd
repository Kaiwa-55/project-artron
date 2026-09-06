extends SceneTree

const AreaActionContextScript = preload("res://combat/targeting/area_action_context.gd")

func _init() -> void:
	var failures: Array[String] = []
	var actor := CombatantState.new(); actor.id = "actor"
	var first := CombatantState.new(); first.id = "first"
	var second := CombatantState.new(); second.id = "second"
	var skill := SkillData.new(); skill.id = "area_skill"
	var attack := AttackData.new(); attack.id = "area_attack"
	var context = AreaActionContextScript.new()
	context.setup_skill(actor, skill, Vector2(10, 20), attack, [first, second])
	check(context.source_type == AreaActionContextScript.SourceType.SKILL and context.source_data == skill, "Context should retain its Skill source", failures)
	check(context.take_next_target() == first and context.current_index == 1, "Context should resolve targets in stored order", failures)
	var attack_result := AttackResult.new(); attack_result.hit = true; attack_result.margin = 3; attack_result.final_damage = 4
	context.record_target_result(first, attack_result)
	check(context.target_results.size() == 1 and context.target_results[0].damage == 4, "Context should retain per-target results", failures)
	check(context.take_next_target() == second and not context.has_remaining_targets(), "Context should advance independently of the executor", failures)
	context.finish()
	check(context.completed and context.current_target == null, "Context should expose completion state", failures)

	var ability := AbilityData.new(); ability.id = "area_ability"
	context = AreaActionContextScript.new()
	context.setup_ability(actor, ability, Vector2.ZERO, attack, [first])
	check(context.source_type == AreaActionContextScript.SourceType.ABILITY and context.ability_data == ability, "The same Context should support Area Abilities", failures)
	context.cancel(AreaActionContextScript.CancelScope.ENTIRE_ACTION, "test")
	check(context.cancelled and not context.has_remaining_targets() and context.cancellation_reason == "test", "Context should support scoped cancellation", failures)

	if failures.is_empty(): print("AREA_ACTION_CONTEXT_TEST: PASS"); quit(0)
	for failure in failures: push_error(failure)
	quit(1)

func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition: failures.append(message)
