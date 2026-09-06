class_name TraitSystem
extends RefCounted

const TraitDataScript = preload("res://data/trait/trait_data.gd")


func has_trait(combatant, trait_id: String) -> bool:
	if combatant == null:
		return false
	for trait_data in combatant.active_traits:
		if trait_data != null and trait_data.id == trait_id:
			return true
	return false


func attack_has_trait(attack, trait_id: String) -> bool:
	if attack == null:
		return false
	for trait_data in attack.traits:
		if trait_data != null and trait_data.id == trait_id:
			return true
	return false


func get_incoming_damage_bonus(target, damage_type: String) -> int:
	if target == null:
		return 0
	var total := 0
	for trait_data in target.active_traits:
		if trait_data != null \
				and trait_data.trait_type == TraitDataScript.Type.DAMAGE_TAKEN_BONUS \
				and trait_data.triggering_damage_type.to_lower() == damage_type.to_lower():
			total += trait_data.value
	return total
