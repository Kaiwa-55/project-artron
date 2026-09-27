extends SceneTree

const CombatantNode := preload("res://entities/combatant.gd")
const CombatUI := preload("res://scenes/combat/control.gd")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var failures: Array[String] = []
	var combat := CombatSystem.new()
	var holder := make_combatant("holder", "Desert Raider", 1, Vector2(120, 120), 100)
	var target := make_combatant("target", "Player", 2, Vector2(240, 120), 10)
	var other_target := make_combatant("other_target", "Guard", 2, Vector2(120, 240), 10)
	combat.start_combat([holder, target, other_target])
	combat.combat_state.current_actor_id = holder.id
	var grab := combat.use_basic_maneuver(holder.id, target.id, ActionTypes.Maneuver.GRAB)
	check(grab.success, "Grab succeeds", failures)
	var grabbing: EffectInstance = find_effect(holder, "grabbing")
	var grabbed: EffectInstance = find_effect(target, "grabbed")
	check(grabbing != null and grabbing.get_display_name() == "Grabbing Player", "Holder status names the target", failures)
	check(grabbed != null and grabbed.get_display_name() == "Grabbed by Desert Raider", "Target status names the holder", failures)
	var second_grab := combat.use_basic_maneuver(holder.id, other_target.id, ActionTypes.Maneuver.GRAB)
	check(not second_grab.success and not other_target.has_status("grabbed"), "Holder cannot start a second Grab", failures)
	var holder_token := CombatantNode.new()
	var target_token := CombatantNode.new()
	root.add_child(holder_token)
	root.add_child(target_token)
	holder_token.setup(holder)
	target_token.setup(target)
	check(holder_token.get_node("StatusIcons/Status_grabbing").tooltip_text == "Grabbing Player", "Holder status icon names the target", failures)
	check(target_token.get_node("StatusIcons/Status_grabbed").tooltip_text == "Grabbed by Desert Raider", "Target status icon names the holder", failures)
	var ui = CombatUI.new()
	check(ui.get_effect_names(holder).contains("Grabbing Player") and ui.get_effect_names(target).contains("Grabbed by Desert Raider"), "Combat status details name both participants", failures)
	combat.combat_state.current_actor_id = target.id
	target.strength = 100
	var escape := combat.execute_escape(target.id, "grabbed")
	holder_token.refresh_from_state()
	target_token.refresh_from_state()
	check(escape.success and not holder.has_status("grabbing") and not target.has_status("grabbed"), "Escape clears both linked statuses", failures)
	check(holder_token.get_node_or_null("StatusIcons/Status_grabbing") == null and target_token.get_node_or_null("StatusIcons/Status_grabbed") == null, "Both status icons clear after escape", failures)
	holder_token.queue_free()
	target_token.queue_free()
	ui.free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("GRAB_STATUS_PRESENTATION_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func make_combatant(id: String, name: String, team: int, position: Vector2, strength: int) -> CombatantState:
	var actor := CombatantState.new()
	actor.id = id
	actor.display_name = name
	actor.team = team
	actor.position = position
	actor.strength = strength
	actor.base_max_hp = 100
	actor.hp = 100
	actor.max_hp = 100
	actor.base_max_ap = 5
	actor.ap = 5
	actor.max_ap = 5
	actor.effective_max_ap = 5
	actor.base_speed = 30.0
	actor.speed = 30.0
	actor.unarmed_attack = preload("res://data/attack/unarmed_attack.tres")
	return actor


func find_effect(actor: CombatantState, effect_id: String) -> EffectInstance:
	for instance in actor.effects:
		if instance.data.id == effect_id:
			return instance
	return null


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
