extends Resource
## Explicit, export-safe catalog. Add content here rather than editing UI code.
@export var base_character: CharacterData
@export_range(0, 9999) var starting_gold: int = 200
@export var ancestries: Array[Resource] = []
@export var classes: Array[Resource] = []
@export var abilities: Array[AbilityData] = []
@export var equipment: Array[Resource] = []
@export var visuals: Array[Resource] = []
@export var steps: Array[Dictionary] = []

func find_ability(ability_id: String) -> AbilityData:
	for ability in get_abilities():
		if ability.id == ability_id:
			return ability
	return null

func get_abilities() -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	var ids: Dictionary = {}
	var sources: Array = abilities.duplicate()
	for source in ancestries + classes:
		sources.append_array(source.granted_abilities)
		if source is CharacterClassData:
			for entry in source.progression_entries:
				sources.append_array(entry.granted_abilities)
	for ability in sources:
		if ability != null and not ids.has(ability.id):
			ids[ability.id] = true
			result.append(ability)
	return result


func get_skills() -> Array[SkillData]:
	var result: Array[SkillData] = []
	var ids: Dictionary = {}
	var sources: Array = base_character.skills.duplicate() if base_character != null else []
	for ability in get_abilities():
		sources.append_array(ability.granted_skills)
	for skill in sources:
		if skill != null and not ids.has(skill.id):
			ids[skill.id] = true
			result.append(skill)
	return result

func visual_for(source_id: String):
	for visual in visuals:
		if visual.source_id == source_id:
			return visual
	return null
