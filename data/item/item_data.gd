class_name ItemData
extends Resource

enum Category {
	CONSUMABLE,
	QUEST,
	MATERIAL
}

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon_texture: Texture2D
@export var category: Category = Category.CONSUMABLE
@export var traits: Array = []
@export_range(1, 999) var maximum_stack_size: int = 99
@export_range(0, 9999) var sell_price: int = 0
@export var ammunition_damage_bonus: int = 0
@export var ammunition_to_hit_bonus: int = 0


func has_trait(trait_id: String) -> bool:
	for trait_data in traits:
		if trait_data != null and trait_data.id == trait_id:
			return true
	return false
