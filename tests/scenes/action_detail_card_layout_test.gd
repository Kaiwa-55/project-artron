extends SceneTree

const CardScene := preload("res://scenes/combat/ui/ActionDetailCard.tscn")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var card := CardScene.instantiate()
	var popup := PopupPanel.new()
	root.add_child(popup)
	var long_description := "A long description that must remain readable inside the scrolling area. ".repeat(20)
	card.setup(load("res://data/attack/frost_shard.tres"), null, null, long_description)
	# Tooltip containers measure their child before the first layout pass.
	var initial_minimum: Vector2 = card.get_combined_minimum_size()
	popup.add_child(card)
	popup.popup(Rect2i(10, 10, 200, 240))
	await process_frame
	await process_frame
	var compact: bool = card.custom_minimum_size.x <= 200.0
	compact = compact and card.get_node("Column/Title").get_theme_font_size("font_size") == 12
	compact = compact and card.get_node("Column/Stats").get_theme_font_size("font_size") == 8
	var description_viewport := card.get_node("Column/DescriptionViewport") as Control
	var description := card.get_node("Column/DescriptionViewport/Description") as RichTextLabel
	compact = compact and description_viewport.custom_minimum_size.y == 56.0
	compact = compact and description_viewport.size_flags_vertical == Control.SIZE_SHRINK_BEGIN
	compact = compact and not description.fit_content and description.scroll_active
	compact = compact and description.text == long_description
	compact = compact and card.size.y < 260.0
	compact = compact and initial_minimum == Vector2(200, 240)
	compact = compact and popup.size.y < 260
	var scrollbar := description.get_v_scroll_bar()
	compact = compact and scrollbar.max_value > scrollbar.page
	scrollbar.value = 24.0
	compact = compact and scrollbar.value > 0.0
	popup.queue_free()
	print("ACTION_DETAIL_CARD_LAYOUT_TEST: " + ("PASS" if compact else "FAIL"))
	quit(0 if compact else 1)
