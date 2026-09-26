extends SceneTree

const RunMapScene := preload("res://scenes/run/RunMap.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var run_map = RunMapScene.instantiate()
	root.add_child(run_map)
	await process_frame
	var state: RunState = run_map.run_state
	var member_id := String(state.party_progression_states.keys()[0])
	var member: CombatantState = state.party_progression_states[member_id]
	var system := RewardSystem.new()
	var item_node := make_treasure("test_treasure_item")
	var equipment_node := make_treasure("test_treasure_equipment")
	var route_node := make_treasure("test_treasure_route")
	state.nodes.append_array([item_node, equipment_node, route_node])
	var choices := system.generate_choices(state, item_node)
	check(choices.size() == 4, "Treasure offers four choices")
	check(signature(choices) == signature(system.generate_choices(state, item_node)), "Treasure choices repeat for the same seed and node")
	var item_reward: RewardOptionData
	for choice in choices:
		if choice.reward_type == RewardOptionData.RewardType.ITEM:
			item_reward = choice
	check(item_reward != null, "Treasure includes an item")
	var before_items := count_item(member, item_reward.product.id)
	check(not system.claim(state, item_node.id, item_reward, "missing_member"), "Item reward requires a valid recipient")
	check(system.claim(state, item_node.id, item_reward, member_id), "Item reward can be claimed")
	check(count_item(member, item_reward.product.id) == before_items + item_reward.amount, "Claim adds the item to the selected member")
	check(not system.claim(state, item_node.id, item_reward, member_id), "Treasure cannot be claimed twice")
	var gear_reward: RewardOptionData
	for choice in system.generate_choices(state, equipment_node):
		if choice.reward_type == RewardOptionData.RewardType.EQUIPMENT:
			gear_reward = choice
	check(gear_reward != null, "Treasure includes equipment")
	var before_equipment := member.equipment_inventory.size()
	check(system.claim(state, equipment_node.id, gear_reward, member_id), "Equipment reward can be claimed")
	check(member.equipment_inventory.size() == before_equipment + 1 and member.equipment_inventory[-1] != gear_reward.product, "Equipment is added as an independent inventory copy")
	var forged := RewardOptionData.new()
	forged.id = "treasure_gold"
	forged.reward_type = RewardOptionData.RewardType.GOLD
	forged.amount = 99999
	check(not system.claim(state, route_node.id, forged), "Treasure rejects a reward that was not offered")
	state.get_current_node().next_node_ids.append(route_node.id)
	run_map.selected_node_id = route_node.id
	run_map.confirm_selected_node()
	await process_frame
	await process_frame
	var reward_scene := current_scene
	check(reward_scene != null and reward_scene.name == "RewardSelection", "Entering Treasure opens reward selection")
	if reward_scene != null and reward_scene.name == "RewardSelection":
		check(reward_scene.title_label.text == "TREASURE CACHE", "Treasure has its own heading")
		check(reward_scene.recipient_picker != null and reward_scene.recipient_picker.item_count == state.party_progression_states.size(), "Treasure lets the player choose an item recipient")
		var selected_id := String(reward_scene.recipient_picker.get_item_metadata(reward_scene.recipient_picker.item_count - 1))
		var selected_member: CombatantState = state.party_progression_states[selected_id]
		reward_scene.recipient_picker.select(reward_scene.recipient_picker.item_count - 1)
		for card in reward_scene.cards.get_children():
			var choice: RewardOptionData = card.get_meta("reward")
			if choice.reward_type != RewardOptionData.RewardType.ITEM:
				continue
			var before := count_item(selected_member, choice.product.id)
			card.pressed.emit()
			check(count_item(selected_member, choice.product.id) == before + choice.amount and state.reward_claimed_node_ids.has(route_node.id), "Selecting a Treasure card grants the item and records the claim")
			break
		await create_timer(0.5).timeout
		check(current_scene != null and current_scene.get_script().resource_path == "res://scenes/run/run_map.gd", "Claiming Treasure returns to the Run Map")
	for failure in failures:
		push_error(failure)
	print("TREASURE_NODE_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func make_treasure(node_id: String) -> MapNodeData:
	var node := MapNodeData.new()
	node.id = node_id
	node.node_type = MapNodeData.NodeType.TREASURE
	return node


func signature(choices: Array[RewardOptionData]) -> String:
	var parts: Array[String] = []
	for choice in choices:
		parts.append("%s:%d:%s" % [choice.id, choice.amount, choice.product.resource_path if choice.product != null else ""])
	return "|".join(parts)


func count_item(member: CombatantState, item_id: String) -> int:
	var total := 0
	for stack in member.item_inventory:
		if stack != null and stack.item != null and stack.item.id == item_id:
			total += stack.quantity
	return total


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
