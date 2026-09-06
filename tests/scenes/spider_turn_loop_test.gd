extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var prototype = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	root.add_child(prototype)
	var spider = load("res://data/character/giant_spider.tres").create_combatant_state()
	spider.id = "giantspider"
	spider.position = Vector2.ZERO
	var player := CombatantState.new()
	player.id = "player"
	player.team = 1
	player.base_max_hp = 100
	player.base_max_ap = 3
	player.position = Vector2(240, 0)
	prototype.combat_system = CombatSystem.new()
	var combatants: Array[CombatantState] = [player, spider]
	prototype.combat_system.start_combat(combatants)
	prototype.combat_system.combat_state.current_actor_id = spider.id
	spider.ap = 3
	prototype.enemy_actions_this_turn = 0
	prototype.get_node("PlayerCharacter").setup(player)
	prototype.get_node("EnemyCharacter2").setup(spider)
	prototype.get_node("Control").reset_for_combat()
	prototype.get_node("Control").setup(prototype.combat_system)
	prototype.run_enemy_ai_if_needed()
	for frame in range(100):
		await create_timer(0.05).timeout
		if prototype.combat_system.combat_state.current_actor_id == "player":
			break
	var success: bool = spider.ap == 0 and prototype.combat_system.combat_state.current_actor_id == "player" and spider.position != Vector2.ZERO and spider.ability_cooldowns.has("web_shot") and spider.ability_cooldowns.has("skitter")
	if not success:
		push_error("Scene AI should use Web Shot, Skitter and Bite before ending its turn")
	prototype.queue_free()
	await process_frame
	print("SPIDER_TURN_LOOP_TEST: " + ("PASS" if success else "FAIL"))
	quit(0 if success else 1)
