extends SceneTree

const PlayerData := preload("res://data/character/player.tres")


func _init() -> void:
	var failures: Array[String] = []
	var party := PartySetupState.new()
	for index in range(3):
		var character: CharacterData = PlayerData.duplicate(true)
		character.display_name = "Hero %d" % (index + 1)
		party.set_member(index, character)
	check(party.get_valid_members().size() == 3, "Party accepts three characters", failures)
	var fourth: CharacterData = PlayerData.duplicate(true)
	party.set_member(3, fourth)
	check(party.get_valid_members().size() == 3, "Party rejects a fourth character", failures)
	party.remove_member(1)
	check(party.get_valid_members().size() == 2 and party.get_valid_members()[1].display_name == "Hero 3", "Removing a character preserves the remaining party", failures)
	if failures.is_empty():
		print("PARTY_SETUP_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
