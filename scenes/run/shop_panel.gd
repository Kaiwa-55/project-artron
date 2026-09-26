class_name ShopPanel
extends Control

signal purchase_requested(actor_id: String, product: Resource, quantity: int, price: int)
signal sale_requested(actor_id: String, entry: Variant, quantity: int)
signal shop_closed()

const UITheme := preload("res://scenes/ui/artron_ui_theme.gd")
const ShopTrade := preload("res://run/shop_trade_system.gd")
const SHOP_TITLE_SIZE := 16
const SHOP_BODY_SIZE := 9
const SHOP_DETAIL_SIZE := 8
var party: Array[CombatantState] = []
var gold: int = 0
var shop_data: Resource
var _gold_label: Label
var _party_rows: VBoxContainer
var _member_picker: OptionButton
var _buy_tab: Button
var _sell_tab: Button
var _help_label: Label
var _selected_member_id: String = ""
var _active_tab: String = "buy"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	hide()


func open_for_party(members: Array[CombatantState], current_gold: int, shop: Resource) -> void:
	party = members.filter(func(member): return member != null)
	gold = maxi(0, current_gold)
	_gold_label.text = "GOLD  %d" % gold
	shop_data = shop
	_selected_member_id = party[0].id if not party.is_empty() else ""
	_active_tab = "buy"
	get_node("Margin/ShopCard/Column/Header/Title").text = get_shop_display_name()
	get_node("Margin/ShopCard/Column/Summary").text = get_shop_description()
	var banner: TextureRect = get_node("Margin/ShopCard/Column/Body/Sidebar/Banner")
	banner.texture = get_shop_banner()
	banner.visible = banner.texture != null
	_refresh_member_picker()
	_update_tab_buttons()
	_build_party_rows()
	show()
	move_to_front()


func refresh_gold(current_gold: int) -> void:
	gold = maxi(0, current_gold)
	if _gold_label != null:
		_gold_label.text = "GOLD  %d" % gold
	_build_party_rows()


func _build() -> void:
	if get_node_or_null("Shade") != null:
		return
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.035, 0.05, 0.84)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(margin)
	var card := PanelContainer.new()
	card.name = "ShopCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UITheme.style(UITheme.WINDOW_BACKGROUND, UITheme.GOLD, UITheme.CARD_PADDING))
	margin.add_child(card)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 3)
	card.add_child(column)
	var header := HBoxContainer.new()
	header.name = "Header"
	column.add_child(header)
	var title := UITheme.label("WAYFARER'S SHOP", SHOP_TITLE_SIZE, UITheme.GOLD)
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_gold_label = UITheme.label("GOLD  0", SHOP_BODY_SIZE, UITheme.GOLD)
	header.add_child(_gold_label)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "×"
	close_button.tooltip_text = "Close Shop"
	UITheme.apply_button_style(close_button)
	close_button.custom_minimum_size = Vector2(24, 24)
	close_button.add_theme_font_size_override("font_size", 13)
	close_button.pressed.connect(close_shop)
	header.add_child(close_button)
	var summary := UITheme.label("Choose which party member receives each purchase.", SHOP_BODY_SIZE, UITheme.MUTED)
	summary.name = "Summary"
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_constant_override("line_spacing", 0)
	column.add_child(summary)
	var body := HBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	column.add_child(body)
	var sidebar := VBoxContainer.new()
	sidebar.name = "Sidebar"
	sidebar.custom_minimum_size.x = 200
	sidebar.add_theme_constant_override("separation", 4)
	body.add_child(sidebar)
	var banner := TextureRect.new()
	banner.name = "Banner"
	banner.custom_minimum_size = Vector2(0, 75)
	banner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	banner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.hide()
	sidebar.add_child(banner)
	var controls := VBoxContainer.new()
	controls.name = "ShopControls"
	controls.add_theme_constant_override("separation", 2)
	sidebar.add_child(controls)
	controls.add_child(UITheme.label("SHOPPING FOR", SHOP_BODY_SIZE, UITheme.GOLD))
	_member_picker = OptionButton.new()
	_member_picker.name = "MemberPicker"
	_member_picker.custom_minimum_size = Vector2(150, 32)
	_member_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_button_style(_member_picker)
	_member_picker.add_theme_font_size_override("font_size", SHOP_BODY_SIZE)
	_member_picker.item_selected.connect(_on_member_selected)
	controls.add_child(_member_picker)
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", 4)
	sidebar.add_child(tabs)
	_buy_tab = Button.new()
	_buy_tab.name = "BuyTab"
	_buy_tab.text = "BUY"
	_buy_tab.toggle_mode = true
	_buy_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_button_style(_buy_tab)
	_buy_tab.add_theme_font_size_override("font_size", SHOP_BODY_SIZE)
	_buy_tab.pressed.connect(func(): select_tab("buy"))
	tabs.add_child(_buy_tab)
	_sell_tab = Button.new()
	_sell_tab.name = "SellTab"
	_sell_tab.text = "SELL"
	_sell_tab.toggle_mode = true
	_sell_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_button_style(_sell_tab)
	_sell_tab.add_theme_font_size_override("font_size", SHOP_BODY_SIZE)
	_sell_tab.pressed.connect(func(): select_tab("sell"))
	tabs.add_child(_sell_tab)
	_help_label = UITheme.label("", SHOP_BODY_SIZE, UITheme.MUTED)
	_help_label.name = "TradeHelp"
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_label.add_theme_constant_override("line_spacing", 0)
	sidebar.add_child(_help_label)
	var trade := VBoxContainer.new()
	trade.name = "Trade"
	trade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trade.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(trade)
	var scroll := ScrollContainer.new()
	scroll.name = "OffersScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	trade.add_child(scroll)
	_party_rows = VBoxContainer.new()
	_party_rows.name = "PartyRows"
	_party_rows.add_theme_constant_override("separation", 3)
	_party_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_party_rows)
	var leave := Button.new()
	leave.name = "LeaveButton"
	leave.text = "LEAVE SHOP"
	leave.custom_minimum_size = Vector2(0, 32)
	UITheme.apply_button_style(leave)
	leave.add_theme_font_size_override("font_size", SHOP_BODY_SIZE)
	leave.pressed.connect(close_shop)
	column.add_child(leave)


func close_shop() -> void:
	if not visible:
		return
	hide()
	shop_closed.emit()


func _build_party_rows() -> void:
	if _party_rows == null:
		return
	for child in _party_rows.get_children():
		_party_rows.remove_child(child)
		child.queue_free()
	for member in party:
		if member.id != _selected_member_id:
			continue
		var row := PanelContainer.new()
		row.name = member.id
		row.add_theme_stylebox_override("panel", UITheme.style(UITheme.CARD_BACKGROUND, UITheme.CARD_BORDER, 6))
		_party_rows.add_child(row)
		var content := VBoxContainer.new()
		content.name = "Content"
		content.add_theme_constant_override("separation", 3)
		row.add_child(content)
		var details := UITheme.label("BUY FOR %s" % member.display_name if _active_tab == "buy" else "SELL FROM %s" % member.display_name, SHOP_BODY_SIZE, UITheme.GOLD)
		content.add_child(details)
		var offers := VBoxContainer.new()
		offers.name = "Offers"
		offers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		offers.add_theme_constant_override("separation", 1)
		content.add_child(offers)
		if _active_tab == "buy":
			for offer in get_shop_offers():
				_add_offer(offers, member, offer)
			if offers.get_child_count() == 0:
				offers.add_child(UITheme.label("No items for sale.", SHOP_BODY_SIZE, UITheme.MUTED))
		else:
			for stack in member.item_inventory:
				if stack != null and stack.item != null and stack.quantity > 0:
					_add_sale(offers, member, stack, stack.item.display_name, stack.quantity, false)
			for equipment in member.equipment_inventory:
				if equipment != null:
					_add_sale(offers, member, equipment, equipment.display_name, 1, member.equipped_items.values().has(equipment))
			if offers.get_child_count() == 0:
				offers.add_child(UITheme.label("Nothing available to sell.", SHOP_BODY_SIZE, UITheme.MUTED))


func _refresh_member_picker() -> void:
	_member_picker.clear()
	for index in range(party.size()):
		_member_picker.add_item(party[index].display_name)
		_member_picker.set_item_metadata(index, party[index].id)
		if party[index].id == _selected_member_id:
			_member_picker.select(index)


func _on_member_selected(index: int) -> void:
	_selected_member_id = String(_member_picker.get_item_metadata(index))
	_build_party_rows()


func select_tab(tab: String) -> void:
	if tab != "buy" and tab != "sell":
		return
	_active_tab = tab
	_update_tab_buttons()
	_build_party_rows()


func _update_tab_buttons() -> void:
	_buy_tab.set_pressed_no_signal(_active_tab == "buy")
	_sell_tab.set_pressed_no_signal(_active_tab == "sell")
	_help_label.text = "Choose a character, then press BUY beside an item. If a button is gray, you need more Gold." if _active_tab == "buy" else "Choose a character, then press SELL. Equipped gear must be unequipped before selling."


func _add_offer(parent: VBoxContainer, member: CombatantState, offer: Resource) -> void:
	var product: Resource = offer.get("product") if offer != null else null
	var quantity := int(offer.get("quantity")) if offer != null else 0
	var price := int(offer.get("price")) if offer != null else -1
	if product == null or quantity <= 0 or price < 0:
		return
	var row := HBoxContainer.new()
	parent.add_child(row)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(28, 28)
	icon.texture = get_offer_icon(offer, product)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = icon.texture != null
	row.add_child(icon)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 0)
	details.add_child(UITheme.label("%s x%d" % [get_product_name(product), quantity], SHOP_BODY_SIZE, UITheme.TEXT))
	var description := UITheme.label(get_product_description(product), SHOP_DETAIL_SIZE, UITheme.MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_constant_override("line_spacing", 0)
	details.add_child(description)
	if gold < price:
		details.add_child(UITheme.label("Need %d more Gold" % (price - gold), SHOP_DETAIL_SIZE, UITheme.MUTED))
	row.add_child(details)
	var buy := Button.new()
	buy.name = "Buy_%s" % get_product_id(product)
	buy.text = "BUY %d G" % price
	buy.custom_minimum_size = Vector2(80, 28)
	buy.tooltip_text = "%s\nCosts %d Gold" % [get_product_description(product), price]
	buy.disabled = gold < price
	if buy.disabled:
		buy.tooltip_text = "Need %d more Gold to buy %s." % [price - gold, get_product_name(product)]
	UITheme.apply_button_style(buy)
	buy.add_theme_font_size_override("font_size", SHOP_BODY_SIZE)
	buy.pressed.connect(func(): purchase_requested.emit(member.id, product, quantity, price))
	row.add_child(buy)


func _add_sale(parent: VBoxContainer, member: CombatantState, entry, display_name: String, quantity: int, equipped: bool) -> void:
	var unit_price: int = ShopTrade.sell_unit_price(entry)
	if unit_price <= 0:
		return
	var row := HBoxContainer.new()
	row.name = "Sell_%s" % (entry.item.id if entry is ItemStack else entry.id)
	parent.add_child(row)
	var details := UITheme.label("%s x%d%s" % [display_name, quantity, " (unequip first)" if equipped else ""], SHOP_BODY_SIZE, UITheme.TEXT)
	row.add_child(details)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sell_one := Button.new()
	sell_one.name = "SellOne"
	sell_one.text = "SELL 1 · %d G" % unit_price
	sell_one.custom_minimum_size = Vector2(80, 28)
	sell_one.disabled = equipped
	if equipped:
		sell_one.tooltip_text = "Unequip %s before selling it." % display_name
	UITheme.apply_button_style(sell_one)
	sell_one.add_theme_font_size_override("font_size", SHOP_BODY_SIZE)
	sell_one.pressed.connect(func(): sale_requested.emit(member.id, entry, 1))
	row.add_child(sell_one)
	if quantity > 1:
		var sell_all := Button.new()
		sell_all.name = "SellAll"
		sell_all.text = "SELL ALL · %d G" % (unit_price * quantity)
		sell_all.custom_minimum_size = Vector2(92, 28)
		UITheme.apply_button_style(sell_all)
		sell_all.add_theme_font_size_override("font_size", SHOP_BODY_SIZE)
		sell_all.pressed.connect(func(): sale_requested.emit(member.id, entry, quantity))
		row.add_child(sell_all)


func get_shop_offers() -> Array:
	return Array(shop_data.call("get_offers")) if shop_data != null else []


func get_shop_display_name() -> String:
	return String(shop_data.get("display_name")) if shop_data != null else "WAYFARER'S SHOP"


func get_shop_description() -> String:
	return String(shop_data.get("description")) if shop_data != null else "This Shop has no stock."


func get_shop_banner() -> Texture2D:
	return shop_data.get("banner_texture") as Texture2D if shop_data != null else null


func get_offer_icon(offer: Resource, product: Resource) -> Texture2D:
	var configured_icon := offer.get("icon_texture") as Texture2D
	if configured_icon != null:
		return configured_icon
	return product.get("icon_texture") as Texture2D


func get_product_name(product: Resource) -> String:
	return String(product.get("display_name"))


func get_product_description(product: Resource) -> String:
	return String(product.get("description"))


func get_product_id(product: Resource) -> String:
	return String(product.get("id"))
