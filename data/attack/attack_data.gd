class_name AttackData
extends Resource


@export var id: String = ""
@export var display_name: String = ""
@export var animation_template: Resource

@export var attack_attribute: AttributeTypes.Type = \
	AttributeTypes.Type.STRENGTH

@export var defense_type: DefenseTypes.Type = \
	DefenseTypes.Type.HIGHEST

@export var requires_to_hit: bool = true

@export var to_hit_bonus: int = 0
@export var is_unarmed: bool = false

@export var can_critical: bool = true
@export_range(0, 100) var critical_chance: int = 5
@export_range(1.0, 5.0, 0.1) var critical_multiplier: float = 2.0

@export var defense_bonus: int = 0

@export var ap_cost: int = 1

@export var base_damage: int = 0

@export var range_feet: float = 5.0
@export var minimum_range_feet: float = 0.0
@export var thrown_range_feet: float = 0.0
# Runtime-only link on a throw snapshot; never mutate the equipped attack.
var thrown_item: Resource
# Runtime-only bonus supplied by the Active Ability that created this attack.
var active_damage_bonus: int = 0
var active_damage_bonus_source: String = ""

@export var damage_type: String = "slash"

@export var effects_on_hit: Array[EffectData] = []
@export var effects_on_miss: Array[EffectData] = []
@export var traits: Array = []
@export var granted_abilities: Array[AbilityData] = []
