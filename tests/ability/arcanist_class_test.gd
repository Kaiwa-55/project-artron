extends SceneTree

const Catalog = preload("res://data/creation/default_creation_catalog.tres")
const Draft = preload("res://scenes/character_creation/creation_draft.gd")
const Arcanist = preload("res://data/class/arcanist.tres")

var failures: Array[String] = []


func _init() -> void:
	var draft = Draft.new()
	draft.setup(Catalog)
	draft.select_class(Arcanist)
	draft.ancestry_choices.assign([0, 1, 2])
	draft.class_choices.assign([1])
	draft.rebuild()
	check(draft.preview.class_id == "arcanist", "Arcanist should be selectable in Character Creation.")
	check(draft.preview.max_mana == 8, "Arcanist should start with 8 Mana.")
	check(draft.preview.intelligence == Catalog.base_character.intelligence + 1, "Arcane Mind should grant Intelligence +1 through the class.")
	check(draft.preview.available_skills.is_empty(), "Arcanist should not receive every spell before choosing Spell Training.")
	check(not draft.step_error("spells").is_empty(), "Arcane Mind's unspent Spell Choices should be shown as pending.")

	var training: AbilityData = Catalog.find_ability("spell_training_arcane_bolt")
	var ability_points_before: int = draft.preview.ability_points
	draft.toggle_spell(training)
	check(draft.learned_spell_ids.has(training.id), "Arcane Mind should allow the Arcanist to choose Spell Training.")
	check(draft.preview.ability_points == ability_points_before, "Learning a Spell should not spend an Ability Point.")
	check(draft.preview.available_skills.any(func(skill): return skill.id == "arcane_bolt"), "Learning Spell Training should add its Skill to the spellbook.")
	draft.toggle_spell(Catalog.find_ability("spell_training_arcane_burst"))
	check(draft.get_spell_choices_remaining() == 0, "Arcane Mind should provide exactly two starting Spell Choices.")
	check(draft.step_error("spells").is_empty(), "Choosing both granted Spells should complete the Spells step.")
	draft.toggle_spell(Catalog.find_ability("spell_training_arcane_cone"))
	check(not draft.learned_spell_ids.has("spell_training_arcane_cone"), "A third Spell cannot be learned without another Ability granting a Spell Choice.")
	var character: CharacterData = draft.finish()
	var state: CombatantState = character.create_combatant_state()
	CharacterClassSystem.new().apply_class(state)
	ProgressionSystem.new().initialize_character(state)
	check(state.available_skills.any(func(skill): return skill.id == "arcane_bolt"), "A selected Skill should survive Character Creation handoff.")

	state.level = 3
	for ability_id in ["potent_casting", "efficient_casting", "spell_reach", "rapid_formula"]:
		var ability: AbilityData = Catalog.find_ability(ability_id)
		if not state.available_abilities.has(ability):
			state.available_abilities.append(ability)
		if not state.equipped_abilities.has(ability_id):
			state.equipped_abilities.append(ability_id)
	var ability_system := AbilitySystem.new()
	var skill_system := SkillSystem.new(ability_system)
	var bolt = load("res://data/skill/arcane_bolt.tres")
	var modified_attack: AttackData = skill_system.get_attack_data(bolt, state)
	check(modified_attack.base_damage == bolt.attack_data.base_damage + 1, "Potent Casting should add 1 Damage to Skills.")
	check(skill_system.get_effective_mana_cost(state, bolt) == maxi(1, bolt.mana_cost - 1), "Efficient Casting should reduce Skill Mana cost by 1.")
	state.mana = state.max_mana
	skill_system.consume_skill_costs(state, bolt)
	check(skill_system.get_effective_mana_cost(state, bolt) == bolt.mana_cost, "Efficient Casting should apply only to the first qualifying Skill each Turn.")
	check(skill_system.get_effective_range_feet(state, bolt) == bolt.attack_data.range_feet + 5.0, "Spell Reach should add 5 ft to Skill range.")
	check(skill_system.get_effective_cooldown_turns(state, bolt) == maxi(0, bolt.cooldown_turns - 1), "Rapid Formula should reduce Skill cooldown by 1 Turn.")

	for failure in failures:
		push_error(failure)
	print("ARCANIST_CLASS_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
