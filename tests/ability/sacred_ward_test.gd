extends SceneTree

const PlayerTemplate = preload("res://data/character/player.tres")
const DevoteeData = preload("res://data/class/devotee.tres")
const SacredWard = preload("res://data/ability/sacred_ward.tres")
const Catalog = preload("res://data/creation/default_creation_catalog.tres")

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _init() -> void:
	var character = PlayerTemplate.duplicate(true)
	character.character_class = DevoteeData
	character.level = 2
	character.class_attribute_choices.assign([AttributeTypes.Type.CONSTITUTION])
	character.available_abilities.append(SacredWard)
	character.selected_ability_ids.append("sacred_ward")
	character.equipped_abilities.append("sacred_ward")
	var devotee: CombatantState = character.create_combatant_state()
	devotee.wisdom = 14
	devotee.position = Vector2.ZERO
	var ally := CombatantState.new()
	ally.id = "ally"
	ally.display_name = "Ally"
	ally.team = devotee.team
	ally.base_max_hp = 20
	ally.hp = 20
	ally.position = Vector2(120, 0)
	var enemy := CombatantState.new()
	enemy.id = "enemy"
	enemy.team = devotee.team + 1
	enemy.base_max_hp = 20
	enemy.hp = 20
	enemy.position = Vector2(300, 0)
	var system := CombatSystem.new()
	system.start_combat([devotee, ally, enemy])
	system.combat_state.current_actor_id = devotee.id
	devotee.ap = 6

	var applied := system.use_active_ability(devotee.id, ally.id, "sacred_ward")
	check(applied.success and devotee.ap == 4 and devotee.faith == 10, "Sacred Ward costs 2 AP and no Faith")
	check(system.effect_system.get_fortitude_bonus(ally) == 2 and system.effect_system.get_reflex_bonus(ally) == 2 and system.effect_system.get_will_bonus(ally) == 2, "Sacred Ward scales all three defenses from Wisdom modifier")
	check(ally.effects.size() == 1 and ally.effects[0].remaining_turns == 1, "Sacred Ward creates one one-turn Effect")
	if not ally.effects.is_empty():
		ally.effects[0].remaining_turns = 0
	var refreshed := system.use_active_ability(devotee.id, ally.id, "sacred_ward")
	check(refreshed.success and ally.effects.size() == 1 and ally.effects[0].remaining_turns == 1, "Reusing Sacred Ward refreshes duration without stacking")
	check(system.effect_system.get_reflex_bonus(ally) == 2, "Refreshed Sacred Ward does not stack its bonus")

	devotee.ap = 4
	var self_cast := system.use_active_ability(devotee.id, devotee.id, "sacred_ward")
	check(self_cast.success and system.effect_system.get_will_bonus(devotee) == 2, "Sacred Ward can target its caster")

	ally.remove_status("sacred_ward")
	devotee.ap = 4
	system.map_rules.add_circular_obstacle(Vector2(60, 0), 15.0, "Wall")
	var blocked := system.use_active_ability(devotee.id, ally.id, "sacred_ward")
	check(not blocked.success and devotee.ap == 4 and not ally.has_status("sacred_ward"), "Blocked line of sight rejects Sacred Ward before spending AP")
	check(Catalog.abilities.any(func(ability): return ability != null and ability.id == "sacred_ward"), "Sacred Ward is available in Character Creation")

	for failure in failures:
		push_error(failure)
	print("SACRED_WARD_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
