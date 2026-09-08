class_name AbilitySystem
extends RefCounted

const AbilityEffectDataScript = preload("res://data/ability/ability_effect_data.gd")
const AbilityUseEffectDataScript = preload("res://data/ability/ability_use_effect_data.gd")


func toggle_ability(combatant, ability_id: String) -> ActionResult:
	var ability = get_available_ability(combatant, ability_id)
	if ability != null and ability.is_passive:
		return ActionResult.failure("Passive abilities are always active.")
	if combatant.equipped_abilities.has(ability_id):
		return unequip_ability(combatant, ability_id)
	return equip_ability(combatant, ability_id)


func equip_ability(combatant, ability_id: String) -> ActionResult:
	var ability = get_available_ability(combatant, ability_id)
	if ability == null:
		return ActionResult.failure("Ability is not available to this character.")
	if combatant.level < ability.required_level:
		return ActionResult.failure("Requires level %d." % ability.required_level)
	if ability.prerequisite_id != "" and not combatant.equipped_abilities.has(ability.prerequisite_id):
		return ActionResult.failure("Requires %s first." % ability.prerequisite_id)
	for trait_id in ability.required_trait_ids:
		if not combatant_has_trait(combatant, trait_id):
			return ActionResult.failure("Requires the %s trait." % trait_id)
	if combatant.equipped_abilities.has(ability_id):
		return ActionResult.failure("Ability is already equipped.")

	combatant.equipped_abilities.append(ability_id)
	return ActionResult.success_result()


func unequip_ability(combatant, ability_id: String) -> ActionResult:
	if not combatant.equipped_abilities.has(ability_id):
		return ActionResult.failure("Ability is not equipped.")

	for equipped_id in combatant.equipped_abilities:
		var equipped_ability = get_available_ability(combatant, equipped_id)
		if equipped_ability != null and equipped_ability.prerequisite_id == ability_id:
			return ActionResult.failure("Unequip %s first." % equipped_ability.display_name)

	combatant.equipped_abilities.erase(ability_id)
	clear_ability_stacks(combatant, ability_id)
	return ActionResult.success_result()


func get_to_hit_bonus(combatant, attack, target_distance_feet: float = 0.0) -> int:
	var total_bonus := 0
	for ability in get_attack_abilities(combatant, attack):
		for effect_index in range(ability.effects.size()):
			var effect = ability.effects[effect_index]
			if effect == null or not attack_matches(effect, attack):
				continue
			if effect.effect_type == AbilityEffectDataScript.Type.STACKED_TO_HIT_BONUS:
				total_bonus += get_stack_count(combatant, ability.id, effect_index) * effect.to_hit_bonus_per_stack
			elif effect.effect_type == AbilityEffectDataScript.Type.PASSIVE_TO_HIT_BONUS:
				total_bonus += effect.passive_value
			elif effect.effect_type == AbilityEffectDataScript.Type.CONDITIONAL_TO_HIT_BONUS:
				if int(combatant.ability_uses_this_turn.get(ability.id, 0)) >= 1:
					continue
				if target_distance_feet < effect.minimum_target_distance_feet:
					continue
				if not effect.required_attack_trait_ids.all(func(trait_id): return attack_has_trait(attack, trait_id)):
					continue
				total_bonus += effect.passive_value
				combatant.ability_uses_this_turn[ability.id] = 1
	return total_bonus


func get_attack_range_bonus(combatant, attack) -> float:
	var total_bonus := 0.0
	for ability in get_attack_abilities(combatant, attack):
		for effect in ability.effects:
			if effect != null \
				and effect.effect_type == AbilityEffectDataScript.Type.PASSIVE_ATTACK_RANGE_BONUS_FEET \
				and attack_matches(effect, attack):
				total_bonus += effect.passive_value
	return total_bonus


func get_critical_chance_bonus(combatant, attack) -> int:
	return get_non_stacking_attack_bonus(combatant, attack, AbilityEffectDataScript.Type.PASSIVE_CRITICAL_CHANCE_BONUS)


func get_critical_damage_bonus(combatant, attack) -> int:
	return get_non_stacking_attack_bonus(combatant, attack, AbilityEffectDataScript.Type.CRITICAL_DAMAGE_BONUS)


func get_first_move_distance_bonus(combatant) -> float:
	var total := 0.0
	if combatant == null:
		return total
	for ability in get_active_abilities(combatant):
		if int(combatant.ability_uses_this_turn.get(ability.id, 0)) >= 1:
			continue
		var ability_bonus := 0.0
		for effect in ability.effects:
			if effect != null and effect.effect_type == AbilityEffectDataScript.Type.PASSIVE_FIRST_MOVE_DISTANCE_BONUS:
				ability_bonus = maxf(ability_bonus, float(effect.passive_value))
		total += ability_bonus
	return total


func commit_first_move_distance_bonuses(combatant) -> void:
	if combatant == null:
		return
	for ability in get_active_abilities(combatant):
		if int(combatant.ability_uses_this_turn.get(ability.id, 0)) >= 1:
			continue
		if ability.effects.any(func(effect): return effect != null and effect.effect_type == AbilityEffectDataScript.Type.PASSIVE_FIRST_MOVE_DISTANCE_BONUS):
			combatant.ability_uses_this_turn[ability.id] = 1


func apply_after_move_passives(combatant) -> Array[Dictionary]:
	var applied: Array[Dictionary] = []
	if combatant == null:
		return applied
	for ability in get_active_abilities(combatant):
		for effect in ability.effects:
			if effect == null or effect.effect_type != AbilityEffectDataScript.Type.AFTER_MOVE_APPLY_STATUS or effect.status_effect == null:
				continue
			if combatant.movement_distance_this_turn + 0.001 < effect.minimum_move_distance_feet:
				continue
			if combatant.has_status(effect.status_effect.id):
				continue
			combatant.add_effect(effect.status_effect)
			applied.append({"ability_name": ability.display_name, "effect_name": effect.status_effect.display_name})
	return applied


func get_non_stacking_attack_bonus(combatant, attack, effect_type: int) -> int:
	var total := 0
	for ability in get_attack_abilities(combatant, attack):
		# One Ability contributes at most once, even if its data is duplicated.
		var ability_bonus := 0
		for effect in ability.effects:
			if effect != null and effect.effect_type == effect_type and attack_matches(effect, attack):
				ability_bonus = maxi(ability_bonus, effect.passive_value)
		total += ability_bonus
	return total


func get_conditional_damage_bonuses(attacker, target, attack, current_round: int) -> Array[Dictionary]:
	var bonuses: Array[Dictionary] = []
	if attacker == null or target == null:
		return bonuses
	for ability in get_attack_abilities(attacker, attack):
		if ability == null or attacker.level < ability.required_level:
			continue
		for effect in ability.effects:
			if effect == null or effect.effect_type != AbilityEffectDataScript.Type.CONDITIONAL_DAMAGE_BONUS:
				continue
			if effect.first_successful_hit_per_turn and int(attacker.ability_uses_this_turn.get(ability.id, 0)) >= 1:
				continue
			if not effect.required_attack_trait_ids.all(func(trait_id): return attack_has_trait(attack, trait_id)):
				continue
			if not attack_matches(effect, attack) or not conditional_damage_matches(effect, target, current_round):
				continue
			var amount: int = effect.flat_damage_bonus + effect.damage_bonus_per_level * attacker.level
			if effect.alternate_target_hp_at_or_below_percent > 0 and target.max_hp > 0 and target.hp * 100 <= target.max_hp * effect.alternate_target_hp_at_or_below_percent:
				amount = effect.alternate_flat_damage_bonus + effect.damage_bonus_per_level * attacker.level
			if amount != 0:
				bonuses.append({"ability_id": ability.id, "source": ability.display_name, "amount": amount, "consume_on_hit": effect.first_successful_hit_per_turn})
	return bonuses


func commit_conditional_damage_bonuses(attacker, bonuses: Array[Dictionary]) -> void:
	if attacker == null:
		return
	var committed: Array[String] = []
	for bonus in bonuses:
		var ability_id := String(bonus.get("ability_id", ""))
		if bonus.get("consume_on_hit", false) and not ability_id.is_empty() and not committed.has(ability_id):
			attacker.ability_uses_this_turn[ability_id] = 1
			committed.append(ability_id)


func consume_on_hit_status_effects(attacker, attack) -> Array[Dictionary]:
	var statuses: Array[Dictionary] = []
	if attacker == null or attack == null:
		return statuses
	var consumed_abilities: Array[String] = []
	for ability in get_attack_abilities(attacker, attack):
		if ability == null or attacker.level < ability.required_level:
			continue
		if int(attacker.ability_uses_this_turn.get(ability.id, 0)) >= 1:
			continue
		for effect in ability.effects:
			if effect == null or effect.effect_type != AbilityEffectDataScript.Type.ON_HIT_APPLY_STATUS:
				continue
			if effect.status_effect == null or not attack_matches(effect, attack):
				continue
			if not effect.required_attack_trait_ids.all(func(trait_id): return attack_has_trait(attack, trait_id)):
				continue
			statuses.append({
				"ability_id": ability.id,
				"source": ability.display_name,
				"effect": effect.status_effect,
			})
			if effect.first_successful_hit_per_turn and not consumed_abilities.has(ability.id):
				attacker.ability_uses_this_turn[ability.id] = 1
				consumed_abilities.append(ability.id)
	return statuses


func conditional_damage_matches(effect, target, current_round: int) -> bool:
	var conditions: Array[bool] = []
	if effect.requires_target_unattacked_this_round:
		conditions.append(target.last_attack_declared_round != current_round)
	if effect.target_hp_below_percent > 0:
		conditions.append(target.max_hp > 0 and target.hp * 100 < target.max_hp * effect.target_hp_below_percent)
	if not effect.required_target_status_ids.is_empty():
		conditions.append(effect.required_target_status_ids.any(func(status_id): return target.has_status(status_id)))
	if conditions.is_empty():
		return true
	if effect.condition_mode == AbilityEffectDataScript.ConditionMode.ALL:
		return not conditions.has(false)
	return conditions.has(true)


func get_skill_cooldown_modifier(combatant, skill_id: String) -> int:
	var modifier := 0
	if combatant == null:
		return modifier
	for ability in get_active_abilities(combatant):
		if ability == null or combatant.level < ability.required_level:
			continue
		for effect in ability.effects:
			if effect == null or effect.effect_type != AbilityEffectDataScript.Type.SKILL_COOLDOWN_MODIFIER:
				continue
			if effect.affected_skill_ids.is_empty() or effect.affected_skill_ids.has(skill_id):
				modifier += effect.skill_cooldown_modifier
	return modifier


func get_skill_damage_bonus(combatant) -> int:
	return _sum_skill_modifier(combatant, AbilityEffectDataScript.Type.PASSIVE_SKILL_DAMAGE_BONUS, "skill_damage_bonus")


func get_skill_mana_discount(combatant, skill = null) -> int:
	var total := 0
	if combatant == null:
		return total
	for ability in get_active_abilities(combatant):
		if ability == null or combatant.level < ability.required_level:
			continue
		for effect in ability.effects:
			if effect == null or effect.effect_type != AbilityEffectDataScript.Type.PASSIVE_SKILL_MANA_DISCOUNT:
				continue
			if skill != null and skill.mana_cost < effect.minimum_skill_base_mana_cost:
				continue
			if effect.first_skill_per_turn and int(combatant.ability_uses_this_turn.get(ability.id, 0)) >= 1:
				continue
			total += effect.skill_mana_discount
	return total


func commit_skill_mana_discount(combatant, skill) -> void:
	if combatant == null or skill == null:
		return
	for ability in get_active_abilities(combatant):
		for effect in ability.effects:
			if effect != null and effect.effect_type == AbilityEffectDataScript.Type.PASSIVE_SKILL_MANA_DISCOUNT \
				and effect.first_skill_per_turn and skill.mana_cost >= effect.minimum_skill_base_mana_cost \
				and int(combatant.ability_uses_this_turn.get(ability.id, 0)) < 1:
				combatant.ability_uses_this_turn[ability.id] = 1


func get_minimum_skill_mana_cost(combatant, skill = null) -> int:
	var minimum := 0
	for ability in get_active_abilities(combatant):
		for effect in ability.effects:
			if effect != null and effect.effect_type == AbilityEffectDataScript.Type.PASSIVE_SKILL_MANA_DISCOUNT \
				and (skill == null or skill.mana_cost >= effect.minimum_skill_base_mana_cost) \
				and (not effect.first_skill_per_turn or int(combatant.ability_uses_this_turn.get(ability.id, 0)) < 1):
				minimum = maxi(minimum, effect.minimum_skill_mana_cost)
	return minimum


func get_skill_range_bonus(combatant) -> float:
	return float(_sum_skill_modifier(combatant, AbilityEffectDataScript.Type.PASSIVE_SKILL_RANGE_BONUS_FEET, "skill_range_bonus_feet"))


func _sum_skill_modifier(combatant, effect_type: int, property_name: String) -> int:
	var total := 0
	if combatant == null:
		return total
	for ability in get_active_abilities(combatant):
		if ability == null or combatant.level < ability.required_level:
			continue
		for effect in ability.effects:
			if effect != null and effect.effect_type == effect_type:
				total += int(effect.get(property_name))
	return total


func get_remaining_cooldown(combatant, ability_id: String) -> int:
	if combatant == null:
		return 0
	return maxi(0, int(combatant.ability_cooldowns.get(ability_id, 0)))


func start_cooldown(combatant, ability) -> int:
	if combatant == null or ability == null:
		return 0
	var turns: int = maxi(0, ability.cooldown_turns)
	if turns > 0:
		combatant.ability_cooldowns[ability.id] = turns
		combatant.ability_cooldown_skip_next_reduction[ability.id] = true
	else:
		combatant.ability_cooldowns.erase(ability.id)
		combatant.ability_cooldown_skip_next_reduction.erase(ability.id)
	return turns


func set_remaining_cooldown(combatant, ability_id: String, turns: int) -> int:
	if combatant == null:
		return 0
	var value := maxi(0, turns)
	if value <= 0:
		combatant.ability_cooldowns.erase(ability_id)
		combatant.ability_cooldown_skip_next_reduction.erase(ability_id)
	else:
		combatant.ability_cooldowns[ability_id] = value
	return value


func change_remaining_cooldown(combatant, ability_id: String, amount: int) -> int:
	return set_remaining_cooldown(combatant, ability_id, get_remaining_cooldown(combatant, ability_id) + amount)


func reduce_cooldowns(combatant) -> Array[Dictionary]:
	var reduced: Array[Dictionary] = []
	if combatant == null:
		return reduced
	for ability_id in combatant.ability_cooldowns.keys().duplicate():
		if combatant.ability_cooldown_skip_next_reduction.erase(ability_id):
			continue
		var remaining: int = maxi(0, int(combatant.ability_cooldowns[ability_id]) - 1)
		if remaining <= 0:
			combatant.ability_cooldowns.erase(ability_id)
		else:
			combatant.ability_cooldowns[ability_id] = remaining
		reduced.append({"ability_id": ability_id, "remaining": remaining})
	return reduced


func on_attack_resolved(combatant, attack) -> Array[Dictionary]:
	var triggered: Array[Dictionary] = []
	for ability in get_attack_abilities(combatant, attack):
		if ability == null:
			continue
		for effect_index in range(ability.effects.size()):
			var effect = ability.effects[effect_index]
			if effect == null or effect.trigger != AbilityEffectDataScript.Trigger.ON_ATTACK_RESOLVED:
				continue
			if not attack_matches(effect, attack):
				continue
			if effect.effect_type == AbilityEffectDataScript.Type.STACKED_TO_HIT_BONUS:
				var current_stacks := get_stack_count(combatant, ability.id, effect_index)
				var next_stacks: int = current_stacks + effect.stack_amount
				if effect.max_stacks > 0:
					next_stacks = min(next_stacks, effect.max_stacks)
				if next_stacks == current_stacks:
					continue
				set_stack_count(combatant, ability.id, effect_index, next_stacks)
				triggered.append({
					"ability_name": ability.display_name,
					"stacks": next_stacks,
					"bonus": next_stacks * effect.to_hit_bonus_per_stack,
				})
	return triggered


func clear_end_turn_bonuses(combatant) -> Array[Dictionary]:
	var cleared: Array[Dictionary] = []
	for ability in get_active_abilities(combatant):
		if ability == null:
			continue
		for effect_index in range(ability.effects.size()):
			var effect = ability.effects[effect_index]
			if effect == null or not effect.clear_stacks_at_end_turn:
				continue
			var stacks := get_stack_count(combatant, ability.id, effect_index)
			if stacks <= 0:
				continue
			set_stack_count(combatant, ability.id, effect_index, 0)
			cleared.append({"ability_name": ability.display_name, "stacks": stacks})
	return cleared


func get_available_ability(combatant, ability_id: String):
	for ability in combatant.available_abilities:
		if ability != null and ability.id == ability_id:
			return ability
	var weapon_attack = combatant.equipped_weapon_attack if combatant != null else null
	if weapon_attack != null:
		for ability in weapon_attack.granted_abilities:
			if ability != null and ability.id == ability_id:
				return ability
	return null


func is_ability_active(combatant, ability_id: String) -> bool:
	if combatant == null:
		return false
	if combatant.equipped_abilities.has(ability_id):
		return true
	var weapon_attack = combatant.equipped_weapon_attack
	if weapon_attack == null:
		return false
	for ability in weapon_attack.granted_abilities:
		if ability != null and ability.id == ability_id and meets_required_traits(combatant, ability):
			return true
	return false


func get_active_abilities(combatant) -> Array:
	var abilities: Array = []
	var ability_ids: Array[String] = []
	if combatant == null:
		return abilities
	for ability_id in combatant.equipped_abilities:
		var ability = get_available_ability(combatant, ability_id)
		if ability != null and meets_required_traits(combatant, ability) and not ability_ids.has(ability.id):
			abilities.append(ability)
			ability_ids.append(ability.id)
	var weapon_attack = combatant.equipped_weapon_attack
	if weapon_attack != null:
		for ability in weapon_attack.granted_abilities:
			if ability != null and meets_required_traits(combatant, ability) and not ability_ids.has(ability.id):
				abilities.append(ability)
				ability_ids.append(ability.id)
	return abilities


func meets_required_traits(combatant, ability) -> bool:
	if combatant == null or ability == null:
		return false
	for trait_id in ability.required_trait_ids:
		if not combatant_has_trait(combatant, trait_id):
			return false
	return true


func get_movement_effect(ability):
	if ability == null:
		return null
	for effect in ability.effects:
		if effect != null and effect.effect_type == AbilityEffectDataScript.Type.ABILITY_MOVEMENT:
			return effect
	return null


func get_attack_data(combatant, ability) -> AttackData:
	if combatant == null or ability == null:
		return null
	var source: int = ability.attack_source
	if ability.uses_equipped_weapon_attack:
		source = AbilityData.AttackSource.EQUIPPED_WEAPON
	match source:
		AbilityData.AttackSource.EQUIPPED_WEAPON:
			return combatant.equipped_weapon_attack
		AbilityData.AttackSource.CONFIGURED_ATTACK:
			return ability.attack_data
	return null


func get_targeting_range(combatant, ability) -> float:
	if combatant == null or ability == null:
		return 0.0
	if ability.execution_mode == AbilityData.ExecutionMode.ATTACK_SEQUENCE:
		var main_item = combatant.equipped_items.get(EquipmentSystem.WEAPON_SLOT_1)
		var off_item = combatant.equipped_items.get(EquipmentSystem.WEAPON_SLOT_2)
		if main_item == null or off_item == null or main_item.weapon_attack == null or off_item.weapon_attack == null:
			return 0.0
		return minf(main_item.weapon_attack.range_feet, off_item.weapon_attack.range_feet)
	if ability.targeting_range_feet > 0.0:
		return ability.targeting_range_feet
	var attack: AttackData = get_attack_data(combatant, ability)
	return attack.range_feet if attack != null else 0.0


func target_filter_matches(actor, target, ability) -> bool:
	if actor == null or target == null or ability == null:
		return false
	match ability.target_filter:
		AbilityData.TargetFilter.ENEMIES:
			return actor.team != target.team
		AbilityData.TargetFilter.ALLIES:
			return actor.team == target.team
	return true


func validate_active_use(combatant, ability, target = null) -> ActionResult:
	if combatant == null or ability == null or not is_ability_active(combatant, ability.id):
		return ActionResult.failure("Ability is not active.")
	if ability.is_passive:
		return ActionResult.failure("Passive abilities cannot be activated.")
	if ability.reaction_only:
		return ActionResult.failure("Reaction abilities can only be used when their trigger occurs.")
	if combatant.level < ability.required_level:
		return ActionResult.failure("Requires level %d." % ability.required_level)
	if combatant.ap < ability.ap_cost:
		return ActionResult.failure("Not enough AP.")
	if combatant.get_total_faith() < ability.faith_cost:
		return ActionResult.failure("Not enough Faith: %s requires %d Faith." % [ability.display_name, ability.faith_cost])
	if get_remaining_cooldown(combatant, ability.id) > 0:
		return ActionResult.failure("%s is on cooldown." % ability.display_name)
	if ability.uses_per_turn > 0 and int(combatant.ability_uses_this_turn.get(ability.id, 0)) >= ability.uses_per_turn:
		return ActionResult.failure("%s has already been used this turn." % ability.display_name)
	if ability.execution_mode == AbilityData.ExecutionMode.ATTACK_SEQUENCE:
		var sequence_validation: ActionResult = EquipmentSystem.new().validate_dual_weapon_setup(combatant)
		if not sequence_validation.success:
			return sequence_validation
	for trait_id in ability.required_trait_ids:
		if not combatant_has_trait(combatant, trait_id):
			return ActionResult.failure("Requires the %s trait." % trait_id)
	if not ability.required_attack_trait_ids.is_empty():
		var source_attack := get_attack_data(combatant, ability)
		if source_attack == null:
			return ActionResult.failure("Equip a valid weapon first.")
		for trait_id in ability.required_attack_trait_ids:
			if not attack_has_trait(source_attack, trait_id):
				return ActionResult.failure("Requires a weapon with the %s trait." % trait_id)
	if ability.target_mode == AbilityData.TargetMode.SELF:
		return ActionResult.success_result()
	if ability.target_mode == AbilityData.TargetMode.SINGLE_COMBATANT:
		if target == null or target.is_dying():
			return ActionResult.failure("Choose a valid target.")
		if not target_filter_matches(combatant, target, ability):
			return ActionResult.failure("That target is not valid for this Ability.")
	return ActionResult.success_result()


func get_use_effects(ability) -> Array:
	var entries: Array = []
	if ability == null:
		return entries
	entries.append_array(ability.use_effects)
	for effect in ability.effects_on_use:
		if effect == null:
			continue
		var legacy_entry := AbilityUseEffectDataScript.new()
		legacy_entry.effect = effect
		entries.append(legacy_entry)
	return entries


func sync_granted_reactions(combatant) -> void:
	if combatant == null:
		return
	# Remove only reactions owned by available Abilities, preserving reactions
	# granted directly by the character, ancestry, class, or equipment.
	var granted_ids: Array[String] = []
	for ability in combatant.available_abilities:
		if ability == null:
			continue
		for reaction in ability.granted_reactions:
			if reaction != null and not granted_ids.has(reaction.id):
				granted_ids.append(reaction.id)
	for index in range(combatant.active_reactions.size() - 1, -1, -1):
		var active_reaction = combatant.active_reactions[index]
		if active_reaction != null and granted_ids.has(active_reaction.id):
			combatant.active_reactions.remove_at(index)
	for ability_id in combatant.equipped_abilities:
		var ability = get_available_ability(combatant, ability_id)
		if ability == null or combatant.level < ability.required_level:
			continue
		for reaction in ability.granted_reactions:
			if reaction != null and not has_reaction(combatant, reaction.id):
				combatant.active_reactions.append(reaction)


func has_reaction(combatant, reaction_id: String) -> bool:
	for reaction in combatant.active_reactions:
		if reaction != null and reaction.id == reaction_id:
			return true
	return false


func get_attack_abilities(combatant, attack) -> Array:
	var abilities: Array = []
	var ability_ids: Array[String] = []
	for ability_id in combatant.equipped_abilities:
		var ability = get_available_ability(combatant, ability_id)
		if ability != null and combatant.level >= ability.required_level and not ability_ids.has(ability.id):
			abilities.append(ability)
			ability_ids.append(ability.id)
	if attack != null:
		for ability in attack.granted_abilities:
			if ability != null and combatant.level >= ability.required_level and not ability_ids.has(ability.id):
				abilities.append(ability)
				ability_ids.append(ability.id)
	return abilities


func attack_matches(effect, attack) -> bool:
	return not effect.requires_unarmed_attack or attack_has_trait(attack, "unarmed")


func attack_has_trait(attack, trait_id: String) -> bool:
	if attack == null:
		return false
	for trait_data in attack.traits:
		if trait_data != null and trait_data.id == trait_id:
			return true
	return false


func get_stack_count(combatant, ability_id: String, effect_index: int) -> int:
	return int(combatant.ability_stacks.get(get_stack_key(ability_id, effect_index), 0))


func set_stack_count(combatant, ability_id: String, effect_index: int, count: int) -> void:
	var key := get_stack_key(ability_id, effect_index)
	if count <= 0:
		combatant.ability_stacks.erase(key)
	else:
		combatant.ability_stacks[key] = count


func clear_ability_stacks(combatant, ability_id: String) -> void:
	var prefix := "%s:" % ability_id
	for key in combatant.ability_stacks.keys():
		if String(key).begins_with(prefix):
			combatant.ability_stacks.erase(key)


func get_stack_key(ability_id: String, effect_index: int) -> String:
	return "%s:%d" % [ability_id, effect_index]


func combatant_has_trait(combatant, trait_id: String) -> bool:
	for trait_data in combatant.active_traits:
		if trait_data != null and trait_data.id == trait_id:
			return true
	return false


func ability_has_trait(ability, trait_id: String) -> bool:
	if ability == null:
		return false
	for trait_data in ability.traits:
		if trait_data != null and trait_data.id == trait_id:
			return true
	return false
