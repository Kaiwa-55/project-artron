class_name ShopPanel
extends Control

signal purchase_requested(actor_id: String, product: Resource, quantity: int, price: int)
signal shop_closed()

const UITheme := preload("res://scenes/ui/artron_ui_theme.gd")
var party: Array[CombatantState] = []
var gold: int = 0
var shop_data: Resource
var _gold_label: Label
var _party_rows: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	hide()


func open_for_party(members: Array[CombatantState], current_gold: int, shop: Resource) -> void:
	party = members.filter(func(member): return member != null)
	gold = maxi(0, current_gold)
	shop_data = shop
	get_node("Margin/ShopCard/Column/Header/Title").text = get_shop_display_name()
	get_node("Margin/ShopCard/Column/Summary").text = get_shop_description()
	var banner: TextureRect = get_node("Margin/ShopCard/Column/Banner")
	banner.texture = get_shop_banner()
	banner.visible = banner.texture != null
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
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
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
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	var header := HBoxContainer.new()
	header.name = "Header"
	column.add_child(header)
	var title := UITheme.label("WAYFARER'S SHOP", UITheme.TITLE_SIZE, UITheme.GOLD)
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_gold_label = UITheme.label("GOLD  0", UITheme.FONT_SIZE, UITheme.GOLD)
	header.add_child(_gold_label)
	var summary := UITheme.label("Choose which party member receives each purchase.", UITheme.FONT_SIZE, UITheme.MUTED)
	summary.name = "Summary"
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(summary)
	var banner := TextureRect.new()
	banner.name = "Banner"
	# This becomes roughly 320 px tall at the common 1280x720 display scale,
	# while leaving room for the offers and purchase buttons.
	banner.custom_minimum_size = Vector2(0, 110)
	banner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	banner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.hide()
	column.add_child(banner)
	column.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.name = "OffersScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_party_rows = VBoxContainer.new()
	_party_rows.name = "PartyRows"
	_party_rows.add_theme_constant_override("separation", 6)
	_party_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_party_rows)
	var leave := Button.new()
	leave.name = "LeaveButton"
	leave.text = "LEAVE SHOP"
	leave.custom_minimum_size = Vector2(0, 32)
	UITheme.apply_button_style(leave)
	leave.pressed.connect(func():
		hide()
		shop_closed.emit())
	column.add_child(leave)


func _build_party_rows() -> void:
	if _party_rows == null:
		return
	for child in _party_rows.get_children():
		_party_rows.remove_child(child)
		child.queue_free()
	for member in party:
		var row := PanelContainer.new()
		row.name = member.id
		row.add_theme_stylebox_override("panel", UITheme.style(UITheme.CARD_BACKGROUND, UITheme.CARD_BORDER, 6))
		_party_rows.add_child(row)
		var content := HBoxContainer.new()
		content.name = "Content"
		content.add_theme_constant_override("separation", 8)
		row.add_child(content)
		var details := UITheme.label(member.display_name, UITheme.FONT_SIZE, UITheme.TEXT)
		details.custom_minimum_size = Vector2(100, 0)
		content.add_child(details)
		var offers := VBoxContainer.new()
		offers.name = "Offers"
		offers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		offers.add_theme_constant_override("separation", 3)
		content.add_child(offers)
		for offer in get_shop_offers():
			_add_offer(offers, member, offer)


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
	var details := UITheme.label("%s x%d" % [get_product_name(product), quantity], UITheme.SECTION_SIZE, UITheme.TEXT)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.tooltip_text = get_product_description(product)
	row.add_child(details)
	var buy := Button.new()
	buy.name = "Buy_%s" % get_product_id(product)
	buy.text = "BUY %d G" % price
	buy.custom_minimum_size = Vector2(80, 28)
	buy.tooltip_text = "%s\nCosts %d Gold" % [get_product_description(product), price]
	buy.disabled = gold < price
	UITheme.apply_button_style(buy)
	buy.pressed.connect(func(): purchase_requested.emit(member.id, product, quantity, price))
	row.add_child(buy)


func get_shop_offers() -> Array:
	return Array(shop_data.get("offers")) if shop_data != null else []


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
