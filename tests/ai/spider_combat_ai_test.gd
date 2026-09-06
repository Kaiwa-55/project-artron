extends SceneTree

const Spider = preload("res://data/character/giant_spider.tres")
const AI = preload("res://combat/ai/enemy_ai_system.gd")
var failures: Array[String] = []

func _init() -> void:
	var spider = Spider.create_combatant_state()
	var target := CombatantState.new()
	target.id = "target"
	target.team = 1
	target.base_max_hp = 100
	target.position = Vector2(240, 0)
	spider.position = Vector2.ZERO
	var system := CombatSystem.new()
	system.start_combat([spider, target])
	system.combat_state.current_actor_id = spider.id
	spider.ap = 3
	check(spider.equipped_weapon_attack == spider.natural_attack, "Natural Bite survives equipment initialization")
	var ai = AI.new()
	var decision: Dictionary = ai.choose_decision(system, spider)
	check(decision.get("candidate").source_data.id == "web_shot", "Spider opens with Web Shot at range")
	check(ai.execute_decision(system, decision).success, "Web Shot executes")
	check(spider.ap == 1, "Web Shot spends its current 2 AP cost")
	decision = ai.choose_decision(system, spider)
	check(decision.get("candidate").source_data.id == "skitter", "Spider chooses Skitter while Web Shot cools down")
	check(ai.execute_decision(system, decision).success, "Skitter executes without a player destination prompt")
	check(not system.has_pending_ability_movement() and not system.has_pending_reaction(), "Skitter leaves no pending choice")
	check(spider.ap == 0 and spider.position != Vector2.ZERO, "Skitter spends its remaining AP and moves")
	check(ai.choose_decision(system, spider).type == AI.DecisionType.END_TURN, "Spider ends after spending all AP")

	# Verify melee choice independently; the Web Shot + Skitter opener now spends all 3 AP.
	spider.ap = 3
	spider.position = target.position + Vector2.LEFT * (4.0 * system.map_rules.world_units_per_foot)
	decision = ai.choose_decision(system, spider)
	check(decision.type == AI.DecisionType.ATTACK, "Spider chooses Bite in melee range")
	check(ai.execute_decision(system, decision).success, "Bite executes")
	system.equipment_system.refresh_equipment(spider)
	check(spider.equipped_weapon_attack.id == "venomous_bite", "Bite also survives later equipment refreshes")
	spider.position = Vector2.ZERO
	spider.ap = 3
	system.ability_system.set_remaining_cooldown(spider, "web_shot", 1)
	system.ability_system.set_remaining_cooldown(spider, "skitter", 0)
	spider.ability_uses_this_turn.clear()
	system.map_rules.add_circular_obstacle(Vector2(110, 0), 20.0)
	decision = ai.choose_decision(system, spider)
	if decision.type == AI.DecisionType.MOVE or decision.type == AI.DecisionType.ABILITY:
		var destination: Vector2 = decision.get("target_position", spider.position)
		check(system.map_rules.validate_movement_path(spider, destination, system.combat_state.combatants).success, "Gridless planning only proposes an unblocked detour")
	else:
		check(decision.type == AI.DecisionType.END_TURN, "Spider ends its turn when no unblocked route exists")
	for failure in failures:
		push_error(failure)
	print("SPIDER_COMBAT_AI_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
