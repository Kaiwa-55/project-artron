class_name CharacterClassData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
# Negative values mean the class does not set that base value.
@export var base_speed_feet: float = -1.0
@export var base_mana: int = -1
@export var base_faith: int = -1
@export var fixed_attribute_bonuses: Dictionary = {}
@export_range(0, 6) var attribute_choice_count: int = 0
@export var attribute_choice_options: Array[int] = []
@export var attribute_bonus_per_choice: int = 1
@export var granted_abilities: Array = []
@export var traits: Array = []
@export var auto_equipped_ability_ids: Array[String] = []
@export var progression_entries: Array[Resource] = []


func get_progression_entry(level: int) -> Resource:
	for entry in progression_entries:
		if entry != null and entry.level == level:
			return entry
	return null


func has_valid_progression(max_level: int) -> bool:
	var used_levels: Dictionary = {}
	for entry in progression_entries:
		if entry == null or not entry.is_valid(max_level) or used_levels.has(entry.level):
			return false
		used_levels[entry.level] = true
	return true
