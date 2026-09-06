class_name AbilityUseEffectData
extends Resource

enum Timing { ALWAYS, ON_HIT, ON_MISS }
enum Recipient { CASTER, TARGET }
enum DynamicEffect { NONE, GAIN_FAITH_FROM_WISDOM_MODIFIER, HEAL_OR_HARM_BY_FAITH, SMITE_LIGHT_BY_FAITH, HEAL_BY_FAITH }

@export var timing: Timing = Timing.ALWAYS
@export var recipient: Recipient = Recipient.CASTER
@export var effect: EffectData
@export var dynamic_effect: DynamicEffect = DynamicEffect.NONE
@export var damage_type: String = ""
@export_range(1, 99) var faith_divisor: int = 1
@export var scale_stat_bonuses_with_attribute: bool = false
@export var scaling_attribute: AttributeTypes.Type = AttributeTypes.Type.WISDOM
@export var scaling_multiplier: int = 1
@export var scale_reflex_bonus: bool = false
@export var scale_fortitude_bonus: bool = false
@export var scale_will_bonus: bool = false
