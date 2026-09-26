class_name SkillSystem
extends RefCounted

var ability_system


func _init(p_ability_system = null) -> void:
	ability_system = p_ability_system

func validate_skill(actor: CombatantState, target: CombatantState, skill, attack_system: AttackSystem) -> ActionResult:
	if skill == null:
		return ActionResult.failure("Skill data does not exist.")
	if actor.has_status("silenced") and skill.mana_cost > 0:
		return ActionResult.failure("Silenced characters cannot use Mana Skills.")
	if not actor.available_skills.has(skill):
		return ActionResult.failure("Skill is not available to this character.")
	if actor.mana < get_effective_mana_cost(actor, skill):
		return ActionResult.failure("Not enough Mana.")
	if get_remaining_cooldown(actor, skill.id) > 0:
		return ActionResult.failure("%s is on cooldown (%d turn(s))." % [skill.display_name, get_remaining_cooldown(actor, skill.id)])
	if skill.target_mode == SkillData.TargetMode.SELF and skill.self_effect != null:
		if target != actor:
			return ActionResult.failure("This Skill targets the caster.")
		return ActionResult.success_result() if actor.ap >= skill.ap_cost else ActionResult.failure("Not enough AP.")
	var skill_attack := get_attack_data(skill, actor)
	if skill_attack == null:
		return ActionResult.failure("Skill has no action data.")
	return attack_system.validate_attack(actor, target, skill_attack)


func execute_self_effect_skill(actor: CombatantState, skill: SkillData, effect_system: EffectSystem) -> ActionResult:
	var mana_cost: int = get_effective_mana_cost(actor, skill)
	var cooldown: int = get_effective_cooldown_turns(actor, skill)
	if not actor.spend_ap(skill.ap_cost):
		return ActionResult.failure("Not enough AP.")
	consume_skill_costs(actor, skill)
	actor.focus_draught_skill_bonus = 0
	var result := ActionResult.success_result()
	result.events.append(CombatEvent.new(EventTypes.Type.SKILL_CAST, actor.id, actor.id, {"skill_name": skill.display_name, "mana_cost": mana_cost, "cooldown": cooldown}))
	if effect_system.apply_effect(actor, skill.self_effect, skill.id, skill.display_name, false, actor):
		result.events.append(CombatEvent.new(EventTypes.Type.EFFECT_APPLIED, actor.id, actor.id, {"effect_name": skill.self_effect.display_name, "skill_name": skill.display_name}))
	return result


func consume_skill_costs(actor: CombatantState, skill) -> void:
	actor.focus_draught_skill_bonus = actor.focus_draught_ready_bonus
	actor.focus_draught_ready_bonus = 0
	actor.change_mana(-get_effective_mana_cost(actor, skill))
	if ability_system != null:
		ability_system.commit_skill_mana_discount(actor, skill)
	# The attack itself pays its AP through AttackSystem.
	var cooldown := get_effective_cooldown_turns(actor, skill)
	if cooldown > 0:
		actor.skill_cooldowns[skill.id] = cooldown
	else:
		actor.skill_cooldowns.erase(skill.id)


func reduce_cooldowns(actor: CombatantState) -> Array[Dictionary]:
	var reduced: Array[Dictionary] = []
	for skill_id in actor.skill_cooldowns.keys().duplicate():
		var remaining: int = max(0, int(actor.skill_cooldowns[skill_id]) - 1)
		if remaining == 0:
			actor.skill_cooldowns.erase(skill_id)
		else:
			actor.skill_cooldowns[skill_id] = remaining
		reduced.append({"skill_id": skill_id, "remaining": remaining})
	return reduced


func get_remaining_cooldown(actor: CombatantState, skill_id: String) -> int:
	return max(0, int(actor.skill_cooldowns.get(skill_id, 0)))


func get_available_skill(actor: CombatantState, skill_id: String) -> SkillData:
	if actor == null:
		return null
	for skill in actor.available_skills:
		if skill != null and skill.id == skill_id:
			return skill
	return null


func get_effective_cooldown_turns(actor: CombatantState, skill) -> int:
	if skill == null:
		return 0
	var modifier: int = ability_system.get_skill_cooldown_modifier(actor, skill.id) if ability_system != null else 0
	return maxi(0, skill.cooldown_turns + modifier)


func set_remaining_cooldown(actor: CombatantState, skill_id: String, turns: int) -> int:
	var value := maxi(0, turns)
	if value == 0:
		actor.skill_cooldowns.erase(skill_id)
	else:
		actor.skill_cooldowns[skill_id] = value
	return value


func change_remaining_cooldown(actor: CombatantState, skill_id: String, amount: int) -> int:
	return set_remaining_cooldown(actor, skill_id, get_remaining_cooldown(actor, skill_id) + amount)


func get_effective_mana_cost(actor: CombatantState, skill) -> int:
	if skill == null:
		return 0
	var discount: int = ability_system.get_skill_mana_discount(actor, skill) if ability_system != null else 0
	var minimum: int = ability_system.get_minimum_skill_mana_cost(actor, skill) if ability_system != null else 0
	return maxi(minimum, skill.mana_cost - discount)


func get_effective_range_feet(actor: CombatantState, skill) -> float:
	if skill == null:
		return 0.0
	var base_range: float = skill.targeting_range_feet
	if base_range <= 0.0 and skill.attack_data != null:
		base_range = skill.attack_data.range_feet
	return base_range + (ability_system.get_skill_range_bonus(actor) if ability_system != null else 0.0)


func get_attack_data(skill, actor: CombatantState = null, consume_focus: bool = false) -> AttackData:
	if skill == null or skill.attack_data == null:
		return null
	var skill_attack: AttackData = skill.attack_data.duplicate()
	skill_attack.ap_cost = skill.ap_cost
	var character_class = actor.get_meta("class_data") if actor != null and actor.has_meta("class_data") else null
	if character_class != null:
		skill_attack.attack_attribute = AttackData.AttackAttribute.CLASS_MAIN_ATTRIBUTE
	if actor != null and ability_system != null:
		var ability_damage_sources: Array[Dictionary] = []
		var ability_damage: int = ability_system.get_skill_damage_bonus(actor, ability_damage_sources)
		skill_attack.base_damage += ability_damage
		skill_attack.base_damage_bonus_sources.append_array(ability_damage_sources)
		skill_attack.range_feet += ability_system.get_skill_range_bonus(actor)
	if actor != null and skill.mana_cost > 0:
		var counted_items: Array = []
		for item in actor.equipped_items.values():
			if item == null or counted_items.has(item):
				continue
			counted_items.append(item)
			if skill_attack.requires_to_hit:
				skill_attack.to_hit_bonus += item.spell_skill_to_hit_bonus
				if item.spell_skill_to_hit_bonus != 0:
					skill_attack.to_hit_bonus_sources.append({"source": item.display_name, "amount": item.spell_skill_to_hit_bonus})
			if not item.spell_skill_damage_type.is_empty() and skill_attack.damage_type == item.spell_skill_damage_type:
				skill_attack.base_damage += item.spell_skill_damage_bonus
				if item.spell_skill_damage_bonus != 0:
					skill_attack.base_damage_bonus_sources.append({"source": item.display_name, "amount": item.spell_skill_damage_bonus})
	if actor != null and consume_focus:
		var focus_bonus: int = actor.focus_draught_skill_bonus
		skill_attack.to_hit_bonus += focus_bonus
		if focus_bonus != 0:
			skill_attack.to_hit_bonus_sources.append({"source": "Focus Draught", "amount": focus_bonus})
		actor.focus_draught_skill_bonus = 0
	return skill_attack
