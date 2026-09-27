extends SceneTree

const PreCombatStatusScript := preload("res://data/encounter/pre_combat_status.gd")
const PreCombatStatusSystemScript := preload("res://encounter/pre_combat_status_system.gd")
const Poisoned := preload("res://data/status/poisoned.tres")
const Slowed := preload("res://data/status/slowed.tres")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var encounter := EncounterData.new()
	encounter.player_team = 1
	var party_status := PreCombatStatusScript.new()
	party_status.effect = Poisoned
	party_status.target_mode = PreCombatStatusScript.TargetMode.PLAYER_PARTY
	var target_status := PreCombatStatusScript.new()
	party_status.applications = 1
	var slowed_one: EffectData = Slowed.duplicate(true)
	slowed_one.stacks_on_apply = 1
	target_status.effect = slowed_one
	target_status.target_mode = PreCombatStatusScript.TargetMode.CHARACTER_ID
	target_status.character_id = "enemy_leader"
	# EffectData can also be added directly and defaults to the player party.
	encounter.pre_combat_statuses.assign([party_status, target_status, slowed_one])

	var player := create_member("player", 1)
	var ally := create_member("ally", 1)
	var enemy := create_member("enemy_leader", 2)
	var other_enemy := create_member("enemy_guard", 2)
	var combatants: Array[CombatantState] = [player, ally, enemy, other_enemy]
	var combat_system := CombatSystem.new()
	var applied := PreCombatStatusSystemScript.new().apply(encounter, combatants, combat_system.effect_system)

	check(applied == 5, "Should apply configured assignments and the direct EffectData shorthand.")
	check(has_effect(player, Poisoned.id) and has_effect(ally, Poisoned.id), "Player Party should target every member of the configured player team.")
	check(has_effect(player, Slowed.id) and has_effect(ally, Slowed.id), "A direct EffectData should apply once to every player-party member.")
	check(has_effect(enemy, Slowed.id), "Character ID should target only the matching combatant.")
	check(not has_effect(other_enemy, Slowed.id) and not has_effect(enemy, Poisoned.id), "Statuses should not leak to unmatched combatants.")
	combat_system.start_combat(combatants)
	check(has_effect(player, Poisoned.id) and has_effect(enemy, Slowed.id), "Pre-combat statuses should remain active when the first turn starts.")

	if failures.is_empty():
		print("PRE_COMBAT_STATUS_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("PRE_COMBAT_STATUS_TEST: FAIL (%d)" % failures.size())
		quit(1)


func create_member(member_id: String, member_team: int) -> CombatantState:
	var member := CombatantState.new()
	member.id = member_id
	member.display_name = member_id
	member.team = member_team
	member.base_max_hp = 10
	member.max_hp = 10
	member.hp = 10
	return member


func has_effect(member: CombatantState, effect_id: String) -> bool:
	return member.effects.any(func(instance): return instance != null and instance.data != null and instance.data.id == effect_id)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
