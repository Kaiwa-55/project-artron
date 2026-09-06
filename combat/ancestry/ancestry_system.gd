class_name AncestrySystem
extends RefCounted


func apply_ancestry(combatant: CombatantState) -> void:
	if combatant == null or not combatant.has_meta("ancestry_data"):
		return
	var ancestry = combatant.get_meta("ancestry_data")
	if ancestry == null:
		return
	combatant.ancestry_id = ancestry.id
	combatant.ancestry_display_name = ancestry.display_name
	combatant.base_max_hp += ancestry.base_hp
	combatant.base_speed += ancestry.speed_feet
	apply_attribute_choices(combatant, ancestry)
	for trait_data in ancestry.traits:
		if trait_data != null and not combatant.active_traits.has(trait_data):
			combatant.active_traits.append(trait_data)
	for ability in ancestry.granted_abilities:
		if ability == null:
			continue
		if not combatant.available_abilities.has(ability):
			combatant.available_abilities.append(ability)
		if not combatant.granted_ability_ids.has(ability.id):
			combatant.granted_ability_ids.append(ability.id)
		if ability.auto_equip_on_grant and not combatant.equipped_abilities.has(ability.id):
			combatant.equipped_abilities.append(ability.id)


func apply_attribute_choices(combatant: CombatantState, ancestry) -> void:
	var used: Dictionary = {}
	var applied := 0
	for attribute_value in combatant.ancestry_attribute_choices:
		if applied >= ancestry.attribute_choice_count or used.has(attribute_value):
			continue
		if attribute_value < AttributeTypes.Type.STRENGTH or attribute_value > AttributeTypes.Type.CHARISMA:
			continue
		used[attribute_value] = true
		applied += 1
		match attribute_value:
			AttributeTypes.Type.STRENGTH: combatant.strength += ancestry.attribute_bonus_per_choice
			AttributeTypes.Type.DEXTERITY: combatant.dexterity += ancestry.attribute_bonus_per_choice
			AttributeTypes.Type.CONSTITUTION: combatant.constitution += ancestry.attribute_bonus_per_choice
			AttributeTypes.Type.INTELLIGENCE: combatant.intelligence += ancestry.attribute_bonus_per_choice
			AttributeTypes.Type.WISDOM: combatant.wisdom += ancestry.attribute_bonus_per_choice
			AttributeTypes.Type.CHARISMA: combatant.charisma += ancestry.attribute_bonus_per_choice
