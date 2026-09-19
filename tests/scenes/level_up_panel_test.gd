extends SceneTree

const PanelScene := preload("res://scenes/run/LevelUpPanel.tscn")
const PlayerData := preload("res://data/character/player.tres")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var failures: Array[String] = []
	DisplayServer.window_set_size(Vector2i(640, 360))
	root.size = Vector2i(640, 360)
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
	check(panel.confirm_button.is_visible_in_tree(), "Confirm remains visible at 640x360", failures)
	check(
		panel.get_global_rect().encloses(panel.confirm_button.get_global_rect()),
		"Confirm remains inside the Level Up panel at 640x360",
		failures
	)
	check(root.get_visible_rect().encloses(panel.get_global_rect()), "Level Up panel fits inside the 640x360 viewport", failures)
	for path in ["Layout/Header", "Layout/Steps", "Layout/PartyRoster", "Layout/Footer"]:
		var section: Control = panel.get_node(path)
		check(panel.get_global_rect().encloses(section.get_global_rect()), "%s remains inside the Level Up panel" % path, failures)
	check(not panel.get_node("Layout/ContentScroll/Content/Summary").visible, "Compact Level Up hides the side preview to preserve choice space", failures)
	check(panel.get_node("Layout/ContentScroll/Content/ChoiceZone/Margin/Column/AbilityScroll").custom_minimum_size.y >= 150.0, "Choose Ability should reserve most of the choice area at 640x360", failures)
	check(
		panel.get_node("Layout/Footer").get_parent() == panel.get_node("Layout"),
		"Footer stays pinned outside the scrolling content",
		failures
	)
	check(panel.party_roster.get_child_count() == 1, "Level Up panel builds a selectable Character portrait", failures)
	var hero_button: Button = panel.party_roster.get_child(0)
	var cancel_button: Button = panel.get_node("Layout/Footer/Margin/Row/Cancel")
	check(panel.party_roster_row.get_parent() == panel.footer_row, "Compact Party selector should move into the footer", failures)
	check(absf(hero_button.get_global_rect().position.y - cancel_button.get_global_rect().position.y) <= 1.0, "Selected Hero and Cancel should share the same vertical level", failures)
	check(hero_button.custom_minimum_size.x <= 110.0, "Compact hero selector leaves room for footer actions", failures)
	check(not panel.status_label.visible, "Compact footer hides the long status copy so it cannot overlap actions", failures)
	check(panel.ability_list.get_child_count() > 0, "Panel lists learnable or learned Abilities from the shared catalog", failures)
	var first_ability_card := panel.ability_list.get_child(0)
	if first_ability_card is Button:
		check(first_ability_card.custom_minimum_size.y <= 34.0, "Ability cards stay compact at 640x360", failures)
		check(first_ability_card.get_theme_font_size("font_size") >= 8, "Compact Ability text remains readable", failures)
	if character.attribute_points > 0:
		var dexterity_card: PanelContainer = panel.attribute_list.get_child(1)
		check(dexterity_card.get_child(0).custom_minimum_size.x <= 145.0, "Attribute cards use compact widths at 640x360", failures)
		var dexterity_text: String = dexterity_card.get_child(0).get_child(0).text
		check(dexterity_text.contains(str(character.dexterity)), "Level Up Attribute cards must show the post-Ancestry and post-Class value", failures)
	else:
		check(not panel.attribute_list.visible, "Attribute section stays hidden when the hero has no Attribute Improve points", failures)
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
