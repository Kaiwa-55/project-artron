class_name AIProfile
extends Resource

@export var id: String = "standard"
@export var display_name: String = "Standard"
@export var damage_weight: float = 10.0
@export var kill_bonus: float = 100.0
@export var position_weight: float = 15.0
@export var planning_weight: float = 4.0
@export var area_target_bonus: float = 12.0
@export var low_hp_damage_multiplier: float = 1.0
@export var low_hp_status_multiplier: float = 1.0
@export var status_weight: float = 1.0
@export var ap_cost_weight: float = 8.0
@export var mana_cost_weight: float = 3.0
@export var risk_weight: float = 1.0
@export var end_turn_score: float = 0.0
@export var useful_action_end_turn_penalty: float = 30.0
@export_range(0, 10) var reaction_ap_reserve: int = 0
# Optional boss behavior. Empty source ids keep ordinary enemies on the
# standard one-decision Utility AI path.
@export_range(0.0, 1.0, 0.05) var phase_two_hp_ratio: float = 0.65
@export_range(0.0, 1.0, 0.05) var phase_three_hp_ratio: float = 0.35
@export var phase_one_source_id: String = ""
@export var phase_two_source_id: String = ""
@export var phase_three_source_id: String = ""
@export var combo_opener_source_id: String = ""
@export var combo_approach_source_id: String = ""
@export var combo_finisher_source_id: String = ""
@export var phase_preference_bonus: float = 0.0
@export var combo_step_bonus: float = 0.0
@export var phase_three_reaction_ap_reserve: int = -1
@export var status_values: Dictionary = {
	"bleeding": 8.0,
	"burning": 12.0,
	"poisoned": 24.0,
	"slowed": 12.0,
	"rooted": 34.0,
	"dazed": 28.0,
	"stunned": 45.0,
	"silenced": 26.0,
	"frightened": 18.0,
	"weakened": 22.0,
	"surprise": 38.0
}
