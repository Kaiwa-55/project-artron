extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	root.size = Vector2i(640, 360)
	var tooltips = load("res://scenes/ui/bounded_tooltips.gd").new()
	root.add_child(tooltips)
	tooltips.set_process(false)
	tooltips.show_description("Attack with Unarmed Attack. On Hit, gain bonus Damage equal to Level and apply Weakened. ".repeat(20), Vector2(635, 355))
	await process_frame
	tooltips.show_description(tooltips.description.text, Vector2(635, 355))
	var passed := Rect2(Vector2.ZERO, root.size).encloses(tooltips.panel.get_global_rect())
	passed = passed and tooltips.description.get_theme_font_size("normal_font_size") == 11
	passed = passed and tooltips.description.get_content_height() > tooltips.description.size.y and tooltips.description.scroll_active
	tooltips.queue_free()
	print("BOUNDED_TOOLTIPS_TEST: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
