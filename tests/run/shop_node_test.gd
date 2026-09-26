extends SceneTree

const RunMapScene := preload("res://scenes/run/RunMap.tscn")
const MinorHealingPotion := preload("res://data/item/minor_healing_potion.tres")
const HealerShop := preload("res://data/shop/healer_shop.tres")
const OutfitterShop := preload("res://data/shop/outfitter_shop.tres")
const TestIcon := preload("res://assets/icon/skill_icons22.png")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var generated_nodes := RunGenerator.new().generate(424242)
	var generated_shops := generated_nodes.filter(func(node): return node.node_type == MapNodeData.NodeType.SHOP)
	check(generated_shops.all(func(node): return node.shop_data != null), "Generated Shop nodes receive a Shop resource from the catalog.")
	var run_map = RunMapScene.instantiate()
	root.add_child(run_map)
	await process_frame
	var member_id := String(run_map.get_party_entries().front().get("id", "player"))
	var member: CombatantState = run_map.run_state.party_progression_states.get(member_id)
	run_map.run_state.gold = 50
	var count_before := get_item_quantity(member, MinorHealingPotion.id)
	run_map.open_shop(make_shop_node(HealerShop))
	await process_frame
	check(run_map.shop_panel.visible, "Shop node opens the Shop panel.")
	check(run_map.shop_panel._gold_label.text == "GOLD  50", "Opening the shop immediately displays the current gold.")
	check(run_map.shop_panel.get_node("Margin/ShopCard/Column/Header/Title").text == HealerShop.display_name, "Shop UI uses the selected Shop resource name.")
	var visual_shop: Resource = HealerShop.duplicate(true)
	visual_shop.set("display_name", "TEST APOTHECARY")
	visual_shop.set("banner_texture", TestIcon)
	var visual_offers: Array = visual_shop.get("offers")
	visual_offers[0].set("icon_texture", TestIcon)
	run_map.open_shop(make_shop_node(visual_shop))
	await process_frame
	check(run_map.shop_panel.get_node("Margin/ShopCard/Column/Body/Sidebar/Banner").visible, "Shop displays a configured banner image.")
	check(run_map.shop_panel.get_node("Margin/ShopCard/Column/Header/Title").text == "TEST APOTHECARY", "Shop displays a configured name without code changes.")
	check(run_map.shop_panel.get_node("Margin/ShopCard/Column/Body/Sidebar/Banner").custom_minimum_size.y == 75.0, "Shop image fills the left column.")
	check(run_map.shop_panel.get_node("Margin/ShopCard/Column/Body/Trade/OffersScroll") is ScrollContainer, "Shop places its purchase list inside a scrollable area.")
	var banner_rect: Rect2 = run_map.shop_panel.get_node("Margin/ShopCard/Column/Body/Sidebar/Banner").get_global_rect()
	check(banner_rect.size.y >= 75.0, "Shop art remains prominent beside the trade list.")
	check(run_map.shop_panel.get_node("Margin/ShopCard/Column/Body/Trade/OffersScroll/PartyRows").get_child_count() == 1, "Shop shows one selected party member at a time.")
	check(run_map.shop_panel.get_node("Margin/ShopCard/Column/Body/Sidebar/ShopControls/MemberPicker") is OptionButton, "Shop has one clear party member selector.")
	check(run_map.shop_panel.get_node("Margin/ShopCard/Column/Body/Sidebar/Tabs/BuyTab").button_pressed, "Shop opens on the Buy tab.")
	var player_offers: VBoxContainer = run_map.shop_panel.get_node("Margin/ShopCard/Column/Body/Trade/OffersScroll/PartyRows/%s/Content/Offers" % member_id)
	check(player_offers.get_child(0).get_node("Icon").visible, "Shop displays a configured offer image.")
	var buy_button: Button = player_offers.get_child(0).get_child(2)
	await click_button(buy_button)
	check(run_map.run_state.gold == 25, "Buying an item deducts its Gold cost once.")
	check(run_map.gold_label.text == "GOLD  25", "Run Map Gold updates after a purchase.")
	check(get_item_quantity(member, MinorHealingPotion.id) == count_before + 1, "Buying an item adds it to the selected member inventory.")
	run_map.purchase_shop_item(member_id, MinorHealingPotion, 1, 0)
	check(run_map.run_state.gold == 25 and get_item_quantity(member, MinorHealingPotion.id) == count_before + 1, "Shop rejects a price not present in its offers.")
	run_map.purchase_shop_item(member_id, MinorHealingPotion, 2, 25)
	check(run_map.run_state.gold == 25 and get_item_quantity(member, MinorHealingPotion.id) == count_before + 1, "Shop rejects a changed quantity.")
	run_map.purchase_shop_item(member_id, MinorHealingPotion, 2, 30)
	check(run_map.run_state.gold == 25 and get_item_quantity(member, MinorHealingPotion.id) == count_before + 1, "Shop rejects a purchase when Gold is insufficient.")
	run_map.open_shop(make_shop_node(OutfitterShop))
	run_map.run_state.gold = 70
	run_map.shop_panel.refresh_gold(run_map.run_state.gold)
	player_offers = run_map.shop_panel.get_node("Margin/ShopCard/Column/Body/Trade/OffersScroll/PartyRows/%s/Content/Offers" % member_id)
	check(player_offers.get_child_count() >= 2, "A different Shop resource can offer a different item list.")
	player_offers.get_child(1).get_child(2).pressed.emit()
	check(member.equipment_inventory.any(func(equipment): return equipment != null and equipment.id == "dagger"), "Shop can sell configured equipment as well as consumables.")
	run_map.shop_panel.get_node("Margin/ShopCard/Column/LeaveButton").pressed.emit()
	check(not run_map.shop_panel.visible, "Player can leave the Shop and continue the Run.")
	run_map.purchase_shop_item(member_id, MinorHealingPotion, 1, 50)
	check(run_map.run_state.gold == 25, "Shop rejects purchases after leaving.")
	run_map.open_shop(make_shop_node(HealerShop))
	await click_button(run_map.shop_panel.get_node("Margin/ShopCard/Column/Body/Sidebar/Tabs/SellTab"))
	var sale_row: HBoxContainer = run_map.shop_panel.get_node("Margin/ShopCard/Column/Body/Trade/OffersScroll/PartyRows/%s/Content/Offers/Sell_minor_healing_potion" % member_id)
	check(sale_row.get_node("SellOne") is Button, "Shop shows a sell action for owned items.")
	var potions_before_sale := get_item_quantity(member, MinorHealingPotion.id)
	await click_button(sale_row.get_node("SellOne"))
	check(run_map.run_state.gold == 37 and get_item_quantity(member, MinorHealingPotion.id) == potions_before_sale - 1, "Selling one potion adds its configured sale value and removes one item.")
	check(run_map.gold_label.text == "GOLD  37", "Run Map Gold updates after a sale.")
	run_map.sell_shop_item(member_id, ItemStack.new(MinorHealingPotion, 1), 1)
	check(run_map.run_state.gold == 37, "Shop rejects an item stack that the member does not own.")
	var bulk_stack := ItemStack.new(MinorHealingPotion, 3)
	member.item_inventory.append(bulk_stack)
	run_map.shop_panel.refresh_gold(run_map.run_state.gold)
	var offers_after_refresh: VBoxContainer = run_map.shop_panel.get_node("Margin/ShopCard/Column/Body/Trade/OffersScroll/PartyRows/%s/Content/Offers" % member_id)
	var sell_all_button: Button
	for row in offers_after_refresh.get_children():
		if row is HBoxContainer and row.get_node_or_null("SellAll") != null and row.get_child(0).text.contains("x3"):
			sell_all_button = row.get_node("SellAll")
			break
	check(sell_all_button != null, "Shop offers to sell an entire owned stack.")
	if sell_all_button != null:
		sell_all_button.pressed.emit()
	check(run_map.run_state.gold == 73 and not member.item_inventory.has(bulk_stack), "Selling a full stack pays for every item and removes the empty stack.")
	var quest_item := ItemData.new()
	quest_item.id = "test_quest_item"
	quest_item.category = ItemData.Category.QUEST
	quest_item.sell_price = 100
	var quest_stack := ItemStack.new(quest_item, 1)
	member.item_inventory.append(quest_stack)
	run_map.sell_shop_item(member_id, quest_stack, 1)
	check(run_map.run_state.gold == 73 and member.item_inventory.has(quest_stack), "Quest items cannot be sold even if they have a price.")
	var bought_dagger: EquipmentData = member.equipment_inventory[-1]
	var gear_count := member.equipment_inventory.size()
	run_map.sell_shop_item(member_id, bought_dagger, 1)
	check(run_map.run_state.gold == 85 and member.equipment_inventory.size() == gear_count - 1, "Selling unequipped equipment removes it and pays half its base price.")
	var equipped: EquipmentData = member.equipped_items.get(0)
	if equipped != null:
		run_map.sell_shop_item(member_id, equipped, 1)
		check(run_map.run_state.gold == 85 and member.equipment_inventory.has(equipped), "Equipped equipment cannot be sold.")
	run_map.queue_free()
	for failure in failures:
		push_error(failure)
	print("SHOP_NODE_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func get_item_quantity(member: CombatantState, item_id: String) -> int:
	var total := 0
	for stack in member.item_inventory:
		if stack != null and stack.item != null and stack.item.id == item_id:
			total += stack.quantity
	return total


func make_shop_node(shop: Resource) -> MapNodeData:
	var node := MapNodeData.new()
	node.node_type = MapNodeData.NodeType.SHOP
	node.shop_data = shop
	return node


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func click_button(button: Button) -> void:
	await process_frame
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	point = button.get_global_rect().get_center()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = point
	click.global_position = point
	click.pressed = true
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	await process_frame
