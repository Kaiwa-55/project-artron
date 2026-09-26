extends SceneTree

const PrototypeScene := preload("res://scenes/prototype/PrototypeCombat.tscn")
const CardScene := preload("res://scenes/combat/ui/CombatLogActionCard.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var scene = PrototypeScene.instantiate()
	scene.set_script(preload("res://tests/helpers/idle_combat_ui.gd"))
	root.add_child(scene)
	await process_frame
	await process_frame
	var ui: Control = scene.get_node("UILayer/Control")
	var panel: Control = ui.get_node("CombatLogPanel")
	scene.toggle_combat_log()
	await process_frame
	check(bool(ProjectSettings.get_setting("gui/fonts/dynamic_fonts/use_oversampling")), "Dynamic font oversampling is enabled")
	var log_font: Font = panel.get_node("Margin/VBoxContainer/Header/Title").get_theme_font("font")
	check(log_font is FontFile and log_font.hinting == TextServer.HINTING_NORMAL and log_font.force_autohinter, "Combat Log uses a fully hinted font")
	check(panel.visible and absf(panel.get_global_rect().end.x - ui.get_global_rect().end.x) < 2.0, "Combat Log docks to the right edge")
	check(panel.size.y >= ui.size.y - 2.0 and panel.size.x <= ui.size.x * 0.35, "Combat Log is a full-height narrow strip")
	check(panel.get_node("Margin/VBoxContainer/Header/Title").get_theme_font_size("font_size") <= 9, "Combat Log heading uses smaller text")
	check(panel.get_node("Margin/VBoxContainer/Scroll").horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Combat Log wraps details without horizontal scrolling")
	check(ui.get_node("CombatUI/Endturn").get_global_rect().end.x <= panel.get_global_rect().position.x, "End Turn remains outside the open log")
	check(ui.get_node("Enemy_panel").get_global_rect().end.x <= panel.get_global_rect().position.x, "Target panel remains outside the open log")
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	check(style != null and style.border_width_left >= 2 and style.border_color.r > style.border_color.g, "Combat Log has a red leading line")
	var combat: CombatSystem = scene.combat_system
	var attacker: CombatantState = combat.combat_state.get_combatant("player")
	var target: CombatantState
	for candidate in combat.combat_state.combatants.values():
		if candidate.team != attacker.team:
			target = candidate
			break
	check(target != null, "Test encounter has a target")
	if target != null:
		attacker.strength = 40
		attacker.ap = attacker.max_ap
		attacker.position = Vector2.ZERO
		target.position = Vector2(60, 0)
		var attack := AttackData.new()
		attack.id = "log_test_attack"
		attack.display_name = "Test Sword +1"
		attack.base_damage = 5
		attack.to_hit_bonus = 1
		attack.ap_cost = 1
		attack.can_critical = false
		var buff := EffectData.new()
		buff.id = "log_test_buff"
		buff.display_name = "Battle Focus"
		buff.attack_bonus = 3
		buff.damage_bonus = 1
		attacker.add_effect(buff)
		var training := AbilityData.new()
		training.id = "log_test_training"
		training.display_name = "Weapon Training"
		var training_bonus := AbilityEffectData.new()
		training_bonus.effect_type = AbilityEffectData.Type.PASSIVE_TO_HIT_BONUS
		training_bonus.passive_value = 2
		training.effects.append(training_bonus)
		attack.granted_abilities.append(training)
		var resolved: AttackResult = combat.attack_system.resolve_attack(attacker, target, attack, false, [], -2, -1)
		check(resolved.hit, "Controlled test attack hits")
		var listed_to_hit := 0
		for part in resolved.to_hit_breakdown:
			listed_to_hit += int(part.amount)
		check(listed_to_hit == resolved.attack_modifier, "Named To Hit parts sum to the applied modifier")
		var action: ActionResult = combat.action_system.build_attack_result(attacker, target, attack, resolved)
		var event: CombatEvent = action.events[0]
		var entry: Dictionary = ui.create_combat_log_card_data(event, ui.format_combat_event(event))
		var details: String = entry.details
		for expected in ["Strength", "Test Sword +1 accuracy +1", "Battle Focus +3", "Weapon Training +2", "Repeated attack -2", "Off-hand -1", "Base damage +5", "Resistance"]:
			if expected == "Resistance" and resolved.resistance == 0:
				continue
			check(details.contains(expected), "Combat Log explains %s" % expected)
		check(not details.contains("Margin:") and not details.contains("AP -"), "Attack log omits margin and AP cost")
		check(entry.roll.contains("3d8") and entry.roll.contains("vs"), "Combat Log shows the roll and target defense")
		var card = CardScene.instantiate()
		panel.get_node("Margin/VBoxContainer/Scroll/Entries").add_child(card)
		card.setup(entry, true)
		await process_frame
		check(card.get_node("Margin/Content/Details").get_theme_font("font") == log_font, "Combat Log cards inherit the dedicated font")
		check(card.get_global_rect().end.x <= panel.get_global_rect().end.x + 1.0, "Combat Log card fits inside the strip")
		check(card.get_node("Margin/Content/Details").max_lines_visible == -1, "Combat Log details are not truncated")
		check(card.get_node("Margin/Content/Header/ActionName").get_theme_font_size("font_size") <= 7, "Combat Log action title uses smaller text")
		check(card.get_node("Margin/Content/Details").get_theme_font_size("font_size") <= 6, "Combat Log uses smaller detail text")
		card.queue_free()
		var automatic := CombatEvent.new(EventTypes.Type.ATTACK_HIT, attacker.id, target.id, {
			"attack_name": "Automatic Strike", "requires_to_hit": false, "can_critical": false,
			"critical_roll": 50, "damage": 4, "final_damage": 4, "ap_cost": 1
		})
		var automatic_entry: Dictionary = ui.create_combat_log_card_data(automatic, ui.format_combat_event(automatic))
		check(automatic_entry.roll == "Automatic hit" and not automatic_entry.details.contains("To Hit:") and not automatic_entry.details.contains("Critical:"), "Automatic hit shows no invented roll or critical check")
		for cost_event in [
			CombatEvent.new(EventTypes.Type.ABILITY_TRIGGERED, attacker.id, target.id, {"ability_name": "Test Ability", "ap_cost": 2, "cooldown": 1}),
			CombatEvent.new(EventTypes.Type.ITEM_USED, attacker.id, attacker.id, {"item_name": "Test Potion", "ap_cost": 1, "quantity_remaining": 2})
		]:
			var cost_entry: Dictionary = ui.create_combat_log_card_data(cost_event, ui.format_combat_event(cost_event))
			check(not cost_entry.details.contains("AP -"), "Other action logs omit AP cost")
	scene.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("COMBAT_LOG_BREAKDOWN_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
