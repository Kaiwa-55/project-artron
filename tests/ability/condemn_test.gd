extends SceneTree

const PlayerTemplate := preload("res://data/character/player.tres")
const EnemyTemplate := preload("res://data/character/enemy.tres")
const Devotee := preload("res://data/class/devotee.tres")
const Condemn := preload("res://data/ability/condemn.tres")
const Catalog := preload("res://data/creation/default_creation_catalog.tres")


func _init() -> void:
	var failures: Array[String] = []
	var character = PlayerTemplate.duplicate(true)
	character.character_class = Devotee
	character.level = 1
	character.class_attribute_choices.assign([AttributeTypes.Type.CONSTITUTION])
	var devotee: CombatantState = character.create_combatant_state()
	var enemy: CombatantState = EnemyTemplate.create_combatant_state()
	devotee.id = "devotee"; devotee.team = 0
	enemy.id = "enemy"; enemy.team = 1

	var system := CombatSystem.new()
	system.start_combat([devotee, enemy])
	system.combat_state.current_actor_id = devotee.id
	devotee.position = Vector2.ZERO
	enemy.position = Vector2(120, 0)
	devotee.ap = 5
	devotee.faith = 10
	devotee.temporary_faith = 0
	var hp_before: int = enemy.hp

	var result := system.use_active_ability(devotee.id, enemy.id, Condemn.id)
	check(result.success, "Condemn can target an enemy within 15 feet", failures)
	check(enemy.hp == hp_before - 2, "Faith 10 deals floor(Faith / 4) = 2 Light Damage", failures)
	var weakened = enemy.effects.filter(func(instance): return instance != null and instance.data != null and instance.data.id == "weakened").front()
	check(weakened != null and weakened.data.potency == 2 and weakened.data.reflex_bonus == -2 and weakened.data.fortitude_bonus == -2 and weakened.data.will_bonus == -2, "Faith 10 applies Weakened 2", failures)
	check(devotee.ap == 3 and devotee.get_total_faith() == 9, "Condemn costs 2 AP and 1 Faith after calculating its effects", failures)

	var ap_before_repeat: int = devotee.ap
	var faith_before_repeat: int = devotee.get_total_faith()
	var repeat := system.use_active_ability(devotee.id, enemy.id, Condemn.id)
	check(not repeat.success and devotee.ap == ap_before_repeat and devotee.get_total_faith() == faith_before_repeat, "Condemn cannot be used twice in one Turn and rejected use spends no resources", failures)

	devotee.ability_uses_this_turn.clear()
	enemy.position = Vector2(300, 0)
	var out_of_range := system.use_active_ability(devotee.id, enemy.id, Condemn.id)
	check(not out_of_range.success and devotee.ap == ap_before_repeat and devotee.get_total_faith() == faith_before_repeat, "Condemn rejects targets beyond 15 feet before spending resources", failures)

	check(Condemn.required_level == 1 and Condemn.ap_cost == 2 and Condemn.faith_cost == 1 and Condemn.uses_per_turn == 1, "Condemn has the specified level, costs, and per-turn limit", failures)
	check(["devotee", "divine"].all(func(id): return Condemn.traits.any(func(trait_data): return trait_data != null and trait_data.id == id)), "Condemn has Devotee and Divine traits", failures)
	check(Catalog.abilities.has(Condemn) and Devotee.get_progression_entry(1).granted_abilities.has(Condemn), "Condemn is registered in Character Creation and Level 1 progression", failures)

	for failure in failures:
		push_error(failure)
	print("CONDEMN_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
