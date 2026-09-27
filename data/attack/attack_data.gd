class_name AttackData
extends Resource

enum AttackAttribute {
	STRENGTH,
	DEXTERITY,
	CONSTITUTION,
	INTELLIGENCE,
	WISDOM,
	CHARISMA,
	CLASS_MAIN_ATTRIBUTE,
}

@export var id: String = ""
@export var display_name: String = ""
@export var animation_template: Resource

@export_enum("Strength", "Dexterity", "Constitution", "Intelligence", "Wisdom", "Charisma", "Class Main Attribute")
var attack_attribute: int = AttackAttribute.STRENGTH

@export var defense_type: DefenseTypes.Type = \
	DefenseTypes.Type.HIGHEST

@export var requires_to_hit: bool = true

@export var to_hit_bonus: int = 0
# Runtime snapshots keep the sources of bonuses added after this Resource loads.
var to_hit_bonus_sources: Array[Dictionary] = []
@export var is_unarmed: bool = false

@export var can_critical: bool = true
@export_range(0, 100) var critical_chance: int = 5
@export_range(1.0, 5.0, 0.1) var critical_multiplier: float = 2.0

@export var defense_bonus: int = 0

@export var ap_cost: int = 1

## A positive capacity enables ammunition tracking for attacks with the Reload trait.
@export_range(0, 99) var ammunition_capacity: int = 0
@export_range(1, 9) var reload_ap_cost: int = 1
@export var ammunition_item_ids: Array[String] = []
# Selected arrow for a single attack declaration; never stored on the shared weapon resource.
var ammunition_item_id: String = ""

@export var base_damage: int = 0
var base_damage_bonus_sources: Array[Dictionary] = []
@export var uses_attribute_damage_modifier: bool = true

@export var range_feet: float = 5.0
@export var minimum_range_feet: float = 0.0
@export var thrown_range_feet: float = 0.0
# Runtime-only link on a throw snapshot; never mutate the equipped attack.
var thrown_item: Resource
# Runtime-only bonus supplied by the Active Ability that created this attack.
var active_damage_bonus: int = 0
var active_damage_bonus_source: String = ""

@export var damage_type: String = "slash"

@export var effects_on_hit: Array[EffectData] = []
@export var effects_on_miss: Array[EffectData] = []
@export var hit_effect_overrides: Dictionary = {}
@export var miss_effect_overrides: Dictionary = {}
@export var traits: Array = []
@export var granted_abilities: Array[AbilityData] = []


func get_effects_on_hit() -> Array[EffectData]:
	return _configured_effects(effects_on_hit, hit_effect_overrides)


func get_effects_on_miss() -> Array[EffectData]:
	return _configured_effects(effects_on_miss, miss_effect_overrides)


func _configured_effects(effects: Array[EffectData], overrides: Dictionary) -> Array[EffectData]:
	var configured_effects: Array[EffectData] = []
	for effect in effects:
		if effect == null:
			continue
		if not overrides.has(effect.id):
			configured_effects.append(effect)
			continue
		var settings: Dictionary = overrides[effect.id]
		var configured: EffectData = effect.duplicate(true)
		configured.stacks_on_apply = int(settings.get("stacks_on_apply", configured.stacks_on_apply))
		configured.max_stacks = maxi(configured.max_stacks, configured.stacks_on_apply)
		configured.duration_turns = int(settings.get("duration_turns", configured.duration_turns))
		configured.potency = int(settings.get("potency", configured.potency))
		for tag in settings.get("additional_tags", []):
			if not configured.status_tags.has(String(tag)):
				configured.status_tags.append(String(tag))
		configured_effects.append(configured)
	return configured_effects


func resolve_attack_attribute(combatant: CombatantState) -> int:
	if combatant != null:
		for trait_data in traits:
			if trait_data != null and trait_data.id == "finesse":
				return AttributeTypes.Type.STRENGTH if combatant.strength >= combatant.dexterity else AttributeTypes.Type.DEXTERITY
	if attack_attribute != AttackAttribute.CLASS_MAIN_ATTRIBUTE:
		return attack_attribute
	if combatant != null and combatant.has_meta("class_data"):
		var character_class = combatant.get_meta("class_data")
		if character_class != null:
			return character_class.main_attribute
	return AttributeTypes.Type.STRENGTH
