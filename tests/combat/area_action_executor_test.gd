extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var actor: CombatantState = load("res://data/character/player.tres").create_combatant_state()
	var enemy: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	actor.position = Vector2.ZERO
	enemy.position = Vector2(60, 0)
	enemy.active_reactions.clear()
	var skill = load("res://data/skill/arcane_burst.tres").duplicate(true)
	skill.attack_data = skill.attack_data.duplicate(true)
	skill.attack_data.requires_to_hit = false
	actor.max_mana = 10
	actor.mana = 10
	var system := CombatSystem.new()
	system.start_combat([actor, enemy])
	actor.available_skills.append(skill)
	system.combat_state.current_actor_id = actor.id
	actor.ap = 10
	actor.mana = 10

	check(system.area_action_executor != null, "CombatSystem should own an AreaActionExecutor", failures)
	check(system.validate_ground_skill_start(actor.id, skill.id).success, "Public validation should delegate to AreaActionExecutor", failures)
	var result := system.execute_ground_skill(actor.id, skill.id, enemy.position)
	check(result.success, "Public execution should delegate to AreaActionExecutor", failures)
	check(system.pending_area_context == null, "Compatibility accessor should expose the Executor context", failures)
	check(result.events.any(func(event): return event.type == EventTypes.Type.SKILL_CAST), "AreaActionExecutor should emit the Area summary", failures)

	if failures.is_empty():
		print("AREA_ACTION_EXECUTOR_TEST: PASS")
		quit(0)
	for failure in failures:
		push_error(failure)
	quit(1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
