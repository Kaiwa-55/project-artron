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
@export var consume_on_use: bool = true
@export var effects: Array[EffectData] = []
