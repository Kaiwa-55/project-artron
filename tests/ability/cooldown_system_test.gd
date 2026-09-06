extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var ability_system := AbilitySystem.new()
	var skill_system := SkillSystem.new(ability_system)
	var actor := CombatantState.new()
	actor.mana = 10
	actor.max_mana = 10
	var skill := SkillData.new()
	skill.id = "cooldown_test_skill"
	skill.mana_cost = 1
	skill.cooldown_turns = 3
	var ability := AbilityData.new()
	ability.id = "cooldown_training"
	ability.display_name = "Cooldown Training"
	var effect := AbilityEffectData.new()
	effect.effect_type = AbilityEffectData.Type.SKILL_COOLDOWN_MODIFIER
	effect.skill_cooldown_modifier = -1
	effect.affected_skill_ids = [skill.id]
	ability.effects = [effect]
	actor.available_abilities = [ability]
	actor.equipped_abilities = [ability.id]
	if skill_system.get_effective_cooldown_turns(actor, skill) != 2:
		failures.append("Ability modifier should reduce effective cooldown")
	skill_system.consume_skill_costs(actor, skill)
	if skill_system.get_remaining_cooldown(actor, skill.id) != 2:
		failures.append("using Skill should assign effective cooldown")
	if skill_system.change_remaining_cooldown(actor, skill.id, -1) != 1:
		failures.append("remaining cooldown should support relative adjustment")
	if skill_system.set_remaining_cooldown(actor, skill.id, 5) != 5:
		failures.append("remaining cooldown should support direct assignment")
	if skill_system.change_remaining_cooldown(actor, skill.id, -99) != 0 or actor.skill_cooldowns.has(skill.id):
		failures.append("cooldown should clamp to zero and clear its entry")
	for failure in failures: push_error(failure)
	print("COOLDOWN_SYSTEM_TEST: PASS" if failures.is_empty() else "COOLDOWN_SYSTEM_TEST: FAIL (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)
