class_name ConsumableData
extends ItemData

enum TargetMode {
	SELF,
	SINGLE_COMBATANT,
	GROUND
}

enum TargetFilter {
	SELF_ONLY,
	ALLIES,
	ENEMIES,
	ALL_COMBATANTS
}

@export_range(0, 10) var ap_cost: int = 1
@export var target_mode: TargetMode = TargetMode.SELF
@export var target_filter: TargetFilter = TargetFilter.SELF_ONLY
@export_range(0.0, 500.0, 0.5) var range_feet: float = 0.0
@export var requires_line_of_sight: bool = true
@export var cannot_target_dying: bool = true
@export var requires_missing_hp: bool = false
@export var requires_missing_mana: bool = false
@export var required_status_id: String = ""
@export var grants_next_skill_accuracy_bonus: int = 0
@export var consume_on_use: bool = true
@export var reaction_only: bool = false
@export var effects: Array[EffectData] = []
# Ground items use the existing TargetingSystem circle preview.
@export var targeting_range_feet: float = 0.0
@export var area_shape: int = 1
@export var area_radius_feet: float = 0.0
@export var area_blocked_by_obstacles: bool = true
@export var include_caster: bool = true
@export var line_length_feet: float = 0.0
@export var line_width_feet: float = 0.0
@export var cone_angle_degrees: float = 0.0
@export var attack_data: AttackData
@export_range(0, 3) var light_level_penalty: int = 0
@export_range(0, 99) var light_duration_rounds: int = 0
