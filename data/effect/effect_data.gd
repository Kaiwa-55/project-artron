class_name EffectData
extends Resource

enum Type {
	DAMAGE,
	HEAL,
	STAT,
	RESOURCE,
	CLEANSE
}

enum Trigger {
	ON_APPLY,
	START_OF_TURN,
	END_OF_TURN
}

enum ResourceType {
	HP,
	AP,
	MANA
}

enum StatusKind {
	NONE,
	BLEEDING,
	BURNING,
	POISONED,
	SLOWED,
	ROOTED,
	DAZED,
	STUNNED,
	SILENCED,
	FRIGHTENED,
	WEAKENED,
	SURPRISE,
	HIDDEN,
	HASTE,
	DYING
}

enum StackMode {
	REFRESH_DURATION,
	ADD_STACKS,
	KEEP_STRONGER
}

@export var id: String = ""
@export var display_name: String = ""
@export var icon_texture: Texture2D
@export_range(1, 99) var duration_turns: int = 1
@export var expire_at_start_of_turn: bool = false
# Persistent Stances and similar effects remain until explicitly removed or the
# Combat ends instead of consuming a turn-based duration.
@export var persists_until_combat_end: bool = false
@export var effect_type: Type = Type.STAT
@export var trigger: Trigger = Trigger.ON_APPLY

@export var amount: int = 0
@export var damage_type: String = ""
@export var resource_type: ResourceType = ResourceType.HP
@export var status_kind: StatusKind = StatusKind.NONE
@export var stack_mode: StackMode = StackMode.REFRESH_DURATION
@export_range(0, 99) var potency: int = 0

@export var attack_bonus: int = 0
@export var damage_bonus: int = 0
# Optional Attack Trait filter for bonuses granted by temporary effects such as
# Stances. Empty means the bonus applies to every Attack.
@export var required_attack_trait_ids: Array[String] = []
@export var reflex_bonus: int = 0
@export var fortitude_bonus: int = 0
@export var will_bonus: int = 0
@export var speed_penalty_per_stack: float = 0.0
@export var speed_bonus_per_stack: float = 0.0

# Aura effects remain on their source and are evaluated against current
# positions whenever a relevant action resolves.
@export var aura_radius_feet: float = 0.0
@export var aura_attack_bonus: int = 0
@export var aura_affects_allies: bool = true
@export var aura_includes_source: bool = true
@export var aura_color: Color = Color(0.96, 0.78, 0.32, 0.18)

# Status rules. Effects do not stack unless their own data explicitly allows it.
@export var stackable: bool = false
@export_range(1, 999) var stacks_on_apply: int = 1
@export_range(1, 999) var max_stacks: int = 1
@export var status_tags: Array[String] = []
@export var can_be_cleansed: bool = true
# Statuses opt into the Escape Action individually. The real DC is captured
# from the applier's Class DC when the status is applied.
@export var can_escape: bool = false
@export_range(0, 10) var escape_ap_cost: int = 1
@export_range(0, 99) var default_escape_dc: int = 12

# Control status: reduces the affected Combatant's effective Max AP this turn.
@export_range(0, 99) var ap_penalty_per_stack: int = 0
@export_range(0, 99) var max_ap_bonus_per_stack: int = 0

# Cleanse effect targeting. These fields are used when effect_type is CLEANSE.
@export var cleanse_all: bool = false
@export var cleanse_status_ids: Array[String] = []
@export var cleanse_status_tags: Array[String] = []
