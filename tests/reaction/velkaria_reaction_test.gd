extends SceneTree

const PlayerData = preload("res://data/character/player.tres")
const VelkariaData = preload("res://data/character/velkaria.tres")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var system := CombatSystem.new()
	var player: CombatantState = PlayerData.create_combatant_state()
	var boss: CombatantState = VelkariaData.create_combatant_state()
	player.position = Vector2(200, 250)
	boss.position = Vector2(340, 250)
	system.start_combat([player, boss])
	system.combat_state.current_actor_id = player.id
	system.start_current_turn()
	var attack := AttackData.new()
	attack.id = "reaction_test_attack"
	attack.display_name = "Reaction Test Attack"
	attack.requires_to_hit = false
	attack.ap_cost = 0
	attack.base_damage = 1
	attack.range_feet = 5.0
	var request := ActionRequest.new(player.id, ActionTypes.Type.ATTACK)
	request.target_id = boss.id
	request.attack_data = attack
	var origin := boss.position
	var ap_before_reaction := boss.ap
	var hp_before_attack := boss.hp
	var result: ActionResult = system.execute_action(request)
	var triggered := false
	for event in result.events:
		if event.type == EventTypes.Type.REACTION_TRIGGERED and event.source_id == boss.id and event.data.get("reaction_name", "") == "Skittering Guard":
			triggered = true
	var attack_missed := result.events.any(func(event): return event.type == EventTypes.Type.ATTACK_MISS and event.target_id == boss.id)
	var attack_hit := result.events.any(func(event): return event.type == EventTypes.Type.ATTACK_HIT and event.target_id == boss.id)
	var avoided_damage := boss.hp == hp_before_attack
	var position_after_reaction := boss.position
	var ap_after_reaction := boss.ap
	player.position = boss.position - Vector2(140, 0)
	var second_result: ActionResult = system.execute_action(request)
	var triggered_twice := second_result.events.any(func(event): return event.type == EventTypes.Type.REACTION_TRIGGERED and event.source_id == boss.id and event.data.get("reaction_name", "") == "Skittering Guard")
	var limited_once_per_round := not triggered_twice and boss.position == position_after_reaction and boss.ap == ap_after_reaction
	var success := result.success and triggered and attack_missed and not attack_hit and avoided_damage and limited_once_per_round and boss.position != origin and boss.ap == ap_before_reaction - 1
	if not success:
		push_error("Velkaria must move out of range with Skittering Guard and turn the attack into a Miss without taking damage.")
		print("CHECKS result=", result.success, " triggered=", triggered, " missed=", attack_missed, " hit=", attack_hit, " no_damage=", avoided_damage, " once=", limited_once_per_round, " moved=", boss.position != origin, " max_ap=", boss.effective_max_ap)
		print("REACTIONS=" + str(boss.active_reactions) + " EVENTS=" + str(result.events.map(func(event): return {"type": event.type, "data": event.data})))
	print("VELKARIA_REACTION_TEST: " + ("PASS" if success else "FAIL") + " from=" + str(origin) + " to=" + str(boss.position) + " AP=" + str(boss.ap))
	quit(0 if success else 1)
