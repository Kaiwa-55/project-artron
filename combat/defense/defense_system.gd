class_name DefenseSystem
extends RefCounted

var effect_system: EffectSystem


func _init(p_effect_system: EffectSystem) -> void:
	effect_system = p_effect_system


func get_defense(
	target: CombatantState,
	defense_type: DefenseTypes.Type
) -> int:
	# Defense is a combatant stat.  Keep the choice of which defense is
	# challenged here so every attack resolves against the target's real value.
	if target == null:
		return 0

	match defense_type:

		DefenseTypes.Type.REFLEX:
			return target.reflex + target.defense_bonus + target.reflex_bonus + effect_system.get_reflex_bonus(target)

		DefenseTypes.Type.FORTITUDE:
			return target.fortitude + target.defense_bonus + target.fortitude_bonus + effect_system.get_fortitude_bonus(target)

		DefenseTypes.Type.WILL:
			return target.will + target.defense_bonus + effect_system.get_will_bonus(target)

		DefenseTypes.Type.HIGHEST:
			return max(
				target.reflex + target.defense_bonus + target.reflex_bonus + effect_system.get_reflex_bonus(target),
				target.fortitude + target.defense_bonus + target.fortitude_bonus + effect_system.get_fortitude_bonus(target),
				target.will + target.defense_bonus + effect_system.get_will_bonus(target)
			)

		DefenseTypes.Type.HIGHEST_REFLEX_FORTITUDE:
			return max(
				target.reflex + target.defense_bonus + target.reflex_bonus + effect_system.get_reflex_bonus(target),
				target.fortitude + target.defense_bonus + target.fortitude_bonus + effect_system.get_fortitude_bonus(target)
			)

	return 0
