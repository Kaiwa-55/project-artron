extends SceneTree

const SpiderData = preload("res://data/character/spider.tres")
const GiantSpiderData = preload("res://data/character/giant_spider.tres")
const VelkariaData = preload("res://data/character/velkaria.tres")
const EncounterDataScript = preload("res://data/encounter/encounter_data.gd")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var prototype = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	var encounter = EncounterDataScript.new()
	encounter.enemies.append(SpiderData)
	encounter.enemies.append(GiantSpiderData)
	encounter.enemies.append(VelkariaData)
	prototype.encounter_data = encounter
	root.add_child(prototype)
	# Cover the reported order deterministically instead of relying on initiative dice.
	var forced_order: Array[String] = ["player", "ally", "spider", "giant_spider", "velkaria"]
	prototype.combat_system.combat_state.turn_order = forced_order
	prototype.combat_system.combat_state.current_actor_id = "player"
	prototype.combat_system.combat_state.current_round = 1
	prototype.combat_system.start_current_turn()
	await process_frame
	var safety := 0
	var moved_then_ended := false
	var ally_passed_without_moving := false
	while not prototype.combat_system.combat_state.is_finished() and prototype.combat_system.combat_state.current_round <= 2 and safety < 500:
		safety += 1
		var state = prototype.combat_system.combat_state
		if prototype.combat_system.has_pending_reaction():
			prototype.resolve_reaction_choice(-1)
		elif prototype.is_player_party_turn():
			var actor = state.get_current_actor()
			if actor != null and actor.id == "player" and not moved_then_ended:
				moved_then_ended = true
				prototype.move_player(actor.position + Vector2(-120.0, 0.0))
				# This used to be discarded while the movement tween was active.
				prototype.next_turn()
			elif actor != null and actor.id == "ally" and not prototype.is_movement_animating():
				ally_passed_without_moving = true
				prototype.refresh_end_turn_lock()
				prototype.reference_end_turn_button.pressed.emit()
			elif not prototype.is_movement_animating():
				prototype.refresh_end_turn_lock()
				prototype.reference_end_turn_button.pressed.emit()
		await create_timer(0.02).timeout

	var attacks: Dictionary = {"spider": 0, "giant_spider": 0, "velkaria": 0}
	var web_shots := 0
	var royal_web_uses := 0
	var giant_bites := 0
	for event in prototype.combat_system.event_system.event_history:
		if event.type == EventTypes.Type.ABILITY_TRIGGERED and event.source_id == "giant_spider" and event.data.get("ability_name", "") == "Web Shot":
			web_shots += 1
		if event.type == EventTypes.Type.ABILITY_TRIGGERED and event.source_id == "velkaria" and event.data.get("ability_name", "") == "Royal Web":
			royal_web_uses += 1
		if event.type not in [EventTypes.Type.ATTACK_HIT, EventTypes.Type.ATTACK_MISS]:
			continue
		if attacks.has(event.source_id):
			attacks[event.source_id] += 1
		if event.source_id == "giant_spider" and event.data.get("attack_id", "") == "venomous_bite":
			giant_bites += 1
	var obstacle_ready: bool = prototype.combat_system.map_rules.obstacles.size() == 1 \
		and prototype.get_node("Control/Battlefield").has_node("StonePillar")
	var circular_enemy_tokens := true
	for enemy_node in prototype.get_enemy_nodes():
		var texture: Texture2D = enemy_node.state.token_texture
		var image: Image = texture.get_image() if texture != null else null
		if image == null or image.get_pixel(0, 0).a > 0.01:
			circular_enemy_tokens = false
	var success: bool = obstacle_ready and circular_enemy_tokens and moved_then_ended and ally_passed_without_moving and attacks.spider > 0 and attacks.giant_spider > 0 and attacks.velkaria > 0 and royal_web_uses > 0
	if not success:
		push_error("Every Spider enemy must act and Velkaria must use Royal Web in the multi-party scene.")
		print("AI LOG: " + str(prototype.get_node("Control").local_log_entries))
	print("MULTI_PARTY_TURN_LOOP_TEST: " + ("PASS" if success else "FAIL") + " " + str(attacks) + " giant_bites=" + str(giant_bites) + " royal_web=" + str(royal_web_uses))
	prototype.queue_free()
	quit(0 if success else 1)
