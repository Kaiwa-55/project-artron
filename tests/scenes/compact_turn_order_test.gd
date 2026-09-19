extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var arena = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	DisplayServer.window_set_size(Vector2i(640, 360))
	root.size = Vector2i(640, 360)
	await process_frame
	arena._apply_responsive_layout()
	await process_frame
	var header: Panel = arena.get_node("UILayer/Control/Header")
	var header_style := header.get_theme_stylebox("panel") as StyleBoxFlat
	var success := header.size.y <= 30.1 and header_style != null and header_style.bg_color == preload("res://scenes/ui/artron_ui_theme.gd").CARD_BACKGROUND
	for child in arena.initiative_row.get_children():
		if child is Button:
			success = success and child.custom_minimum_size == Vector2(24, 24)
	arena.queue_free()
	await process_frame
	print("COMPACT_TURN_ORDER_TEST: " + ("PASS" if success else "FAIL"))
	quit(0 if success else 1)
