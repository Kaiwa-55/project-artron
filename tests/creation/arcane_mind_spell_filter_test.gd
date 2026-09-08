extends SceneTree

const Catalog := preload("res://data/creation/default_creation_catalog.tres")
const DraftScript := preload("res://scenes/character_creation/creation_draft.gd")


func _init() -> void:
	var failures: Array[String] = []
	var draft = DraftScript.new()
	draft.setup(Catalog)
	var arcanist = Catalog.classes.filter(func(class_data): return class_data.id == "arcanist")[0]
	draft.select_class(arcanist)

	var arcane_bolt: AbilityData = Catalog.find_ability("spell_training_arcane_bolt")
	var arcane_cone: AbilityData = Catalog.find_ability("spell_training_arcane_cone")
	var arcane_burst: AbilityData = Catalog.find_ability("spell_training_arcane_burst")
	var ember_bolt: AbilityData = Catalog.find_ability("spell_training_ember_bolt")
	var arcane_mind: AbilityData = Catalog.find_ability("arcane_mind")

	check(arcane_mind.spell_required_trait_ids == ["arcane"] and arcane_mind.spell_max_level == 1, "Arcane Mind allows only Arcane Level 1 spells", failures)
	check(draft.is_spell_training_allowed(arcane_bolt), "Arcane Bolt is allowed", failures)
	check(draft.is_spell_training_allowed(arcane_cone), "Arcane Cone is allowed", failures)
	check(not draft.is_spell_training_allowed(arcane_burst), "Arcane Burst is rejected because it is above Level 1", failures)
	check(not draft.is_spell_training_allowed(ember_bolt), "Elemental Ember Bolt is rejected because it lacks Arcane", failures)

	draft.toggle_spell(ember_bolt)
	check(not draft.learned_spell_ids.has(ember_bolt.id), "An invalid Elemental spell cannot be selected through Arcane Mind", failures)
	draft.toggle_spell(arcane_bolt)
	draft.toggle_spell(arcane_cone)
	check(draft.learned_spell_ids.size() == 2 and draft.get_spell_choices_remaining() == 0, "Arcane Mind can fill both slots with valid Arcane Level 1 spells", failures)

	if failures.is_empty():
		print("ARCANE_MIND_SPELL_FILTER_TEST: PASS")
		quit(0)
	for failure in failures:
		push_error(failure)
	quit(1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
