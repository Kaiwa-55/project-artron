extends SceneTree

const PlayerData = preload("res://data/character/player.tres")
const EnemyData = preload("res://data/character/enemy.tres")
const ParryData = preload("res://data/reaction/parry.tres")

var failures: Array[String] = []


func _init() -> void:
	test_single_attack_and_skill_reactions()
	test_reaction_attack_inside_movement_queue()
	test_area_action_resumes_after_each_defense()
	if failures.is_empty():
		print("REACTION_ACTION_INTEGRATION_TEST: PASS")
		quit(0)
	for failure in failures:
		push_error(failure)
	quit(1)


func test_single_attack_and_skill_reactions() -> void:
	var player: CombatantState = PlayerData.create_combatant_state()
	var enemy: CombatantState = EnemyData.create_combatant_state()
	player.position = Vector2(160, 100)
	enemy.position = Vector2(100, 100)
	player.active_reactions = [ParryData]
	var guaranteed := AttackData.new()
	guaranteed.id = "reaction_flow_attack"
	guaranteed.display_name = "Reaction Flow Attack"
	guaranteed.requires_to_hit = false
	guaranteed.ap_cost = 0
	guaranteed.base_damage = 0
	guaranteed.range_feet = 20.0
	var system := CombatSystem.new()
	system.start_combat([enemy, player])
	system.combat_state.current_actor_id = enemy.id
	player.ap = player.max_ap
	enemy.ap = enemy.max_ap
	var attack_request := ActionRequest.new(enemy.id, ActionTypes.Type.ATTACK)
	attack_request.target_id = player.id
	attack_request.attack_data = guaranteed
	var attack_prompt := system.execute_action(attack_request)
	check(attack_prompt.requires_reaction_choice and attack_prompt.reaction_prompt.has("prepared_attack"), "Single Attack should pause before final Hit/Damage for Defensive Reactions.")
	var attack_resumed := system.resolve_pending_reaction(-1)
	check(attack_resumed.success and not system.has_pending_reaction(), "Single Attack should resume after its Reaction choice.")

	var skill := SkillData.new()
	skill.id = "reaction_flow_skill"
	skill.display_name = "Reaction Flow Skill"
	skill.attack_data = guaranteed
	skill.ap_cost = 0
	enemy.available_skills = [skill]
	player.ap = player.max_ap
	var skill_request := ActionRequest.new(enemy.id, ActionTypes.Type.SKILL)
	skill_request.target_id = player.id
	skill_request.skill_data = skill
	var skill_prompt := system.execute_action(skill_request)
	check(skill_prompt.requires_reaction_choice and skill_prompt.reaction_prompt.get("skill_data") == skill, "Single-target Skill should use the same Defensive Reaction window.")
	var skill_resumed := system.resolve_pending_reaction(-1)
	check(skill_resumed.success and not system.has_pending_reaction(), "Single-target Skill should resume after its Reaction choice.")
	check(skill_resumed.events.any(func(event): return event.type == EventTypes.Type.SKILL_CAST), "Resumed Skill should finish and emit its Skill event.")


func test_reaction_attack_inside_movement_queue() -> void:
	var player: CombatantState = PlayerData.create_combatant_state()
	var enemy: CombatantState = EnemyData.create_combatant_state()
	player.position = Vector2(200, 100)
	enemy.position = Vector2(105, 75)
	player.active_reactions = [ParryData]
	var guaranteed := AttackData.new()
	guaranteed.id = "guaranteed_opportunity"
	guaranteed.display_name = "Guaranteed Opportunity"
	guaranteed.requires_to_hit = false
	guaranteed.ap_cost = 0
	guaranteed.base_damage = 0
	guaranteed.range_feet = 5.0
	var opportunity := ReactionData.new()
	opportunity.id = "guaranteed_opportunity"
	opportunity.display_name = "Guaranteed Opportunity"
	opportunity.trigger = ReactionData.Trigger.ENEMY_LEAVES_REACH
	opportunity.attack_source = ReactionData.AttackSource.REACTION_ABILITY
	opportunity.attack_data = guaranteed
	opportunity.reach_feet = 5.0
	opportunity.auto_resolve = true
	enemy.active_reactions = [opportunity]
	var system := CombatSystem.new()
	system.start_combat([player, enemy])
	system.combat_state.turn_order = [enemy.id, player.id]
	system.combat_state.current_actor_id = player.id
	player.ap = player.max_ap
	enemy.ap = enemy.max_ap
	var movement := MovementData.new()
	movement.ap_cost = 1
	movement.world_units_per_foot = system.map_rules.world_units_per_foot
	var request := ActionRequest.new(player.id, ActionTypes.Type.MOVE)
	request.target_position = Vector2(500, 100)
	request.movement_data = movement
	var origin := player.position
	var prompt := system.execute_action(request)
	check(prompt.requires_reaction_choice and prompt.reaction_prompt.get("reaction_queue_continuation", false), "An Opportunity Attack against the player should open its Defensive Reaction before Move resumes.")
	check(system.get_reaction_depth() == 1, "Nested defensive prompt should be represented by an open Reaction frame.")
	var resumed := system.resolve_pending_reaction(-1)
	check(resumed.success and player.position != origin, "Declining the nested defense should resume the original Move.")
	check(not system.has_pending_reaction() and system.pending_reaction_queue.is_empty(), "Movement Reaction Queue should be empty after the original Action resumes.")


func test_area_action_resumes_after_each_defense() -> void:
	var attacker: CombatantState = EnemyData.create_combatant_state()
	var player: CombatantState = PlayerData.create_combatant_state()
	var ally: CombatantState = PlayerData.create_combatant_state()
	attacker.position = Vector2(100, 100)
	player.position = Vector2(220, 100)
	ally.id = "ally"
	ally.position = Vector2(260, 100)
	player.active_reactions = [ParryData]
	ally.active_reactions = [ParryData]
	var ability := AbilityData.new()
	ability.id = "enemy_area"
	ability.display_name = "Enemy Area"
	ability.target_mode = AbilityData.TargetMode.GROUND
	ability.target_filter = AbilityData.TargetFilter.ENEMIES
	ability.area_shape = AbilityData.AreaShape.CIRCLE
	ability.targeting_range_feet = 20.0
	ability.area_radius_feet = 8.0
	ability.attack_source = AbilityData.AttackSource.CONFIGURED_ATTACK
	var attack := AttackData.new()
	attack.id = "enemy_area_attack"
	attack.display_name = "Enemy Area Attack"
	attack.requires_to_hit = false
	attack.base_damage = 0
	attack.range_feet = 20.0
	ability.attack_data = attack
	attacker.available_abilities = [ability]
	attacker.equipped_abilities = [ability.id]
	var system := CombatSystem.new()
	system.start_combat([attacker, player, ally])
	system.combat_state.turn_order = [player.id, ally.id, attacker.id]
	system.combat_state.current_actor_id = attacker.id
	attacker.ap = attacker.max_ap
	player.ap = player.max_ap
	ally.ap = ally.max_ap
	var prompt := system.execute_ground_ability(attacker.id, ability.id, Vector2(240, 100))
	check(prompt.requires_reaction_choice and prompt.reaction_prompt.get("area_action_continuation", false), "Area Action should pause for the player's Defensive Reaction.")
	var resolved := system.resolve_pending_reaction(-1)
	check(resolved.success and not resolved.requires_reaction_choice, "Area Action should continue through remaining AI-controlled targets after the player's choice.")
	check(system.pending_area_context == null and not system.has_pending_reaction(), "Area context should close only after every target and Reaction resolves.")
	var summaries := resolved.events.filter(func(event): return event.type == EventTypes.Type.ABILITY_TRIGGERED and event.data.get("area_target_count", 0) == 2)
	check(summaries.size() == 1, "Resumed Area Action should resolve both targets and emit one summary.")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
