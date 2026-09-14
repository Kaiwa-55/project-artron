extends SceneTree

const RewardScene := preload("res://scenes/run/RewardSelection.tscn")

var failures: Array[String] = []


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	DisplayServer.window_set_size(Vector2i(640, 360))
	root.size = Vector2i(640, 360)
	var screen = RewardScene.instantiate()
	root.add_child(screen)
	await process_frame
	var rewards: Array[RewardOptionData] = []
	for index in range(4):
		var reward := RewardOptionData.new()
		reward.display_name = "Reward %d" % (index + 1)
		reward.description = "A useful reward for every member of the party."
		reward.amount = 10 + index
		rewards.append(reward)
	screen.build_cards(rewards)
	screen._apply_responsive_layout()
	await process_frame
	var cards: GridContainer = screen.get_node("Margin/Layout/Cards")
	check(cards.columns == 2, "Reward cards should use a 2x2 grid at 640x360")
	check(cards.get_child_count() == 4, "Reward Selection should show all four choices")
	for card in cards.get_children():
		check(screen.get_global_rect().encloses(card.get_global_rect()), "Every reward card must fit inside the 640x360 screen")
		check(cards.get_global_rect().encloses(card.get_global_rect()), "Every reward card must stay inside the reward grid")
		check(card.get_theme_font_size("font_size") >= 10, "Compact reward text must remain readable")
	screen.queue_free()
	for failure in failures:
		push_error(failure)
	print("REWARD_SELECTION_LAYOUT_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
