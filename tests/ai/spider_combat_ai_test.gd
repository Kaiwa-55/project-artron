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
	check(spider.ap == 2, "Web Shot leaves two AP")
	decision = ai.choose_decision(system, spider)
	check(decision.get("candidate").source_data.id == "skitter", "Spider chooses Skitter while Web Shot cools down")
	check(ai.execute_decision(system, decision).success, "Skitter executes without a player destination prompt")
	check(not system.has_pending_ability_movement() and not system.has_pending_reaction(), "Skitter leaves no pending choice")
	check(spider.ap == 1 and spider.position != Vector2.ZERO, "Skitter spends one AP and moves")
	decision = ai.choose_decision(system, spider)
	check(decision.type == AI.DecisionType.ATTACK, "Spider chooses Bite in melee range")
	check(ai.execute_decision(system, decision).success, "Bite executes")
	check(spider.ap == 0 and ai.choose_decision(system, spider).type == AI.DecisionType.END_TURN, "Spider ends only after spending its AP")
	spider.ap = 3
	system.equipment_system.refresh_equipment(spider)
	check(spider.equipped_weapon_attack.id == "venomous_bite", "Bite also survives later equipment refreshes")
	spider.position = Vector2.ZERO
	system.ability_system.set_remaining_cooldown(spider, "skitter", 0)
	spider.ability_uses_this_turn.clear()
	system.map_rules.add_circular_obstacle(Vector2(110, 0), 20.0)
	decision = ai.choose_decision(system, spider)
	check(decision.type == AI.DecisionType.END_TURN, "Blocked paths are not proposed for Move or Skitter")
	for failure in failures:
		push_error(failure)
	print("SPIDER_COMBAT_AI_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
