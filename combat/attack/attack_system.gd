class_name AttackSystem
extends RefCounted


var dice_system: DiceSystem
var defense_system: DefenseSystem
var damage_system: DamageSystem
var effect_system: EffectSystem
var ability_system
var map_rules
var trait_system


func _init(
	p_dice_system: DiceSystem,
	p_defense_system: DefenseSystem,
	p_damage_system: DamageSystem,
	p_effect_system: EffectSystem,
	p_ability_system,
	p_trait_system
) -> void:

	dice_system = p_dice_system
	defense_system = p_defense_system
	damage_system = p_damage_system
	effect_system = p_effect_system
	ability_system = p_ability_system
	trait_system = p_trait_system

func validate_attack(
	attacker: CombatantState,
	target: CombatantState,
	attack: AttackData
) -> ActionResult:

	if attacker == null:
		return ActionResult.failure(
			"Attacker does not exist."
	)

	if target == null:
		return ActionResult.failure(
			"Target does not exist."
	)

	if attack == null:
		return ActionResult.failure(
			"Attack data does not exist."
	)

	if attacker.is_dying():
		return ActionResult.failure(
			"Attacker is Dying."
	)

	if target.is_dying():
		return ActionResult.failure(
			"Target is Dying."
	)

	if attacker.ap < attack.ap_cost:
		return ActionResult.failure(
			"Not enough AP."
		)

	if target.has_status("hidden") and attacker.team != target.team:
		return ActionResult.failure("Target is Hidden and has not been detected.")

	if attacker.team == target.team:
		return ActionResult.failure(
			"Target must be an enemy."
		)

	if not is_in_range(
		attacker,
		target,
		attack
	):
		return ActionResult.failure(
			"Target is out of range."
		)

	return ActionResult.success_result()

func is_in_range(
	attacker: CombatantState,
	target: CombatantState,
	attack: AttackData
) -> bool:

	if map_rules != null:
		return map_rules.is_target_in_range(
			attacker,
			target,
			attack.range_feet + ability_system.get_attack_range_bonus(attacker, attack)
		)

	return attacker.position.distance_to(target.position) <= attack.range_feet

func resolve_attack(
	attacker: CombatantState,
	target: CombatantState,
	attack: AttackData,
	defer_damage: bool = false,
	conditional_damage_bonuses: Array[Dictionary] = []
) -> AttackResult:

	var result := AttackResult.new()
	result.conditional_damage_bonuses = conditional_damage_bonuses.duplicate(true)
	var bonus_sources: PackedStringArray = []
	for bonus in conditional_damage_bonuses:
		result.conditional_damage_bonus += int(bonus.get("amount", 0))
		bonus_sources.append(String(bonus.get("source", "Bonus")))
	result.damage_bonus_source = ", ".join(bonus_sources)

	# AP
	if not attacker.spend_ap(attack.ap_cost):
		return result

	# To Hit
	if attack.requires_to_hit:
		var attack_modifier: int = attacker.get_attribute_modifier(
			attack.attack_attribute
		) + attack.to_hit_bonus + effect_system.get_attack_bonus(attacker) \
			+ ability_system.get_to_hit_bonus(attacker, attack, get_target_edge_distance_feet(attacker, target))
		result.roll = dice_system.roll_3d8()
		result.attack_modifier = attack_modifier
		# Always read Defense from the target before deciding whether the attack
		# connects. Damage is only calculated after this comparison succeeds.
		result.defense = \
			defense_system.get_defense(
				target,
				attack.defense_type
			)
		result.original_defense = result.defense
		result.margin = result.roll + result.attack_modifier - result.defense
		result.hit = result.margin >= 0

	else:
		result.hit = true

	result.triggered_abilities = ability_system.on_attack_resolved(attacker, attack)
	if defer_damage:
		result.deferred = true
		return result

	# Miss
	if not result.hit:
		return result

	# Damage
	result.critical_roll = dice_system.roll_percent()
	var critical_chance: int = clampi(attack.critical_chance + ability_system.get_critical_chance_bonus(attacker, attack), 0, 100)
	result.critical = attack.can_critical and result.critical_roll <= critical_chance

	if result.critical:
		result.damage = damage_system.calculate_critical_damage(attacker, attack)
		result.damage += ability_system.get_critical_damage_bonus(attacker, attack)
	else:
		result.damage = damage_system.calculate_damage(attacker, target, attack)
	result.damage += result.conditional_damage_bonus
	result.damage += trait_system.get_incoming_damage_bonus(target, attack.damage_type)

	result.immune = damage_system.is_immune(target, attack)

	result.resistance = \
		damage_system.get_resistance(
			target,
			attack
		)

	if result.immune:
		result.final_damage = 0
	else:
		result.final_damage = damage_system.calculate_final_damage(
			result.damage,
			result.resistance
		)

	target.apply_damage(
		result.final_damage
	)
	ability_system.commit_conditional_damage_bonuses(attacker, result.conditional_damage_bonuses)

	if not result.immune:
		for effect in attack.effects_on_hit:
			if effect_system.apply_effect(target, effect):
				result.applied_effects.append(effect.display_name)
	apply_passive_on_hit_statuses(attacker, target, attack, result)

	if attack.defense_bonus > 0:
		attacker.reflex_bonus += attack.defense_bonus
		attacker.fortitude_bonus += attack.defense_bonus

	return result


func get_target_edge_distance_feet(attacker: CombatantState, target: CombatantState) -> float:
	if map_rules != null:
		return map_rules.get_edge_distance_world_units(attacker, target) / map_rules.world_units_per_foot
	return attacker.position.distance_to(target.position)


func finalize_attack(attacker: CombatantState, target: CombatantState, attack: AttackData, result: AttackResult) -> AttackResult:
	if not result.deferred or not result.hit:
		return result
	result.deferred = false
	result.critical_roll = dice_system.roll_percent()
	var critical_chance: int = clampi(attack.critical_chance + ability_system.get_critical_chance_bonus(attacker, attack), 0, 100)
	result.critical = attack.can_critical and result.critical_roll <= critical_chance
	result.damage = damage_system.calculate_critical_damage(attacker, attack) if result.critical else damage_system.calculate_damage(attacker, target, attack)
	if result.critical:
		result.damage += ability_system.get_critical_damage_bonus(attacker, attack)
	result.damage += result.conditional_damage_bonus
	result.damage += trait_system.get_incoming_damage_bonus(target, attack.damage_type)
	result.immune = damage_system.is_immune(target, attack)
	result.resistance = damage_system.get_resistance(target, attack)
	result.final_damage = 0 if result.immune else maxi(0, damage_system.calculate_final_damage(result.damage, result.resistance) - result.reaction_damage_reduction)
	target.apply_damage(result.final_damage)
	ability_system.commit_conditional_damage_bonuses(attacker, result.conditional_damage_bonuses)
	if not result.immune:
		for effect in attack.effects_on_hit:
			if effect_system.apply_effect(target, effect): result.applied_effects.append(effect.display_name)
	apply_passive_on_hit_statuses(attacker, target, attack, result)
	return result


func apply_passive_on_hit_statuses(attacker: CombatantState, target: CombatantState, attack: AttackData, result: AttackResult) -> void:
	for entry in ability_system.consume_on_hit_status_effects(attacker, attack):
		var effect: EffectData = entry.get("effect")
		if effect_system.apply_effect(target, effect):
			result.applied_effects.append(effect.display_name)
