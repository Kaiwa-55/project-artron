extends SceneTree

const CreationScene := preload("res://scenes/character_creation/CharacterCreation.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_tests")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func run_tests() -> void:
	var creation = CreationScene.instantiate()
	creation.auto_start_combat = false
	root.add_child(creation)
	await process_frame
	check(creation.step_buttons.size() == creation.catalog.steps.size(), "The creation journey exposes every catalog step.")
	check(creation.left != null and creation.center != null and creation.summary_column != null, "The new creation layout has choice, detail, and character-summary columns.")
	check(creation.left.get_parent() is ScrollContainer and creation.center.get_parent() is ScrollContainer, "Long choice and detail content uses native scrolling.")
	check(creation.step_index == 0 and creation.center.find_child("TokenZoom", true, false) != null, "Identity opens with character and token controls.")
	creation.size = Vector2(640, 360)
	await process_frame
	check(not creation._summary_panel.visible and creation._list_panel.custom_minimum_size.x == 158, "The compact game viewport keeps the choice and detail columns on screen.")
	creation.size = Vector2(1280, 720)
	await process_frame
	check(creation._summary_panel.visible, "The wide layout restores the character summary column.")
	creation.show_step(2)
	await process_frame
	var class_cards: Array = creation.left.get_children().filter(func(node): return node is Button)
	check(class_cards.size() == creation.catalog.classes.size(), "Every catalog class has a selectable card in the new layout.")
	check(creation.center.find_children("*", "TextureRect", true, false).is_empty(), "Class details keep the central reading area free of artwork.")
	creation.show_step(6)
	await process_frame
	check(creation.left.get_children().any(func(node): return node is Button), "Equipment remains available from the new creation layout.")
	creation.show_step(7)
	await process_frame
	check(creation.center.get_child_count() > 0, "Review renders in the new layout.")
	creation.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("CHARACTER_CREATION_LAYOUT_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
