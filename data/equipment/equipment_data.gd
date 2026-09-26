class_name EquipmentData
extends Resource

enum Slot { WEAPON = 0, ARMOR = 1, SHIELD = 2, HEAD = 4, LEGS = 5, BOOTS = 6, GLOVES = 7, ACCESSORY = 8 }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_range(0, 9999) var purchase_price: int = 25
@export var slot: Slot = Slot.WEAPON
@export var weapon_attack: AttackData
@export var reflex_bonus: int = 0
@export var fortitude_bonus: int = 0
@export var will_bonus: int = 0
@export var stealth_bonus: int = 0
@export var max_mana_bonus: int = 0
@export var light_radius_feet: float = 0.0
@export var light_level_bonus: int = 0
@export var spell_skill_to_hit_bonus: int = 0
@export var spell_skill_damage_bonus: int = 0
@export var spell_skill_damage_type: String = ""
@export var damage_resistances: Dictionary = {}


func create_enhanced(level: int) -> EquipmentData:
	if weapon_attack == null or level < 1 or level > 2:
		return null
	var enhanced: EquipmentData = duplicate()
	var enhanced_attack: AttackData = weapon_attack.duplicate()
	enhanced.id = "%s_plus_%d" % [id, level]
	enhanced.display_name = "%s +%d" % [display_name, level]
	enhanced.description = "%s +%d Base Damage and To Hit." % [description, level]
	enhanced.purchase_price = mini(9999, purchase_price + 100 * level)
	enhanced_attack.id = "%s_attack_plus_%d" % [id, level]
	enhanced_attack.display_name = "%s +%d" % [weapon_attack.display_name, level]
	enhanced_attack.base_damage += level
	enhanced_attack.to_hit_bonus += level
	enhanced.weapon_attack = enhanced_attack
	return enhanced
