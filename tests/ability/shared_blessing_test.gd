extends SceneTree

const PlayerTemplate = preload("res://data/character/player.tres")
const DevoteeData = preload("res://data/class/devotee.tres")
const SharedBlessing = preload("res://data/ability/shared_blessing.tres")
const Catalog = preload("res://data/creation/default_creation_catalog.tres")

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func make_combatant(id: String, team: int, position: Vector2, hp: int = 10) -> CombatantState:
	var result := CombatantState.new()
	result.id = id
	result.display_name = id.capitalize()
	result.team = team
	result.base_max_hp = 20
	result.hp = hp
	result.position = position
	return result


func _init() -> void:
	var character = PlayerTemplate.duplicate(true)
	character.character_class = DevoteeData
	character.level = 3
	character.class_attribute_choices.assign([AttributeTypes.Type.CONSTITUTION])
	character.available_abilities.append(SharedBlessing)
	character.selected_ability_ids.append("shared_blessing")
	character.equipped_abilities.append("shared_blessing")
	var devotee: CombatantState = character.create_combatant_state()
	devotee.position = Vector2.ZERO
	devotee.hp = devotee.max_hp - 5
	var ally := make_combatant("ally", devotee.team, Vector2(100, 0))
	var dying_ally := make_combatant("dying_ally", devotee.team, Vector2(80, 20), 0)
	dying_ally.life_state = CombatEnums.LifeState.DYING
	var enemy := make_combatant("enemy", devotee.team + 1, Vector2(110, 0))
	var system := CombatSystem.new()
	system.start_combat([devotee, ally, dying_ally, enemy])
	devotee.hp = devotee.max_hp - 5
	ally.hp = 10
	dying_ally.hp = 0
	dying_ally.life_state = CombatEnums.LifeState.DYING
	system.combat_state.current_actor_id = devotee.id
	devotee.ap = 4
	var enemy_hp := enemy.hp
	var result := system.execute_ground_ability(devotee.id, "shared_blessing", Vector2(60, 0))
	check(result.success, "Shared Blessing resolves through Area Action Context")
	check(devotee.hp == devotee.max_hp and ally.hp == 15, "Shared Blessing heals caster and each Ally by floor(pre-cost Faith / 2); caster=%d/%d ally=%d" % [devotee.hp, devotee.max_hp, ally.hp])
	check(enemy.hp == enemy_hp and dying_ally.hp == 0, "Shared Blessing ignores Enemies and cannot revive Dying Allies")
	check(devotee.ap == 2 and devotee.faith == 8, "Shared Blessing costs 2 AP and 2 Faith once")
	var heal_events := result.events.filter(func(event): return event.type == EventTypes.Type.EFFECT_HEAL_APPLIED)
	check(heal_events.size() == 2, "Each eligible target receives healing exactly once")

	devotee.ap = 4
	devotee.faith = 1
	var rejected := system.execute_ground_ability(devotee.id, "shared_blessing", Vector2(60, 0))
	check(not rejected.success and devotee.ap == 4 and devotee.faith == 1, "Insufficient Faith rejects Shared Blessing before spending AP")
	check(Catalog.abilities.any(func(ability): return ability != null and ability.id == "shared_blessing"), "Shared Blessing is available in Character Creation")

	for failure in failures:
		push_error(failure)
	print("SHARED_BLESSING_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
