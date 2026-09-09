class_name EffectSystem
extends RefCounted


func apply_effect(target: CombatantState, effect: EffectData, source_ability_id: String = "", source_ability_name: String = "", is_stance: bool = false, source: CombatantState = null) -> bool:
	if target == null or effect == null or effect.id.is_empty():
		return false
	if target.is_immune_to_status(effect):
		return false

	if effect.effect_type == EffectData.Type.CLEANSE:
		return cleanse_statuses(
			target,
			effect.cleanse_status_ids,
			effect.cleanse_status_tags,
			effect.cleanse_all
		) > 0

	var source_id := source.id if source != null else ""
	var source_dc: int = source.class_dc if source != null else effect.default_escape_dc
	target.add_effect(effect, source_ability_id, source_ability_name, is_stance, source_id, source_dc)
	if target.movement_in_progress:
		target.movement_remaining_feet = minf(target.movement_remaining_feet, target.get_effective_speed())
	return true


func get_escapable_effects(combatant: CombatantState) -> Array[EffectInstance]:
	var result: Array[EffectInstance] = []
	if combatant == null:
		return result
	for instance in combatant.effects:
		if instance != null and instance.data != null and instance.data.can_escape:
			result.append(instance)
	return result


func get_attack_bonus(combatant: CombatantState) -> int:
	return get_total_bonus(combatant, "attack_bonus")


func get_damage_bonus(combatant: CombatantState, attack: AttackData = null) -> int:
	if combatant == null:
		return 0
	var total := 0
	for effect_instance in combatant.effects:
		var effect: EffectData = effect_instance.data
		if effect == null or not effect_matches_attack(effect, attack):
			continue
		total += effect.damage_bonus * effect_instance.stack_count
	return total


func effect_matches_attack(effect: EffectData, attack: AttackData) -> bool:
	if effect.required_attack_trait_ids.is_empty():
		return true
	if attack == null:
		return false
	for required_trait_id in effect.required_attack_trait_ids:
		if not attack.traits.any(func(trait_data): return trait_data != null and trait_data.id == required_trait_id):
			return false
	return true


func get_reflex_bonus(combatant: CombatantState) -> int:
	return get_total_bonus(combatant, "reflex_bonus")


func get_fortitude_bonus(combatant: CombatantState) -> int:
	return get_total_bonus(combatant, "fortitude_bonus")


func get_will_bonus(combatant: CombatantState) -> int:
	return get_total_bonus(combatant, "will_bonus")


func get_max_ap_penalty(combatant: CombatantState) -> int:
	var total := 0
	if combatant == null:
		return total
	for effect_instance in combatant.effects:
		total += effect_instance.data.ap_penalty_per_stack * effect_instance.stack_count
	return total


func get_max_ap_bonus(combatant: CombatantState) -> int:
	var total := 0
	if combatant == null:
		return total
	for effect_instance in combatant.effects:
		total += effect_instance.data.max_ap_bonus_per_stack * effect_instance.stack_count
	return total


func resolve_effects(
	combatant: CombatantState,
	trigger: EffectData.Trigger
) -> Array[Dictionary]:
	var resolutions: Array[Dictionary] = []

	for effect_instance in combatant.effects:
		var effect := effect_instance.data
		var stacks := effect_instance.stack_count
		if effect.trigger != trigger:
			continue

		match effect.effect_type:
			EffectData.Type.DAMAGE:
				var immune := combatant.is_immune_to_damage(effect.damage_type)
				var resistance := combatant.get_damage_resistance(effect.damage_type)
				var final_damage: int = 0 if immune else max(0, effect.amount * stacks - resistance)
				combatant.apply_damage(final_damage)
				resolutions.append({
					"type": "damage",
					"effect_name": effect.display_name,
					"amount": final_damage,
					"stacks": stacks,
					"damage_type": effect.damage_type,
					"immune": immune
				})

			EffectData.Type.HEAL:
				resolutions.append({
					"type": "heal",
					"effect_name": effect.display_name,
					"amount": combatant.heal(effect.amount * stacks),
					"stacks": stacks
				})

			EffectData.Type.RESOURCE:
				resolutions.append(resolve_resource_effect(combatant, effect, stacks))

	return resolutions


func expire_turn_end_effects(combatant: CombatantState) -> Array[EffectInstance]:
	var expired: Array[EffectInstance] = []

	for index in range(combatant.effects.size() - 1, -1, -1):
		var effect := combatant.effects[index]
		if effect.data.expire_at_start_of_turn or effect.data.persists_until_combat_end:
			continue
		effect.remaining_turns -= 1

		if effect.remaining_turns <= 0:
			expired.append(effect)
			combatant.effects.remove_at(index)

	return expired


func expire_start_turn_effects(combatant: CombatantState) -> Array[EffectInstance]:
	var expired: Array[EffectInstance] = []
	if combatant == null:
		return expired
	for index in range(combatant.effects.size() - 1, -1, -1):
		var effect := combatant.effects[index]
		if not effect.data.expire_at_start_of_turn or effect.data.persists_until_combat_end:
			continue
		expired.append(effect)
		combatant.effects.remove_at(index)
	return expired


func decay_start_turn_stacks(combatant: CombatantState) -> Array[EffectInstance]:
	var removed: Array[EffectInstance] = []
	if combatant == null:
		return removed
	for index in range(combatant.effects.size() - 1, -1, -1):
		var instance := combatant.effects[index]
		if instance == null or instance.data == null or instance.data.stack_decay_at_start_turn <= 0:
			continue
		instance.stack_count = maxi(0, instance.stack_count - instance.data.stack_decay_at_start_turn)
		if instance.stack_count <= 0:
			removed.append(instance)
			combatant.effects.remove_at(index)
	return removed


func decay_end_turn_stacks(combatant: CombatantState) -> Array[EffectInstance]:
	var removed: Array[EffectInstance] = []
	var constitution_reduction := maxi(1, combatant.get_modifier(combatant.constitution))
	for index in range(combatant.effects.size() - 1, -1, -1):
		var instance := combatant.effects[index]
		match instance.data.status_kind:
			EffectData.StatusKind.BLEEDING:
				instance.stack_count = maxi(0, instance.stack_count - constitution_reduction)
			EffectData.StatusKind.SLOWED:
				instance.stack_count = maxi(0, instance.stack_count - constitution_reduction)
			EffectData.StatusKind.FRIGHTENED:
				instance.stack_count = maxi(0, instance.stack_count - 1)
		if instance.stack_count <= 0:
			removed.append(instance)
			combatant.effects.remove_at(index)
	return removed


func resolve_resource_effect(
	combatant: CombatantState,
	effect: EffectData,
	stacks: int = 1
) -> Dictionary:
	var amount_changed := 0
	var resource_name := "HP"

	match effect.resource_type:
		EffectData.ResourceType.HP:
			if effect.amount >= 0:
				amount_changed = combatant.heal(effect.amount * stacks)
			else:
				var previous_hp := combatant.hp
				combatant.apply_damage(-effect.amount * stacks)
				amount_changed = combatant.hp - previous_hp
			resource_name = "HP"
		EffectData.ResourceType.AP:
			amount_changed = combatant.change_ap(effect.amount * stacks)
			resource_name = "AP"
		EffectData.ResourceType.MANA:
			amount_changed = combatant.change_mana(effect.amount * stacks)
			resource_name = "Mana"

	return {
		"type": "resource",
		"effect_name": effect.display_name,
		"amount": amount_changed,
		"stacks": stacks,
		"resource_name": resource_name
	}


func get_total_bonus(combatant: CombatantState, property_name: String) -> int:
	if combatant == null:
		return 0

	var total := 0
	for effect in combatant.effects:
		total += effect.data.get(property_name) * effect.stack_count

	return total


func cleanse_statuses(
	combatant: CombatantState,
	status_ids: Array[String] = [],
	status_tags: Array[String] = [],
	cleanse_all: bool = false
) -> int:
	var removed := 0
	for index in range(combatant.effects.size() - 1, -1, -1):
		var instance = combatant.effects[index]
		var status = instance.data
		if not status.can_be_cleansed:
			continue
		var id_matches := status_ids.has(status.id)
		var tag_matches := false
		for tag in status.status_tags:
			if status_tags.has(tag):
				tag_matches = true
				break
		if cleanse_all or id_matches or tag_matches:
			combatant.effects.remove_at(index)
			removed += 1
	return removed


func clear_all_effects(combatant: CombatantState) -> void:
	if combatant != null:
		combatant.effects.clear()
