class_name EquipmentData
extends Resource

enum Slot { WEAPON, ARMOR, SHIELD }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var slot: Slot = Slot.WEAPON
@export var weapon_attack: AttackData
@export var reflex_bonus: int = 0
@export var fortitude_bonus: int = 0
@export var will_bonus: int = 0
@export var damage_resistances: Dictionary = {}
