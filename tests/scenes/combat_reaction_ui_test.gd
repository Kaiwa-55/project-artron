extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var arena: Node = load("res://scenes/combat/CombatArena.tscn").instantiate()
	var ui: Control = arena.get_node("UILayer/Control")
	var reactions: Array = []
	for index in range(7):
		var reaction := ReactionData.new()
		reaction.id = "reaction_%d" % index
		reaction.display_name = "Reaction %d" % (index + 1)
		reaction.description = "Reaction description %d" % (index + 1)
		reaction.ap_cost = 1
		reaction.faith_cost = index % 2
		reactions.append(reaction)

	ui.show_reaction_prompt({"reactions": reactions})
	var authored_panel: Control = ui.get_node("CombatUI/Reaction")
	var description_panel: Control = ui.get_node("CombatUI/ReactionDescription")
	var scroll: ScrollContainer = ui.get_node("CombatUI/Reaction/Reaction/VBoxContainer/ReactionScroll")
	var list: VBoxContainer = scroll.get_node("ReactionList")
	var visible_cards := list.get_children().filter(func(child): return child.visible)
	check(authored_panel.visible and not ui.get_node("ReactionPrompt").visible, "Reaction choices use the authored Combat UI panel", failures)
	check(authored_panel.offset_right <= description_panel.offset_left, "Reaction list and description panels do not overlap", failures)
	check(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Reaction list is vertical-only scrolling", failures)
	check(visible_cards.size() == reactions.size(), "Every available Reaction gets its own list card", failures)
	check(not list.get_node("ReactionTemplate").visible, "The authored template card is never shown as a real Reaction", failures)

	list.get_node("Reaction_5/Button").pressed.emit()
	check(ui.get_node("CombatUI/ReactionDescription/Frame/Description").text.contains("Reaction description 6"), "Selecting a Reaction updates its description", failures)
	var choices: Array[int] = []
	ui.reaction_choice_selected.connect(func(index: int): choices.append(index))
	ui.get_node("CombatUI/Reaction/Reaction/VBoxContainer/HBoxContainer/Use_Button/Button").pressed.emit()
	check(choices == [5], "Use resolves the selected Reaction index", failures)
	ui.get_node("CombatUI/Reaction/Reaction/VBoxContainer/HBoxContainer/Cancel_Button/Button").pressed.emit()
	check(choices == [5, -1], "Cancel declines the Reaction without selecting an action", failures)

	arena.free()
	for failure in failures:
		push_error(failure)
	print("COMBAT_REACTION_UI_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
