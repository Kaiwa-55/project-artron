extends SceneTree

const PlayerData = preload("res://data/character/player.tres")
const EnemyData = preload("res://data/character/enemy.tres")
const OpportunityAttack = preload("res://data/reaction/opportunity_attack.tres")

var failures: Array[String] = []

func _init() -> void:
	var setup := build_combat()
	var system: CombatSystem = setup.system
	var player: CombatantState = setup.player
	var enemy: CombatantState = setup.enemy
	var request := build_move(system, enemy)
	var prompt_result := system.execute_action(request)
	check(prompt_result.requires_reaction_choice, "Player Opportunity Attack should wait for a choice")
	check(prompt_result.reaction_prompt.get("opportunity_choice", false), "Prompt should identify an Opportunity choice")
	var origin := enemy.position
	var decline_result := system.resolve_pending_reaction(-1)
	check(decline_result.success and enemy.position != origin, "Declining should resume the enemy movement")
	check(player.ap == player.max_ap, "Declining should not spend player AP")

	setup = build_combat()
	system = setup.system
	player = setup.player
	enemy = setup.enemy
	request = build_move(system, enemy)
	prompt_result = system.execute_action(request)
	var ap_before := player.ap
	var use_result := system.resolve_pending_reaction(0)
	check(prompt_result.requires_reaction_choice and use_result.success, "Using Opportunity Attack should resolve and resume movement")
	check(player.ap < ap_before, "Using Opportunity Attack should spend AP")
	check(not system.has_pending_reaction(), "Opportunity choice should clear after resolution")

	if failures.is_empty():
		print("OPPORTUNITY_CHOICE_TEST: PASS")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		print("OPPORTUNITY_CHOICE_TEST: FAIL (%d)" % failures.size())
		quit(1)

func build_combat() -> Dictionary:
	var player: CombatantState = PlayerData.create_combatant_state()
	var enemy: CombatantState = EnemyData.create_combatant_state()
	player.position = Vector2(100, 100)
	enemy.position = Vector2(195, 100)
	var system := CombatSystem.new()
	system.start_combat([player, enemy])
	# This test targets the choice flow, independent of the current prototype class loadout.
	player.active_reactions = [OpportunityAttack]
	system.combat_state.current_actor_id = enemy.id
	player.ap = player.max_ap
	enemy.ap = enemy.max_ap
	return {"system": system, "player": player, "enemy": enemy}

func build_move(system: CombatSystem, enemy: CombatantState) -> ActionRequest:
	var movement := MovementData.new()
	movement.ap_cost = 1
	movement.world_units_per_foot = system.map_rules.world_units_per_foot
	var request := ActionRequest.new(enemy.id, ActionTypes.Type.MOVE)
	request.target_position = Vector2(500, 100)
	request.movement_data = movement
	return request

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
