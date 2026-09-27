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

	if map_rules != null and attacker.team != target.team:
		var visibility: Dictionary = map_rules.get_visibility(attacker, target)
		if visibility.not_visible:
			return ActionResult.failure("Target is not visible.")

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
	if is_inside_minimum_range(attacker, target, attack):
		return ActionResult.failure("Target is too close; this Attack requires at least %.0f ft." % attack.minimum_range_feet)

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


func is_inside_minimum_range(attacker: CombatantState, target: CombatantState, attack: AttackData) -> bool:
	if attack.minimum_range_feet <= 0.0:
		return false
	if map_rules != null:
		return map_rules.get_edge_distance_world_units(attacker, target) < attack.minimum_range_feet * map_rules.world_units_per_foot
	return attacker.position.distance_to(target.position) < attack.minimum_range_feet

func resolve_attack(
	attacker: CombatantState,
	target: CombatantState,
	attack: AttackData,
	defer_damage: bool = false,
	conditional_damage_bonuses: Array[Dictionary] = [],
	repeated_attack_penalty: int = 0,
	offhand_penalty: int = 0
) -> AttackResult:

	var result := AttackResult.new()
	result.repeated_attack_penalty = repeated_attack_penalty
	result.offhand_penalty = offhand_penalty
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
		var visibility_penalty := 0
		if map_rules != null:
			visibility_penalty = int(map_rules.get_visibility(attacker, target).attack_penalty)
		result.visibility_penalty = visibility_penalty
		var attribute_type: int = attack.resolve_attack_attribute(attacker)
		var attribute_bonus: int = attacker.get_attribute_modifier(attribute_type)
		var effect_bonus: int = effect_system.get_attack_bonus(attacker)
		var ability_breakdown: Array[Dictionary] = []
		var ability_bonus: int = ability_system.get_to_hit_bonus(attacker, attack, get_target_edge_distance_feet(attacker, target), ability_breakdown)
		var attack_modifier: int = attribute_bonus + attack.to_hit_bonus + effect_bonus + ability_bonus \
			+ repeated_attack_penalty + offhand_penalty + visibility_penalty
		result.to_hit_breakdown.append({"source": AttributeTypes.Type.keys()[attribute_type].capitalize(), "amount": attribute_bonus})
		var sourced_accuracy := 0
		for source in attack.to_hit_bonus_sources:
			result.to_hit_breakdown.append(source.duplicate(true))
			sourced_accuracy += int(source.get("amount", 0))
		var intrinsic_accuracy: int = attack.to_hit_bonus - sourced_accuracy
		if intrinsic_accuracy != 0:
			result.to_hit_breakdown.append({"source": "%s accuracy" % attack.display_name, "amount": intrinsic_accuracy})
		for instance in attacker.effects:
			if instance != null and instance.data != null and instance.data.attack_bonus != 0:
				result.to_hit_breakdown.append({"source": instance.data.display_name, "amount": instance.data.attack_bonus * instance.stack_count})
		result.to_hit_breakdown.append_array(ability_breakdown)
		if repeated_attack_penalty != 0:
			result.to_hit_breakdown.append({"source": "Repeated attack", "amount": repeated_attack_penalty})
		if offhand_penalty != 0:
			result.to_hit_breakdown.append({"source": "Off-hand", "amount": offhand_penalty})
		if visibility_penalty != 0:
			result.to_hit_breakdown.append({"source": "Visibility", "amount": visibility_penalty})
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
		apply_miss_effects(target, attack, result, attacker)
		return result

	# Damage
	result.critical_roll = dice_system.roll_percent()
	var critical_chance: int = clampi(attack.critical_chance + ability_system.get_critical_chance_bonus(attacker, attack), 0, 100)
	result.critical_chance = critical_chance
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
	result.damage_breakdown = get_damage_breakdown(attacker, target, attack, result)

	target.apply_damage(
		result.final_damage
	)
	ability_system.commit_conditional_damage_bonuses(attacker, result.conditional_damage_bonuses)

	if not result.immune:
		for effect in attack.get_effects_on_hit():
			if effect_system.apply_effect(target, effect, "", "", false, attacker):
				result.applied_effects.append(effect.display_name)
	apply_passive_on_hit_statuses(attacker, target, attack, result)

	if attack.defense_bonus > 0:
		attacker.reflex_bonus += attack.defense_bonus
		attacker.fortitude_bonus += attack.defense_bonus
	grant_finishing_gauge_on_hit(attacker, result)

	return result


func declare_attack_action(attacker: CombatantState, attack: AttackData) -> int:
	if attacker == null or attack == null or not attack.requires_to_hit:
		return 0
	var declaration_index := attacker.attacks_declared_this_turn
	attacker.attacks_declared_this_turn += 1
	if declaration_index == 0:
		return 0
	if declaration_index == 1:
		return -2
	return -4


func get_target_edge_distance_feet(attacker: CombatantState, target: CombatantState) -> float:
	if map_rules != null:
		return map_rules.get_edge_distance_world_units(attacker, target) / map_rules.world_units_per_foot
	return attacker.position.distance_to(target.position)


func finalize_attack(attacker: CombatantState, target: CombatantState, attack: AttackData, result: AttackResult) -> AttackResult:
	if not result.deferred:
		return result
	if not result.hit:
		result.deferred = false
		apply_miss_effects(target, attack, result, attacker)
		return result
	result.deferred = false
	result.critical_roll = dice_system.roll_percent()
	var hit_recipient: CombatantState = result.redirected_damage_target if result.redirect_hit_effects and result.redirected_damage_target != null else target
	var critical_chance: int = clampi(attack.critical_chance + ability_system.get_critical_chance_bonus(attacker, attack), 0, 100)
	result.critical_chance = critical_chance
	result.critical = attack.can_critical and result.critical_roll <= critical_chance
	result.damage = damage_system.calculate_critical_damage(attacker, attack) if result.critical else damage_system.calculate_damage(attacker, hit_recipient, attack)
	if result.critical:
		result.damage += ability_system.get_critical_damage_bonus(attacker, attack)
	result.damage += result.conditional_damage_bonus
	result.damage += trait_system.get_incoming_damage_bonus(hit_recipient, attack.damage_type)
	result.immune = damage_system.is_immune(hit_recipient, attack)
	result.resistance = damage_system.get_resistance(hit_recipient, attack)
	result.final_damage = 0 if result.immune else maxi(0, damage_system.calculate_final_damage(result.damage, result.resistance) - result.reaction_damage_reduction)
	result.damage_breakdown = get_damage_breakdown(attacker, hit_recipient, attack, result)
	var damage_recipient: CombatantState = result.redirected_damage_target if result.redirected_damage_target != null else target
	damage_recipient.apply_damage(result.final_damage)
	ability_system.commit_conditional_damage_bonuses(attacker, result.conditional_damage_bonuses)
	if not result.immune:
		for effect in attack.get_effects_on_hit():
			if effect_system.apply_effect(hit_recipient, effect, "", "", false, attacker): result.applied_effects.append(effect.display_name)
	apply_passive_on_hit_statuses(attacker, hit_recipient, attack, result)
	grant_finishing_gauge_on_hit(attacker, result)
	return result


func get_damage_breakdown(attacker: CombatantState, target: CombatantState, attack: AttackData, result: AttackResult) -> Array[Dictionary]:
	var breakdown: Array[Dictionary] = []
	var attribute_bonus := 0
	if attack.uses_attribute_damage_modifier:
		attribute_bonus = attacker.get_attribute_modifier(attack.resolve_attack_attribute(attacker))
	var sourced_base_damage := 0
	for source in attack.base_damage_bonus_sources:
		breakdown.append(source.duplicate(true))
		sourced_base_damage += int(source.get("amount", 0))
	breakdown.push_front({"source": "Base damage", "amount": attack.base_damage - sourced_base_damage})
	if attribute_bonus != 0:
		breakdown.append({"source": AttributeTypes.Type.keys()[attack.resolve_attack_attribute(attacker)].capitalize(), "amount": attribute_bonus})
	var effect_bonus := 0
	for instance in attacker.effects:
		if instance == null or instance.data == null or not effect_system.effect_matches_attack(instance.data, attack):
			continue
		var amount: int = instance.data.damage_bonus * instance.stack_count
		if amount != 0:
			breakdown.append({"source": instance.data.display_name, "amount": amount})
			effect_bonus += amount
	var critical_extra := 0
	if result.critical:
		critical_extra = floori((attack.base_damage + attribute_bonus) * attack.critical_multiplier) - attack.base_damage - attribute_bonus
		breakdown.append({"source": "Critical x%.1f" % attack.critical_multiplier, "amount": critical_extra})
	var critical_ability_bonus: int = ability_system.get_critical_damage_bonus(attacker, attack) if result.critical else 0
	if critical_ability_bonus != 0:
		breakdown.append({"source": "Critical ability", "amount": critical_ability_bonus})
	for bonus in result.conditional_damage_bonuses:
		var amount: int = int(bonus.get("amount", 0))
		if amount != 0:
			breakdown.append({"source": String(bonus.get("source", "Ability")), "amount": amount})
	var incoming_bonus: int = trait_system.get_incoming_damage_bonus(target, attack.damage_type)
	if incoming_bonus != 0:
		breakdown.append({"source": "Target vulnerability", "amount": incoming_bonus})
	var listed_raw: int = attack.base_damage + attribute_bonus + effect_bonus + critical_extra + critical_ability_bonus + result.conditional_damage_bonus + incoming_bonus
	if listed_raw != result.damage:
		breakdown.append({"source": "Damage adjustment", "amount": result.damage - listed_raw})
	if result.resistance != 0:
		breakdown.append({"source": "Resistance", "amount": -result.resistance})
	if result.reaction_damage_reduction != 0:
		breakdown.append({"source": "Reaction reduction", "amount": -result.reaction_damage_reduction})
	return breakdown


func grant_finishing_gauge_on_hit(attacker: CombatantState, result: AttackResult) -> void:
	if result == null or not result.hit or not trait_system.has_trait(attacker, "martial_artist"):
		return
	result.finishing_gauge_gained = attacker.change_finishing_gauge(1)


func apply_miss_effects(target: CombatantState, attack: AttackData, result: AttackResult, attacker: CombatantState = null) -> void:
	if target == null or attack == null:
		return
	for effect in attack.get_effects_on_miss():
		if effect_system.apply_effect(target, effect, "", "", false, attacker):
			result.applied_effects.append(effect.display_name)


func apply_passive_on_hit_statuses(attacker: CombatantState, target: CombatantState, attack: AttackData, result: AttackResult) -> void:
	for entry in ability_system.consume_on_hit_status_effects(attacker, attack):
		var effect: EffectData = entry.get("effect")
		if effect_system.apply_effect(target, effect, String(entry.get("ability_id", "")), String(entry.get("source", "")), false, attacker):
			result.applied_effects.append(effect.display_name)
