extends SceneTree

const Catalog := preload("res://data/creation/default_creation_catalog.tres")
const ArcaneFocus := preload("res://data/ability/arcane_focus.tres")
const ArcaneStep := preload("res://data/ability/arcane_step.tres")
const ArcaneWard := preload("res://data/ability/arcane_ward.tres")
const ArcaneAim := preload("res://data/ability/arcane_aim.tres")
const AdvancedArcaneTheory := preload("res://data/ability/advanced_arcane_theory.tres")
const ArcaneShatterTraining := preload("res://data/ability/Spell Training/spell_training_arcane_shatter.tres")
const ArcaneShatter := preload("res://data/skill/arcane_shatter.tres")

func _init() -> void:
	var expected := {
		1: ["arcane_focus", "arcane_step", "arcane_ward"],
		2: ["arcane_aim", "potent_casting", "efficient_casting"],
		3: ["advanced_arcane_theory", "spell_reach"],
	}
	var failures: Array[String] = []
	for level in expected:
		var choices: Array[String] = []
		for ability in Catalog.abilities:
			if ability != null and ability.required_trait_ids.has("arcanist") and ability.required_level == level and not ability.auto_equip_on_grant and ability.granted_skills.is_empty():
				choices.append(ability.id)
		choices.sort()
		var wanted: Array = expected[level].duplicate()
		wanted.sort()
		if choices != wanted:
			failures.append("Arcanist Level %d choices were %s, expected %s." % [level, choices, wanted])
	if ArcaneFocus.is_passive == false or ArcaneFocus.effects.is_empty() or ArcaneFocus.effects[0].skill_mana_discount != 1:
		failures.append("Arcane Focus must provide the Level 1 passive Skill Mana discount.")
	if ArcaneStep.effects.is_empty() or ArcaneStep.effects[0].movement_distance_feet != 10.0 or ArcaneStep.effects[0].movement_triggers_reactions:
		failures.append("Arcane Step must provide 10 ft reaction-free movement.")
	if ArcaneWard.ap_cost != 1 or ArcaneWard.cooldown_turns != 2 or ArcaneWard.use_effects.is_empty():
		failures.append("Arcane Ward must be a 1 AP defensive active Ability with a cooldown.")
	if not ArcaneAim.is_passive or ArcaneAim.effects.is_empty() or ArcaneAim.effects[0].passive_value != 1 or not ArcaneAim.effects[0].required_attack_trait_ids.has("arcane"):
		failures.append("Arcane Aim must grant +1 To Hit to Arcane Skill attacks.")
	if AdvancedArcaneTheory.spell_choices_granted != 1 or AdvancedArcaneTheory.spell_min_level != 2 or AdvancedArcaneTheory.spell_max_level != 2 or not AdvancedArcaneTheory.spell_required_trait_ids.has("arcane"):
		failures.append("Advanced Arcane Theory must grant one Level 2 Arcane spell choice.")
	if ArcaneShatterTraining.granted_skills.size() != 1 or ArcaneShatterTraining.granted_skills[0].id != "arcane_shatter":
		failures.append("Arcane Shatter training must grant Arcane Shatter.")
	if ArcaneShatter.spell_level != 2 or ArcaneShatter.traits.is_empty() or ArcaneShatter.traits[0].id != "arcane" or ArcaneShatter.mana_cost != 3 or ArcaneShatter.ap_cost != 2 or ArcaneShatter.cooldown_turns != 2:
		failures.append("Arcane Shatter must retain its Level 2 Arcane casting costs and cooldown.")
	elif ArcaneShatter.attack_data == null or ArcaneShatter.attack_data.base_damage != 6 or ArcaneShatter.attack_data.effects_on_hit.is_empty() or ArcaneShatter.attack_data.effects_on_hit[0].id != "dazed":
		failures.append("Arcane Shatter must deal 6 Arcane damage and apply Dazed on hit.")
	for failure in failures:
		push_error(failure)
	print("ARCANIST_CHOICE_ROSTER_TEST: PASS" if failures.is_empty() else "ARCANIST_CHOICE_ROSTER_TEST: FAIL (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)
