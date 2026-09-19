class_name SkillProficiencies
extends RefCounted

const STEALTH := "stealth"
const PERCEPTION := "perception"
const ATHLETICS := "athletics"
const ACROBATICS := "acrobatics"
const SURVIVAL := "survival"

const IDS: Array[String] = [STEALTH, PERCEPTION, ATHLETICS, ACROBATICS, SURVIVAL]


static func default_ranks() -> Dictionary:
	return {
		STEALTH: 0,
		PERCEPTION: 0,
		ATHLETICS: 0,
		ACROBATICS: 0,
		SURVIVAL: 0,
	}


static func normalized_ranks(value: Dictionary) -> Dictionary:
	var result := default_ranks()
	for skill_id in IDS:
		result[skill_id] = maxi(0, int(value.get(skill_id, 0)))
	return result
