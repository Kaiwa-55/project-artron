class_name CharacterClassSystem
extends RefCounted


func apply_class(combatant: CombatantState) -> void:
	if combatant == null or not combatant.has_meta("class_data"):
		return
	var character_class = combatant.get_meta("class_data")
	if character_class == null:
		return
	combatant.class_id = character_class.id
	combatant.class_display_name = character_class.display_name
	if character_class.base_speed_feet >= 0.0:
		# Movement speed is composed from Ancestry and Class.
		combatant.base_speed += character_class.base_speed_feet
	if character_class.base_mana >= 0:
		combatant.base_max_mana = character_class.base_mana
	if character_class.base_faith >= 0:
		combatant.max_faith = character_class.base_faith
		combatant.faith = combatant.max_faith
	apply_fixed_attribute_bonuses(combatant, character_class.fixed_attribute_bonuses)
	apply_attribute_choices(combatant, character_class)
	for trait_data in character_class.traits:
		if trait_data != null and not combatant.active_traits.has(trait_data): combatant.active_traits.append(trait_data)
	for ability in character_class.granted_abilities:
		if ability == null:
			continue
		if not combatant.available_abilities.has(ability):
			combatant.available_abilities.append(ability)
		if ability.auto_equip_on_grant and combatant.level >= ability.required_level:
			if not combatant.equipped_abilities.has(ability.id):
				combatant.equipped_abilities.append(ability.id)
			if not combatant.granted_ability_ids.has(ability.id):
				combatant.granted_ability_ids.append(ability.id)
	for ability_id in character_class.auto_equipped_ability_ids:
		var ability = find_granted_ability(character_class, ability_id)
		if ability != null and combatant.level >= ability.required_level:
			if not combatant.equipped_abilities.has(ability_id):
				combatant.equipped_abilities.append(ability_id)
			if not combatant.granted_ability_ids.has(ability_id):
				combatant.granted_ability_ids.append(ability_id)


func find_granted_ability(character_class, ability_id: String):
	for ability in character_class.granted_abilities:
		if ability != null and ability.id == ability_id:
			return ability
	return null


func apply_fixed_attribute_bonuses(combatant: CombatantState, bonuses: Dictionary) -> void:
	for attribute_value in bonuses:
		apply_attribute_bonus(combatant, int(attribute_value), int(bonuses[attribute_value]))


func apply_attribute_choices(combatant: CombatantState, character_class) -> void:
	var used: Dictionary = {}
	var applied := 0
	var selected_choices: Array = []
	if combatant.has_meta("class_attribute_choices"):
		selected_choices = combatant.get_meta("class_attribute_choices")
	for attribute_value in selected_choices:
		if applied >= character_class.attribute_choice_count or used.has(attribute_value):
			continue
		if not character_class.attribute_choice_options.has(attribute_value):
			continue
		used[attribute_value] = true
		applied += 1
		apply_attribute_bonus(combatant, attribute_value, character_class.attribute_bonus_per_choice)


func apply_attribute_bonus(combatant: CombatantState, attribute_value: int, amount: int) -> void:
	match attribute_value:
		AttributeTypes.Type.STRENGTH: combatant.strength += amount
		AttributeTypes.Type.DEXTERITY: combatant.dexterity += amount
		AttributeTypes.Type.CONSTITUTION: combatant.constitution += amount
		AttributeTypes.Type.INTELLIGENCE: combatant.intelligence += amount
		AttributeTypes.Type.WISDOM: combatant.wisdom += amount
		AttributeTypes.Type.CHARISMA: combatant.charisma += amount
