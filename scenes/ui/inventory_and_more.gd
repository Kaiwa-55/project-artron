extends "res://scenes/ui/character_panel.gd"

signal item_use_requested(item)

const InventoryViewScript := preload("res://scenes/ui/inventory_view.gd")
const UITheme := preload("res://scenes/ui/artron_ui_theme.gd")
const SLOT_NAMES := EquipmentSystem.SLOT_NAMES
var inventory_view: PanelContainer
var equipment_view: HBoxContainer
var profile_view: HBoxContainer
var equipment_entries: VBoxContainer
var equipment_slots: VBoxContainer
var equipment_action_bar: VBoxContainer
var equipment_search: LineEdit
var equipment_name: Label
var equipment_detail: Label
var equipment_hint: Label
var profile_abilities: VBoxContainer
var defense_labels: Dictionary = {}
var selected_entry
var exit_button: Button
var use_button: Button


func _ready() -> void:
	inventory_view = InventoryViewScript.new()
	add_child(inventory_view)
	inventory_view.entry_selected.connect(_select_entry)
	inventory_view.use_requested.connect(_use_selected_item)
	inventory_view.tab_requested.connect(set_tab)
	inventory_view.close_requested.connect(close)
	inventory_view.minimum_size_changed.connect(_layout_window, CONNECT_DEFERRED)
	resized.connect(_layout_window)
	tab_buttons = inventory_view.tab_buttons
	exit_button = inventory_view.close_button
	page_title = inventory_view.owner_label
	status_label = inventory_view.resources
	use_button = inventory_view.use_button
	_build_equipment()
	_build_profile()
	content_list = equipment_entries
	set_tab(active_tab)
	_layout_window()


func _layout_window() -> void:
	if inventory_view == null:
		return
	inventory_view.size = Vector2(minf(760, size.x - 12), minf(460, size.y - 12))
	inventory_view.position = (size - inventory_view.size) * 0.5


func set_tab(tab_id: String) -> void:
	if tab_id not in ["abilities", "equipment", "inventory"]:
		return
	active_tab = tab_id
	selected_entry = null
	if inventory_view == null:
		return
	inventory_view.set_active_tab(tab_id)
	equipment_view.visible = tab_id == "equipment"
	profile_view.visible = tab_id == "abilities"
	refresh()


func refresh() -> void:
	if inventory_view == null:
		return
	var player := _get_character()
	if player == null:
		inventory_view.hide()
		return
	inventory_view.show()
	if selected_entry != null and not ((selected_entry is ItemStack and player.item_inventory.has(selected_entry)) or (selected_entry is EquipmentData and player.equipment_inventory.has(selected_entry))):
		selected_entry = null
	inventory_view.display(player, selected_entry, changes_locked or not item_use_requested.has_connections())
	page_title.text = player.display_name + " / " + {"abilities": "Character", "equipment": "Equipment", "inventory": "Inventory"}[active_tab]
	page_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.text = "HP %d/%d  |  Mana %d/%d  |  AP %d/%d  |  Speed %.1f ft" % [player.hp, player.max_hp, player.mana, player.max_mana, player.ap, player.effective_max_ap, player.get_effective_speed()]
	_render_equipment(player)
	_render_profile(player)


func _build_equipment() -> void:
	equipment_view = _body()
	equipment_view.name = "Equipment"
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_view.add_child(left)
	equipment_search = LineEdit.new()
	equipment_search.placeholder_text = "Search equipment..."
	equipment_search.text_changed.connect(func(_text): _render_equipment_entries(_get_character()))
	left.add_child(equipment_search)
	equipment_entries = _scroll_column(left)
	var right := _card_column(equipment_view)
	var detail_column := _scroll_column(right)
	equipment_name = _label("Select equipment", 14)
	detail_column.add_child(equipment_name)
	equipment_detail = _label("", 11)
	detail_column.add_child(equipment_detail)
	equipment_hint = _label("", 10, inventory_view.MUTED)
	detail_column.add_child(equipment_hint)
	detail_column.add_child(_label("CURRENT LOADOUT", 9, inventory_view.GOLD))
	equipment_slots = VBoxContainer.new()
	detail_column.add_child(equipment_slots)
	equipment_action_bar = VBoxContainer.new()
	right.add_child(equipment_action_bar)


func _render_equipment(player: CombatantState) -> void:
	_clear(equipment_slots)
	for slot in EquipmentSystem.LOADOUT_SLOTS:
		var item = player.equipped_items.get(slot)
		var button: Button = inventory_view._button("%s: %s" % [SLOT_NAMES[slot], item.display_name if item != null else "Empty"], _select_entry.bind(item))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.disabled = item == null
		equipment_slots.add_child(button)
	_render_equipment_entries(player)
	_render_equipment_details(player)


func _render_equipment_entries(player: CombatantState) -> void:
	_clear(equipment_entries)
	if player == null:
		return
	var query := equipment_search.text.strip_edges().to_lower()
	for item in player.equipment_inventory:
		if item == null or (not query.is_empty() and not (item.display_name + " " + item.description).to_lower().contains(query)):
			continue
		var equipped: bool = player.equipped_items.values().has(item)
		var button: Button = inventory_view._button(item.display_name + ("  [Equipped]" if equipped else ""), _select_entry.bind(item))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.custom_minimum_size.y = 34
		if item == selected_entry:
			button.add_theme_stylebox_override("normal", inventory_view._style(UITheme.SELECTED_BACKGROUND, UITheme.GOLD, UITheme.BUTTON_PADDING))
		equipment_entries.add_child(button)
	if equipment_entries.get_child_count() == 0:
		equipment_entries.add_child(_label("No equipment matches." if not query.is_empty() else "No equipment in your pack.", 11, inventory_view.MUTED))


func _render_equipment_details(player: CombatantState) -> void:
	_clear(equipment_action_bar)
	var item := selected_entry as EquipmentData
	equipment_name.text = item.display_name if item != null else "Select equipment"
	equipment_detail.text = item.description if item != null else "Choose gear from the list or your equipped slots."
	equipment_hint.text = "Viewing only" if changes_locked else ("Hand changes cost 1 AP. Worn gear is locked in combat." if combat_system != null else "Equipment changes are free outside combat.")
	if item == null:
		return
	equipment_detail.text += "\nFortitude %+d / Reflex %+d / Will %+d" % [item.fortitude_bonus, item.reflex_bonus, item.will_bonus]
	var slots: Array = [0] if _is_two_handed(item) else EquipmentSystem.new().get_valid_slots(item)
	for slot in slots:
		var equipped: bool = player.equipped_items.get(slot) == item
		var caption: String = ("Unequip " if equipped else "Equip ") + ("Both Hands" if _is_two_handed(item) else SLOT_NAMES[slot])
		if combat_system != null and (slot == 0 or slot == 3):
			caption += " - 1 AP"
		var button: Button = inventory_view._button(caption, _request_equipment_change.bind(item, slot))
		button.disabled = changes_locked or (combat_system != null and (slot != 0 and slot != 3 or player.ap < 1))
		equipment_action_bar.add_child(button)


func _request_equipment_change(item: EquipmentData, slot: int) -> void:
	var player := _get_character()
	if player == null or changes_locked or not player.equipment_inventory.has(item):
		return
	if combat_system != null and (slot != 0 and slot != 3 or player.ap < 1):
		return
	equipment_change_requested.emit(item, slot)
	refresh()


func _build_profile() -> void:
	profile_view = _body()
	profile_view.name = "Character"
	summary = _scroll_column(_card_column(profile_view))
	profile_abilities = _scroll_column(_card_column(profile_view))


func _render_profile(player: CombatantState) -> void:
	_clear(summary)
	_clear(profile_abilities)
	defense_labels.clear()
	summary.add_child(_label("LEVEL %d / %s" % [player.level, player.class_display_name], 14, inventory_view.GOLD))
	summary.add_child(_label("Ancestry: " + player.ancestry_display_name, 11))
	var progression := ProgressionSystem.new().progression_data
	var xp := maxi(0, player.experience - progression.get_cumulative_xp_for_level(player.level))
	summary.add_child(_label("Experience %d / %d | Class DC %d" % [xp, progression.get_xp_span_for_level(player.level), player.class_dc], 10, inventory_view.MUTED))
	summary.add_child(_label("ATTRIBUTES", 9, inventory_view.GOLD))
	var attributes := GridContainer.new()
	attributes.columns = 3
	attributes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attributes.add_theme_constant_override("h_separation", 12)
	summary.add_child(attributes)
	for attribute in [["STR", player.strength], ["DEX", player.dexterity], ["CON", player.constitution], ["INT", player.intelligence], ["WIS", player.wisdom], ["CHA", player.charisma]]:
		var value := _label("%s  %d" % attribute, 12)
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		attributes.add_child(value)
	summary.add_child(_label("SKILL PROFICIENCIES", 9, inventory_view.GOLD))
	var proficiencies := GridContainer.new()
	proficiencies.name = "SkillProficiencies"
	proficiencies.columns = 1
	proficiencies.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_child(proficiencies)
	for entry in [["Stealth", "stealth"], ["Perception", "perception"], ["Athletics", "athletics"], ["Acrobatics", "acrobatics"], ["Survival", "survival"]]:
		var proficiency := _label("%s  %d" % [entry[0], player.get_skill_rank(entry[1])], 11)
		proficiency.autowrap_mode = TextServer.AUTOWRAP_OFF
		proficiencies.add_child(proficiency)
	summary.add_child(_label("DEFENSES", 9, inventory_view.GOLD))
	var values := _displayed_defenses(player)
	for index in range(3):
		var caption: String = ["Fortitude", "Reflex", "Will"][index]
		var label := _label("%s  %d" % [caption, values[index]], 11)
		defense_labels[caption] = label
		summary.add_child(label)
	if player.max_faith > 0:
		summary.add_child(_label("Faith %d/%d | Temporary +%d" % [player.faith, player.max_faith, player.temporary_faith], 11))
	if player.max_finishing_gauge > 0:
		summary.add_child(_label("Finishing Gauge %d/%d" % [player.finishing_gauge, player.max_finishing_gauge], 11))
	summary.add_child(_label("Initiative %+d" % player.initiative_bonus, 11))
	var resistances: Array[String] = []
	var keys := player.damage_resistances.keys()
	for key in player.equipment_damage_resistances:
		if not keys.has(key):
			keys.append(key)
	for key in keys:
		resistances.append("%s %d" % [String(key).capitalize(), player.get_damage_resistance(key)])
	summary.add_child(_label("Resistance: " + (", ".join(resistances) if not resistances.is_empty() else "None"), 10, inventory_view.MUTED))
	summary.add_child(_label("Immunity: " + _names(player.damage_immunities + player.status_immunities), 10, inventory_view.MUTED))
	summary.add_child(_label("Traits: " + _names(player.active_traits), 10, inventory_view.MUTED))
	var statuses: Array = []
	for effect in player.effects:
		if effect != null and effect.data != null:
			statuses.append(effect.data.display_name)
	summary.add_child(_label("Status: " + _names(statuses), 10, inventory_view.MUTED))
	var abilities: Array = combat_system.ability_system.get_active_abilities(player) if combat_system != null else player.available_abilities
	profile_abilities.add_child(_label("ABILITIES", 9, inventory_view.GOLD))
	if abilities.is_empty():
		profile_abilities.add_child(_label("No abilities learned.", 11, inventory_view.MUTED))
	for ability in abilities:
		if ability == null:
			continue
		profile_abilities.add_child(_label(ability.display_name, 12, inventory_view.GOLD))
		var kind := "Passive" if ability.is_passive else ("Reaction" if ability.reaction_only else "Active")
		var costs := "%s | %d AP" % [kind, ability.ap_cost]
		if player.equipped_abilities.has(ability.id):
			costs += " | Equipped"
		if ability.faith_cost > 0:
			costs += " | %d Faith" % ability.faith_cost
		if ability.finishing_gauge_cost > 0:
			costs += " | %d Gauge" % ability.finishing_gauge_cost
		costs += " | CD %d" % int(player.ability_cooldowns.get(ability.id, 0))
		profile_abilities.add_child(_label(costs, 9, inventory_view.MUTED))
		profile_abilities.add_child(_label(ability.description, 11))
		profile_abilities.add_child(HSeparator.new())
	profile_abilities.add_child(_label("SKILLS", 9, inventory_view.GOLD))
	if player.available_skills.is_empty():
		profile_abilities.add_child(_label("No skills learned.", 11, inventory_view.MUTED))
	for skill in player.available_skills:
		if skill != null:
			profile_abilities.add_child(_label(skill.display_name, 12, inventory_view.GOLD))
			profile_abilities.add_child(_label(skill.description, 11))


func _displayed_defenses(player: CombatantState) -> Array:
	if combat_system != null:
		return [combat_system.defense_system.get_defense(player, DefenseTypes.Type.FORTITUDE), combat_system.defense_system.get_defense(player, DefenseTypes.Type.REFLEX), combat_system.defense_system.get_defense(player, DefenseTypes.Type.WILL)]
	var bonus := AbilitySystem.new().get_passive_defense_bonus(player)
	return [player.fortitude + bonus, player.reflex + bonus, player.will + bonus]


func _select_entry(entry) -> void:
	selected_entry = entry
	if active_tab == "inventory":
		inventory_view.select(entry)
	elif active_tab == "equipment":
		_render_equipment(_get_character())


func _use_selected_item() -> void:
	var player := _get_character()
	if changes_locked or player == null or not selected_entry is ItemStack or not player.item_inventory.has(selected_entry):
		return
	if selected_entry.item != null and selected_entry.quantity > 0 and selected_entry.item.category == ItemData.Category.CONSUMABLE:
		item_use_requested.emit(selected_entry.item)


func get_visible_entry_count() -> int:
	var player := _get_character()
	if player == null:
		return 0
	return player.equipment_inventory.size() if active_tab == "equipment" else player.item_inventory.size()


func _body() -> HBoxContainer:
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	inventory_view.column.add_child(body)
	return body


func _card_column(parent: Node) -> VBoxContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.x = 190
	card.add_theme_stylebox_override("panel", inventory_view._style(UITheme.CARD_BACKGROUND, UITheme.CARD_BORDER, UITheme.CARD_PADDING))
	parent.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	return column


func _scroll_column(parent: Node) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	scroll.add_child(column)
	return column


func _label(text: String, font_size: int, color: Color = UITheme.TEXT) -> Label:
	var label: Label = inventory_view._label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _names(values: Array) -> String:
	var names: Array[String] = []
	for value in values:
		if value != null:
			names.append(str(value) if value is String else String(value.display_name))
	return ", ".join(names) if not names.is_empty() else "None"
