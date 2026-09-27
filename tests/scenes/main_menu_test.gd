extends SceneTree

const MainMenu := preload("res://scenes/menu/main_menu.tscn")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var failures: Array[String] = []
	var saves: Node = root.get_node("SaveGame")
	saves.save_directory = "user://empty_menu_test_%d" % Time.get_ticks_usec()
	var menu := MainMenu.instantiate()
	root.add_child(menu)
	check(menu.button_list.get_child_count() == 3, "Main menu shows New Game, Load Game, and Quit", failures)
	menu.show_load_slots()
	await process_frame
	check(menu.button_list.get_child_count() == 4 and menu.button_list.get_child(0).disabled, "Load lists slots and disables empty slots", failures)
	menu.show_new_slots()
	await process_frame
	check(not menu.button_list.get_child(0).disabled, "New Game allows an empty slot", failures)
	menu.start_new(1)
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/run/CreateParty.tscn", "New Game opens party creation", failures)
	saves.save_directory = saves.SAVE_DIR
	for failure in failures:
		push_error(failure)
	print("MAIN_MENU_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
