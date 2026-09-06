class_name ReactionEffectData
extends Resource

enum Type { DEFENSE_BONUS, TURN_HIT_TO_MISS, ATTACK, MOVEMENT, CANCEL_ACTION, RESOURCE_CHANGE, APPLY_STATUS, REMOVE_STATUS, ROLL_MODIFIER, DAMAGE_MODIFIER }
enum Target { REACTOR, TRIGGER_ACTOR, ATTACK_TARGET }
enum DistanceMode { FIXED_FEET, SPEED_MULTIPLIER }

@export var effect_type: Type = Type.DEFENSE_BONUS
@export var target: Target = Target.REACTOR
@export var amount: int = 0
@export_range(0, 99) var faith_divisor: int = 0
@export_range(0, 99) var minimum_amount: int = 0
@export var minimum_margin: int = 0
@export var maximum_margin: int = 0
@export var uses_margin_range: bool = false
@export var distance_mode: DistanceMode = DistanceMode.FIXED_FEET
@export var distance_feet: float = 0.0
@export var speed_multiplier: float = 0.0
@export var movement_triggers_reactions: bool = true
@export var attack_source: int = 0
@export var attack_data: AttackData
@export var status_effect: EffectData
@export var status_id: String = ""
