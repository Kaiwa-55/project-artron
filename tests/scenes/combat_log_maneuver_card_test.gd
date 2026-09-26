extends SceneTree


const PrototypeScene := preload("res://scenes/prototype/PrototypeCombat.tscn")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var failures: Array[String] = []
	var scene = PrototypeScene.instantiate()
	scene.set_script(preload("res://tests/helpers/idle_combat_ui.gd"))
	root.add_child(scene)
	await process_frame
	await process_frame
	var combat: CombatSystem = scene.combat_system
	var actor: CombatantState = combat.combat_state.get_combatant("player")
	var target: CombatantState
	for candidate in combat.combat_state.combatants.values():
		if candidate.team != actor.team:
			target = candidate
			break
	if target == null:
		failures.append("Test encounter must include an enemy target.")
		scene.queue_free()
		print("COMBAT_LOG_MANEUVER_CARD_TEST: FAIL")
		quit(1)
		return
	actor.strength = 100
	actor.ap = actor.max_ap
	combat.combat_state.current_actor_id = actor.id
	for maneuver in [ActionTypes.Maneuver.GRAB, ActionTypes.Maneuver.PUSH, ActionTypes.Maneuver.PULL]:
		target.position = actor.position + Vector2(60, 0)
		target.remove_status("grabbed")
		actor.remove_status("grabbing")
		actor.ap = actor.max_ap
		combat.use_basic_maneuver(actor.id, target.id, maneuver)
	actor.ap = actor.max_ap
	var hide_result: ActionResult = combat.use_hide(actor.id)
	var ui: Control = scene.get_node("UILayer/Control")
	ui.update_combat_log()
	var cards: Array = ui.get_node("CombatLogPanel/Margin/VBoxContainer/Scroll/Entries").get_children()
	for maneuver_name in ["Grab", "Push", "Pull"]:
		var found := false
		for card in cards:
			if card.get_node("Margin/Content/Header/ActionName").text == maneuver_name:
				found = true
				break
		if not found:
			failures.append("Combat Log should show a %s card." % maneuver_name)
	var hide_card: Control
	for card in cards:
		if card.get_node("Margin/Content/Header/ActionName").text == "Hide":
			hide_card = card
			break
	if hide_card == null or not hide_result.success:
		failures.append("Combat Log should show a Hide card.")
	else:
		var roll_text: String = hide_card.get_node("Margin/Content/Resolution/Result/Roll").text
		var details_text: String = hide_card.get_node("Margin/Content/Details").text
		var expected_dc: int = hide_result.events[0].data.checks[0].dc
		if not roll_text.contains("DC %d" % expected_dc) or roll_text.contains("vs 0"):
			failures.append("Hide card should show the enemy's actual DC instead of zero.")
		if details_text.contains("AP -"):
			failures.append("Maneuver cards should omit AP cost.")
	scene.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("COMBAT_LOG_MANEUVER_CARD_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
