extends Control

const CombatLogActionCardScene := preload("res://scenes/combat/ui/CombatLogActionCard.tscn")

signal reaction_choice_selected(reaction_index: int)

var combat_system: CombatSystem
var local_log_entries: PackedStringArray = []
var selected_target_name: String = "None"
var selected_target_id: String = "enemy"
var displayed_reactions: Array = []
var selected_reaction_index: int = -1
var reaction_ui_bound: bool = false


func setup(system: CombatSystem) -> void:
	combat_system = system
	_bind_authored_reaction_ui()
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
		var observer: CombatantState = player if player != null else primary_player
		var visibility_text := "Unknown"
		if observer != null:
			var visibility: Dictionary = combat_system.map_rules.get_visibility(observer, enemy)
			visibility_text = ["Visible", "Partially Visible (-4 Attack)", "Not Visible"][int(visibility.visibility)]
		$Enemy_panel/VBoxContainer/Effects.text = "Visibility: %s\nEffects: %s" % [visibility_text, get_effect_names(enemy)]
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
		var duration_text := "" if effect.data.persists_until_combat_end else " (%d)" % effect.remaining_turns
		names.append("%s%s%s" % [effect.get_display_name(), stack_text, duration_text])
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
	if weapon.ammunition_capacity > 0 and TraitSystem.new().attack_has_trait(weapon, "reload"):
		var ammo: int = int(player.ammunition.get(weapon.id, weapon.ammunition_capacity))
		var cannot_reload: bool = combat_system.get_combat_state().is_finished() or combat_system.get_combat_state().current_actor_id != "player"
		var reload_button := Button.new()
		reload_button.custom_minimum_size = Vector2(0, 34)
		reload_button.text = "Reload (%d/%d กระสุน, %d AP)" % [ammo, weapon.ammunition_capacity, weapon.reload_ap_cost]
		reload_button.tooltip_text = "เติมกระสุนให้อาวุธที่ถืออยู่"
		reload_button.disabled = cannot_reload or player.ap < weapon.reload_ap_cost or ammo >= weapon.ammunition_capacity
		reload_button.pressed.connect(reload_weapon)
		menu.add_child(reload_button)
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
		if item.slot != EquipmentData.Slot.WEAPON and item.slot != EquipmentData.Slot.SHIELD:
			add_equipment_button(menu, "Worn gear locked: %s" % item.display_name, item.description, true, Callable())
		elif item.slot == EquipmentData.Slot.SHIELD:
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
	var cannot_move := actor == null or not combat_system.movement_system.can_begin_or_continue_move(actor, 1)
	$ActionSources/Move.disabled = not enabled or cannot_move
	$"ActionSources/End Turn".disabled = not enabled


func show_reaction_prompt(prompt: Dictionary) -> void:
	_bind_authored_reaction_ui()
	$ReactionPrompt.visible = false
	displayed_reactions.clear()
	var reactions: Array = prompt.get("reactions", []).duplicate()
	if reactions.is_empty() and prompt.has("reaction"):
		reactions.append(prompt["reaction"])
	if reactions.is_empty():
		hide_reaction_prompt()
		return
	displayed_reactions.assign(reactions)
	var list: VBoxContainer = $CombatUI/Reaction/Reaction/VBoxContainer/ReactionScroll/ReactionList
	var template: NinePatchRect = list.get_node("ReactionTemplate")
	template.hide()
	for child in list.get_children():
		if child != template:
			list.remove_child(child)
			child.queue_free()
	for index in range(reactions.size()):
		var reaction = reactions[index]
		var card: NinePatchRect = template.duplicate()
		card.name = "Reaction_%d" % index
		card.visible = true
		card.get_node("HBoxContainer/VBoxContainer/Name").text = reaction.display_name
		card.get_node("HBoxContainer/VBoxContainer/Cost").text = _format_reaction_cost(reaction, prompt.get("reactor"))
		var button: Button = card.get_node("Button")
		button.tooltip_text = reaction.description
		button.pressed.connect(_select_authored_reaction.bind(index, prompt))
		list.add_child(card)
	$CombatUI/Reaction.visible = true
	_select_authored_reaction(0, prompt)
	$CombatUI/Reaction/Reaction/VBoxContainer/ReactionScroll.scroll_vertical = 0


func hide_reaction_prompt() -> void:
	$ReactionPrompt.visible = false
	$CombatUI/Reaction.visible = false
	$CombatUI/ReactionDescription.visible = false
	selected_reaction_index = -1
	displayed_reactions.clear()


func _bind_authored_reaction_ui() -> void:
	if reaction_ui_bound:
		return
	var cancel_button: Button = $CombatUI/Reaction/Reaction/VBoxContainer/HBoxContainer/Cancel_Button/Button
	var use_button: Button = $CombatUI/Reaction/Reaction/VBoxContainer/HBoxContainer/Use_Button/Button
	cancel_button.pressed.connect(_on_reaction_pressed.bind(-1))
	use_button.pressed.connect(_use_selected_reaction)
	reaction_ui_bound = true


func _select_authored_reaction(index: int, prompt: Dictionary) -> void:
	if index < 0 or index >= displayed_reactions.size():
		return
	selected_reaction_index = index
	var list: VBoxContainer = $CombatUI/Reaction/Reaction/VBoxContainer/ReactionScroll/ReactionList
	for child in list.get_children():
		if child.name == "ReactionTemplate":
			continue
		var child_index: int = int(String(child.name).trim_prefix("Reaction_"))
		child.modulate = Color.WHITE if child_index == index else Color(0.72, 0.72, 0.72, 1.0)
	var reaction = displayed_reactions[index]
	$CombatUI/ReactionDescription/Frame/Description.text = "%s\n\n%s" % [_reaction_context_text(prompt), reaction.description]
	$CombatUI/ReactionDescription.visible = true


func _use_selected_reaction() -> void:
	if selected_reaction_index >= 0:
		_on_reaction_pressed(selected_reaction_index)


func _format_reaction_cost(reaction, reactor: CombatantState = null) -> String:
	var costs: PackedStringArray = ["%d AP" % reaction.ap_cost]
	if reaction.faith_cost > 0:
		costs.append("%d Faith" % reaction.faith_cost)
	if reactor != null and not reaction.source_skill_id.is_empty():
		var skill: SkillData = combat_system.skill_system.get_available_skill(reactor, reaction.source_skill_id)
		if skill != null:
			costs.append("%d Mana" % combat_system.skill_system.get_effective_mana_cost(reactor, skill))
	return "Cost: %s" % " · ".join(costs)


func _reaction_context_text(prompt: Dictionary) -> String:
	var attacker = prompt.get("attacker")
	var attacker_name: String = attacker.display_name if attacker != null else "An enemy"
	if prompt.get("opportunity_choice", false):
		return "%s is leaving your weapon's reach." % attacker_name
	if prompt.get("counterattack_choice", false):
		return "%s missed you with a melee attack. You may counterattack." % attacker_name
	if prompt.get("step_back", false):
		return "The attack has resolved. Choose a movement Reaction."
	if prompt.get("damage_intervention", false):
		var protected_target = prompt.get("attack_target")
		return "%s is about to damage %s." % [attacker_name, protected_target.display_name if protected_target != null else "your ally"]
	var prepared: AttackResult = prompt.get("prepared_attack")
	if prepared != null:
		return "%s rolled %d vs DEF %d (margin %+d)." % [attacker_name, prepared.roll + prepared.attack_modifier, prepared.defense, prepared.margin]
	return "Choose a Reaction to resolve the current trigger."


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


func reload_weapon() -> void:
	var result := combat_system.reload_weapon("player")
	if not result.success:
		add_log_message("Reload failed: %s" % result.failure_reason)
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
		card.setup(entry, true)


func is_player_relevant_log_message(message: String) -> bool:
	var normalized := message.to_lower()
	return normalized.contains("failed") or normalized.contains("cannot") or normalized.contains("unavailable")


func should_show_combat_event(event: CombatEvent) -> bool:
	# Item effects remain in event history for feedback/automation, while the
	# player-facing log combines them into the single ITEM_USED action card.
	if event.data.has("item_id") and event.type in [EventTypes.Type.EFFECT_HEAL_APPLIED, EventTypes.Type.EFFECT_DAMAGE_APPLIED]:
		return false
	match event.type:
		EventTypes.Type.ATTACK_HIT, \
		EventTypes.Type.ATTACK_MISS, \
		EventTypes.Type.EFFECT_APPLIED, \
		EventTypes.Type.EFFECT_EXPIRED, \
		EventTypes.Type.EFFECT_DAMAGE_APPLIED, \
		EventTypes.Type.EFFECT_HEAL_APPLIED, \
		EventTypes.Type.EFFECT_RESOURCE_CHANGED, \
		EventTypes.Type.FAITH_CHANGED, \
		EventTypes.Type.EQUIPMENT_CHANGED, \
		EventTypes.Type.REACTION_AVAILABLE, \
		EventTypes.Type.REACTION_TRIGGERED, \
		EventTypes.Type.REACTION_DECLINED, \
		EventTypes.Type.TURN_STARTED, \
		EventTypes.Type.COMBAT_VICTORY, \
		EventTypes.Type.COMBAT_DEFEAT, \
		EventTypes.Type.SKILL_CAST, \
		EventTypes.Type.MANEUVER_USED:
			return true
		EventTypes.Type.ESCAPE_ATTEMPTED:
			return true
		EventTypes.Type.ITEM_USED:
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
	if event.type in [EventTypes.Type.EFFECT_APPLIED, EventTypes.Type.EFFECT_EXPIRED, EventTypes.Type.EFFECT_DAMAGE_APPLIED, EventTypes.Type.EFFECT_HEAL_APPLIED]:
		action_name = String(event.data.get("effect_name", action_name))
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
		EventTypes.Type.EFFECT_RESOURCE_CHANGED:
			type_name = "RESOURCE"
			outcome = "RESTORED" if int(event.data.get("amount", 0)) > 0 else "SPENT"
			damage_text = "%+d %s" % [int(event.data.get("amount", 0)), String(event.data.get("resource_name", "Resource"))]
			tone = "heal" if int(event.data.get("amount", 0)) > 0 else "damage"
		EventTypes.Type.FAITH_CHANGED:
			type_name = "FAITH"
			outcome = "CHANGED"
			tone = "reaction"
		EventTypes.Type.EQUIPMENT_CHANGED:
			action_name = String(event.data.get("item_name", "Equipment"))
			type_name = "GEAR"
			outcome = "CHANGED"
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
		EventTypes.Type.ESCAPE_ATTEMPTED:
			action_name = "Escape: %s" % event.data.get("effect_name", "Status")
			type_name = "ACTION"
			outcome = "SUCCESS" if event.data.get("succeeded", false) else "FAILED"
			tone = "heal" if event.data.get("succeeded", false) else "damage"
			roll_text = "%d vs DC %d" % [event.data.get("total", 0), event.data.get("dc", 0)]
		EventTypes.Type.MANEUVER_USED:
			action_name = event.data.get("maneuver", "Maneuver")
			type_name = "ACTION"
			outcome = "SUCCESS" if event.data.get("succeeded", false) else "FAILED"
			tone = "heal" if event.data.get("succeeded", false) else "damage"
			if event.data.get("maneuver", "") == "Hide":
				var enemy_dcs: Array[String] = []
				for check in event.data.get("checks", []):
					enemy_dcs.append("%s DC %d" % [String(check.get("enemy_id", "")).capitalize(), int(check.get("dc", 0))])
				roll_text = "%d vs %s" % [event.data.get("total", 0), ", ".join(enemy_dcs)] if not enemy_dcs.is_empty() else str(event.data.get("total", 0))
			elif event.data.has("dc"):
				roll_text = "%d vs DC %d" % [event.data.get("total", 0), event.data.get("dc", 0)]
			elif event.data.has("defense"):
				roll_text = "%d vs DEF %d" % [event.data.get("total", 0), event.data.get("defense", 0)]
		EventTypes.Type.ITEM_USED:
			action_name = event.data.get("item_name", "Item")
			type_name = "ITEM"
			if int(event.data.get("healing", 0)) > 0:
				outcome = "HEALED"
				damage_text = "+%d HP" % int(event.data.get("healing", 0))
				tone = "heal"
			elif int(event.data.get("damage", 0)) > 0:
				outcome = "DAMAGED"
				damage_text = "%d damage" % int(event.data.get("damage", 0))
				tone = "damage"
			else:
				outcome = "USED"
	if event.type == EventTypes.Type.ATTACK_HIT and not event.data.get("requires_to_hit", true):
		roll_text = "Automatic hit"
	elif event.data.has("attack_total"):
		var defense_name := "DEF"
		var defense_type: int = int(event.data.get("defense_type", -1))
		if defense_type >= 0 and defense_type < DefenseTypes.Type.size():
			defense_name = DefenseTypes.Type.keys()[defense_type].capitalize().replace("_", " ")
		roll_text = "3d8 %d %+d = %d vs %s %d" % [event.data.get("roll", 0), event.data.get("attack_modifier", 0), event.data.get("attack_total", 0), defense_name, event.data.get("defense", 0)]
	if event.type != EventTypes.Type.ITEM_USED and (event.data.has("final_damage") or event.data.has("damage")):
		damage_text = "%d %s damage" % [event.data.get("final_damage", event.data.get("damage", 0)), event.data.get("damage_type", "")]
	elif event.type in [EventTypes.Type.EFFECT_DAMAGE_APPLIED, EventTypes.Type.DAMAGE_APPLIED] and event.data.has("amount"):
		damage_text = "%d %s damage" % [int(event.data.amount), String(event.data.get("damage_type", ""))]
	return {
		"action": action_name,
		"type": type_name,
		"actor": get_log_combatant_name(event.source_id),
		"target": get_log_combatant_name(event.target_id) if not event.target_id.is_empty() else "",
		"outcome": outcome,
		"roll": roll_text,
		"damage": damage_text,
		"details": build_combat_log_details(event, details),
		"tone": tone,
	}


func get_log_combatant_name(combatant_id: String) -> String:
	if combat_system != null and combat_system.combat_state != null:
		var combatant: CombatantState = combat_system.combat_state.get_combatant(combatant_id)
		if combatant != null and not combatant.display_name.is_empty():
			return combatant.display_name
	return combatant_id.capitalize()


func format_log_bonus_parts(parts: Array) -> String:
	var labels: PackedStringArray = []
	for part in parts:
		if part is Dictionary:
			labels.append("%s %+d" % [String(part.get("source", "Bonus")), int(part.get("amount", 0))])
	return " · ".join(labels)


func build_combat_log_details(event: CombatEvent, fallback: String) -> String:
	var lines: PackedStringArray = []
	if event.type in [EventTypes.Type.ATTACK_HIT, EventTypes.Type.ATTACK_MISS]:
		if event.data.get("requires_to_hit", true):
			var to_hit_parts: Array = event.data.get("to_hit_breakdown", [])
			if not to_hit_parts.is_empty():
				lines.append("To Hit: %s = %+d" % [format_log_bonus_parts(to_hit_parts), int(event.data.get("attack_modifier", 0))])
			var defense_bonus: int = int(event.data.get("defense", 0)) - int(event.data.get("original_defense", event.data.get("defense", 0)))
			if defense_bonus != 0:
				lines.append("Defense: base %d · Reaction %+d = %d" % [int(event.data.get("original_defense", 0)), defense_bonus, int(event.data.get("defense", 0))])
		if event.type == EventTypes.Type.ATTACK_HIT:
			if event.data.has("critical_roll") and event.data.get("can_critical", true):
				lines.append("Critical: d100 %d vs %d%% %s" % [int(event.data.get("critical_roll", 0)), int(event.data.get("critical_chance", 0)), "CRIT" if event.data.get("critical", false) else "normal"])
			var damage_parts: Array = event.data.get("damage_breakdown", [])
			if not damage_parts.is_empty():
				lines.append("Damage parts: %s" % format_log_bonus_parts(damage_parts))
				lines.append("Raw %d → Final %d %s" % [int(event.data.get("damage", 0)), int(event.data.get("final_damage", 0)), String(event.data.get("damage_type", ""))])
			if event.data.get("immune", false):
				lines.append("Target is immune to %s damage." % String(event.data.get("damage_type", "this")))
			if int(event.data.get("finishing_gauge_gained", 0)) > 0:
				lines.append("Finishing Gauge +%d (%d/%d)" % [int(event.data.get("finishing_gauge_gained", 0)), int(event.data.get("finishing_gauge", 0)), int(event.data.get("max_finishing_gauge", 0))])
		return "\n".join(lines)
	if event.type == EventTypes.Type.MANEUVER_USED:
		if event.data.has("roll"):
			var skill_name := "Stealth" if event.data.get("maneuver", "") == "Hide" else ("Perception" if event.data.get("maneuver", "") == "Search" else "Strength")
			var modifier: int = int(event.data.get("stealth", event.data.get("perception", event.data.get("strength_modifier", 0))))
			lines.append("Check: 3d8 %d · %s %+d = %d" % [int(event.data.roll), skill_name, modifier, int(event.data.get("total", 0))])
		if event.data.get("maneuver", "") == "Hide":
			for check in event.data.get("checks", []):
				var los_bonus := 4 if check.get("has_line_of_sight", false) else 0
				var perception: int = int(check.get("dc", 0)) - 10 - los_bonus
				lines.append("%s: DC 10 + Perception %d + sight %d = %d (%s)" % [get_log_combatant_name(String(check.get("enemy_id", ""))), perception, los_bonus, int(check.get("dc", 0)), "PASS" if check.get("succeeded", false) else "FAIL"])
		elif event.data.get("maneuver", "") == "Search" and event.data.has("dc"):
			lines.append("DC: 10 + target Stealth %d = %d" % [int(event.data.get("stealth", 0)), int(event.data.dc)])
		elif event.data.has("defense"):
			lines.append("vs Defense %d" % int(event.data.defense))
		if event.data.has("distance_feet"):
			lines.append("Moved %.1f / %.1f ft" % [float(event.data.get("distance_feet", 0.0)), float(event.data.get("requested_distance_feet", 0.0))])
		if int(event.data.get("collision_damage", 0)) > 0:
			lines.append("Collision damage %d" % int(event.data.collision_damage))
		if int(event.data.get("fall_damage", 0)) > 0:
			lines.append("Fall damage %d" % int(event.data.fall_damage))
		return "\n".join(lines)
	if event.type == EventTypes.Type.ESCAPE_ATTEMPTED:
		lines.append("Check: 3d8 %d · Strength %+d = %d vs DC %d" % [int(event.data.get("roll", 0)), int(event.data.get("strength_modifier", 0)), int(event.data.get("total", 0)), int(event.data.get("dc", 0))])
	if not fallback.is_empty():
		lines.append(fallback)
	if event.data.has("mana_cost") and not fallback.contains("Mana -"):
		lines.append("Mana -%d" % int(event.data.mana_cost))
	if event.data.has("cooldown") and not fallback.contains("Cooldown "):
		lines.append("Cooldown %d turn(s)" % int(event.data.cooldown))
	return "\n".join(lines)


func record_action_result(result: ActionResult) -> void:
	if not result.success:
		local_log_entries.append(
			"Action failed: %s" % result.failure_reason
		)
	elif combat_system != null and combat_system.has_pending_step_back_move():
		var movement_name: String = combat_system.pending_reaction_move_name if not combat_system.pending_reaction_move_name.is_empty() else "Reaction movement"
		set_mode_hint("%s: click a destination up to %.1f ft away." % [movement_name, combat_system.step_back_move_distance_feet])

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
				format_attack_penalties(event)
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
				format_attack_penalties(event)
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
				event.data.get("amount", event.data.get("damage", event.data.get("final_damage", 0))),
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
				if event.data.get("finishing_gauge_spent", 0) > 0:
					return "%s uses %s (Finishing Gauge -%d, Gauge %d)." % [
						event.source_id.capitalize(),
						event.data.get("ability_name", "Ability"),
						event.data.get("finishing_gauge_spent", 0),
						event.data.get("finishing_gauge", 0)
					]
				return "%s uses %s (Cooldown %d)." % [
					event.source_id.capitalize(),
					event.data.get("ability_name", "Ability"),
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

		EventTypes.Type.ESCAPE_ATTEMPTED:
			return "%s attempts to Escape %s — 3d8 %d %+d STR = %d vs DC %d: %s." % [
				event.source_id.capitalize(),
				event.data.get("effect_name", "a Status"),
				event.data.get("roll", 0),
				event.data.get("strength_modifier", 0),
				event.data.get("total", 0),
				event.data.get("dc", 0),
				"escaped" if event.data.get("succeeded", false) else "failed"
			]

		EventTypes.Type.MANEUVER_USED:
			if event.data.get("maneuver", "") == "Hide":
				return "%s uses Hide — 3d8 %d + Stealth %d = %d: %s." % [
					event.source_id.capitalize(), event.data.get("roll", 0), event.data.get("stealth", 0), event.data.get("total", 0), "Concealment +1 against detected enemies" if event.data.get("succeeded", false) else "failed against every enemy"
				]
			if event.data.get("maneuver", "") == "Search":
				return "%s uses Search on %s — 3d8 %d + Perception %d = %d vs DC %d: %s." % [
					event.source_id.capitalize(), event.target_id.capitalize(), event.data.get("roll", 0), event.data.get("perception", 0), event.data.get("total", 0), event.data.get("dc", 0), "Hide Concealment -1" if event.data.get("concealment_reduced", false) else ("no Hide Concealment to reveal" if event.data.get("succeeded", false) else "failed")
				]
			var result_text := "succeeds" if event.data.get("succeeded", false) else "fails"
			return "%s uses %s: %s." % [
				event.source_id.capitalize(),
				event.data.get("maneuver", "a Maneuver"),
				result_text
			]

		EventTypes.Type.ITEM_USED:
			var effect_text := ""
			if int(event.data.get("healing", 0)) > 0:
				effect_text = " and restores %d HP" % int(event.data.get("healing", 0))
			elif int(event.data.get("damage", 0)) > 0:
				effect_text = " and deals %d damage" % int(event.data.get("damage", 0))
			return "%s uses %s%s (%d remaining)." % [
				event.source_id.capitalize(),
				event.data.get("item_name", "an Item"),
				effect_text,
				event.data.get("quantity_remaining", 0)
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
	attack_text += format_attack_penalties(event)

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


func format_attack_penalties(event: CombatEvent) -> String:
	var text := format_repeated_attack_penalty(event)
	var offhand_penalty: int = int(event.data.get("offhand_penalty", 0))
	if offhand_penalty < 0:
		text += " Off-hand Penalty: %d." % offhand_penalty
		text += " Combined Penalty: %d." % (int(event.data.get("repeated_attack_penalty", 0)) + offhand_penalty)
	var visibility_penalty: int = int(event.data.get("visibility_penalty", 0))
	if visibility_penalty < 0:
		text += " Partially Visible: %d." % visibility_penalty
	return text
