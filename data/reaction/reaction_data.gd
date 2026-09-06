class_name ReactionData
extends Resource

enum Trigger {
	ENEMY_LEAVES_REACH,
	ENEMY_ATTACKS_SELF,
	AFTER_ENEMY_ATTACKS_SELF,
	DAMAGE_TAKEN,
	ENEMY_ENTERS_REACH,
	ALLY_ATTACKED,
	STATUS_WOULD_APPLY,
	TURN_START,
	TURN_END,
	AFTER_SELF_RANGED_ATTACK_HIT
}

enum AttackSource {
	REACTION_ABILITY,
	EQUIPPED_WEAPON
}
enum Resolution { DEFENSE_BONUS, TURN_HIT_TO_MISS }

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var traits: Array = []
@export var trigger: Trigger = Trigger.ENEMY_LEAVES_REACH
@export var reach_feet: float = 5.0
# Attack reactions either inherit the equipped weapon's AttackData (including
# range and damage) or use this reaction's dedicated AttackData.
@export var attack_source: AttackSource = AttackSource.REACTION_ABILITY
@export var attack_data: AttackData
@export var required_weapon_trait_ids: Array[String] = []
@export var auto_resolve: bool = true
@export_range(0, 99) var ap_cost: int = 1
@export_range(0, 99) var faith_cost: int = 0
# Applied only while resolving this reaction.  This is the general AC/DEF bonus
# used by defensive reactions such as Parry.
@export var defense_bonus: int = 0
@export var resolution: Resolution = Resolution.DEFENSE_BONUS
@export var required_trait_id: String = ""
@export var melee_only: bool = false
@export_range(0, 99) var max_hit_margin: int = 0
@export var effects: Array = []
@export_range(0, 99) var uses_per_round: int = 0
@export var requires_line_of_sight: bool = false
@export var can_target_self: bool = true
