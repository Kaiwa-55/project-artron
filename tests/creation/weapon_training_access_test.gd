extends SceneTree

const Assassin = preload("res://data/class/assassin.tres")
const MartialArtist = preload("res://data/class/martial_artist.tres")
const Human = preload("res://data/ancestry/human.tres")
const BlueBlood = preload("res://data/ancestry/human_blue_blood.tres")
const SimpleTraining = preload("res://data/ability/simple_weapon_training.tres")
const AdvancedTraining = preload("res://data/ability/advanced_weapon_training.tres")
const Sword = preload("res://data/attack/sword.tres")
const Greatsword = preload("res://data/attack/greatsword.tres")

var failures: Array[String] = []


func _init() -> void:
	var assassin := make_actor(BlueBlood, Assassin, 0)
	check(SimpleTraining.required_level == 0 and AdvancedTraining.required_level == 0, "Weapon training starts at Level 0")
	check(not assassin.active_traits.any(func(trait_data): return trait_data != null and trait_data.id == "weapon_training_access"), "Assassin needs no training-access trait")
	for ability in [SimpleTraining, AdvancedTraining]:
		check(assassin.granted_ability_ids.has(ability.id) and assassin.equipped_abilities.has(ability.id), "Assassin starts with %s" % ability.id)
	check(AbilitySystem.new().get_to_hit_bonus(assassin, Sword) == 2 and AbilitySystem.new().get_to_hit_bonus(assassin, Greatsword) == 2, "Assassin gets both attack bonuses at Level 0")
	var human_assassin := make_actor(Human, Assassin, 1)
	check(AbilitySystem.new().get_to_hit_bonus(human_assassin, Sword) == 2 and AbilitySystem.new().get_to_hit_bonus(human_assassin, Greatsword) == 2, "Human Assassin never receives duplicate training bonuses")
	var human := make_actor(Human, MartialArtist, 1)
	human.ability_points = 2
	var progression := ProgressionSystem.new()
	check(not human.active_traits.any(func(trait_data): return trait_data != null and trait_data.id == "weapon_training_access"), "Ordinary Human needs no training-access trait")
	check(progression.can_learn_ability(human, SimpleTraining), "Ordinary Human can choose Simple Weapon Training")
	check(not progression.can_learn_ability(human, AdvancedTraining), "Ordinary Human cannot choose Advanced Weapon Training")
	check(progression.learn_ability(human, SimpleTraining).success, "Ordinary Human learns Simple Weapon Training")
	check(AbilitySystem.new().get_to_hit_bonus(human, Sword) == 2 and AbilitySystem.new().get_to_hit_bonus(human, Greatsword) == 0, "Ordinary Human gains only Simple weapon bonus")
	var blue_blood := make_actor(BlueBlood, MartialArtist, 1)
	blue_blood.ability_points = 2
	check(not progression.can_learn_ability(blue_blood, SimpleTraining) and not progression.can_learn_ability(blue_blood, AdvancedTraining), "Blue Blood cannot choose ordinary Human weapon training")
	for failure in failures:
		push_error(failure)
	print("WEAPON_TRAINING_ACCESS_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func make_actor(ancestry: Resource, character_class: Resource, level: int) -> CombatantState:
	var character := CharacterData.new()
	character.ancestry = ancestry
	character.character_class = character_class
	character.level = level
	var actor: CombatantState = character.create_combatant_state()
	AncestrySystem.new().apply_ancestry(actor)
	CharacterClassSystem.new().apply_class(actor)
	return actor


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
