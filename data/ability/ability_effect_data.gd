class_name AbilityEffectData
extends Resource


enum Trigger {
	ON_ATTACK_RESOLVED,
	ON_TURN_START,
	ON_TURN_END
}

enum Type {
	STACKED_TO_HIT_BONUS,
	PASSIVE_TO_HIT_BONUS,
	PASSIVE_ATTACK_RANGE_BONUS_FEET,
	CONDITIONAL_DAMAGE_BONUS,
	SKILL_COOLDOWN_MODIFIER,
	ABILITY_MOVEMENT,
	PASSIVE_CRITICAL_CHANCE_BONUS,
	CRITICAL_DAMAGE_BONUS,
	CONDITIONAL_TO_HIT_BONUS,
	PASSIVE_FIRST_MOVE_DISTANCE_BONUS,
	ON_HIT_APPLY_STATUS,
	AFTER_MOVE_APPLY_STATUS,
	PASSIVE_SKILL_DAMAGE_BONUS,
	PASSIVE_SKILL_MANA_DISCOUNT,
	PASSIVE_SKILL_RANGE_BONUS_FEET,
	PASSIVE_SPEED_BONUS_FEET,
	PASSIVE_DAMAGE_RESISTANCE
}

enum ConditionMode {
	ANY,
	ALL
}

@export var trigger: Trigger = Trigger.ON_ATTACK_RESOLVED
@export var effect_type: Type = Type.STACKED_TO_HIT_BONUS
@export var requires_unarmed_attack: bool = false
@export var stack_amount: int = 1
@export var to_hit_bonus_per_stack: int = 1
@export var passive_value: int = 0
@export var max_stacks: int = 0
@export var clear_stacks_at_end_turn: bool = true

# Data-driven conditional damage. Multiple Abilities and effects may contribute
# to the same attack; no Ability id is hard-coded in AbilitySystem.
@export var condition_mode: ConditionMode = ConditionMode.ANY
@export var requires_target_unattacked_this_round: bool = false
@export_range(0, 100) var target_hp_below_percent: int = 0
@export var required_target_status_ids: Array[String] = []
@export var required_attack_trait_ids: Array[String] = []
@export var minimum_target_distance_feet: float = 0.0
@export var first_successful_hit_per_turn: bool = false
@export_range(0, 100) var alternate_target_hp_at_or_below_percent: int = 0
@export var alternate_flat_damage_bonus: int = 0
@export var flat_damage_bonus: int = 0
@export var damage_bonus_per_level: int = 0

# Status applied only after the attack's final Hit result is known. This keeps
# defensive Reactions able to turn a Hit into a Miss before the status fires.
@export var status_effect: EffectData
@export var minimum_move_distance_feet: float = 0.0

# Modifies the cooldown assigned when a Skill is used. An empty id list applies
# to every Skill; negative values reduce cooldown and positive values increase it.
@export var skill_cooldown_modifier: int = 0
@export var affected_skill_ids: Array[String] = []

# Active movement Ability data. Path blocking still uses MapRules.
@export var movement_distance_feet: float = 0.0
@export var movement_triggers_reactions: bool = true

# Generic spellcasting modifiers. They apply to Skills, never weapon Attacks or
# Active Abilities, so spell selection and class scaling remain separate.
@export var skill_damage_bonus: int = 0
@export var skill_mana_discount: int = 0
@export_range(0, 99) var minimum_skill_mana_cost: int = 0
@export_range(0, 99) var minimum_skill_base_mana_cost: int = 0
@export var first_skill_per_turn: bool = false
@export var skill_range_bonus_feet: float = 0.0

# Generic passive Resistance. When divide_by_level is enabled, passive_value
# is divided by the owner's current Level before the minimum is applied.
@export var resistance_damage_type_ids: Array[String] = []
@export var resistance_divide_by_level: bool = false
@export var minimum_resistance: int = 0
