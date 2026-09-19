extends SceneTree

const TestScene = preload("res://scenes/test/VisionConcealmentTest.tscn")


func _init() -> void:
	var scene := TestScene.instantiate()
	root.add_child(scene)
	await process_frame
	var passed: bool = scene.get_node("Controls/VisionInput") != null \
		and scene.get_node("Controls/LightInput").item_count == 4 \
		and scene.get_node("Controls/TargetZoneInput").item_count == 3 \
		and scene.get_node("ResultPanel/Margin/Column/ResultLabel").text == "NOT VISIBLE"
	print("VISION_CONCEALMENT_SCENE_TEST: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
