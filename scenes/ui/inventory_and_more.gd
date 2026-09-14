extends "res://scenes/ui/character_panel.gd"

signal item_use_requested(item)

const ItemPreviewScene := preload("res://scenes/ui/ItemWhenSelectedPanel.tscn")
const PAGE_SIZE := 16
const CLASS_TRAIT_IDS := ["assassin", "arcanist", "devotee", "martial_artist"]
const ANCESTRY_TRAIT_IDS := ["human"]
const HAND_1 := 0
const ARMOR := 1
const HAND_2 := 3

var current_page := 0
var selected_entry
var equipment_view: Control
var profile_view: Control
var item_grid: GridContainer
var profile_ability_slots: Array[Control] = []
var profile_runtime_ability_cards: Array[Control] = []
var profile_ability_column: VBoxContainer
var profile_ability_scroll: ScrollContainer
var profile_previous_button: BaseButton
var profile_next_button: BaseButton
var profile_page_number: Label
var profile_page_count := 1
var exit_button: BaseButton
var page_number: Label
var previous_button: BaseButton
var next_button: BaseButton
var equipment_slots: Dictionary = {}
var detail_label: Label
var use_button: Button
var equipment_action_bar: HBoxContainer
var overlay: Control
var item_preview: PanelContainer
var _visible_entries: Array = []


func _ready() -> void:
	_bind_authored_ui()
	_connect_navigation()
	_create_runtime_overlays()
	set_tab(active_tab)


func _bind_authored_ui() -> void:
	var panel: Control = get_node_or_null("PanelContainer")
	if panel == null:
		push_error("InventoryAndMore requires PanelContainer.")
		return
	exit_button = get_node_or_null("ExitButton")
	if exit_button != null:
		var window_chrome := Control.new()
		window_chrome.name = "WindowChrome"
		window_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
		window_chrome.z_index = 20
		panel.add_child(window_chrome)
		exit_button.reparent(window_chrome, false)
		exit_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		exit_button.offset_left = -34.0
		exit_button.offset_top = 5.0
		exit_button.offset_right = -25.0
		exit_button.offset_bottom = 14.0
		exit_button.z_index = 20
	equipment_view = panel.get_node_or_null("EquiptMentMargincontainer")
	profile_view = panel.get_node_or_null("ProfileMargincontainer")
	if profile_view == null:
		profile_view = panel.get_node_or_null("ProfileMargincontainer2")
	if profile_view == null:
		profile_view = panel.find_child("ProfileMargincontainer*", false, false) as Control
	if equipment_view == null or profile_view == null:
		push_error("InventoryAndMore requires Equipment and Profile containers.")
		return
	item_grid = equipment_view.find_child("GridContainer", true, false) as GridContainer
	var first_ability: Control = profile_view.find_child("AbilityContainer", true, false) as Control
	if item_grid == null or first_ability == null:
		push_error("InventoryAndMore requires its Item grid and Profile Ability cards.")
		return
	var ability_column: VBoxContainer = first_ability.get_parent() as VBoxContainer
	var ability_panel: Control = ability_column.get_parent()
	profile_ability_column = ability_column
	profile_ability_slots = [
		ability_column.get_node_or_null("AbilityContainer"),
		ability_column.get_node_or_null("AbilityContainer2"),
		ability_column.get_node_or_null("AbilityContainer3"),
	]
	profile_ability_slots = profile_ability_slots.filter(func(slot): return slot != null)
	_prepare_ability_cards()
	_prepare_ability_scroll(ability_panel, ability_column)
	var profile_pager: Control = ability_panel.get_node_or_null("HBoxContainer")
	if profile_pager != null:
		profile_pager.visible = false
		profile_previous_button = profile_pager.get_node_or_null("ButtonPrevious")
		profile_page_number = profile_pager.get_node_or_null("Label")
		profile_next_button = profile_pager.get_node_or_null("ButtonNext")
	var pager := item_grid.get_parent().get_node("HBoxContainer")
	previous_button = pager.get_node("ButtonPrevious")
	page_number = pager.get_node("Label")
	next_button = pager.get_node("ButtonNext")
	page_title = get_node("PanelContainer/EquiptMentMargincontainer/EquiptMentcontainer/VBoxContainer/HBoxContainer2/NinePatchRect3/Label")
	equipment_slots = {
		HAND_1: get_node("PanelContainer/EquiptMentMargincontainer/EquiptMentcontainer/VBoxContainer/HBoxContainer/EquiptmentSlot/EquiptmentSlot/VBoxContainer2/Main Hand"),
		ARMOR: get_node("PanelContainer/EquiptMentMargincontainer/EquiptMentcontainer/VBoxContainer/HBoxContainer/EquiptmentSlot/EquiptmentSlot/VBoxContainer/Body"),
		HAND_2: get_node("PanelContainer/EquiptMentMargincontainer/EquiptMentcontainer/VBoxContainer/HBoxContainer/EquiptmentSlot/EquiptmentSlot/VBoxContainer3/Off Hand"),
	}


func _connect_navigation() -> void:
	if equipment_view == null or profile_view == null or item_grid == null:
		return
	if exit_button != null:
		_connect_once(exit_button, close)
	for view in [equipment_view, profile_view]:
		var nav := _find_navigation(view)
		if nav == null:
			continue
		_connect_once(nav.get_node("CharacterBoxContainer/CharacterButton"), set_tab.bind("abilities"))
		_connect_once(nav.get_node("InventoryBoxContainer/InventoryButton"), set_tab.bind("inventory"))
		_connect_once(nav.get_node("EquiptmentBoxContainer/EquiptmentButton"), set_tab.bind("equipment"))
		_connect_once(nav.get_node("CraftBoxContainer2/CraftButton"), set_tab.bind("craft"))
	_connect_once(previous_button, _change_page.bind(-1))
	_connect_once(next_button, _change_page.bind(1))
	if profile_previous_button != null:
		_connect_once(profile_previous_button, _change_page.bind(-1))
	if profile_next_button != null:
		_connect_once(profile_next_button, _change_page.bind(1))
	for slot in equipment_slots:
		_make_slot_interactive(equipment_slots[slot], int(slot))


func _create_runtime_overlays() -> void:
	# Compatibility mirrors keep the CharacterPanel API stable for existing callers.
	summary = VBoxContainer.new()
	summary.name = "ApiSummary"
	summary.visible = false
	add_child(summary)
	content_list = VBoxContainer.new()
	content_list.name = "ApiContent"
	content_list.visible = false
	add_child(content_list)
	overlay = Control.new()
	overlay.name = "RuntimeOverlay"
	overlay.set_anchors_preset(Control.PRESET_CENTER)
	overlay.position = Vector2(-212.5, -125)
	overlay.size = Vector2(425, 250)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	status_label = Label.new()
	status_label.name = "SelectionDetails"
	status_label.position = Vector2(10, 222)
	status_label.size = Vector2(190, 22)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status_label.add_theme_font_size_override("font_size", 7)
	status_label.add_theme_color_override("font_color", Color("d9c28c"))
	status_label.visible = false
	overlay.add_child(status_label)
	detail_label = status_label
	use_button = Button.new()
	use_button.name = "UseSelectedButton"
	use_button.text = "USE"
	use_button.position = Vector2(372, 218)
	use_button.size = Vector2(42, 22)
	use_button.add_theme_font_size_override("font_size", 7)
	use_button.visible = false
	use_button.pressed.connect(_use_selected_item)
	overlay.add_child(use_button)
	equipment_action_bar = HBoxContainer.new()
	equipment_action_bar.name = "EquipmentActions"
	equipment_action_bar.position = Vector2(5, 216)
	equipment_action_bar.size = Vector2(190, 28)
	equipment_action_bar.add_theme_constant_override("separation", 4)
	equipment_action_bar.visible = false
	overlay.add_child(equipment_action_bar)
	item_preview = get_node_or_null("PanelContainer2")
	if item_preview == null:
		item_preview = ItemPreviewScene.instantiate()
		add_child(item_preview)
	item_preview.visible = false
	tab_buttons = {}
	var nav := _find_navigation(equipment_view)
	if nav != null:
		tab_buttons = {
			"abilities": nav.get_node("CharacterBoxContainer/CharacterButton"),
			"inventory": nav.get_node("InventoryBoxContainer/InventoryButton"),
			"equipment": nav.get_node("EquiptmentBoxContainer/EquiptmentButton"),
		}


func setup(system, target_id: String = "player") -> void:
	combat_system = system
	standalone_character = null
	combatant_id = target_id
	set_tab(active_tab)


func setup_standalone(player: CombatantState, initial_tab: String = "inventory") -> void:
	combat_system = null
	standalone_character = player
	changes_locked = true
	set_tab(initial_tab)


func set_tab(tab_id: String) -> void:
	if tab_id not in ["abilities", "equipment", "inventory", "craft"]:
		return
	active_tab = tab_id
	current_page = 0
	if profile_ability_scroll != null:
		profile_ability_scroll.scroll_vertical = 0
	selected_entry = null
	_update_equipment_actions(null)
	if equipment_view != null:
		equipment_view.visible = tab_id != "abilities"
	if profile_view != null:
		profile_view.visible = tab_id == "abilities"
		var profile_content := profile_view.get_node_or_null("Profilecontainer")
		if profile_content != null:
			profile_content.visible = tab_id == "abilities"
	refresh()


func refresh() -> void:
	if not is_node_ready() or item_grid == null:
		return
	var player := _get_character()
	if player == null:
		_clear_visuals()
		return
	_update_profile(player)
	_update_equipment_slots(player)
	_visible_entries = _entries_for_tab(player)
	_render_page(player)
	_build_api_mirror(player)


func _get_character() -> CombatantState:
	if standalone_character != null:
		return standalone_character
	if combat_system == null or combat_system.get_combat_state() == null:
		return null
	return combat_system.get_combat_state().get_combatant(combatant_id)


func _entries_for_tab(player: CombatantState) -> Array:
	match active_tab:
		"equipment": return player.equipment_inventory.duplicate()
		"inventory":
			var result: Array = []
			for stack in player.item_inventory:
				result.append(stack)
			for item in player.equipment_inventory:
				result.append(item)
			return result
		"craft": return []
	return _ability_entries(player)


func _render_page(player: CombatantState) -> void:
	if active_tab == "abilities":
		_render_ability_page(player)
		return
	var max_page := maxi(0, ceili(float(_visible_entries.size()) / PAGE_SIZE) - 1)
	current_page = clampi(current_page, 0, max_page)
	var active_grid := item_grid
	var active_pager := active_grid.get_parent().get_node("HBoxContainer")
	var active_previous: BaseButton = active_pager.get_node("ButtonPrevious")
	var active_page_number: Label = active_pager.get_node("Label")
	var active_next: BaseButton = active_pager.get_node("ButtonNext")
	active_page_number.text = "%d / %d" % [current_page + 1, max_page + 1]
	active_previous.disabled = current_page == 0
	active_next.disabled = current_page >= max_page
	page_title.text = _title_for_tab()
	var first := current_page * PAGE_SIZE
	var cells := active_grid.get_children()
	for index in range(cells.size()):
		var entry_index := first + index
		_render_cell(cells[index], _visible_entries[entry_index] if entry_index < _visible_entries.size() else null)
	if active_tab == "craft":
		detail_label.text = "Crafting API is not available yet"
	elif _visible_entries.is_empty():
		detail_label.text = "No entries"
	elif selected_entry == null:
		detail_label.text = "Select an item to view details"
	use_button.visible = active_tab == "inventory" and _is_item_stack(selected_entry) and not changes_locked
	_update_equipment_actions(selected_entry)


func _ability_entries(player: CombatantState) -> Array:
	if combat_system != null:
		return combat_system.ability_system.get_active_abilities(player)
	return player.available_abilities.duplicate()


func _render_ability_page(player: CombatantState) -> void:
	var groups := _group_abilities(player, _visible_entries)
	profile_page_count = 1
	current_page = 0
	if profile_page_number != null:
		profile_page_number.text = "Scroll"
	if profile_previous_button != null:
		profile_previous_button.disabled = true
	if profile_next_button != null:
		profile_next_button.disabled = true
	_clear_runtime_ability_cards()
	var keys := ["class", "ancestry", "basic"]
	for index in range(profile_ability_slots.size()):
		var list: Array = groups[keys[index]]
		_render_ability_group(profile_ability_slots[index], list, player)
	detail_label.text = _profile_summary(player) if selected_entry == null else "%s: %s" % [_entry_name(selected_entry), _entry_description(selected_entry)]
	use_button.visible = false


func _group_abilities(player: CombatantState, abilities: Array) -> Dictionary:
	var groups := {"class": [], "ancestry": [], "basic": []}
	for ability in abilities:
		if ability == null:
			continue
		var requirements: Array[String] = ability.required_trait_ids
		if (not player.ancestry_id.is_empty() and requirements.has(player.ancestry_id)) or _has_any(requirements, ANCESTRY_TRAIT_IDS):
			groups["ancestry"].append(ability)
		elif (not player.class_id.is_empty() and requirements.has(player.class_id)) or _has_any(requirements, CLASS_TRAIT_IDS):
			groups["class"].append(ability)
		else:
			groups["basic"].append(ability)
	return groups


func _render_ability_card(slot: Control, ability, player: CombatantState) -> void:
	var old_button := slot.get_node_or_null("AbilityButton")
	if old_button != null:
		slot.remove_child(old_button)
		old_button.queue_free()
	var frame: Control = slot.get_node_or_null("frame")
	if frame != null:
		frame.visible = ability != null
	slot.visible = ability != null
	if ability == null:
		slot.tooltip_text = "No Ability in this category"
		return
	_set_descendant_label(frame, "Name", ability.display_name)
	_set_descendant_label(frame, "Trait", _ability_trait_text(ability))
	_set_descendant_label(frame, "Level", "Level %d" % ability.required_level)
	var button := Button.new()
	button.name = "AbilityButton"
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.mouse_force_pass_scroll_events = true
	var kind := "Passive" if ability.is_passive else ("Reaction" if ability.reaction_only else "Active")
	var costs: Array[String] = []
	if ability.ap_cost > 0:
		costs.append("%d AP" % ability.ap_cost)
	if ability.faith_cost > 0:
		costs.append("%d Faith" % ability.faith_cost)
	if ability.finishing_gauge_cost > 0:
		costs.append("%d Gauge" % ability.finishing_gauge_cost)
	var equipped := " - Equipped" if player.equipped_abilities.has(ability.id) else ""
	_set_descendant_label(frame, "Abilitytype", kind + equipped)
	var detail_parts: Array[String] = []
	if not costs.is_empty():
		detail_parts.append(", ".join(costs))
		if not ability.description.is_empty():
			detail_parts.append(ability.description)
	_set_descendant_label(frame, "Description", " - ".join(detail_parts))
	button.text = ""
	button.pressed.connect(_select_entry.bind(ability))
	slot.add_child(button)


func _prepare_ability_cards() -> void:
	if profile_ability_slots.is_empty():
		return
	var template: Control = profile_ability_slots[0].get_node_or_null("frame")
	if template == null:
		return
	template.custom_minimum_size.y = 48.0
	for index in range(1, profile_ability_slots.size()):
		var slot: Control = profile_ability_slots[index]
		if slot.get_node_or_null("frame") != null:
			continue
		for child in slot.get_children():
			slot.remove_child(child)
			child.queue_free()
		if slot is NinePatchRect:
			slot.texture = null
		var frame_copy: Control = template.duplicate()
		slot.add_child(frame_copy)
		frame_copy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _prepare_ability_scroll(ability_panel: Control, ability_column: VBoxContainer) -> void:
	if ability_panel == null or ability_column == null:
		return
	profile_ability_scroll = ScrollContainer.new()
	profile_ability_scroll.name = "AbilityScroll"
	profile_ability_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	profile_ability_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	profile_ability_scroll.anchor_left = ability_column.anchor_left
	profile_ability_scroll.anchor_top = ability_column.anchor_top
	profile_ability_scroll.anchor_right = ability_column.anchor_right
	profile_ability_scroll.anchor_bottom = 0.97200006
	profile_ability_scroll.offset_left = ability_column.offset_left
	profile_ability_scroll.offset_top = ability_column.offset_top
	profile_ability_scroll.offset_right = ability_column.offset_right
	profile_ability_scroll.offset_bottom = 0.04798889
	ability_panel.add_child(profile_ability_scroll)
	ability_column.reparent(profile_ability_scroll, false)
	ability_column.add_theme_constant_override("separation", 5)
	ability_column.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ability_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _render_ability_group(base_slot: Control, abilities: Array, player: CombatantState) -> void:
	_render_ability_card(base_slot, abilities[0] if not abilities.is_empty() else null, player)
	for index in range(1, abilities.size()):
		var card := _create_runtime_ability_card(base_slot)
		profile_ability_column.add_child(card)
		profile_ability_column.move_child(card, base_slot.get_index() + index)
		profile_runtime_ability_cards.append(card)
		_render_ability_card(card, abilities[index], player)


func _create_runtime_ability_card(base_slot: Control) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "RuntimeAbilityCard"
	card.custom_minimum_size = Vector2(0, 48)
	card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var source_frame: Control = base_slot.get_node_or_null("frame")
	if source_frame == null and not profile_ability_slots.is_empty():
		source_frame = profile_ability_slots[0].get_node_or_null("frame")
	if source_frame != null:
		var frame_copy: Control = source_frame.duplicate()
		card.add_child(frame_copy)
	return card


func _clear_runtime_ability_cards() -> void:
	for card in profile_runtime_ability_cards:
		if is_instance_valid(card):
			card.get_parent().remove_child(card)
			card.queue_free()
	profile_runtime_ability_cards.clear()


func _set_descendant_label(root: Control, node_name: String, value: String) -> void:
	if root == null:
		return
	var label: Label = root.find_child(node_name, true, false) as Label
	if label != null:
		label.text = value


func _ability_trait_text(ability) -> String:
	var names: Array[String] = []
	for trait_data in ability.traits:
		if trait_data != null:
			var trait_name: String = trait_data.display_name if "display_name" in trait_data and not trait_data.display_name.is_empty() else trait_data.id
			names.append(trait_name)
	if names.is_empty():
		for trait_id in ability.required_trait_ids:
			names.append(String(trait_id).capitalize())
	return ", ".join(names) if not names.is_empty() else "Basic"


func _has_any(values: Array[String], candidates: Array) -> bool:
	for candidate in candidates:
		if values.has(candidate):
			return true
	return false


func _render_cell(cell: Control, entry) -> void:
	for child in cell.get_children():
		child.queue_free()
	cell.tooltip_text = ""
	if entry == null:
		return
	var button := Button.new()
	button.name = "EntryButton"
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.text = _entry_short_name(entry)
	button.add_theme_font_size_override("font_size", 6)
	button.pressed.connect(_select_entry.bind(entry))
	button.mouse_entered.connect(_show_item_preview.bind(entry, button))
	button.mouse_exited.connect(_hide_item_preview)
	cell.add_child(button)
	var icon := _entry_icon(entry)
	if icon != null:
		button.icon = icon
		button.expand_icon = true
		button.icon_max_width = 28
	var quantity := _entry_quantity(entry)
	if quantity > 1:
		var count := Label.new()
		count.text = str(quantity)
		count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count.position = Vector2(-13, -12)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.add_theme_font_size_override("font_size", 7)
		cell.add_child(count)


func _select_entry(entry) -> void:
	selected_entry = entry
	detail_label.text = "%s — %s" % [_entry_name(entry), _entry_description(entry)]
	use_button.visible = active_tab == "inventory" and _is_item_stack(entry) and not changes_locked
	_update_equipment_actions(entry)


func _show_item_preview(entry, source: Control) -> void:
	if item_preview == null or entry == null:
		return
	item_preview.setup(entry)
	item_preview.visible = true
	var preview_size: Vector2 = item_preview.size
	var viewport_size: Vector2 = get_viewport_rect().size
	var position: Vector2 = source.global_position + Vector2(source.size.x + 6.0, 0.0)
	if position.x + preview_size.x > viewport_size.x:
		position.x = source.global_position.x - preview_size.x - 6.0
	if position.y + preview_size.y > viewport_size.y:
		position.y = viewport_size.y - preview_size.y - 4.0
	item_preview.global_position = position.max(Vector2(4.0, 4.0))


func _hide_item_preview() -> void:
	if item_preview != null:
		item_preview.visible = false


func _use_selected_item() -> void:
	if changes_locked or not _is_item_stack(selected_entry) or selected_entry.item == null:
		return
	item_use_requested.emit(selected_entry.item)


func _make_slot_interactive(panel: Control, slot: int) -> void:
	var button := Button.new()
	button.name = "SlotButton"
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.add_theme_font_size_override("font_size", 6)
	button.pressed.connect(_activate_equipment_slot.bind(slot))
	panel.add_child(button)


func _activate_equipment_slot(slot: int) -> void:
	var player := _get_character()
	if player == null:
		return
	var item = player.equipped_items.get(slot)
	if item == null:
		return
	_select_entry(item)


func _update_equipment_actions(entry) -> void:
	if equipment_action_bar == null:
		return
	for child in equipment_action_bar.get_children():
		equipment_action_bar.remove_child(child)
		child.queue_free()
	equipment_action_bar.visible = false
	if not entry is EquipmentData or active_tab not in ["inventory", "equipment"]:
		return
	var player := _get_character()
	if player == null:
		return
	var disabled := changes_locked or player.ap < 1
	if entry.slot == EquipmentData.Slot.ARMOR:
		_add_equipment_action(_body_action_text(player, entry), entry, ARMOR, disabled or combat_system != null)
	elif _is_two_handed(entry):
		_add_equipment_action(_both_hands_action_text(player, entry), entry, HAND_1, disabled)
	else:
		_add_equipment_action(_action_text(player, entry, HAND_1), entry, HAND_1, disabled)
		_add_equipment_action(_action_text(player, entry, HAND_2), entry, HAND_2, disabled)
	equipment_action_bar.visible = equipment_action_bar.get_child_count() > 0


func _add_equipment_action(caption: String, item: EquipmentData, slot: int, disabled: bool) -> void:
	var button := Button.new()
	button.text = caption
	button.disabled = disabled
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 6)
	button.pressed.connect(_request_equipment_change.bind(item, slot))
	equipment_action_bar.add_child(button)


func _request_equipment_change(item: EquipmentData, slot: int) -> void:
	if changes_locked:
		return
	equipment_change_requested.emit(item, slot)
	refresh()
	_update_equipment_actions(item)


func _body_action_text(player: CombatantState, item: EquipmentData) -> String:
	return "Unequip Body - 1 AP" if player.equipped_items.get(ARMOR) == item else "Equip Body - 1 AP"


func _both_hands_action_text(player: CombatantState, item: EquipmentData) -> String:
	return "Unequip Both - 1 AP" if player.equipped_items.get(HAND_1) == item else "Equip Both Hands - 1 AP"


func _update_equipment_slots(player: CombatantState) -> void:
	for slot in equipment_slots:
		var button: Button = equipment_slots[slot].get_node_or_null("SlotButton")
		if button == null:
			continue
		var item = player.equipped_items.get(slot)
		button.text = _entry_short_name(item) if item != null else _slot_name(int(slot))
		button.tooltip_text = _entry_name(item) if item != null else "Empty %s" % _slot_name(int(slot))
		button.disabled = changes_locked or (slot == ARMOR and combat_system != null)


func _update_profile(player: CombatantState) -> void:
	if profile_view == null:
		return
	var base := "PanelContainer/%s/Profilecontainer/VBoxContainer" % profile_view.name
	var detail := base + "/HBoxContainer/CharacterDetail"
	_set_label(base + "/HBoxContainer2/NinePatchRect3/Label", "Profile")
	var portrait: TextureRect = get_node_or_null(detail + "/CharacterImage")
	if portrait != null:
		portrait.texture = player.token_texture
	_set_label(detail + "/VBox/Name", player.display_name)
	_set_label(detail + "/VBox/Ancestry", "Ancestry: %s" % player.ancestry_display_name)
	_set_label(detail + "/VBox/Class", "Class: %s" % player.class_display_name)
	_set_label(detail + "/VBox/Class DC", "Class DC: %d" % player.class_dc)
	_set_label(detail + "/VBox/Level/Level", "Lv.%d" % player.level)
	var progression := ProgressionSystem.new().progression_data
	var level_start: int = progression.get_cumulative_xp_for_level(player.level)
	var level_span: int = progression.get_xp_span_for_level(player.level)
	_set_bar(detail + "/VBox/Level/LevelProgressBar", player.experience - level_start, level_span)
	_set_label(detail + "/VBox/Traits", "Traits: %s" % _named_resources(player.active_traits))
	_set_label(detail + "/Hp/Label", "HP %d / %d" % [player.hp, player.max_hp])
	_set_bar(detail + "/Hp/ProgressBar", player.hp, player.max_hp)
	if player.max_faith > 0:
		_set_label(detail + "/Mana/Label", "Faith %d / %d" % [player.get_total_faith(), player.max_faith])
		_set_bar(detail + "/Mana/ProgressBar", player.get_total_faith(), player.max_faith)
	else:
		_set_label(detail + "/Mana/Label", "Mana %d / %d" % [player.mana, player.max_mana])
		_set_bar(detail + "/Mana/ProgressBar", player.mana, player.max_mana)
	_set_label(detail + "/Other_Stat/Speed", "Speed: %.1f ft" % player.get_effective_speed())
	_set_label(detail + "/Other_Stat/Initiative", "Initiative: %+d" % player.initiative_bonus)
	_set_label(detail + "/Other_Stat/Resistance", "Resistance: %s" % _dictionary_values(player.damage_resistances, player.equipment_damage_resistances))
	_set_label(detail + "/Other_Stat/Immune", "Immune: %s" % _string_values(player.damage_immunities, player.status_immunities))
	var passive_defense_bonus := AbilitySystem.new().get_passive_defense_bonus(player)
	var fortitude: int = combat_system.defense_system.get_defense(player, DefenseTypes.Type.FORTITUDE) if combat_system != null else player.fortitude + player.equipment_fortitude_bonus + passive_defense_bonus
	var reflex: int = combat_system.defense_system.get_defense(player, DefenseTypes.Type.REFLEX) if combat_system != null else player.reflex + player.equipment_reflex_bonus + passive_defense_bonus
	var will: int = combat_system.defense_system.get_defense(player, DefenseTypes.Type.WILL) if combat_system != null else player.will + player.equipment_will_bonus + passive_defense_bonus
	_set_label(detail + "/Defense/Fortitude/Value", str(fortitude))
	_set_label(detail + "/Defense/Reflex/Value", str(reflex))
	_set_label(detail + "/Defense/Will/Value", str(will))
	for entry in [["Str", player.strength], ["Con", player.constitution], ["Dex", player.dexterity], ["Wis", player.wisdom], ["Int", player.intelligence], ["Cha", player.charisma]]:
		_set_label(detail + "/Attribute/%s/Value" % entry[0], str(entry[1]))
	var defense_base := "PanelContainer/EquiptMentMargincontainer/EquiptMentcontainer/VBoxContainer/HBoxContainer/EquiptmentSlot/DefenseValue/HBoxContainer/VBoxContainer"
	_set_value_text(defense_base + "/FortitdeContainer/HBoxContainer/Value", "Fortitude", player.fortitude + player.equipment_fortitude_bonus)
	_set_value_text(defense_base + "/ReflexContainer2/HBoxContainer/Value", "Reflex", player.reflex + player.equipment_reflex_bonus)
	_set_value_text(defense_base + "/WillContainer3/HBoxContainer/Value", "Will", player.will + player.equipment_will_bonus)


func _set_value_text(path: String, caption: String, value: int) -> void:
	var label: Label = get_node_or_null(path)
	if label != null:
		label.text = "%s:%d" % [caption, value]


func _set_label(path: String, value: String) -> void:
	var label: Label = get_node_or_null(path)
	if label != null:
		label.text = value


func _set_bar(path: String, value: float, maximum: float) -> void:
	var bar: ProgressBar = get_node_or_null(path)
	if bar == null:
		return
	bar.max_value = maxf(1.0, maximum)
	bar.value = clampf(value, 0.0, bar.max_value)
	bar.show_percentage = false


func _named_resources(values: Array) -> String:
	var names: Array[String] = []
	for value in values:
		if value == null:
			continue
		var name: String = value.display_name if "display_name" in value and not value.display_name.is_empty() else (value.id if "id" in value else str(value))
		names.append(name)
	return ", ".join(names) if not names.is_empty() else "None"


func _dictionary_values(base_values: Dictionary, equipment_values: Dictionary) -> String:
	var totals := base_values.duplicate()
	for key in equipment_values:
		totals[key] = int(totals.get(key, 0)) + int(equipment_values[key])
	var parts: Array[String] = []
	for key in totals:
		if int(totals[key]) != 0:
			parts.append("%s %d" % [String(key).capitalize(), int(totals[key])])
	return ", ".join(parts) if not parts.is_empty() else "None"


func _string_values(first: Array, second: Array) -> String:
	var values: Array[String] = []
	for value in first + second:
		var text := String(value).capitalize()
		if not values.has(text):
			values.append(text)
	return ", ".join(values) if not values.is_empty() else "None"


func _build_api_mirror(player: CombatantState) -> void:
	_clear(summary)
	_clear(content_list)
	for text in [
		player.display_name,
		"Level %d | %s | %s" % [player.level, player.ancestry_display_name, player.class_display_name],
		"HP %d / %d" % [player.hp, player.max_hp],
		"STR %d  DEX %d  CON %d" % [player.strength, player.dexterity, player.constitution],
		"INT %d  WIS %d  CHA %d" % [player.intelligence, player.wisdom, player.charisma],
		"Fortitude %d  Reflex %d  Will %d" % [player.fortitude + player.equipment_fortitude_bonus, player.reflex + player.equipment_reflex_bonus, player.will + player.equipment_will_bonus],
	]:
		var summary_line := Label.new()
		summary_line.text = text
		summary.add_child(summary_line)
	if active_tab == "equipment":
		var heading := Label.new()
		heading.text = "EQUIPPED"
		content_list.add_child(heading)
		for item in player.equipment_inventory:
			var row := HBoxContainer.new()
			var button := Button.new()
			button.text = _action_text(player, item, HAND_2)
			button.disabled = changes_locked or player.ap < 1
			button.pressed.connect(func(): equipment_change_requested.emit(item, HAND_2))
			row.add_child(button)
			content_list.add_child(row)
	else:
		for entry in _visible_entries:
			var label := Label.new()
			label.text = _entry_name(entry)
			content_list.add_child(label)


func _find_navigation(view: Control) -> VBoxContainer:
	for node in view.find_children("VBoxContainer2", "VBoxContainer", true, false):
		if node.has_node("CharacterBoxContainer/CharacterButton"):
			return node
	return null


func _connect_once(button: BaseButton, callable: Callable) -> void:
	if not button.pressed.is_connected(callable):
		button.pressed.connect(callable)


func _change_page(delta: int) -> void:
	current_page += delta
	refresh()


func _title_for_tab() -> String:
	return {"abilities": "Character", "inventory": "Inventory", "equipment": "Equipment", "craft": "Craft"}.get(active_tab, "Inventory")


func _profile_summary(player: CombatantState) -> String:
	var resource := "Faith %d/%d" % [player.faith, player.max_faith] if player.max_faith > 0 else "Mana %d/%d" % [player.mana, player.max_mana]
	return "Lv.%d  HP %d/%d  AP %d/%d  %s" % [player.level, player.hp, player.max_hp, player.ap, player.effective_max_ap, resource]


func _slot_name(slot: int) -> String:
	return {HAND_1: "Main Hand", HAND_2: "Off Hand", ARMOR: "Body"}.get(slot, "Slot")


func _is_item_stack(entry) -> bool:
	return entry != null and "item" in entry and "quantity" in entry


func _entry_name(entry) -> String:
	if entry == null:
		return "Empty"
	if _is_item_stack(entry):
		return entry.item.display_name if entry.item != null else "Empty"
	return entry.display_name if "display_name" in entry else str(entry)


func _entry_short_name(entry) -> String:
	var words := _entry_name(entry).split(" ", false)
	if words.is_empty():
		return "?"
	if words.size() == 1:
		return words[0].left(6)
	return (words[0].left(1) + words[1].left(5)).to_upper()


func _entry_description(entry) -> String:
	if entry == null:
		return ""
	var data = entry.item if _is_item_stack(entry) else entry
	return data.description if data != null and "description" in data else _entry_name(entry)


func _entry_icon(entry) -> Texture2D:
	if not _is_item_stack(entry) or entry.item == null:
		return null
	return entry.item.icon_texture


func _entry_quantity(entry) -> int:
	return entry.quantity if _is_item_stack(entry) else 1


func _clear_visuals() -> void:
	page_title.text = "No Character"
	detail_label.text = "Character data is unavailable"
	for cell in item_grid.get_children():
		for child in cell.get_children():
			child.queue_free()


func get_visible_entry_count() -> int:
	return _visible_entries.size()
