extends SceneTree

const RunMapScene := preload("res://scenes/run/RunMap.tscn")
const PlayerData := preload("res://data/character/player.tres")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var first: CharacterData = PlayerData.duplicate(true)
	var second: CharacterData = PlayerData.duplicate(true)
	first.creation_gold = 175
	second.creation_gold = 120
	root.get_tree().set_meta("active_party_characters", [first, second])
	var run_map = RunMapScene.instantiate()
	root.add_child(run_map)
	await process_frame
	var success: bool = run_map.run_state.gold == 295 and run_map.gold_label.text == "GOLD  295"
	run_map.run_state.gold = 180
	run_map.refresh_map_state()
	success = success and run_map.gold_label.text == "GOLD  180"
	run_map.queue_free()
	root.get_tree().remove_meta("active_party_characters")
	print("CREATION_GOLD_TRANSFER_TEST: " + ("PASS" if success else "FAIL"))
	quit(0 if success else 1)
