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
	check(run_map.shop_panel.get_node("Margin/ShopCard/Column/Header/Title").text == HealerShop.display_name, "Shop UI uses the selected Shop resource name.")
	var visual_shop: Resource = HealerShop.duplicate(true)
	visual_shop.set("banner_texture", TestIcon)
	var visual_offers: Array = visual_shop.get("offers")
	visual_offers[0].set("icon_texture", TestIcon)
	run_map.open_shop(make_shop_node(visual_shop))
	await process_frame
	check(run_map.shop_panel.get_node("Margin/ShopCard/Column/Banner").visible, "Shop displays a configured banner image.")
	check(run_map.shop_panel.get_node("Margin/ShopCard/Column/Banner").custom_minimum_size.y == 110.0, "Shop banner is sized for the logical viewport while remaining large on screen.")
	check(run_map.shop_panel.get_node("Margin/ShopCard/Column/OffersScroll") is ScrollContainer, "Shop places its purchase list inside a scrollable area.")
	var banner_rect: Rect2 = run_map.shop_panel.get_node("Margin/ShopCard/Column/Banner").get_global_rect()
	check(banner_rect.size.y <= 150.0, "Shop art remains bounded so the offer list stays visible.")
	check(run_map.shop_panel.get_node("Margin/ShopCard/Column/OffersScroll/PartyRows").get_child_count() == run_map.run_state.party_progression_states.size(), "Shop offers a purchase destination for every party member.")
	var player_offers: VBoxContainer = run_map.shop_panel.get_node("Margin/ShopCard/Column/OffersScroll/PartyRows/%s/Content/Offers" % member_id)
	check(player_offers.get_child(0).get_node("Icon").visible, "Shop displays a configured offer image.")
	player_offers.get_child(0).get_child(2).pressed.emit()
	check(run_map.run_state.gold == 25, "Buying an item deducts its Gold cost once.")
	check(get_item_quantity(member, MinorHealingPotion.id) == count_before + 1, "Buying an item adds it to the selected member inventory.")
	run_map.purchase_shop_item(member_id, MinorHealingPotion, 2, 30)
	check(run_map.run_state.gold == 25 and get_item_quantity(member, MinorHealingPotion.id) == count_before + 1, "Shop rejects a purchase when Gold is insufficient.")
	run_map.open_shop(make_shop_node(OutfitterShop))
	run_map.run_state.gold = 70
	run_map.shop_panel.refresh_gold(run_map.run_state.gold)
	player_offers = run_map.shop_panel.get_node("Margin/ShopCard/Column/OffersScroll/PartyRows/%s/Content/Offers" % member_id)
	check(player_offers.get_child_count() >= 2, "A different Shop resource can offer a different item list.")
	player_offers.get_child(1).get_child(2).pressed.emit()
	check(member.equipment_inventory.any(func(equipment): return equipment != null and equipment.id == "dagger"), "Shop can sell configured equipment as well as consumables.")
	run_map.shop_panel.get_node("Margin/ShopCard/Column/LeaveButton").pressed.emit()
	check(not run_map.shop_panel.visible, "Player can leave the Shop and continue the Run.")
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
