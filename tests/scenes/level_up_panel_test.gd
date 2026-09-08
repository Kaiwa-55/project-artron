extends SceneTree

const PanelScene := preload("res://scenes/run/LevelUpPanel.tscn")
const PlayerData := preload("res://data/character/player.tres")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var failures: Array[String] = []
	DisplayServer.window_set_size(Vector2i(2560, 1080))
	var panel: LevelUpPanel = PanelScene.instantiate()
	root.add_child(panel)
	await process_frame
	panel._apply_responsive_size()
	await process_frame
	var character: CombatantState = PlayerData.create_combatant_state()
	AncestrySystem.new().apply_ancestry(character)
	CharacterClassSystem.new().apply_class(character)
	character.set_meta("creation_rules_applied", true)
	ProgressionSystem.new().initialize_character(character)
	panel.open_for(character)
	await process_frame
	check(panel.visible, "Level Up panel opens outside Combat", failures)
	check(panel.has_node("Layout/ContentScroll"), "Level Up choices use a scrollable content area", failures)
	check(panel.confirm_button.is_visible_in_tree(), "Confirm remains visible at 2560x1080", failures)
	check(
		panel.get_global_rect().encloses(panel.confirm_button.get_global_rect()),
		"Confirm remains inside the Level Up panel at 2560x1080",
		failures
	)
	check(
		panel.get_node("Layout/Footer").get_parent() == panel.get_node("Layout"),
		"Footer stays pinned outside the scrolling content",
		failures
	)
	check(panel.party_roster.get_child_count() == 1, "Level Up panel builds a selectable Character portrait", failures)
	check(panel.ability_list.get_child_count() > 0, "Panel lists learnable or learned Abilities from the shared catalog", failures)
	var dexterity_card: PanelContainer = panel.attribute_list.get_child(1)
	var dexterity_text: String = dexterity_card.get_child(0).get_child(0).text
	check(dexterity_text.contains(str(character.dexterity)), "Level Up Attribute cards must show the post-Ancestry and post-Class value", failures)
	var original_dexterity := character.dexterity
	var original_points := character.attribute_points
	if original_points > 0:
		for index in range(original_points):
			panel.change_attribute(AttributeTypes.Type.DEXTERITY, 1)
		check(character.dexterity == original_dexterity, "Attribute preview must not mutate the character before Confirm", failures)
		panel.confirm()
		check(character.dexterity == original_dexterity + original_points, "Confirm applies all staged Attribute choices", failures)
	panel.queue_free()
	if failures.is_empty():
		print("LEVEL_UP_PANEL_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
