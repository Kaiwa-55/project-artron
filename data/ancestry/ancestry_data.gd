class_name AncestryData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var base_hp: int = 0
@export var base_mana: int = 0
@export var speed_feet: float = 0.0
@export_range(0, 6) var attribute_choice_count: int = 0
@export var attribute_bonus_per_choice: int = 1
@export var traits: Array = []
@export var granted_abilities: Array = []
