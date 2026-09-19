extends SceneTree

const PanelScene := preload("res://scenes/run/LevelUpPanel.tscn")
const ElementSchool := preload("res://data/ability/element_school.tres")
const EmberTraining := preload("res://data/ability/Spell Training/spell_training_ember_bolt.tres")
const FrostTraining := preload("res://data/ability/Spell Training/spell_training_frost_shard.tres")
const FrozenGroundTraining := preload("res://data/ability/Spell Training/spell_training_frozen_ground.tres")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var failures: Array[String] = []
	var character := CombatantState.new()
	character.id = "blue_blood_mage"
	character.display_name = "Blue Blood Mage"
	character.level = 1
	character.ability_points = 1
	character.pending_level_up_choices = [{"level": 1, "ability_points_remaining": 1, "attribute_points_remaining": 0}]
	var blue_blood_trait := TraitData.new()
	blue_blood_trait.id = "blue_blood"
	character.active_traits = [blue_blood_trait]
	var progression := ProgressionSystem.new()
	var direct_spell := progression.learn_ability(character, EmberTraining)
	check(not direct_spell.success and character.ability_points == 1, "Spells cannot be purchased directly with Ability Points", failures)
	check(progression.spell_training_matches_grantor(EmberTraining, ElementSchool), "Element School accepts Elemental Spell Level 1", failures)
	check(progression.spell_training_matches_grantor(FrostTraining, ElementSchool), "Element School offers a second Elemental Spell Level 1", failures)
	check(not progression.spell_training_matches_grantor(FrozenGroundTraining, ElementSchool), "Element School rejects Spells above Level 1", failures)
	var panel: LevelUpPanel = PanelScene.instantiate()
	root.add_child(panel)
	await process_frame
	panel.open_for(character)
	panel.toggle_ability(ElementSchool)
	check(panel.selected_abilities.has(ElementSchool), "Level Up can select Element School", failures)
	panel.toggle_spell(EmberTraining, ElementSchool)
	panel.toggle_spell(FrostTraining, ElementSchool)
	check(not panel.confirm_button.disabled, "Choosing both granted Spells enables Confirm", failures)
	panel.confirm()
	check(character.ability_points == 0 and character.selected_ability_ids.has(ElementSchool.id), "Only Element School spends one Ability Point", failures)
	check(character.available_skills.has(EmberTraining.granted_skills[0]) and character.available_skills.has(FrostTraining.granted_skills[0]), "Element School teaches both selected Spells", failures)
	check(character.spell_choices_by_grantor.get(ElementSchool.id, []).size() == 2, "Spell choices are recorded under their granting Ability", failures)
	check(not character.selected_ability_ids.has(EmberTraining.id) and not character.selected_ability_ids.has(FrostTraining.id), "Selected Spells are not purchased as Abilities", failures)
	var combat_copy := CombatantState.new()
	var arena = load("res://scenes/prototype/prototype_combat.gd").new()
	arena.apply_run_progression_state(combat_copy, character)
	check(combat_copy.available_skills.size() == 2 and combat_copy.spell_choices_by_grantor.get(ElementSchool.id, []).size() == 2, "Spell choices persist from Run Map into Combat", failures)
	arena.free()
	panel.queue_free()
	await process_frame
	if failures.is_empty():
		print("SKILL_LEVEL_UP_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
