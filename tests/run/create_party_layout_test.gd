extends SceneTree

const CreatePartyScene := preload("res://scenes/run/CreateParty.tscn")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var failures: Array[String] = []
	root.size = Vector2i(640, 360)
	var scene := CreatePartyScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(640, 360))
	var margin: Control = scene.get_node("Margin")
	var header: Control = scene.get_node("Margin/Layout/Header")
	var slots: Control = scene.get_node("Margin/Layout/Main/Slots")
	var footer: Control = scene.get_node("Margin/Layout/Footer")
	check(viewport_rect.encloses(margin.get_global_rect()), "Create Party content fits 640x360", failures)
	check(not header.get_global_rect().intersects(slots.get_global_rect()), "Party cards do not overlap the header", failures)
	check(not slots.get_global_rect().intersects(footer.get_global_rect()), "Party cards do not overlap the footer", failures)
	for card in scene.cards:
		check(slots.get_global_rect().encloses(card.get_global_rect()), "Every Party card fits inside the formation row", failures)
	scene.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("CREATE_PARTY_LAYOUT_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
