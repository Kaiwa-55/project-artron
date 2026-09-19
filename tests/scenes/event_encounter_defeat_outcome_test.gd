extends SceneTree

const PrototypeCombatScript := preload("res://scenes/prototype/prototype_combat.gd")
const EncounterDataScript := preload("res://data/encounter/encounter_data.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func run_test() -> void:
	var encounter := EncounterDataScript.new()
	check(encounter.event_defeat_outcome == EncounterDataScript.EventDefeatOutcome.END_RUN, "Event Encounters default to ending the Run on defeat.")
	encounter.event_defeat_outcome = EncounterDataScript.EventDefeatOutcome.REVIVE_AT_ONE_HP
	check(encounter.event_defeat_outcome == EncounterDataScript.EventDefeatOutcome.REVIVE_AT_ONE_HP, "EncounterData can author the revive-at-1-HP outcome.")
	var prototype := PrototypeCombatScript.new()
	prototype.combat_system = CombatSystem.new()
	var player := CombatantState.new()
	player.id = "player"
	player.team = 1
	player.base_max_hp = 10
	StatSystem.new().initialize_combatant(player)
	player.hp = 0
	player.life_state = CombatEnums.LifeState.DYING
	prototype.combat_system.start_combat([player])
	player.hp = 0
	player.life_state = CombatEnums.LifeState.DYING
	prototype.revive_party_after_event_defeat()
	check(player.hp == 1 and player.life_state == CombatEnums.LifeState.ALIVE, "Revive-at-1-HP policy restores fallen party members exactly once.")
	prototype.free()
	for failure in failures:
		push_error(failure)
	print("EVENT_ENCOUNTER_DEFEAT_OUTCOME_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
