class_name CharacterPanel
extends PanelContainer

signal equipment_change_requested(item, slot: int)
signal closed

var combat_system
var combatant_id := "player"
var active_tab := "abilities"
var changes_locked := false
var summary: VBoxContainer
var content_list: VBoxContainer
var page_title: Label
var status_label: Label
var tab_buttons: Dictionary = {}
var standalone_character: CombatantState


func _ready() -> void:
	_build_ui()


func setup(system, target_id: String = "player") -> void:
	combat_system = system
	standalone_character = null
	combatant_id = target_id
	refresh()


func setup_standalone(player: CombatantState, initial_tab: String = "inventory") -> void:
	combat_system = null
	standalone_character = player
	active_tab = initial_tab
	changes_locked = true
	refresh()


func set_changes_locked(value: bool) -> void:
	# Called every frame by the arena. Rebuilding unchanged buttons discards
	# the mouse-down before mouse-up can emit pressed.
	if changes_locked == value:
		return
	changes_locked = value
	if visible:
		refresh()


func set_tab(tab_id: String) -> void:
	if tab_buttons.has(tab_id):
		active_tab = tab_id
		refresh()


func refresh() -> void:
	if summary == null:
		return
	var player: CombatantState = standalone_character
	if player == null and combat_system != null:
		player = combat_system.get_combat_state().get_combatant(combatant_id)
	if player == null:
		return
	_clear(summary)
	_clear(content_list)
	for tab_id in tab_buttons:
		tab_buttons[tab_id].button_pressed = tab_id == active_tab
	page_title.text = active_tab.capitalize()
	status_label.text = "AP %d / %d   |   Speed %.1f ft   |   %s" % [player.ap, player.effective_max_ap, player.get_effective_speed(), _resource_text(player)]
	_build_summary(player)
	match active_tab:
		"abilities": _build_abilities(player)
		"equipment": _build_equipment(player, true)
		"inventory": _build_inventory(player)


func _resource_text(player: CombatantState) -> String:
	if player.max_faith > 0:
		return "Faith %d / %d   |   Temporary +%d" % [player.faith, player.max_faith, player.temporary_faith]
	return "Mana %d / %d" % [player.mana, player.max_mana]


func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101a2a")
	style.border_color = Color("38bdf8")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	add_theme_stylebox_override("panel", style)
	var panel_scroll := ScrollContainer.new()
	panel_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(panel_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel_scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "CHARACTER"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	column.add_child(body)
	summary = VBoxContainer.new()
	summary.custom_minimum_size = Vector2(385, 0)
	summary.add_theme_constant_override("separation", 8)
	body.add_child(summary)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var tabs := HBoxContainer.new()
	right.add_child(tabs)
	for tab_id in ["abilities", "equipment", "inventory"]:
		var button := Button.new()
		button.text = tab_id.capitalize()
		button.toggle_mode = true
		button.pressed.connect(set_tab.bind(tab_id))
		tabs.add_child(button)
		tab_buttons[tab_id] = button
	page_title = Label.new()
	page_title.add_theme_font_size_override("font_size", 20)
	page_title.add_theme_color_override("font_color", Color("7dd3fc"))
	right.add_child(page_title)
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color("bae6fd"))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(status_label)
	right.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	content_list = VBoxContainer.new()
	content_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_list.add_theme_constant_override("separation", 7)
	scroll.add_child(content_list)


func _build_summary(player: CombatantState) -> void:
	_add_summary(player.display_name, 24, Color("f8fafc"))
	_add_summary("Level %d  |  %s  |  %s" % [player.level, player.ancestry_display_name, player.class_display_name])
	var portrait := ColorRect.new()
	portrait.custom_minimum_size = Vector2(0, 155)
	portrait.color = Color("17243a")
	summary.add_child(portrait)
	_add_summary("HP  %d / %d" % [player.hp, player.max_hp])
	_add_summary("STR %d   DEX %d   CON %d" % [player.strength, player.dexterity, player.constitution])
	_add_summary("INT %d   WIS %d   CHA %d" % [player.intelligence, player.wisdom, player.charisma])
	var fortitude_bonus: int = int(combat_system.effect_system.get_fortitude_bonus(player)) if combat_system != null else 0
	var reflex_bonus: int = int(combat_system.effect_system.get_reflex_bonus(player)) if combat_system != null else 0
	var will_bonus: int = int(combat_system.effect_system.get_will_bonus(player)) if combat_system != null else 0
	_add_summary("Fortitude %d   Reflex %d   Will %d" % [player.fortitude + fortitude_bonus, player.reflex + reflex_bonus, player.will + will_bonus])
	_add_summary("Speed %.1f ft   Mana %d / %d" % [player.get_effective_speed(), player.mana, player.max_mana])
	if player.max_faith > 0:
		_add_summary("Faith %d / %d   Temporary Faith +%d" % [player.faith, player.max_faith, player.temporary_faith])


func _build_abilities(player: CombatantState) -> void:
	var groups := {"CLASS ABILITY": [], "ANCESTRY ABILITY": [], "BASIC ABILITY": []}
	var abilities: Array = combat_system.ability_system.get_active_abilities(player) if combat_system != null else player.available_abilities
	for ability in abilities:
		if ability == null:
			continue
		var group := "BASIC ABILITY"
		if ability.required_trait_ids.has("assassin") or ability.id in ["killer_instinct", "shadow_step"]:
			group = "CLASS ABILITY"
		elif ability.id == "human_adapt":
			group = "ANCESTRY ABILITY"
		groups[group].append(ability)
	for group in groups:
		_add_content(group, Color("38bdf8"), 15)
		if groups[group].is_empty():
			_add_content("No abilities", Color("94a3b8"))
		for ability in groups[group]:
			var faith_text := "  |  %d Faith" % ability.faith_cost if ability.faith_cost > 0 else ""
			_add_content("%s  |  %d AP%s  |  Cooldown %d" % [ability.display_name, ability.ap_cost, faith_text, int(player.ability_cooldowns.get(ability.id, 0))], Color("f8fafc"), 16)
			_add_content(ability.description, Color("94a3b8"))


func _build_equipment(player: CombatantState, show_actions: bool) -> void:
	_add_content("EQUIPPED", Color("38bdf8"), 15)
	for entry in [["Weapon Slot 1", 0], ["Weapon Slot 2", 3], ["Armor", 1]]:
		var item = player.equipped_items.get(entry[1])
		_add_content("%s: %s" % [entry[0], item.display_name if item != null else "Empty"])
	_add_content("AVAILABLE EQUIPMENT", Color("38bdf8"), 15)
	for item in player.equipment_inventory:
		if item != null:
			_add_item(player, item, show_actions)


func _build_inventory(player: CombatantState) -> void:
	_add_content("BACKPACK", Color("38bdf8"), 15)
	for item in player.equipment_inventory:
		if item != null:
			_add_item(player, item, false)


func _add_item(player: CombatantState, item, show_actions: bool) -> void:
	_add_content(item.display_name, Color("f8fafc"), 16)
	_add_content(item.description, Color("94a3b8"))
	if show_actions:
		var row := HBoxContainer.new()
		content_list.add_child(row)
		if item.slot == 1:
			_add_action(row, "Armor locked", item, -1, true)
		else:
			_add_action(row, _action_text(player, item, 0), item, 0, changes_locked or player.ap < 1)
			if not _is_two_handed(item):
				_add_action(row, _action_text(player, item, 3), item, 3, changes_locked or player.ap < 1)
	content_list.add_child(HSeparator.new())


func _add_action(row: HBoxContainer, text: String, item, slot: int, disabled: bool) -> void:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.pressed.connect(func(): equipment_change_requested.emit(item, slot))
	row.add_child(button)


func _action_text(player: CombatantState, item, slot: int) -> String:
	var hand := 1 if slot == 0 else 2
	if player.equipped_items.get(slot) == item:
		return "Unequip Hand %d - 1 AP" % hand
	if _is_two_handed(item):
		return "Equip W1+W2 - 1 AP"
	return "Equip Hand %d - 1 AP" % hand


func _is_two_handed(item) -> bool:
	if item == null or item.weapon_attack == null:
		return false
	for trait_data in item.weapon_attack.traits:
		if trait_data != null and trait_data.id == "two_handed":
			return true
	return false


func _add_summary(text: String, size: int = 0, color: Color = Color("cbd5e1")) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	if size > 0:
		label.add_theme_font_size_override("font_size", size)
	summary.add_child(label)


func _add_content(text: String, color: Color = Color("cbd5e1"), size: int = 0) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	if size > 0:
		label.add_theme_font_size_override("font_size", size)
	content_list.add_child(label)


func _clear(container: Control) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func close() -> void:
	visible = false
	closed.emit()
