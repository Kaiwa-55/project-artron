extends PanelContainer

signal entry_selected(entry)
signal use_requested
signal tab_requested(tab: String)
signal close_requested

const UITheme := preload("res://scenes/ui/artron_ui_theme.gd")
const GOLD := UITheme.GOLD
const MUTED := UITheme.MUTED
var owner_label: Label
var resources: Label
var search: LineEdit
var category: OptionButton
var entries: VBoxContainer
var empty_label: Label
var item_name: Label
var item_description: Label
var item_meta: Label
var action_hint: Label
var use_button: Button
var item_count: Label
var _stacks: Array = []
var _selected
var _locked := true
var column: VBoxContainer
var body: HBoxContainer
var tab_buttons: Dictionary = {}
var close_button: Button


func _ready() -> void:
	name = "InventoryView"
	theme = UITheme.create_theme()
	add_theme_stylebox_override("panel", _style(UITheme.WINDOW_BACKGROUND, UITheme.WINDOW_BORDER, UITheme.WINDOW_PADDING))
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(identity)
	owner_label = _label("Inventory", UITheme.TITLE_SIZE, GOLD)
	identity.add_child(owner_label)
	resources = _label("", 10, MUTED)
	identity.add_child(resources)
	close_button = _button("Close", close_requested.emit)
	close_button.name = "CloseButton"
	header.add_child(close_button)
	var tabs := HBoxContainer.new()
	column.add_child(tabs)
	for tab in [["abilities", "Character"], ["inventory", "Inventory"], ["equipment", "Equipment"]]:
		var button := _button(tab[1], func(): tab_requested.emit(tab[0]))
		tabs.add_child(button)
		tab_buttons[tab[0]] = button
	body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	column.add_child(body)
	var list_column := VBoxContainer.new()
	list_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(list_column)
	var filters := HBoxContainer.new()
	list_column.add_child(filters)
	search = LineEdit.new()
	search.name = "Search"
	search.placeholder_text = "Search items..."
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size.x = 100
	search.text_changed.connect(func(_text): _render_entries())
	filters.add_child(search)
	category = OptionButton.new()
	category.name = "Category"
	for caption in ["All items", "Consumables", "Quest", "Materials"]:
		category.add_item(caption)
	category.item_selected.connect(func(_index): _render_entries())
	filters.add_child(category)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_column.add_child(scroll)
	entries = VBoxContainer.new()
	entries.name = "Entries"
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation", 4)
	scroll.add_child(entries)
	empty_label = _label("", 11, MUTED)
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_column.add_child(empty_label)
	item_count = _label("", 10, MUTED)
	list_column.add_child(item_count)
	var details := PanelContainer.new()
	details.custom_minimum_size.x = 190
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_stretch_ratio = 0.7
	details.add_theme_stylebox_override("panel", _style(UITheme.CARD_BACKGROUND, UITheme.CARD_BORDER, UITheme.CARD_PADDING))
	body.add_child(details)
	var detail_column := VBoxContainer.new()
	detail_column.add_theme_constant_override("separation", 6)
	details.add_child(detail_column)
	detail_column.add_child(_label("ITEM DETAILS", 9, GOLD))
	item_name = _label("Select an item", 14, Color.WHITE)
	item_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_column.add_child(item_name)
	item_meta = _label("", 10, GOLD)
	detail_column.add_child(item_meta)
	var description_scroll := ScrollContainer.new()
	description_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_column.add_child(description_scroll)
	item_description = _label("Choose an item from your backpack to see its effects.", UITheme.FONT_SIZE, UITheme.TEXT)
	item_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_scroll.add_child(item_description)
	action_hint = _label("", 10, MUTED)
	action_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_column.add_child(action_hint)
	use_button = _button("Use item", use_requested.emit)
	use_button.name = "UseItem"
	detail_column.add_child(use_button)
	use_button.disabled = true


func set_active_tab(tab: String) -> void:
	body.visible = tab == "inventory"
	for key in tab_buttons:
		var button: Button = tab_buttons[key]
		button.add_theme_stylebox_override("normal", _style(UITheme.SELECTED_BACKGROUND if key == tab else UITheme.BUTTON_BACKGROUND, GOLD if key == tab else UITheme.BUTTON_BORDER, UITheme.BUTTON_PADDING))


func display(player: CombatantState, selected, locked: bool) -> void:
	owner_label.text = "%s's Inventory" % player.display_name
	resources.text = "HP %d / %d   |   Mana %d / %d   |   AP %d" % [player.hp, player.max_hp, player.mana, player.max_mana, player.ap]
	_stacks = player.item_inventory.duplicate()
	_selected = selected if selected is ItemStack and _stacks.has(selected) else null
	_locked = locked
	_render_entries()
	_render_details()


func select(entry) -> void:
	_selected = entry if _stacks.has(entry) else null
	_render_entries()
	_render_details()


func _render_entries() -> void:
	for child in entries.get_children():
		entries.remove_child(child)
		child.queue_free()
	var query := search.text.strip_edges().to_lower()
	var shown := 0
	for stack in _stacks:
		if stack == null or stack.item == null or stack.quantity <= 0:
			continue
		if category.selected > 0 and int(stack.item.category) != category.selected - 1:
			continue
		if not query.is_empty() and not (stack.item.display_name + " " + stack.item.description).to_lower().contains(query):
			continue
		shown += 1
		var button := _button("%s   x%d" % [stack.item.display_name, stack.quantity], func(): entry_selected.emit(stack))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.custom_minimum_size.y = 34
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if stack == _selected:
			button.add_theme_stylebox_override("normal", _style(UITheme.SELECTED_BACKGROUND, GOLD, UITheme.BUTTON_PADDING))
		entries.add_child(button)
	empty_label.text = "Your backpack is empty." if _stacks.is_empty() else "No matching items. Try another search or category."
	empty_label.visible = shown == 0
	item_count.text = "%d / %d stacks" % [shown, _stacks.size()]


func _render_details() -> void:
	var valid: bool = _selected != null and _selected.item != null and _selected.quantity > 0
	use_button.disabled = not valid or _locked
	if not valid:
		item_name.text = "Select an item"
		item_meta.text = ""
		item_description.text = "Choose an item from your backpack to see its effects."
		action_hint.text = "Viewing only" if _locked else ""
		return
	var item: ItemData = _selected.item
	item_name.text = item.display_name
	item_meta.text = "%s  |  Owned: %d" % [["Consumable", "Quest item", "Material"][item.category], _selected.quantity]
	item_description.text = item.description if not item.description.is_empty() else "No description available."
	use_button.disabled = _locked or item.category != ItemData.Category.CONSUMABLE
	action_hint.text = "Item use is unavailable right now." if _locked else ("Use this item with its normal action cost." if item.category == ItemData.Category.CONSUMABLE else "This item cannot be used directly.")


func _button(caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	UITheme.apply_button_style(button)
	button.pressed.connect(callback)
	return button


func _label(caption: String, font_size: int, color: Color) -> Label:
	return UITheme.label(caption, font_size, color)


func _style(background: Color, border: Color, padding: int) -> StyleBoxFlat:
	return UITheme.style(background, border, padding)
