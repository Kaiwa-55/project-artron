class_name AbilityData
extends Resource

enum TargetMode { SINGLE_COMBATANT, SELF, GROUND }
enum TargetFilter { ENEMIES, ALLIES, ALL_COMBATANTS }
enum AttackSource { NONE, EQUIPPED_WEAPON, CONFIGURED_ATTACK }
enum AreaShape { NONE, CIRCLE, LINE, CONE }
enum ExecutionMode { STANDARD, ATTACK_SEQUENCE }

@export var id: String = ""
@export var display_name: String = ""
@export_range(0, 10) var required_level: int = 1
@export var prerequisite_id: String = ""
@export var required_trait_ids: Array[String] = []
@export_range(1, 10, 1) var ability_point_cost: int = 1
@export var traits: Array = []
@export var auto_equip_on_grant: bool = false
@export var is_passive: bool = false
@export var reaction_only: bool = false
@export var execution_mode: ExecutionMode = ExecutionMode.STANDARD
# ATTACK_SEQUENCE uses Dual Weapon setup when count is zero. A positive count
# repeats the configured/equipped Attack and can opt into RAP per individual hit.
@export_range(0, 20) var sequence_attack_count: int = 0
@export var sequence_counts_each_attack_for_penalty: bool = false
@export_range(0, 10) var ap_cost: int = 0
@export_range(0, 99) var faith_cost: int = 0
@export_range(0, 99) var finishing_gauge_cost: int = 0
@export_range(0, 99) var cooldown_turns: int = 0
# Zero means that the Ability has no per-turn use limit.
@export_range(0, 10) var uses_per_turn: int = 0
@export var description: String = ""
# Uses the shared AttackAnimationData templates. Attack Abilities override the
# source Attack animation; non-Attack Abilities play this presentation directly.
@export var animation_template: Resource
@export var effects: Array = []
# Legacy self-effects remain supported while data is migrated to use_effects.
@export var effects_on_use: Array[EffectData] = []
@export var uses_equipped_weapon_attack: bool = false
@export var target_mode: TargetMode = TargetMode.SINGLE_COMBATANT
@export var target_filter: TargetFilter = TargetFilter.ENEMIES
@export var attack_source: AttackSource = AttackSource.NONE
@export var attack_data: AttackData
@export var required_attack_trait_ids: Array[String] = []
# Damage added after the normal Critical calculation. This is used by active
# attack abilities whose bonus should scale without becoming a global Passive.
@export var active_attack_flat_damage_bonus: int = 0
@export var active_attack_damage_bonus_per_level: int = 0
@export var active_attack_base_damage_per_level: int = 0
# Adds current Faith to an Active Ability's base damage. The executor snapshots
# this value before paying the Ability's Faith cost.
@export var active_attack_base_damage_from_faith_multiplier: int = 0
# When positive, adds floor(current Faith / divisor) to base damage.
@export_range(0, 99) var active_attack_base_damage_faith_divisor: int = 0
@export var use_effects: Array = []
@export var area_shape: AreaShape = AreaShape.NONE
@export var targeting_range_feet: float = 0.0
@export var area_radius_feet: float = 0.0
@export var line_length_feet: float = 0.0
@export var line_width_feet: float = 5.0
@export_range(1.0, 360.0, 1.0) var cone_angle_degrees: float = 90.0
@export var requires_line_of_sight: bool = true
@export var area_blocked_by_obstacles: bool = true
@export var include_caster: bool = false
@export var granted_reactions: Array = []
@export var granted_skills: Array[SkillData] = []
# The number of spells this learned/granted Ability lets the character choose.
# Spell choices are separate from Ability Points.
@export_range(0, 99) var spell_choices_granted: int = 0
# Optional restrictions for spells selected through this Ability. Empty Traits
# and zero maximum keep the grant unrestricted for future classes.
@export var spell_required_trait_ids: Array[String] = []
@export_range(1, 10) var spell_min_level: int = 1
@export_range(0, 10) var spell_max_level: int = 0
