extends SceneTree

const Warrior = preload("res://data/class/warrior.tres")
const Catalog = preload("res://data/creation/default_creation_catalog.tres")
const Sword = preload("res://data/attack/sword.tres")
const Shortbow = preload("res://data/attack/shortbow.tres")

var failures: Array[String] = []


func _init() -> void:
	var data: CharacterData = load("res://data/character/player.tres").duplicate()
	data.character_class = Warrior
	data.level = 2
	var actor: CombatantState = data.create_combatant_state()
	var enemy: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	var system := CombatSystem.new()
	system.start_combat([actor, enemy])
	var progression := ProgressionSystem.new()
	actor.ability_points = 6
	var choices := [
		["opening_strike", "press_the_advantage"],
		["shield_brace", "unbroken_guard"],
		["evasive_step", "measured_riposte"],
	]
	for path in choices:
		var first: AbilityData = load("res://data/ability/%s.tres" % path[0])
		var second: AbilityData = load("res://data/ability/%s.tres" % path[1])
		check(Catalog.abilities.has(second) and not actor.granted_ability_ids.has(second.id), "%s is selectable, not automatic" % second.display_name)
		check(not progression.can_learn_ability(actor, second), "%s needs its previous path ability" % second.display_name)
		check(progression.learn_ability(actor, first).success and progression.learn_ability(actor, second).success, "%s can be learned with Ability Points" % second.display_name)
	actor.ap = actor.max_ap
	system.combat_state.current_actor_id = actor.id
	var press: AbilityData = Catalog.find_ability("press_the_advantage")
	enemy.hp = enemy.max_hp
	check(not system.ability_system.get_conditional_damage_bonuses(actor, enemy, Sword, 1).any(func(entry): return entry.source == press.display_name), "Press the Advantage needs a wounded target")
	check(system.use_active_ability(actor.id, actor.id, "assault_stance").success, "Assault Stance activates")
	enemy.hp = enemy.max_hp / 2
	check(system.ability_system.get_conditional_damage_bonuses(actor, enemy, Sword, 1).any(func(entry): return entry.source == press.display_name and entry.amount == 3), "Press the Advantage adds 3 melee damage at half HP")
	check(not system.ability_system.get_conditional_damage_bonuses(actor, enemy, Shortbow, 1).any(func(entry): return entry.source == press.display_name), "Press the Advantage excludes ranged attacks")
	check(actor.get_passive_damage_resistance("slash") == 0, "Unbroken Guard is inactive outside Bulwark Stance")
	actor.ap = actor.max_ap
	check(system.use_active_ability(actor.id, actor.id, "bulwark_stance").success, "Bulwark Stance activates")
	check(actor.get_passive_damage_resistance("slash") == 1 and actor.get_passive_damage_resistance("fire") == 0, "Unbroken Guard resists physical damage only")
	actor.ap = actor.max_ap
	check(system.use_active_ability(actor.id, actor.id, "duelist_stance").success, "Duelist Stance activates")
	check(actor.get_passive_damage_resistance("slash") == 0, "Unbroken Guard stops after switching Stance")
	var melee_bonus: int = system.ability_system.get_to_hit_bonus(actor, Sword)
	var ranged_bonus: int = system.ability_system.get_to_hit_bonus(actor, Shortbow)
	check(melee_bonus == ranged_bonus + 1, "Measured Riposte adds +1 to melee attacks only")
	for failure in failures:
		push_error(failure)
	print("WARRIOR_LEVEL_TWO_CHOICES_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
