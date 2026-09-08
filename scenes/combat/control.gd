extends Control

const CombatLogActionCardScene := preload("res://scenes/combat/ui/CombatLogActionCard.tscn")

signal reaction_choice_selected(reaction_index: int)

var combat_system: CombatSystem
var local_log_entries: PackedStringArray = []
var selected_target_name: String = "None"
var selected_target_id: String = "enemy"


func setup(system: CombatSystem) -> void:
	combat_system = system
	update_ui()


func reset_for_combat() -> void:
	local_log_entries.clear()
	hide_reaction_prompt()


func set_mode_hint(message: String) -> void:
	$CombatLogPanel/Margin/VBoxContainer/ModeHint.text = message


func set_selected_target(target_name: String, target_id: String = "enemy") -> void:
	selected_target_name = target_name
	selected_target_id = target_id
	$Enemy_panel.visible = not target_id.is_empty()


func update_ui() -> void:
	var state := combat_system.get_combat_state()

	var primary_player: CombatantState = state.get_combatant("player")
	var current_actor: CombatantState = state.get_current_actor()
	var party_turn: bool = primary_player != null and current_actor != null and current_actor.team == primary_player.team
	var player = current_actor if party_turn else primary_player
	var enemy := state.get_combatant(selected_target_id)
	$Enemy_panel.visible = enemy != null
	if enemy != null:
		$Enemy_panel/VBoxContainer/Name.text = enemy.display_name

	if enemy != null:
		$Enemy_panel/VBoxContainer/Hp.text = "HP: %d / %d" % [enemy.hp, enemy.max_hp]
		$Enemy_panel/VBoxContainer/Effects.text = "Effects: %s" % get_effect_names(enemy)
	$CombatLogPanel/Margin/VBoxContainer/Turn.text = "ROUND %d  •  %s TURN" % [
		state.current_round,
		state.current_actor_id.to_upper()
	]
	if state.is_finished():
		$CombatLogPanel/Margin/VBoxContainer/Turn.text = "COMBAT ENDED  •  %s" % (
			"VICTORY" if state.combat_result == CombatEnums.CombatResult.VICTORY else "DEFEAT"
		)
		set_action_buttons_enabled(false)
	else:
		set_action_buttons_enabled(party_turn)
	update_weapon_button(player, state)
	update_combat_log()


func get_effect_names(combatant: CombatantState) -> String:
	if combatant.effects.is_empty():
		return "None"

	var names: PackedStringArray = []
	for effect in combatant.effects:
		var stack_text := " x%d" % effect.stack_count if effect.stack_count > 1 else ""
		names.append("%s%s (%d)" % [effect.data.display_name, stack_text, effect.remaining_turns])
	return ", ".join(names)


func get_ability_names(combatant: CombatantState) -> String:
	if combatant.equipped_abilities.is_empty():
		return "None"

	var names: PackedStringArray = []
	for ability_id in combatant.equipped_abilities:
		var ability = find_ability(combatant, ability_id)
		names.append(ability.display_name if ability != null else ability_id)
	return ", ".join(names)


func get_trait_names(combatant: CombatantState) -> String:
	if combatant.active_traits.is_empty():
		return "None"

	var names: PackedStringArray = []
	for trait_data in combatant.active_traits:
		if trait_data != null:
			names.append(trait_data.display_name)
	return ", ".join(names)


func get_equipment_names(combatant: CombatantState) -> String:
	var names: PackedStringArray = []
	var weapon_1 = combatant.equipped_items.get(0)
	var weapon_2 = combatant.equipped_items.get(3)
	if weapon_1 != null and weapon_1 == weapon_2:
		names.append("Hands 1+2: %s [Active]" % weapon_1.display_name)
	else:
		if weapon_1 != null:
			names.append("Hand 1: %s%s" % [weapon_1.display_name, " [Active]" if combatant.active_weapon_slot == 0 and weapon_1.weapon_attack != null else ""])
		if weapon_2 != null:
			names.append("Hand 2: %s%s" % [weapon_2.display_name, " [Active]" if combatant.active_weapon_slot == 3 and weapon_2.weapon_attack != null else ""])
	var armor = combatant.equipped_items.get(1)
	if armor != null:
		names.append("Armor: %s" % armor.display_name)
	return ", ".join(names) if not names.is_empty() else "None"


func update_ability_menu(player: CombatantState) -> void:
	var menu := $Player_panel/VBoxContainer2/AbilityMenu
	for child in menu.get_children():
		child.queue_free()

	for ability in player.available_abilities:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 34)
		var equipped := false
		for equipped_ability_id in player.equipped_abilities:
			if equipped_ability_id == ability.id:
				equipped = true
				break
		button.text = ("Passive: " if ability.is_passive else ("Unequip: " if equipped else "Equip: ")) + ability.display_name
		button.tooltip_text = ability.description
		button.disabled = ability.is_passive or combat_system.get_combat_state().is_finished() \
			or combat_system.get_combat_state().current_actor_id != "player"
		button.pressed.connect(toggle_ability.bind(ability.id))
		menu.add_child(button)

	var weapon: AttackData = player.equipped_weapon_attack
	if weapon == null:
		return
	for ability in weapon.granted_abilities:
		if ability == null or not ability.uses_equipped_weapon_attack:
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 34)
		var cooldown: int = combat_system.ability_system.get_remaining_cooldown(player, ability.id)
		button.text = "%s (%d AP)" % [ability.display_name, ability.ap_cost]
		if cooldown > 0:
			button.text += " - CD %d" % cooldown
		button.tooltip_text = "%s\nWeapon: %s | Cooldown: %d turn(s)" % [ability.description, weapon.display_name, ability.cooldown_turns]
		button.disabled = combat_system.get_combat_state().is_finished() \
			or combat_system.get_combat_state().current_actor_id != "player" \
			or player.ap < ability.ap_cost or cooldown > 0 \
			or combat_system.has_pending_reaction()
		button.pressed.connect(use_weapon_ability.bind(ability.id))
		menu.add_child(button)


func update_equipment_menu(player: CombatantState) -> void:
	var menu := $Player_panel/VBoxContainer2/EquipmentMenu
	for child in menu.get_children():
		child.queue_free()

	var state = combat_system.get_combat_state()
	var cannot_act: bool = state.is_finished() or state.current_actor_id != "player"
	for item in player.equipment_inventory:
		if item == null:
			continue
		if item.slot == 1:
			add_equipment_button(menu, "Armor locked: %s" % item.display_name, item.description, true, Callable())
		elif item.slot == 2:
			for hand_slot in [0, 3]:
				var hand_number: int = 1 if hand_slot == 0 else 2
				var shield_equipped: bool = player.equipped_items.get(hand_slot) == item
				var shield_elsewhere: bool = player.equipped_items.get(0 if hand_slot == 3 else 3) == item
				var shield_verb := "Unequip" if shield_equipped else ("Move to" if shield_elsewhere else "Equip")
				add_equipment_button(menu, "%s Hand %d: %s (1 AP)" % [shield_verb, hand_number, item.display_name], item.description, cannot_act or player.ap < 1, toggle_equipment.bind(item, hand_slot))
		elif equipment_is_two_handed(item):
			var two_handed_equipped: bool = player.equipped_items.get(0) == item
			add_equipment_button(menu, ("Unequip Weapon 1+2: " if two_handed_equipped else "Equip Weapon 1+2: ") + item.display_name + " (1 AP)", item.description, cannot_act or player.ap < 1, toggle_equipment.bind(item, 0))
		else:
			for weapon_slot in [0, 3]:
				var slot_number: int = 1 if weapon_slot == 0 else 2
				var equipped: bool = player.equipped_items.get(weapon_slot) == item
				var equipped_elsewhere: bool = player.equipped_items.get(0 if weapon_slot == 3 else 3) == item
				var verb := "Unequip" if equipped else ("Move to" if equipped_elsewhere else "Equip")
				add_equipment_button(menu, "%s Weapon %d: %s (1 AP)" % [verb, slot_number, item.display_name], item.description, cannot_act or player.ap < 1, toggle_equipment.bind(item, weapon_slot))
				if equipped and player.active_weapon_slot != weapon_slot:
					add_equipment_button(menu, "Use Weapon %d: %s (1 AP)" % [slot_number, item.display_name], item.description, cannot_act or player.ap < 1, activate_weapon_slot.bind(weapon_slot))


func add_equipment_button(menu, text: String, tooltip: String, disabled: bool, action: Callable) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 32)
	button.text = text
	button.tooltip_text = tooltip
	button.disabled = disabled
	if action.is_valid():
		button.pressed.connect(action)
	menu.add_child(button)


func equipment_is_two_handed(item) -> bool:
	if item == null or item.weapon_attack == null:
		return false
	for trait_data in item.weapon_attack.traits:
		if trait_data != null and trait_data.id == "two_handed":
			return true
	return false


func find_ability(combatant: CombatantState, ability_id: String):
	for ability in combatant.available_abilities:
		if ability != null and ability.id == ability_id:
			return ability
	return null


func update_skill_button(player: CombatantState, state) -> void:
	var button: Button = $"Player_panel/VBoxContainer2/Arcane Bolt"
	var skill = find_skill(player, "arcane_bolt")
	if skill == null:
		button.visible = false
		return
	var cooldown: int = int(player.skill_cooldowns.get(skill.id, 0))
	var effective_cooldown: int = combat_system.skill_system.get_effective_cooldown_turns(player, skill)
	var mana_cost: int = combat_system.skill_system.get_effective_mana_cost(player, skill)
	button.text = "%s (%d Mana)" % [skill.display_name, mana_cost]
	if cooldown > 0:
		button.text += " - CD %d" % cooldown
	button.tooltip_text = "%s\nMana: %d | AP: %d | Cooldown: %d turn(s)" % [
		skill.description, mana_cost, skill.ap_cost, effective_cooldown
	]
	button.disabled = state.is_finished() or state.current_actor_id != "player" \
		or player.mana < mana_cost or cooldown > 0


func update_weapon_button(player: CombatantState, state) -> void:
	var button: Button = $"ActionSources/Sword Attack"
	var weapon: AttackData = player.equipped_weapon_attack
	button.text = "Weapon Attack" if weapon == null else weapon.display_name
	var primary_player: CombatantState = state.get_combatant("player")
	button.disabled = state.is_finished() or primary_player == null or state.get_current_actor() == null or state.get_current_actor().team != primary_player.team or weapon == null


func find_skill(combatant: CombatantState, skill_id: String):
	for skill in combatant.available_skills:
		if skill != null and skill.id == skill_id:
			return skill
	return null


func set_action_buttons_enabled(enabled: bool) -> void:
	$"ActionSources/Sword Attack".disabled = not enabled
	var actor: CombatantState = combat_system.get_combat_state().get_current_actor() if combat_system != null else null
	var no_speed_remaining := actor == null or combat_system.movement_system.get_available_distance_feet(actor) <= 0.001
	$ActionSources/Move.disabled = not enabled or no_speed_remaining
	$"ActionSources/End Turn".disabled = not enabled


func show_reaction_prompt(prompt: Dictionary) -> void:
	if prompt.get("opportunity_choice", false):
		var opportunity_reaction = prompt.get("reaction")
		var moving_actor = prompt.get("attacker")
		$ReactionPrompt/VBoxContainer/Message.text = "%s is leaving your weapon's reach.\nUse Opportunity Attack before the movement resolves?" % (moving_actor.display_name if moving_actor != null else "An enemy")
		var opportunity_buttons := $ReactionPrompt/VBoxContainer/Buttons
		for child in opportunity_buttons.get_children():
			opportunity_buttons.remove_child(child)
			child.queue_free()
		var use_button := Button.new()
		use_button.custom_minimum_size = Vector2(150, 38)
		use_button.text = "%s (%d AP)" % [opportunity_reaction.display_name, opportunity_reaction.ap_cost]
		use_button.tooltip_text = opportunity_reaction.description
		use_button.pressed.connect(_on_reaction_pressed.bind(0))
		opportunity_buttons.add_child(use_button)
		var decline_button := Button.new()
		decline_button.custom_minimum_size = Vector2(130, 38)
		decline_button.text = "Do Not Use"
		decline_button.pressed.connect(_on_reaction_pressed.bind(-1))
		opportunity_buttons.add_child(decline_button)
		$ReactionPrompt.visible = true
		return
	if prompt.get("step_back", false):
		var reaction = prompt.get("reaction")
		var reaction_name: String = reaction.display_name if reaction != null else "Movement Reaction"
		$ReactionPrompt/VBoxContainer/Message.text = "The attack has resolved. Move up to %.1f ft with %s?" % [prompt.get("distance_feet", 0.0), reaction_name]
		var step_buttons := $ReactionPrompt/VBoxContainer/Buttons
		for child in step_buttons.get_children():
			step_buttons.remove_child(child)
			child.queue_free()
		var use_button := Button.new()
		use_button.custom_minimum_size = Vector2(130, 38)
		use_button.text = "%s (%d AP)" % [reaction_name, reaction.ap_cost if reaction != null else 1]
		use_button.tooltip_text = reaction.description if reaction != null else "Move after the triggering attack."
		use_button.pressed.connect(_on_reaction_pressed.bind(0))
		step_buttons.add_child(use_button)
		var decline_button := Button.new()
		decline_button.custom_minimum_size = Vector2(130, 38)
		decline_button.text = "Do Not Use"
		decline_button.pressed.connect(_on_reaction_pressed.bind(-1))
		step_buttons.add_child(decline_button)
		$ReactionPrompt.visible = true
		return
	var reactions: Array = prompt.get("reactions", [])
	if reactions.is_empty() and prompt.has("reaction"):
		reactions.append(prompt["reaction"])
	var attacker = prompt.get("attacker")
	if reactions.is_empty():
		return
	var attacker_name: String = attacker.display_name if attacker != null else "An enemy"
	var prepared: AttackResult = prompt.get("prepared_attack")
	var attack_total: int = prepared.roll + prepared.attack_modifier if prepared != null else 0
	var defense: int = prepared.defense if prepared != null else 0
	var margin: int = prepared.margin if prepared != null else 0
	if prompt.get("damage_intervention", false):
		var protected_target = prompt.get("attack_target")
		$ReactionPrompt/VBoxContainer/Message.text = "%s is about to damage %s.\nUse a Reaction to reduce the damage?" % [attacker_name, protected_target.display_name if protected_target != null else "your ally"]
	else:
		$ReactionPrompt/VBoxContainer/Message.text = "%s rolled %d vs DEF %d (margin %+d).\nChoose one Reaction:" % [attacker_name, attack_total, defense, margin]
	var buttons := $ReactionPrompt/VBoxContainer/Buttons
	for child in buttons.get_children():
		buttons.remove_child(child)
		child.queue_free()
	for index in range(reactions.size()):
		var reaction = reactions[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(130, 38)
		button.text = "%s (%d AP%s)" % [reaction.display_name, reaction.ap_cost, ", %d Faith" % reaction.faith_cost if reaction.faith_cost > 0 else ""]
		button.tooltip_text = reaction.description
		button.pressed.connect(_on_reaction_pressed.bind(index))
		buttons.add_child(button)
	var skip_button := Button.new()
	skip_button.custom_minimum_size = Vector2(130, 38)
	skip_button.text = "Do Not Use"
	skip_button.pressed.connect(_on_reaction_pressed.bind(-1))
	buttons.add_child(skip_button)
	$ReactionPrompt.visible = true


func hide_reaction_prompt() -> void:
	$ReactionPrompt.visible = false


func _on_reaction_pressed(reaction_index: int) -> void:
	reaction_choice_selected.emit(reaction_index)


func toggle_ability(ability_id: String) -> void:
	var result := combat_system.toggle_ability("player", ability_id)
	if get_parent().has_method("sync_move_mode_from_state"):
		get_parent().sync_move_mode_from_state()
	if result.success:
		add_log_message("Ability equipment updated.")
	else:
		add_log_message("Ability failed: %s" % result.failure_reason)
	update_ui()


func use_weapon_ability(ability_id: String) -> void:
	var result := combat_system.use_weapon_ability("player", selected_target_id, ability_id)
	if get_parent().has_method("sync_move_mode_from_state"):
		get_parent().sync_move_mode_from_state()
	record_action_result(result)
	update_ui()


func toggle_equipment(item, target_slot: int = -1) -> void:
	var result := combat_system.toggle_equipment("player", item, target_slot)
	if get_parent().has_method("sync_move_mode_from_state"):
		get_parent().sync_move_mode_from_state()
	if result.success:
		add_log_message("Equipment updated: %s." % item.display_name)
	else:
		add_log_message("Equipment failed: %s" % result.failure_reason)
	update_ui()


func activate_weapon_slot(target_slot: int) -> void:
	var result := combat_system.set_active_weapon_slot("player", target_slot)
	if get_parent().has_method("sync_move_mode_from_state"):
		get_parent().sync_move_mode_from_state()
	if result.success:
		add_log_message("Active Weapon updated.")
	else:
		add_log_message("Weapon failed: %s" % result.failure_reason)
	update_ui()


func update_combat_log() -> void:
	var entries: Array[Dictionary] = []
	for message in local_log_entries:
		if is_player_relevant_log_message(message):
			entries.append({"action": "Action Error", "type": "WARNING", "actor": "System", "outcome": "FAILED", "details": message, "tone": "damage"})

	for event in combat_system.event_system.get_history():
		if not should_show_combat_event(event):
			continue
		var line := format_combat_event(event)
		if not line.is_empty():
			entries.append(create_combat_log_card_data(event, line))
	entries.reverse()
	var list: VBoxContainer = $CombatLogPanel/Margin/VBoxContainer/Scroll/Entries
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for entry in entries:
		var card = CombatLogActionCardScene.instantiate()
		list.add_child(card)
		card.setup(entry)


func is_player_relevant_log_message(message: String) -> bool:
	var normalized := message.to_lower()
	return normalized.contains("failed") or normalized.contains("cannot") or normalized.contains("unavailable")


func should_show_combat_event(event: CombatEvent) -> bool:
	match event.type:
		EventTypes.Type.ATTACK_HIT, \
		EventTypes.Type.ATTACK_MISS, \
		EventTypes.Type.EFFECT_APPLIED, \
		EventTypes.Type.EFFECT_EXPIRED, \
		EventTypes.Type.EFFECT_DAMAGE_APPLIED, \
		EventTypes.Type.EFFECT_HEAL_APPLIED, \
		EventTypes.Type.REACTION_AVAILABLE, \
		EventTypes.Type.REACTION_TRIGGERED, \
		EventTypes.Type.COMBAT_VICTORY, \
		EventTypes.Type.COMBAT_DEFEAT, \
		EventTypes.Type.SKILL_CAST:
			return true
		EventTypes.Type.DAMAGE_APPLIED:
			# Weapon attacks already include final damage in ATTACK_HIT.
			return event.data.has("ability_name") or event.data.has("damage_type")
		EventTypes.Type.ABILITY_TRIGGERED:
			# Active abilities matter; passive stack bookkeeping does not.
			return int(event.data.get("ap_cost", 0)) > 0 and not event.data.has("stacks")
	return false


func create_combat_log_card_data(event: CombatEvent, details: String) -> Dictionary:
	var action_name: String = event.data.get("attack_name", event.data.get("ability_name", event.data.get("skill_name", event.data.get("reaction_name", event.data.get("effect_name", "Combat Event")))))
	var type_name := "EVENT"
	var outcome := "RESOLVED"
	var tone := "neutral"
	var roll_text := ""
	var damage_text := ""
	match event.type:
		EventTypes.Type.ATTACK_HIT, EventTypes.Type.DAMAGE_APPLIED, EventTypes.Type.EFFECT_DAMAGE_APPLIED:
			type_name = "ATTACK" if event.type == EventTypes.Type.ATTACK_HIT else "DAMAGE"
			outcome = "HIT" if event.type == EventTypes.Type.ATTACK_HIT else "DAMAGED"
			tone = "damage"
		EventTypes.Type.ATTACK_MISS:
			type_name = "ATTACK"
			outcome = "MISS"
		EventTypes.Type.EFFECT_HEAL_APPLIED:
			type_name = "HEAL"
			outcome = "HEALED"
			tone = "heal"
		EventTypes.Type.EFFECT_APPLIED, EventTypes.Type.EFFECT_EXPIRED:
			type_name = "STATUS"
			outcome = "APPLIED" if event.type == EventTypes.Type.EFFECT_APPLIED else "EXPIRED"
			tone = "status"
		EventTypes.Type.REACTION_AVAILABLE, EventTypes.Type.REACTION_TRIGGERED, EventTypes.Type.REACTION_DECLINED, EventTypes.Type.INTERRUPTION_STARTED, EventTypes.Type.INTERRUPTION_ENDED:
			type_name = "REACTION"
			outcome = "TRIGGERED" if event.type == EventTypes.Type.REACTION_TRIGGERED else "PENDING"
			tone = "reaction"
		EventTypes.Type.TURN_STARTED, EventTypes.Type.TURN_ENDED, EventTypes.Type.COMBAT_STARTED:
			type_name = "TURN"
			outcome = "START" if event.type != EventTypes.Type.TURN_ENDED else "END"
			tone = "turn"
		EventTypes.Type.COMBAT_VICTORY:
			type_name = "COMBAT"
			outcome = "VICTORY"
			tone = "heal"
		EventTypes.Type.COMBAT_DEFEAT:
			type_name = "COMBAT"
			outcome = "DEFEAT"
			tone = "damage"
	if event.data.has("attack_total"):
		roll_text = "%d vs DEF %d" % [event.data.get("attack_total", 0), event.data.get("defense", 0)]
	if event.data.has("final_damage") or event.data.has("damage"):
		damage_text = "%d %s damage" % [event.data.get("final_damage", event.data.get("damage", 0)), event.data.get("damage_type", "")]
	return {
		"action": action_name,
		"type": type_name,
		"actor": event.source_id.capitalize(),
		"target": event.target_id.capitalize(),
		"outcome": outcome,
		"roll": roll_text,
		"damage": damage_text,
		"details": details,
		"tone": tone,
	}


func record_action_result(result: ActionResult) -> void:
	if not result.success:
		local_log_entries.append(
			"Action failed: %s" % result.failure_reason
		)

	update_ui()


func add_log_message(message: String) -> void:
	local_log_entries.append(message)
	update_combat_log()


func format_combat_event(event: CombatEvent) -> String:
	if event.type == EventTypes.Type.ATTACK_HIT:
		return format_attack_hit(event)

	match event.type:
		EventTypes.Type.COMBAT_STARTED:
			return "Combat started."

		EventTypes.Type.COMBAT_VICTORY:
			return "Victory! Team %d is the last team standing." % event.data.get("winner_team", 0)

		EventTypes.Type.COMBAT_DEFEAT:
			return "Defeat. Team %d is the last team standing." % event.data.get("winner_team", 0)

		EventTypes.Type.INTERRUPTION_STARTED:
			return "%s interrupts %s with %s." % [
				event.source_id.capitalize(),
				event.target_id.capitalize(),
				event.data.get("reaction_name", "a reaction")
			]

		EventTypes.Type.REACTION_AVAILABLE:
			return "%s may use %s." % [
				event.source_id.capitalize(),
				event.data.get("reaction_name", "a reaction")
			]

		EventTypes.Type.REACTION_TRIGGERED:
			return "%s resolves %s." % [
				event.source_id.capitalize(),
				event.data.get("reaction_name", "a reaction")
			]

		EventTypes.Type.REACTION_DECLINED:
			return "%s declined %s." % [
				event.source_id.capitalize(),
				event.data.get("reaction_name", "a reaction")
			]

		EventTypes.Type.INTERRUPTION_ENDED:
			return "%s interruption ended." % event.source_id.capitalize()

		EventTypes.Type.TURN_STARTED:
			return "%s's turn started." % event.source_id.capitalize()

		EventTypes.Type.TURN_ENDED:
			return "%s's turn ended." % event.source_id.capitalize()

		EventTypes.Type.POSITION_CHANGED:
			return "%s moved %.1f ft." % [
				event.source_id.capitalize(),
				event.data.get("distance_feet", 0.0)
			]

		EventTypes.Type.ATTACK_HIT:
			return "%s hit %s — Roll %d + %d = %d vs DEF %d. Damage: %d.%s" % [
				event.source_id.capitalize(),
				event.target_id.capitalize(),
				event.data.get("roll", 0),
				event.data.get("attack_modifier", 0),
				event.data.get("attack_total", 0),
				event.data.get("defense", 0),
				event.data.get("final_damage", 0),
				format_repeated_attack_penalty(event)
			]

		EventTypes.Type.ATTACK_MISS:
			return "%s used %s on %s but missed - Roll %d + %d = %d vs DEF %d.%s" % [
				event.source_id.capitalize(),
				event.data.get("attack_name", "Attack"),
				event.target_id.capitalize(),
				event.data.get("roll", 0),
				event.data.get("attack_modifier", 0),
				event.data.get("attack_total", 0),
				event.data.get("defense", 0),
				format_repeated_attack_penalty(event)
			]

		EventTypes.Type.EFFECT_APPLIED:
			return "%s is affected by %s." % [
				event.target_id.capitalize(),
				event.data.get("effect_name", "an effect")
			]

		EventTypes.Type.EFFECT_EXPIRED:
			return "%s's %s expired." % [
				event.source_id.capitalize(),
				event.data.get("effect_name", "effect")
			]

		EventTypes.Type.EFFECT_DAMAGE_APPLIED:
			if event.data.get("immune", false):
				return "%s ignored %s because of immunity." % [
					event.target_id.capitalize(),
					event.data.get("effect_name", "an effect")
				]
			return "%s takes %d %s damage from %s." % [
				event.target_id.capitalize(),
				event.data.get("amount", 0),
				event.data.get("damage_type", ""),
				event.data.get("effect_name", "an effect")
			]

		EventTypes.Type.DAMAGE_APPLIED:
			return "%s takes %d %s damage from %s." % [
				event.target_id.capitalize(),
				event.data.get("damage", event.data.get("final_damage", 0)),
				event.data.get("damage_type", ""),
				event.data.get("ability_name", event.source_id.capitalize())
			]

		EventTypes.Type.EFFECT_HEAL_APPLIED:
			return "%s restores %d HP from %s." % [
				event.target_id.capitalize(),
				event.data.get("amount", 0),
				event.data.get("effect_name", "an effect")
			]

		EventTypes.Type.EFFECT_RESOURCE_CHANGED:
			return "%s changes %s by %d from %s." % [
				event.target_id.capitalize(),
				event.data.get("resource_name", "resource"),
				event.data.get("amount", 0),
				event.data.get("effect_name", "an effect")
			]

		EventTypes.Type.FAITH_CHANGED:
			if event.data.get("faith_spent", 0) > 0:
				return "%s spends %d Faith on %s (Faith %d + %d temporary)." % [event.source_id.capitalize(), event.data.faith_spent, event.data.get("ability_name", "an effect"), event.data.faith, event.data.temporary_faith]
			if event.data.get("temporary_faith_lost", 0) > 0:
				return "%s loses %d Temporary Faith (Faith %d + %d temporary)." % [event.source_id.capitalize(), event.data.temporary_faith_lost, event.data.faith, event.data.temporary_faith]
			return "%s gains %d Faith and %d Temporary Faith from %s (Faith %d + %d temporary)." % [event.source_id.capitalize(), event.data.get("faith_gained", 0), event.data.get("temporary_faith_gained", 0), event.data.get("ability_name", "an effect"), event.data.get("faith", 0), event.data.get("temporary_faith", 0)]

		EventTypes.Type.ABILITY_TRIGGERED:
			if not event.data.has("stacks"):
				return "%s uses %s (AP -%d, Cooldown %d)." % [
					event.source_id.capitalize(),
					event.data.get("ability_name", "Ability"),
					event.data.get("ap_cost", 0),
					event.data.get("cooldown", 0)
				]
			return "%s triggered %s: %d stack(s), To Hit +%d." % [
				event.source_id.capitalize(),
				event.data.get("ability_name", "Ability"),
				event.data.get("stacks", 0),
				event.data.get("bonus", 0)
			]

		EventTypes.Type.ABILITY_STACKS_CLEARED:
			return "%s's %s stacks cleared at End Turn." % [
				event.source_id.capitalize(),
				event.data.get("ability_name", "Ability")
			]

		EventTypes.Type.ABILITY_COOLDOWN_REDUCED:
			return "%s cooldown: %d turn(s) remaining." % [
				event.data.get("ability_id", "Ability"),
				event.data.get("remaining", 0)
			]

		EventTypes.Type.SKILL_CAST:
			return "%s casts %s (Mana -%d, Cooldown %d)." % [
				event.source_id.capitalize(),
				event.data.get("skill_name", "a skill"),
				event.data.get("mana_cost", 0),
				event.data.get("cooldown", 0)
			]

		EventTypes.Type.SKILL_COOLDOWN_REDUCED:
			return "%s cooldown: %d turn(s) remaining." % [
				event.data.get("skill_id", "Skill"),
				event.data.get("remaining", 0)
			]

		EventTypes.Type.EQUIPMENT_CHANGED:
			return "%s changed equipment: %s." % [
				event.source_id.capitalize(),
				event.data.get("item_name", "item")
			]

	return ""


func format_attack_hit(event: CombatEvent) -> String:
	var attacker_name := event.source_id.capitalize()
	var target_name := event.target_id.capitalize()
	var attack_name: String = event.data.get("attack_name", "Attack")
	var attack_text := "%s used %s on %s - Roll %d + %d = %d vs DEF %d." % [
		attacker_name,
		attack_name,
		target_name,
		event.data.get("roll", 0),
		event.data.get("attack_modifier", 0),
		event.data.get("attack_total", 0),
		event.data.get("defense", 0)
	]
	attack_text += format_repeated_attack_penalty(event)

	if event.data.get("immune", false):
		return "%s %s is immune to %s damage." % [
			attack_text,
			target_name,
			String(event.data.get("damage_type", "this"))
		]

	var critical_text := ""
	if event.data.get("critical", false):
		critical_text = " CRITICAL!"
	var bonus_text := ""
	if event.data.get("conditional_damage_bonus", 0) > 0:
		var bonus_parts: PackedStringArray = []
		for bonus in event.data.get("conditional_damage_bonuses", []):
			bonus_parts.append("%s +%d" % [bonus.get("source", "Bonus"), bonus.get("amount", 0)])
		bonus_text = " %s." % (", ".join(bonus_parts) if not bonus_parts.is_empty() else "%s +%d" % [event.data.get("damage_bonus_source", "Bonus"), event.data.get("conditional_damage_bonus", 0)])

	return "%s%s%s Damage: %d - Resistance %d = %d." % [
		attack_text,
		critical_text,
		bonus_text,
		event.data.get("damage", 0),
		event.data.get("resistance", 0),
		event.data.get("final_damage", 0)
	]


func format_repeated_attack_penalty(event: CombatEvent) -> String:
	var penalty: int = int(event.data.get("repeated_attack_penalty", 0))
	return " Repeated Attack Penalty: %d." % penalty if penalty < 0 else ""
