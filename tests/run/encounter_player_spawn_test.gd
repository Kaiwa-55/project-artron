extends SceneTree

const EncounterDataScript := preload("res://data/encounter/encounter_data.gd")

var failures: Array[String] = []


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _init() -> void:
	var encounter := EncounterDataScript.new()
	encounter.player_spawn_positions_feet.assign([Vector2(10, 20), Vector2(30, 40)])
	check(encounter.get_player_spawn_position_feet(0, {"position_feet": Vector2(99, 99)}) == Vector2(10, 20), "Encounter spawn position overrides a party entry position")
	check(encounter.get_player_spawn_position_feet(1) == Vector2(30, 40), "Each party member uses the spawn position with the same index")
	check(encounter.get_player_spawn_position_feet(2, {"position_feet": Vector2(50, 60)}) == Vector2(50, 60), "Legacy party entry position remains supported")
	check(encounter.get_player_spawn_position_feet(3) == Vector2(-88, -29.3333), "Older encounters without enough positions use the safe formation fallback")
	for failure in failures:
		push_error(failure)
	print("ENCOUNTER_PLAYER_SPAWN_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
