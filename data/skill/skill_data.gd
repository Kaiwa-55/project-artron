class_name SkillData
extends Resource

enum TargetMode { SINGLE_COMBATANT, SELF, GROUND }
enum AreaShape { NONE, CIRCLE, LINE, CONE }
enum TargetFilter { ENEMIES, ALLIES, ALL_COMBATANTS }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_range(0, 99) var mana_cost: int = 0
@export_range(0, 99) var ap_cost: int = 1
# Number of the caster's following turns for which this skill is unavailable.
@export_range(0, 99) var cooldown_turns: int = 0
@export var attack_data: AttackData
@export var target_mode: TargetMode = TargetMode.SINGLE_COMBATANT
@export var area_shape: AreaShape = AreaShape.NONE
@export var target_filter: TargetFilter = TargetFilter.ENEMIES
@export var targeting_range_feet: float = 0.0
@export var area_radius_feet: float = 0.0
@export var line_length_feet: float = 0.0
@export var line_width_feet: float = 5.0
@export_range(1.0, 360.0, 1.0) var cone_angle_degrees: float = 90.0
@export var requires_line_of_sight: bool = true
@export var area_blocked_by_obstacles: bool = true
@export var include_caster: bool = false
