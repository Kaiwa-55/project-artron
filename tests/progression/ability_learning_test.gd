extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var system := ProgressionSystem.new()
	var character := CombatantState.new()
	character.level = 2
	character.ability_points = 3
	character.pending_level_up_choices = [{"level": 1, "ability_points_remaining": 1, "attribute_points_remaining": 0}, {"level": 2, "ability_points_remaining": 2, "attribute_points_remaining": 0}]
	var assassin_trait := TraitData.new()
	assassin_trait.id = "assassin"
	character.active_traits = [assassin_trait]

	var foundation := create_ability("foundation", "Foundation", 1, 1)
	var advanced := create_ability("advanced_art", "Advanced Art", 2, 2)
	advanced.prerequisite_id = foundation.id
	advanced.required_trait_ids = ["assassin"]
	var wrong_trait := create_ability("martial_art", "Martial Art", 1, 1)
	wrong_trait.required_trait_ids = ["martial_artist"]
	var high_level := create_ability("high_level", "High Level", 3, 1)
	var automatic := create_ability("automatic", "Automatic", 1, 1)
	automatic.auto_equip_on_grant = true

	check(not system.can_learn_ability(character, advanced), "A prerequisite Ability must be learned first.", failures)
	check(system.get_learn_ability_failure_reason(character, advanced).contains("Foundation"), "Prerequisite failure should identify the required Ability.", failures)
	check(not system.can_learn_ability(character, wrong_trait), "Required Traits should be enforced.", failures)
	check(not system.can_learn_ability(character, high_level), "Required Level should be enforced.", failures)
	check(not system.can_learn_ability(character, automatic), "Automatically granted Abilities cannot be purchased.", failures)

	var learned_foundation := system.learn_ability(character, foundation)
	check(learned_foundation.success and learned_foundation.points_spent == 1, "Learning should spend the configured Ability Point cost.", failures)
	check(character.ability_points == 2, "Learning Foundation should leave 2 Ability Points.", failures)
	check(character.selected_ability_ids.has(foundation.id), "Purchased Ability should be tracked separately from granted Abilities.", failures)
	check(character.available_abilities.has(foundation) and character.equipped_abilities.has(foundation.id), "A learned Ability should become available and equipped.", failures)

	var duplicate := system.learn_ability(character, foundation)
	check(not duplicate.success and character.ability_points == 2, "An Ability cannot be learned or charged twice.", failures)
	var learned_advanced := system.learn_ability(character, advanced)
	check(learned_advanced.success and character.ability_points == 0, "A learned prerequisite should unlock its dependent Ability.", failures)
	check(character.pending_level_up_choices.is_empty(), "Using all earned Ability Points should clear their pending choices.", failures)

	var insufficient := create_ability("insufficient", "Insufficient", 1, 1)
	check(not system.can_learn_ability(character, insufficient), "Learning should fail when no Ability Points remain.", failures)
	var learnable := system.get_learnable_abilities(character, [foundation, advanced, insufficient, wrong_trait, high_level, automatic])
	check(learnable.is_empty(), "The filtered catalog should only return Abilities currently learnable.", failures)

	var granted := create_ability("granted", "Granted", 1, 1)
	character.granted_ability_ids.append(granted.id)
	check(not system.can_learn_ability(character, granted), "A class- or ancestry-granted Ability cannot be purchased again.", failures)

	for failure in failures:
		push_error(failure)
	print("ABILITY_LEARNING_TEST: PASS" if failures.is_empty() else "ABILITY_LEARNING_TEST: FAIL (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)


func create_ability(id: String, display_name: String, required_level: int, point_cost: int) -> AbilityData:
	var ability := AbilityData.new()
	ability.id = id
	ability.display_name = display_name
	ability.required_level = required_level
	ability.ability_point_cost = point_cost
	return ability


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
