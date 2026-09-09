class_name DefenseSystem
extends RefCounted

var effect_system: EffectSystem
var ability_system


func _init(p_effect_system: EffectSystem, p_ability_system = null) -> void:
	effect_system = p_effect_system
	ability_system = p_ability_system


func get_defense(
	target: CombatantState,
	defense_type: DefenseTypes.Type
) -> int:
	# Defense is a combatant stat.  Keep the choice of which defense is
	# challenged here so every attack resolves against the target's real value.
	if target == null:
		return 0
	var passive_bonus: int = ability_system.get_passive_defense_bonus(target) if ability_system != null else 0

	match defense_type:

		DefenseTypes.Type.REFLEX:
			return target.reflex + target.defense_bonus + target.reflex_bonus + effect_system.get_reflex_bonus(target) + passive_bonus

		DefenseTypes.Type.FORTITUDE:
			return target.fortitude + target.defense_bonus + target.fortitude_bonus + effect_system.get_fortitude_bonus(target) + passive_bonus

		DefenseTypes.Type.WILL:
			return target.will + target.defense_bonus + effect_system.get_will_bonus(target) + passive_bonus

		DefenseTypes.Type.HIGHEST:
			return max(
				target.reflex + target.defense_bonus + target.reflex_bonus + effect_system.get_reflex_bonus(target) + passive_bonus,
				target.fortitude + target.defense_bonus + target.fortitude_bonus + effect_system.get_fortitude_bonus(target) + passive_bonus,
				target.will + target.defense_bonus + effect_system.get_will_bonus(target) + passive_bonus
			)

		DefenseTypes.Type.HIGHEST_REFLEX_FORTITUDE:
			return max(
				target.reflex + target.defense_bonus + target.reflex_bonus + effect_system.get_reflex_bonus(target) + passive_bonus,
				target.fortitude + target.defense_bonus + target.fortitude_bonus + effect_system.get_fortitude_bonus(target) + passive_bonus
			)

	return 0
