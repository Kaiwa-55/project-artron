extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var arena = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	root.add_child(arena)
	var target: Combatant = arena.get_node("BattlefieldWorld/PlayerCharacter")
	var presenter = arena.movement_presentation
	var success := true
	for type in [EventTypes.Type.ATTACK_MISS, EventTypes.Type.ATTACK_HIT]:
		var event := CombatEvent.new(type, "giantspider", "player", {"final_damage": 0, "is_damaging_attack": true})
		arena.combat_system.event_system.emit(event)
		presenter.sync_movement()
		success = success and is_instance_valid(target.no_damage_icon)
		await create_timer(0.9).timeout
		success = success and target.no_damage_icon == null
		presenter.sync_movement()
		success = success and target.no_damage_icon == null
	# Check real result construction for both damaging and status-only attacks.
	for attack_path in ["res://data/attack/web_shot.tres", "res://data/attack/iron_sword.tres"]:
		var attack = load(attack_path)
		for hit in [false, true]:
			var result := AttackResult.new()
			result.hit = hit
			result.final_damage = 0
			var action_result: ActionResult = arena.combat_system.action_system.build_attack_result(target.state, target.state, attack, result)
			for event in action_result.events:
				if event.type in [EventTypes.Type.ATTACK_HIT, EventTypes.Type.ATTACK_MISS]:
					success = success and presenter.is_no_damage_result(event) == (not hit or attack.base_damage > 0)
	var damage := CombatEvent.new(EventTypes.Type.ATTACK_HIT, "giantspider", "player", {"final_damage": 5, "is_damaging_attack": true})
	arena.combat_system.event_system.emit(damage)
	presenter.sync_movement()
	success = success and target.no_damage_icon == null
	target.show_no_damage_feedback()
	target.setup(target.state)
	success = success and target.no_damage_icon == null
	arena.queue_free()
	await process_frame
	print("NO_DAMAGE_FEEDBACK_TEST: " + ("PASS" if success else "FAIL"))
	quit(0 if success else 1)
