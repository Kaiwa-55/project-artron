extends SceneTree

const PrototypeScene := preload("res://scenes/prototype/PrototypeCombat.tscn")

var failures: Array[String] = []


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	DisplayServer.window_set_size(Vector2i(640, 360))
	root.size = Vector2i(640, 360)
	var scene = PrototypeScene.instantiate()
	root.add_child(scene)
	await process_frame
	scene._apply_responsive_layout()
	await process_frame
	var ui: Control = scene.get_node("UILayer/Control")
	var target: Control = ui.get_node("Enemy_panel")
	check(target.size.x <= 180.1 and target.size.y <= 92.1, "Selected Target must use its compact 640x360 size")
	check(ui.get_global_rect().encloses(target.get_global_rect()), "Selected Target must remain inside the combat viewport")
	check((target.get_node("VBoxContainer/PanelTitle") as Label).label_settings.font_size <= 10, "Selected Target title must use compact typography")
	check((target.get_node("VBoxContainer/Name") as Label).label_settings.font_size <= 9, "Selected Target details must use compact typography")
	scene.queue_free()
	for failure in failures:
		push_error(failure)
	print("SELECTED_TARGET_LAYOUT_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
