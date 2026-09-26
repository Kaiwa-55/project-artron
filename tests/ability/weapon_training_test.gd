extends SceneTree

const SimpleTraining = preload("res://data/ability/simple_weapon_training.tres")
const AdvancedTraining = preload("res://data/ability/advanced_weapon_training.tres")
const Sword = preload("res://data/attack/sword.tres")
const Shortbow = preload("res://data/attack/shortbow.tres")
const Greatsword = preload("res://data/attack/greatsword.tres")
const Crossbow = preload("res://data/attack/crossbow.tres")
const Unarmed = preload("res://data/attack/unarmed_attack.tres")

var failures: Array[String] = []


func _init() -> void:
	var catalog = load("res://data/creation/default_creation_catalog.tres")
	check(catalog.abilities.has(SimpleTraining) and catalog.abilities.has(AdvancedTraining), "Both training abilities are selectable")
	var player: CombatantState = load("res://data/character/player.tres").create_combatant_state()
	AncestrySystem.new().apply_ancestry(player)
	player.available_abilities.append(SimpleTraining)
	var abilities := AbilitySystem.new()
	check(abilities.get_to_hit_bonus(player, Sword) == 0, "Unlearned training grants no bonus")
	check(abilities.equip_ability(player, SimpleTraining.id).success, "Simple training can be learned")
	check(abilities.get_to_hit_bonus(player, Sword) == 2 and abilities.get_to_hit_bonus(player, Shortbow) == 2, "Simple melee and ranged weapons gain +2")
	check(abilities.get_to_hit_bonus(player, Greatsword) == 0 and abilities.get_to_hit_bonus(player, Crossbow) == 0, "Simple training excludes advanced weapons")
	check(abilities.get_to_hit_bonus(player, Unarmed) == 0, "Simple training excludes unarmed attacks")
	check(not ProgressionSystem.new().can_learn_ability(player, AdvancedTraining), "Advanced training cannot be purchased")
	check(not abilities.equip_ability(player, AdvancedTraining.id).success, "Advanced training is unavailable before a class grant")
	player.set_meta("class_data", load("res://data/class/assassin.tres"))
	CharacterClassSystem.new().apply_class(player)
	check(player.granted_ability_ids.has(AdvancedTraining.id) and player.equipped_abilities.has(AdvancedTraining.id), "Assassin class grants advanced training")
	check(abilities.get_to_hit_bonus(player, Greatsword) == 2 and abilities.get_to_hit_bonus(player, Crossbow) == 2, "Advanced melee and ranged weapons gain +2")
	check(abilities.get_to_hit_bonus(player, Sword) == 2 and abilities.get_to_hit_bonus(player, Shortbow) == 2, "Advanced training does not add to simple attacks")
	for failure in failures:
		push_error(failure)
	print("WEAPON_TRAINING_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
