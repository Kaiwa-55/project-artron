extends SceneTree

const Warrior = preload("res://data/class/warrior.tres")
const Catalog = preload("res://data/creation/default_creation_catalog.tres")

var failures: Array[String] = []


func _init() -> void:
	var data: CharacterData = load("res://data/character/player.tres").duplicate()
	data.character_class = Warrior
	data.level = 1
	var actor: CombatantState = data.create_combatant_state()
	CharacterClassSystem.new().apply_class(actor)
	actor.ability_points = 9
	var progression := ProgressionSystem.new()
	var paths := [
		["opening_strike", "relentless_pursuit", "sweeping_assault"],
		["shield_brace", "interpose", "hold_the_line"],
		["evasive_step", "riposte_rhythm", "duels_end"],
	]
	for path in paths:
		var first: AbilityData = load("res://data/ability/%s.tres" % path[0])
		var second: AbilityData = load("res://data/ability/%s.tres" % path[1])
		var third: AbilityData = load("res://data/ability/%s.tres" % path[2])
		check(Catalog.abilities.has(first) and Catalog.abilities.has(second) and Catalog.abilities.has(third), "All three levels of %s appear in Character Creation" % path[0])
		check(progression.can_learn_ability(actor, first), "%s is learnable at Level 1" % first.display_name)
		check(not progression.can_learn_ability(actor, second), "%s requires Level 2 and its prerequisite" % second.display_name)
		check(progression.learn_ability(actor, first).success, "%s can be learned" % first.display_name)
	actor.level = 2
	for path in paths:
		var second: AbilityData = load("res://data/ability/%s.tres" % path[1])
		check(progression.learn_ability(actor, second).success, "%s unlocks after its Level 1 Ability" % second.display_name)
	actor.level = 3
	for path in paths:
		var third: AbilityData = load("res://data/ability/%s.tres" % path[2])
		check(progression.learn_ability(actor, third).success and actor.equipped_abilities.has(third.id), "%s unlocks and equips at Level 3" % third.display_name)
	check(actor.ability_points == 0, "Nine Abilities cost nine Ability Points")
	for failure in failures:
		push_error(failure)
	print("WARRIOR_ABILITY_PATHS_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
