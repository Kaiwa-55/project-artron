extends SceneTree

const PrototypeCombatScript := preload("res://scenes/prototype/prototype_combat.gd")
const Poisoned := preload("res://data/status/poisoned.tres")
const ArcaneBolt := preload("res://data/skill/arcane_bolt.tres")

var failures: Array[String] = []


func _init() -> void:
	var prototype := PrototypeCombatScript.new()
	var persistent := make_combatant("player")
	persistent.hp = 7
	persistent.mana = 3
	var active := make_combatant("player")
	prototype.restore_run_resources(active, persistent)
	check(active.hp == 7 and active.mana == 3, "Combat should start with the HP and Mana stored in RunState.")
	persistent.hp = 0
	prototype.restore_run_resources(active, persistent)
	check(active.hp == 0, "A fallen party member must not be silently restored before the Event death decision.")

	active.hp = 0
	active.mana = 2
	persistent.add_effect(Poisoned)
	persistent.life_state = CombatEnums.LifeState.DYING
	prototype.sync_combatant_to_run_state(active, persistent)
	check(persistent.hp == 0, "A character ending Combat at 0 HP should remain fallen until the Event death decision.")
	check(persistent.mana == 2, "Remaining Mana should persist after Combat.")
	check(persistent.effects.is_empty() and persistent.life_state == active.life_state, "Statuses are removed without changing the character's life state.")

	active.hp = 11
	active.mana = 1
	prototype.sync_combatant_to_run_state(active, persistent)
	check(persistent.hp == 11 and persistent.mana == 1, "Non-zero HP and Mana should persist without being refilled.")

	active.max_hp_bonus = 5
	StatSystem.new().refresh_combatant(active)
	active.hp = 23
	prototype.sync_combatant_to_run_state(active, persistent)
	check(persistent.max_hp == 25 and persistent.hp == 23, "HP granted by a Run-wide Max HP bonus should not be clamped to the character's original maximum.")

	active.strength = 16
	active.constitution = 14
	active.available_skills = [ArcaneBolt]
	prototype.sync_combatant_to_run_state(active, persistent)
	check(persistent.strength == 16 and persistent.constitution == 14 and persistent.available_skills == [ArcaneBolt], "GM attribute and Skill changes should persist from Combat to RunState.")

	prototype.free()
	for failure in failures:
		push_error(failure)
	print("COMBAT_RESOURCE_PERSISTENCE_TEST: PASS" if failures.is_empty() else "COMBAT_RESOURCE_PERSISTENCE_TEST: FAIL (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)


func make_combatant(combatant_id: String) -> CombatantState:
	var combatant := CombatantState.new()
	combatant.id = combatant_id
	combatant.base_max_hp = 20
	combatant.base_max_mana = 10
	StatSystem.new().initialize_combatant(combatant)
	return combatant


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
