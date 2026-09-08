extends SceneTree

const PrototypeScene := preload("res://scenes/prototype/PrototypeCombat.tscn")

var failures: Array[String] = []


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func rect_fits(control: Control, viewport_size: Vector2) -> bool:
	return control.position.x >= -0.1 \
		and control.position.y >= -0.1 \
		and control.position.x + control.size.x <= viewport_size.x + 0.1 \
		and control.position.y + control.size.y <= viewport_size.y + 0.1


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var scene = PrototypeScene.instantiate()
	root.add_child(scene)
	await process_frame
	for viewport_size in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		DisplayServer.window_set_size(viewport_size)
		await process_frame
		var ui: Control = scene.get_node("UILayer/Control")
		scene._apply_responsive_layout()
		await process_frame
		var logical_size := ui.size
		for path in ["Header", "ReferenceActionDock", "ReferencePlayerHUD", "ReferenceTurnHUD", "Enemy_panel", "CombatLogPanel", "ActionMenu", "CharacterPanel"]:
			var control: Control = ui.get_node(path)
			check(rect_fits(control, logical_size), "%s (%s, %s) must fit inside the %dx%d layout" % [path, control.position, control.size, int(logical_size.x), int(logical_size.y)])
		check(ui.get_node("ReferenceActionDock").position.y + ui.get_node("ReferenceActionDock").size.y <= logical_size.y, "Action Bar stays attached to the bottom safe area")
	scene.queue_free()
	for failure in failures:
		push_error(failure)
	print("RESPONSIVE_COMBAT_UI_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
