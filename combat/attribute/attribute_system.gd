class_name AttributeSystem
extends RefCounted



func get_attribute(
	combatant: CombatantState,
	attribute_type: AttributeTypes.Type
) -> int:

	match attribute_type:

		AttributeTypes.Type.STRENGTH:
			return combatant.strength

		AttributeTypes.Type.DEXTERITY:
			return combatant.dexterity

		AttributeTypes.Type.CONSTITUTION:
			return combatant.constitution

		AttributeTypes.Type.INTELLIGENCE:
			return combatant.intelligence

		AttributeTypes.Type.WISDOM:
			return combatant.wisdom

		AttributeTypes.Type.CHARISMA:
			return combatant.charisma

	return 0


func get_attribute_modifier(
	combatant: CombatantState,
	attribute_type: AttributeTypes.Type
) -> int:

	var attribute := get_attribute(
		combatant,
		attribute_type
	)

	return floori(float(attribute - 10) / 2.0)
