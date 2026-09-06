extends SceneTree

const PlayerData = preload("res://data/character/player.tres")
const EnemyData = preload("res://data/character/enemy.tres")
const EnemyAIScript = preload("res://combat/ai/enemy_ai_system.gd")
const StunnedData = preload("res://data/status/stunned.tres")

var failures: Array[String] = []


func _init() -> void:
	test_attack_when_target_is_in_range()
	test_move_toward_closest_target()
	test_single_target_skill_candidate()
	test_single_target_ability_candidate()
	test_status_value_and_duplicate_suppression()
	if failures.is_empty():
		print("ENEMY_AI_SYSTEM_TEST: PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("ENEMY_AI_SYSTEM_TEST: FAIL (%d)" % failures.size())
	quit(1)


func test_attack_when_target_is_in_range() -> void:
	var enemy: CombatantState = EnemyData.create_combatant_state()
	var player: CombatantState = PlayerData.create_combatant_state()
	enemy.position = Vector2(100, 100)
	player.position = Vector2(150, 100)
	var system := CombatSystem.new()
	system.start_combat([enemy, player])
	system.combat_state.current_actor_id = enemy.id
	enemy.ap = enemy.max_ap
	var ai = EnemyAIScript.new()
	var decision: Dictionary = ai.choose_decision(system, enemy)
	check(decision.type == EnemyAIScript.DecisionType.ATTACK, "Enemy AI should attack when its target is in range.")
	var request: ActionRequest = ai.build_action_request(system, decision)
	check(request != null and request.action_type == ActionTypes.Type.ATTACK and request.target_id == player.id, "Attack decision should build a normal Attack ActionRequest.")


func test_move_toward_closest_target() -> void:
	var enemy: CombatantState = EnemyData.create_combatant_state()
	var near_player: CombatantState = PlayerData.create_combatant_state()
	var far_player: CombatantState = PlayerData.create_combatant_state()
	near_player.id = "near_player"
	far_player.id = "far_player"
	enemy.position = Vector2(100, 100)
	near_player.position = Vector2(500, 100)
	far_player.position = Vector2(900, 100)
	var system := CombatSystem.new()
	system.start_combat([enemy, near_player, far_player])
	system.combat_state.current_actor_id = enemy.id
	enemy.ap = enemy.max_ap
	var ai = EnemyAIScript.new()
	var decision: Dictionary = ai.choose_decision(system, enemy)
	check(decision.type == EnemyAIScript.DecisionType.MOVE, "Enemy AI should move when the closest target is outside weapon range.")
	check(decision.target_id == near_player.id, "Enemy AI should select the closest living opponent.")
	check(decision.target_position.x > enemy.position.x, "Enemy AI movement should progress toward its chosen target.")
	var request: ActionRequest = ai.build_action_request(system, decision)
	check(request != null and request.action_type == ActionTypes.Type.MOVE, "Move decision should build a normal Move ActionRequest.")


func test_single_target_skill_candidate() -> void:
	var enemy: CombatantState = EnemyData.create_combatant_state()
	var player: CombatantState = PlayerData.create_combatant_state()
	enemy.position = Vector2(100, 100)
	player.position = Vector2(150, 100)
	var skill := SkillData.new()
	skill.id = "ai_test_skill"
	skill.display_name = "AI Test Skill"
	skill.mana_cost = 0
	skill.ap_cost = 1
	var attack := AttackData.new()
	attack.id = "ai_test_skill_attack"
	attack.range_feet = 20.0
	attack.base_damage = 50
	attack.ap_cost = 1
	skill.attack_data = attack
	enemy.available_skills = [skill]
	var system := CombatSystem.new()
	system.start_combat([enemy, player])
	system.combat_state.current_actor_id = enemy.id
	enemy.ap = enemy.max_ap
	var ai = EnemyAIScript.new()
	var decision: Dictionary = ai.choose_decision(system, enemy)
	check(decision.type == EnemyAIScript.DecisionType.SKILL, "A stronger valid single-target Skill should become the highest-scoring Candidate.")
	var request: ActionRequest = ai.build_action_request(system, decision)
	check(request != null and request.action_type == ActionTypes.Type.SKILL and request.skill_data == skill, "Skill Candidate should build a normal Skill ActionRequest.")


func test_single_target_ability_candidate() -> void:
	var enemy: CombatantState = EnemyData.create_combatant_state()
	var player: CombatantState = PlayerData.create_combatant_state()
	enemy.position = Vector2(100, 100)
	player.position = Vector2(150, 100)
	var ability := AbilityData.new()
	ability.id = "ai_test_ability"
	ability.display_name = "AI Test Ability"
	ability.ap_cost = 1
	ability.target_mode = AbilityData.TargetMode.SINGLE_COMBATANT
	ability.attack_source = AbilityData.AttackSource.CONFIGURED_ATTACK
	var attack := AttackData.new()
	attack.id = "ai_test_ability_attack"
	attack.range_feet = 20.0
	attack.base_damage = 60
	ability.attack_data = attack
	enemy.available_abilities = [ability]
	enemy.equipped_abilities = [ability.id]
	var system := CombatSystem.new()
	system.start_combat([enemy, player])
	system.combat_state.current_actor_id = enemy.id
	enemy.ap = enemy.max_ap
	var ai = EnemyAIScript.new()
	var decision: Dictionary = ai.choose_decision(system, enemy)
	check(decision.type == EnemyAIScript.DecisionType.ABILITY, "A stronger valid single-target Active Ability should become the highest-scoring Candidate.")


func test_status_value_and_duplicate_suppression() -> void:
	var target: CombatantState = PlayerData.create_combatant_state()
	var ai = EnemyAIScript.new()
	var first_value: float = ai.evaluate_status_value(StunnedData, target)
	check(first_value > 0.0, "A new control Status should add positive Utility value.")
	target.add_effect(StunnedData)
	var duplicate_value: float = ai.evaluate_status_value(StunnedData, target)
	check(duplicate_value == 0.0, "KEEP_STRONGER Status should have no Utility when the target already has equal potency.")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
