extends SceneTree

const ShopPanelScene = preload("res://scenes/run/ShopPanel.tscn")
const ShopImage = preload("res://assets/icon/skill_icons22.png")
const Potion = preload("res://data/item/minor_healing_potion.tres")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	root.size = Vector2i(640, 360)
	var first := CombatantState.new()
	first.id = "first"
	first.display_name = "First Hero"
	first.item_inventory.append(ItemStack.new(Potion, 1))
	var second := CombatantState.new()
	second.id = "second"
	second.display_name = "Second Hero"
	second.item_inventory.append(ItemStack.new(Potion, 2))
	var shop := ShopData.new()
	shop.display_name = "CUSTOM TEST SHOP"
	shop.description = "Supplies for the next encounter."
	shop.banner_texture = ShopImage
	var offer := ShopOfferData.new()
	offer.product = Potion
	offer.price = 25
	shop.offers.append(offer)
	var panel = ShopPanelScene.instantiate()
	root.add_child(panel)
	await process_frame
	var members: Array[CombatantState] = [first, second]
	panel.open_for_party(members, 100, shop)
	await process_frame
	check(panel.get_node("Margin/ShopCard/Column/Header/Title").text == shop.display_name, "Custom shop name is visible")
	check(panel.get_node("Margin/ShopCard/Column/Body/Sidebar/Banner").texture == ShopImage, "Custom shop image is visible")
	check(panel.get_node("Margin/ShopCard/Column/Summary").text == shop.description, "Shop description is visible")
	var scroll: ScrollContainer = panel.get_node("Margin/ShopCard/Column/Body/Trade/OffersScroll")
	check(scroll.size.y >= 65.0, "Trade list has usable height at the game's 640x360 viewport")
	var image_rect: Rect2 = panel.get_node("Margin/ShopCard/Column/Body/Sidebar/Banner").get_global_rect()
	var picker_rect: Rect2 = panel.get_node("Margin/ShopCard/Column/Body/Sidebar/ShopControls/MemberPicker").get_global_rect()
	check(image_rect.end.x < scroll.global_position.x, "Shop image is left of the trade list")
	check(picker_rect.position.y >= image_rect.end.y, "Character and trade controls are below the image")
	check(panel.get_node("Margin/ShopCard/Column/LeaveButton").get_global_rect().end.y <= 360.0, "Leave button remains on screen")
	var rows: VBoxContainer = panel.get_node("Margin/ShopCard/Column/Body/Trade/OffersScroll/PartyRows")
	check(rows.get_child_count() == 1 and rows.get_node_or_null("first") != null, "Only the selected member's offers are shown")
	var picker: OptionButton = panel.get_node("Margin/ShopCard/Column/Body/Sidebar/ShopControls/MemberPicker")
	check(picker.item_count == 2, "Both party members can be selected")
	picker.select(1)
	picker.item_selected.emit(1)
	check(rows.get_child_count() == 1 and rows.get_node_or_null("second") != null, "Member selection updates the trade list")
	var selected_offers: VBoxContainer = rows.get_node("second/Content/Offers")
	check(selected_offers.get_child_count() == 1 and selected_offers.get_child(0).get_child(1).get_child_count() == 2, "Buy list shows the item name and description")
	var buy_button: Button = selected_offers.get_child(0).get_node("Buy_minor_healing_potion")
	check(scroll.get_global_rect().intersects(buy_button.get_global_rect()), "Buy button is visible in the trade list")
	var purchase_record := {"buyer": ""}
	panel.purchase_requested.connect(func(actor_id, _product, _quantity, _price): purchase_record.buyer = actor_id)
	await process_frame
	var pointer := buy_button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = pointer
	motion.global_position = pointer
	root.push_input(motion, true)
	await process_frame
	pointer = buy_button.get_global_rect().get_center()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = pointer
	click.global_position = pointer
	click.pressed = true
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	await process_frame
	check(purchase_record.buyer == "second", "Clicking the visible Buy button requests a purchase for the selected member")
	panel.refresh_gold(0)
	var unaffordable_row: HBoxContainer = rows.get_node("second/Content/Offers").get_child(0)
	check(unaffordable_row.get_node("Buy_minor_healing_potion").disabled and unaffordable_row.get_child(1).get_child(2).text.contains("Need 25 more Gold"), "Unaffordable purchases explain why Buy is disabled")
	panel.refresh_gold(100)
	panel.get_node("Margin/ShopCard/Column/Body/Sidebar/Tabs/SellTab").pressed.emit()
	check(panel._active_tab == "sell" and rows.get_node_or_null("second/Content/Offers/Sell_minor_healing_potion") != null, "Sell tab shows only the selected member's inventory")
	check(panel.get_node("Margin/ShopCard/Column/Body/Sidebar/TradeHelp").text.contains("unequipped"), "Sell tab explains equipped gear restrictions")
	panel.refresh_gold(75)
	check(panel._active_tab == "sell" and panel._selected_member_id == "second", "Gold refresh keeps the selected member and tab")
	panel.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("SHOP_PANEL_UI_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
