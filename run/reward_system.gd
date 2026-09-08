class_name RewardSystem
extends RefCounted


func generate_choices(run_state: RunState, node: MapNodeData) -> Array[RewardOptionData]:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_state.seed ^ node.id.hash() ^ 0x52E4A7
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


func claim(run_state: RunState, node_id: String, reward: RewardOptionData) -> bool:
	if run_state == null or reward == null or run_state.reward_claimed_node_ids.has(node_id):
		return false
	match reward.reward_type:
		RewardOptionData.RewardType.GOLD:
			run_state.gold += reward.amount
		RewardOptionData.RewardType.MAX_HP:
			run_state.party_max_hp_bonus += reward.amount
		RewardOptionData.RewardType.ABILITY_POINT:
			run_state.party_ability_point_bonus += reward.amount
		RewardOptionData.RewardType.EXPERIENCE:
			for character in run_state.party_progression_states.values():
				if character is CombatantState:
					ProgressionSystem.new().add_experience(character, reward.amount)
	run_state.reward_claimed_node_ids.append(node_id)
	run_state.reward_history.append({"node_id": node_id, "reward_id": reward.id, "amount": reward.amount})
	return true
