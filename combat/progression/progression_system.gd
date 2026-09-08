class_name ProgressionSystem
extends RefCounted

const DefaultProgression = preload("res://data/progression/default_progression.tres")
const StatSystemScript = preload("res://combat/stat/stat_system.gd")
const AbilityLearningResultScript = preload("res://combat/progression/ability_learning_result.gd")
const AttributeChoiceResultScript = preload("res://combat/progression/attribute_choice_result.gd")

var progression_data: ProgressionData


func _init(data: ProgressionData = null) -> void:
	progression_data = data if data != null else DefaultProgression


func initialize_character(character: CombatantState) -> ProgressionResult:
	if character == null:
		return ProgressionResult.failure("Character is required.")
	if progression_data == null or not progression_data.is_valid():
		return ProgressionResult.failure("Progression data is invalid.")
	var result := _create_result(character)
	character.level = clampi(character.level, 1, progression_data.max_level)
	character.experience = maxi(character.experience, progression_data.get_cumulative_xp_for_level(character.level))
	_grant_rewards_through_level(character, character.level, result)
	var selected_cost_failure := _apply_preselected_ability_costs(character)
	if not selected_cost_failure.is_empty():
		return ProgressionResult.failure(selected_cost_failure)
	StatSystemScript.new().refresh_combatant(character)
	_finish_result(character, result)
	return result


func add_experience(character: CombatantState, amount: int) -> ProgressionResult:
	if character == null:
		return ProgressionResult.failure("Character is required.")
	if progression_data == null or not progression_data.is_valid():
		return ProgressionResult.failure("Progression data is invalid.")
	if amount < 0:
		return ProgressionResult.failure("Experience gained cannot be negative.")

	var result := _create_result(character)
	character.level = clampi(character.level, 1, progression_data.max_level)
	character.experience = maxi(0, character.experience)
	_grant_rewards_through_level(character, character.level, result)
	var selected_cost_failure := _apply_preselected_ability_costs(character)
	if not selected_cost_failure.is_empty():
		return ProgressionResult.failure(selected_cost_failure)

	var maximum_xp := progression_data.get_cumulative_xp_for_level(progression_data.max_level)
	character.experience = mini(maximum_xp, character.experience + amount)
	var resolved_level := maxi(character.level, progression_data.get_level_for_xp(character.experience))
	resolved_level = mini(resolved_level, progression_data.max_level)
	for level in range(character.level + 1, resolved_level + 1):
		character.level = level
		result.levels_gained.append(level)
		_grant_level_rewards(character, level, result)
	character.progression_rewards_granted_through_level = maxi(
		character.progression_rewards_granted_through_level,
		character.level
	)
	StatSystemScript.new().refresh_combatant(character)
	_finish_result(character, result)
	return result


func can_level_up(character: CombatantState) -> bool:
	if character == null or progression_data == null or not progression_data.is_valid():
		return false
	if character.level >= progression_data.max_level:
		return false
	return character.experience >= progression_data.get_cumulative_xp_for_level(character.level + 1)


func get_xp_to_next_level(character: CombatantState) -> int:
	if character == null or progression_data == null or not progression_data.is_valid():
		return 0
	return progression_data.get_xp_to_next_level(character.level, character.experience)


func learn_ability(character: CombatantState, ability: AbilityData) -> RefCounted:
	var reason := get_learn_ability_failure_reason(character, ability)
	if not reason.is_empty():
		return AbilityLearningResultScript.failure(reason)
	var result = AbilityLearningResultScript.new()
	character.ability_points -= ability.ability_point_cost
	_consume_pending_choice(character, "ability_points_remaining", ability.ability_point_cost)
	character.selected_ability_ids.append(ability.id)
	if not character.available_abilities.has(ability):
		character.available_abilities.append(ability)
	if not character.equipped_abilities.has(ability.id):
		character.equipped_abilities.append(ability.id)
	_grant_ability_skills(character, ability)
	result.success = true
	result.ability_id = ability.id
	result.ability_name = ability.display_name
	result.points_spent = ability.ability_point_cost
	result.remaining_ability_points = character.ability_points
	return result


func _grant_ability_skills(character: CombatantState, ability: AbilityData) -> void:
	for skill in ability.granted_skills:
		if skill != null and not character.available_skills.has(skill):
			character.available_skills.append(skill)


func can_learn_ability(character: CombatantState, ability: AbilityData) -> bool:
	return get_learn_ability_failure_reason(character, ability).is_empty()


func get_learn_ability_failure_reason(character: CombatantState, ability: AbilityData) -> String:
	if character == null:
		return "Character is required."
	if ability == null or ability.id.is_empty():
		return "Ability is invalid."
	if not ability.granted_skills.is_empty():
		return "%s must be selected through a Spell Choice." % ability.display_name
	if character.selected_ability_ids.has(ability.id) or character.granted_ability_ids.has(ability.id):
		return "%s is already learned." % ability.display_name
	if ability.auto_equip_on_grant:
		return "%s is granted automatically and cannot be purchased." % ability.display_name
	if character.level < ability.required_level:
		return "%s requires Level %d." % [ability.display_name, ability.required_level]
	for trait_id in ability.required_trait_ids:
		if not _character_has_trait(character, trait_id):
			return "%s requires the %s Trait." % [ability.display_name, trait_id.capitalize()]
	if not ability.prerequisite_id.is_empty() and not _has_learned_ability(character, ability.prerequisite_id):
		return "%s requires %s first." % [ability.display_name, ability.prerequisite_id.capitalize()]
	if character.ability_points < ability.ability_point_cost:
		return "%s requires %d Ability Point(s)." % [ability.display_name, ability.ability_point_cost]
	return ""


func get_learnable_abilities(character: CombatantState, ability_catalog: Array) -> Array[AbilityData]:
	var learnable: Array[AbilityData] = []
	for ability in ability_catalog:
		if ability is AbilityData and can_learn_ability(character, ability):
			learnable.append(ability)
	return learnable


func increase_attribute(character: CombatantState, attribute: AttributeTypes.Type) -> RefCounted:
	if character == null:
		return AttributeChoiceResultScript.failure("Character is required.")
	if character.attribute_points <= 0:
		return AttributeChoiceResultScript.failure("No Attribute Points remain.")
	if attribute < AttributeTypes.Type.STRENGTH or attribute > AttributeTypes.Type.CHARISMA:
		return AttributeChoiceResultScript.failure("Attribute is invalid.")
	match attribute:
		AttributeTypes.Type.STRENGTH: character.strength += 1
		AttributeTypes.Type.DEXTERITY: character.dexterity += 1
		AttributeTypes.Type.CONSTITUTION: character.constitution += 1
		AttributeTypes.Type.INTELLIGENCE: character.intelligence += 1
		AttributeTypes.Type.WISDOM: character.wisdom += 1
		AttributeTypes.Type.CHARISMA: character.charisma += 1
	character.attribute_points -= 1
	character.selected_level_attributes.append(attribute)
	_consume_pending_choice(character, "attribute_points_remaining", 1)
	StatSystemScript.new().refresh_combatant(character)
	var result = AttributeChoiceResultScript.new()
	result.success = true
	result.attribute = attribute
	result.new_value = _get_attribute_value(character, attribute)
	result.remaining_attribute_points = character.attribute_points
	return result


func has_pending_choices(character: CombatantState) -> bool:
	return character != null and (character.ability_points > 0 or character.attribute_points > 0)


func _grant_rewards_through_level(character: CombatantState, target_level: int, result: ProgressionResult) -> void:
	var first_ungranted := maxi(1, character.progression_rewards_granted_through_level + 1)
	for level in range(first_ungranted, target_level + 1):
		_grant_level_rewards(character, level, result)
	character.progression_rewards_granted_through_level = maxi(
		character.progression_rewards_granted_through_level,
		target_level
	)


func _grant_level_rewards(character: CombatantState, level: int, result: ProgressionResult) -> void:
	var ability_points := progression_data.get_ability_points_for_level(level)
	var attribute_points := progression_data.get_attribute_points_for_level(level)
	character.ability_points += ability_points
	character.attribute_points += attribute_points
	result.ability_points_gained += ability_points
	result.attribute_points_gained += attribute_points
	var class_reward := _grant_class_rewards(character, level, result)
	if ability_points > 0 or attribute_points > 0:
		character.pending_level_up_choices.append({
			"level": level,
			"ability_points_remaining": ability_points,
			"attribute_points_remaining": attribute_points
		})
	result.level_rewards.append({
		"level": level,
		"ability_points": ability_points,
		"attribute_points": attribute_points,
		"requires_ability_choice": ability_points > 0,
		"requires_attribute_choice": attribute_points > 0,
		"max_hp_gain": class_reward.max_hp_gain,
		"max_mana_gain": class_reward.max_mana_gain,
		"granted_ability_ids": class_reward.granted_ability_ids
	})


func _grant_class_rewards(character: CombatantState, level: int, result: ProgressionResult) -> Dictionary:
	var rewards := {"max_hp_gain": 0, "max_mana_gain": 0, "granted_ability_ids": []}
	if not character.has_meta("class_data"):
		return rewards
	var character_class = character.get_meta("class_data")
	if character_class == null or not character_class.has_method("get_progression_entry"):
		return rewards
	var entry = character_class.get_progression_entry(level)
	if entry == null:
		return rewards
	character.base_max_hp += entry.max_hp_gain
	character.base_max_mana += entry.max_mana_gain
	result.max_hp_gained += entry.max_hp_gain
	result.max_mana_gained += entry.max_mana_gain
	rewards.max_hp_gain = entry.max_hp_gain
	rewards.max_mana_gain = entry.max_mana_gain
	for ability in entry.granted_abilities:
		if ability == null:
			continue
		if not character.available_abilities.has(ability):
			character.available_abilities.append(ability)
		if not character.granted_ability_ids.has(ability.id):
			character.granted_ability_ids.append(ability.id)
		if ability.auto_equip_on_grant and not character.equipped_abilities.has(ability.id):
			character.equipped_abilities.append(ability.id)
		_grant_ability_skills(character, ability)
		if not result.granted_ability_ids.has(ability.id):
			result.granted_ability_ids.append(ability.id)
		if not rewards.granted_ability_ids.has(ability.id):
			rewards.granted_ability_ids.append(ability.id)
	return rewards


func _has_learned_ability(character: CombatantState, ability_id: String) -> bool:
	return character.selected_ability_ids.has(ability_id) or character.granted_ability_ids.has(ability_id)


func _character_has_trait(character: CombatantState, trait_id: String) -> bool:
	for trait_data in character.active_traits:
		if trait_data != null and trait_data.id == trait_id:
			return true
	return false


func _consume_pending_choice(character: CombatantState, key: String, amount: int) -> void:
	var remaining := amount
	var index := 0
	while index < character.pending_level_up_choices.size() and remaining > 0:
		var choice: Dictionary = character.pending_level_up_choices[index]
		var available := maxi(0, int(choice.get(key, 0)))
		var consumed := mini(available, remaining)
		choice[key] = available - consumed
		remaining -= consumed
		character.pending_level_up_choices[index] = choice
		if int(choice.get("ability_points_remaining", 0)) <= 0 and int(choice.get("attribute_points_remaining", 0)) <= 0:
			character.pending_level_up_choices.remove_at(index)
		else:
			index += 1


func _get_attribute_value(character: CombatantState, attribute: AttributeTypes.Type) -> int:
	match attribute:
		AttributeTypes.Type.STRENGTH: return character.strength
		AttributeTypes.Type.DEXTERITY: return character.dexterity
		AttributeTypes.Type.CONSTITUTION: return character.constitution
		AttributeTypes.Type.INTELLIGENCE: return character.intelligence
		AttributeTypes.Type.WISDOM: return character.wisdom
		AttributeTypes.Type.CHARISMA: return character.charisma
	return 0


func _apply_preselected_ability_costs(character: CombatantState) -> String:
	if character.selected_ability_costs_applied:
		return ""
	var total_cost := 0
	for ability_id in character.selected_ability_ids:
		var ability = _find_available_ability(character, ability_id)
		if ability == null:
			return "Selected Ability %s is not available." % ability_id
		total_cost += ability.ability_point_cost
		_grant_ability_skills(character, ability)
	if total_cost > character.ability_points:
		return "Selected Abilities require %d Ability Points, but only %d are available." % [total_cost, character.ability_points]
	character.ability_points -= total_cost
	_consume_pending_choice(character, "ability_points_remaining", total_cost)
	character.selected_ability_costs_applied = true
	return ""


func _find_available_ability(character: CombatantState, ability_id: String):
	for ability in character.available_abilities:
		if ability != null and ability.id == ability_id:
			return ability
	return null


func _create_result(character: CombatantState) -> ProgressionResult:
	var result := ProgressionResult.new()
	result.previous_experience = character.experience
	result.current_experience = character.experience
	result.previous_level = character.level
	result.current_level = character.level
	return result


func _finish_result(character: CombatantState, result: ProgressionResult) -> void:
	result.success = true
	result.current_experience = character.experience
	result.experience_gained = maxi(0, result.current_experience - result.previous_experience)
	result.current_level = character.level
