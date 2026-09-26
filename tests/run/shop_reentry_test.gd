extends SceneTree

const RunMapScene := preload("res://scenes/run/RunMap.tscn")
const HealerShop := preload("res://data/shop/healer_shop.tres")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var failures: Array[String] = []
	root.size = Vector2i(640, 360)
	var run_map = RunMapScene.instantiate()
	root.add_child(run_map)
	await process_frame
	var shop_node := MapNodeData.new()
	shop_node.id = "reentry_shop"
	shop_node.node_type = MapNodeData.NodeType.SHOP
	shop_node.floor_index = 1
	shop_node.shop_data = HealerShop
	run_map.run_state.get_current_node().next_node_ids.append(shop_node.id)
	run_map.run_state.nodes.append(shop_node)
	run_map.build_map()
	run_map.refresh_map_state()
	await process_frame
	run_map.select_node(shop_node.id)
	run_map.confirm_selected_node()
	check(run_map.shop_panel.visible, "Entering a Shop opens it", failures)
	var completed_count: int = run_map.run_state.completed_node_ids.size()
	run_map.shop_panel.get_node("Margin/ShopCard/Column/Header/CloseButton").pressed.emit()
	check(not run_map.shop_panel.visible and not run_map.node_buttons[shop_node.id].disabled, "X closes the Shop and leaves its map node available", failures)
	run_map.open_party_inventory("player")
	check(run_map.character_panel.visible, "Inventory can open after leaving the Shop", failures)
	run_map.character_panel.hide()
	run_map.node_buttons[shop_node.id].pressed.emit()
	check(run_map.shop_panel.visible, "Clicking the current Shop node reopens it", failures)
	check(run_map.run_state.current_node_id == shop_node.id and run_map.run_state.completed_node_ids.size() == completed_count, "Reopening does not consume another Run node", failures)
	run_map.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("SHOP_REENTRY_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
