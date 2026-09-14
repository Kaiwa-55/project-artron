extends SceneTree

const RunMapScene := preload("res://scenes/run/RunMap.tscn")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var failures: Array[String] = []
	root.size = Vector2i(640, 360)
	var scene := RunMapScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(640, 360))
	var margin: Control = scene.get_node("Margin")
	var header: Control = scene.get_node("Margin/Layout/Header")
	var map_panel: Control = scene.get_node("Margin/Layout/MapPanel")
	var map_scroll: ScrollContainer = scene.get_node("Margin/Layout/MapPanel/MapScroll")
	var footer: Control = scene.get_node("Margin/Layout/Footer")
	check(viewport_rect.encloses(margin.get_global_rect()), "Run Map content fits 640x360", failures)
	check(not header.get_global_rect().intersects(map_panel.get_global_rect()), "Run Map header does not overlap the map", failures)
	check(not footer.get_global_rect().intersects(map_panel.get_global_rect()), "Run Map footer does not overlap the map", failures)
	check(header.get_children().all(func(child): return not child is Control or header.get_global_rect().encloses(child.get_global_rect())), "Run Map header controls fit their row", failures)
	check(map_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "Long Run routes can scroll horizontally", failures)
	check(scene.map_canvas.custom_minimum_size.x > map_scroll.size.x, "Nine-floor Run route extends inside the horizontal scroll area", failures)
	var canvas_rect := Rect2(Vector2.ZERO, scene.map_canvas.custom_minimum_size)
	for node_button in scene.node_buttons.values():
		check(canvas_rect.encloses(Rect2(node_button.position, node_button.size)), "Every Run node stays inside the Map canvas", failures)
		check(node_button.get_theme_font_size("font_size") == 7, "Run node labels use the compact 640x360 font", failures)
	var start_button: Button = scene.node_buttons.get("start")
	check(start_button != null and absf(start_button.get_rect().get_center().y - scene.map_canvas.custom_minimum_size.y * 0.5) < 1.0, "The starting node is vertically centered after layout", failures)
	for button in scene.party_inventory.get_children():
		check(footer.get_global_rect().encloses(button.get_global_rect()), "Party Inventory buttons fit the footer", failures)
	scene.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("RUN_MAP_LAYOUT_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
