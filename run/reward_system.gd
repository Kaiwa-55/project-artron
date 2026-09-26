class_name RewardSystem
extends RefCounted


func generate_choices(run_state: RunState, node: MapNodeData) -> Array[RewardOptionData]:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_state.seed ^ node.id.hash() ^ 0x52E4A7
	if node.node_type == MapNodeData.NodeType.TREASURE:
		return generate_treasure_choices(rng)
	var tier_bonus := 0
	if node.node_type == MapNodeData.NodeType.ELITE:
		tier_bonus = 15
	elif node.node_type == MapNodeData.NodeType.BOSS:
		tier_bonus = 30
	var experience_reward := 100
	if node.node_type == MapNodeData.NodeType.ELITE:
		experience_reward = 200
	elif node.node_type == MapNodeData.NodeType.BOSS:
		experience_reward = 400
	var choices: Array[RewardOptionData] = [
		create_reward("gold", RewardOptionData.RewardType.GOLD, "War Spoils", "Currency for shops during this Run.", rng.randi_range(35, 55) + tier_bonus),
		create_reward("vitality", RewardOptionData.RewardType.MAX_HP, "Hardened Resolve", "Increase every party member's Max HP for this Run.", 3 if tier_bonus == 0 else 4),
		create_reward("training", RewardOptionData.RewardType.ABILITY_POINT, "Combat Insight", "Every party member gains an Ability Point for this Run.", 1),
		create_reward("experience", RewardOptionData.RewardType.EXPERIENCE, "Lessons of Battle", "Every party member gains experience. Level-up choices can be spent before the next Combat.", experience_reward),
	]
	shuffle_choices(choices, rng)
	return choices


func generate_treasure_choices(rng: RandomNumberGenerator) -> Array[RewardOptionData]:
	var choices: Array[RewardOptionData] = [
		create_reward("treasure_gold", RewardOptionData.RewardType.GOLD, "Coin Cache", "Gold for the party's next shop visit.", rng.randi_range(45, 70)),
		create_reward("treasure_training", RewardOptionData.RewardType.ABILITY_POINT, "Ancient Manual", "Every party member gains one Ability Point.", 1),
	]
	var catalog: ShopCatalog = load("res://data/shop/default_shop_catalog.tres")
	var items: Array[Resource] = []
	var equipment: Array[Resource] = []
	for shop in catalog.shops:
		if shop == null:
			continue
		for offer in shop.get_offers():
			if offer == null or offer.product == null:
				continue
			if offer.product is ItemData and not items.has(offer.product):
				items.append(offer.product)
			elif offer.product is EquipmentData and not equipment.has(offer.product):
				equipment.append(offer.product)
	if not items.is_empty():
		var item := items[rng.randi_range(0, items.size() - 1)]
		var item_reward := create_reward("treasure_item", RewardOptionData.RewardType.ITEM, item.display_name, "Choose one party member to receive this item.", 2)
		item_reward.product = item
		choices.append(item_reward)
	if not equipment.is_empty():
		var gear := equipment[rng.randi_range(0, equipment.size() - 1)]
		var gear_reward := create_reward("treasure_equipment", RewardOptionData.RewardType.EQUIPMENT, gear.display_name, "Choose one party member to receive this equipment.", 1)
		gear_reward.product = gear
		choices.append(gear_reward)
	shuffle_choices(choices, rng)
	return choices


func create_reward(id: String, type: RewardOptionData.RewardType, title: String, description: String, amount: int) -> RewardOptionData:
	var reward := RewardOptionData.new()
	reward.id = id
	reward.reward_type = type
	reward.display_name = title
	reward.description = description
	reward.amount = amount
	return reward


func shuffle_choices(choices: Array[RewardOptionData], rng: RandomNumberGenerator) -> void:
	for index in range(choices.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary := choices[index]
		choices[index] = choices[swap_index]
		choices[swap_index] = temporary


func claim(run_state: RunState, node_id: String, reward: RewardOptionData, recipient_id: String = "") -> bool:
	if run_state == null or reward == null or run_state.reward_claimed_node_ids.has(node_id):
		return false
	var node := run_state.get_node(node_id)
	if node == null:
		return false
	var offered: RewardOptionData
	for option in generate_choices(run_state, node):
		if option.id != reward.id or option.reward_type != reward.reward_type or option.amount != reward.amount:
			continue
		if option.product == reward.product or (option.product is EquipmentData and reward.product is EquipmentData and option.product.id == reward.product.id):
			offered = option
			break
	if offered == null:
		return false
	if offered.reward_type in [RewardOptionData.RewardType.ITEM, RewardOptionData.RewardType.EQUIPMENT] and not run_state.party_progression_states.get(recipient_id) is CombatantState:
		return false
	match offered.reward_type:
		RewardOptionData.RewardType.GOLD:
			run_state.gold += offered.amount
		RewardOptionData.RewardType.MAX_HP:
			run_state.party_max_hp_bonus += offered.amount
		RewardOptionData.RewardType.ABILITY_POINT:
			run_state.party_ability_point_bonus += offered.amount
		RewardOptionData.RewardType.EXPERIENCE:
			for character in run_state.party_progression_states.values():
				if character is CombatantState:
					ProgressionSystem.new().add_experience(character, offered.amount)
		RewardOptionData.RewardType.ITEM:
			grant_item(run_state.party_progression_states[recipient_id], offered.product, offered.amount)
		RewardOptionData.RewardType.EQUIPMENT:
			for index in range(offered.amount):
				run_state.party_progression_states[recipient_id].equipment_inventory.append(offered.product.duplicate(true))
	run_state.reward_claimed_node_ids.append(node_id)
	run_state.reward_history.append({"node_id": node_id, "reward_id": offered.id, "amount": offered.amount, "recipient_id": recipient_id})
	return true


func grant_item(member: CombatantState, item: ItemData, quantity: int) -> void:
	var remaining := quantity
	for stack in member.item_inventory:
		if stack != null and stack.item == item and stack.quantity < item.maximum_stack_size:
			var added := mini(remaining, item.maximum_stack_size - stack.quantity)
			stack.quantity += added
			remaining -= added
			if remaining <= 0:
				return
	while remaining > 0:
		var added := mini(remaining, item.maximum_stack_size)
		member.item_inventory.append(ItemStack.new(item, added))
		remaining -= added
