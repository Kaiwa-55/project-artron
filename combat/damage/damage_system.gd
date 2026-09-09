class_name DamageSystem
extends RefCounted


var attribute_system: AttributeSystem
var effect_system: EffectSystem


func _init(
	p_attribute_system: AttributeSystem,
	p_effect_system: EffectSystem
) -> void:

	attribute_system = p_attribute_system
	effect_system = p_effect_system


func get_buff_damage_bonus(
	attacker: CombatantState,
	attack: AttackData
) -> int:

	# Phase 1:
	# Buff System ยังไม่ได้ Implement
	return effect_system.get_damage_bonus(attacker, attack)


func get_resistance(
	target: CombatantState,
	attack: AttackData
) -> int:

	# Phase 1:
	# Resistance System ยังไม่ได้ Implement
	return target.get_damage_resistance(attack.damage_type)


func is_immune(
	target: CombatantState,
	attack: AttackData
) -> bool:
	return target.is_immune_to_damage(attack.damage_type)


func calculate_damage(
	attacker: CombatantState,
	target: CombatantState,
	attack: AttackData
) -> int:

	var attribute_modifier := 0
	if attack.uses_attribute_damage_modifier:
		attribute_modifier = attribute_system.get_attribute_modifier(
			attacker,
			attack.attack_attribute
		)

	var buff_bonus := \
		get_buff_damage_bonus(
			attacker,
			attack
		)

	return max(
		0,
		attack.base_damage
		+ attribute_modifier
		+ buff_bonus
	)


func calculate_critical_damage(
	attacker: CombatantState,
	attack: AttackData
) -> int:
	var attribute_modifier := 0
	if attack.uses_attribute_damage_modifier:
		attribute_modifier = attribute_system.get_attribute_modifier(
			attacker,
			attack.attack_attribute
		)
	var buff_bonus := get_buff_damage_bonus(attacker, attack)

	return max(
		0,
		floori((attack.base_damage + attribute_modifier) * attack.critical_multiplier)
		+ buff_bonus
	)


func calculate_final_damage(
	damage: int,
	resistance: int
) -> int:

	return max(
		0,
		damage - resistance
	)
