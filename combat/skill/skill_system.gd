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
	if actor.mana < skill.mana_cost:
		return ActionResult.failure("Not enough Mana.")
	if get_remaining_cooldown(actor, skill.id) > 0:
		return ActionResult.failure("%s is on cooldown (%d turn(s))." % [skill.display_name, get_remaining_cooldown(actor, skill.id)])
	var skill_attack := get_attack_data(skill)
	if skill_attack == null:
		return ActionResult.failure("Skill has no action data.")
	return attack_system.validate_attack(actor, target, skill_attack)


func consume_skill_costs(actor: CombatantState, skill) -> void:
	actor.change_mana(-skill.mana_cost)
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


func get_attack_data(skill) -> AttackData:
	if skill == null or skill.attack_data == null:
		return null
	var skill_attack: AttackData = skill.attack_data.duplicate()
	skill_attack.ap_cost = skill.ap_cost
	return skill_attack
