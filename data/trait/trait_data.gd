class_name TraitData
extends Resource


enum Type {
	TAG,
	DAMAGE_TAKEN_BONUS
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var trait_type: Type = Type.TAG
@export var tags: Array[String] = []
@export var triggering_damage_type: String = ""
@export var value: int = 0
