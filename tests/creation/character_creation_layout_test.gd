extends SceneTree

const CreationScene = preload("res://scenes/character_creation/CharacterCreation.tscn")
var failures: Array[String] = []
var emitted_character: CharacterData

func _init() -> void:
	call_deferred("run_tests")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func find_character_detail(page: Node) -> Node:
	for detail_name in ["Character Detail", "Character_Detail", "Character_Details"]:
		var detail := page.get_node_or_null(detail_name)
		if detail != null:
			return detail
	return null

func run_tests() -> void:
	var creation := CreationScene.instantiate()
	creation.auto_start_combat = false
	root.add_child(creation)
	await process_frame
	check(creation.has_node("VBoxContainer/Equipment"), "Equipment page is present")
	check(creation.has_node("VBoxContainer/Equipment/Inventory"), "Equipment page has its inventory column")
	check(creation.has_node("VBoxContainer/Equipment/EquipmentDetail"), "Equipment page has slot and item details")
	check(creation.has_node("VBoxContainer/Equipment/Character Detail"), "Equipment page keeps the character summary")
	check(creation.has_node("VBoxContainer/Review"), "Review page is present")
	check(creation.has_node("VBoxContainer/Review/Checklist"), "Review page has edit shortcuts")
	check(creation.has_node("VBoxContainer/Review/CharacterSheet"), "Review page has the final character sheet")
	check(creation.has_node("VBoxContainer/Review/Ready"), "Review page shows creation readiness")
	check(creation.has_node("VBoxContainer/MarginContainer/HBoxContainer/Equipment_button"), "Equipment navigation label is spelled correctly")
	check(creation.has_node("VBoxContainer/MarginContainer/HBoxContainer/Review_button"), "Review navigation node is spelled correctly")
	check(creation.step_buttons.size() == 8 and creation.step_index == 0, "Authored navigation binds all eight creation steps")
	var visible_class_list := creation.get_node("VBoxContainer/Class/Class_Select_Tab/MarginContainer/HBoxContainer/VBoxContainer")
	var visible_class_cards := visible_class_list.get_children().filter(func(node): return node is NinePatchRect)
	check(visible_class_cards.size() == creation.catalog.classes.size(), "Every catalog class receives a clickable authored card")
	var initial_class = creation.draft.character_class
	var selected_class = creation.catalog.classes.filter(func(entry): return entry.id == "devotee")[0]
	visible_class_cards[2].get_node("Button").pressed.emit()
	check(creation.draft.character_class == selected_class, "Clicking an authored Class card updates CreationDraft")
	var class_detail_panel := creation.get_node("VBoxContainer/Class/Class_Detail")
	var class_content := class_detail_panel.find_child("VBoxContainer", true, false) as VBoxContainer
	check(class_content.find_child("Name", true, false).text == selected_class.display_name, "Selecting a Class updates its name in the center panel")
	check(class_content.find_child("Traits", true, false).text.contains(selected_class.description), "Selecting a Class updates its description in the center panel")
	check(class_content.find_child("Base Mana", true, false).text.contains(str(selected_class.base_mana)), "Selecting a Class updates its base resource values")
	check(class_content.find_child("Ability Name", true, false).text.contains(selected_class.granted_abilities[0].display_name), "Selecting a Class updates its granted Abilities")
	var class_scroll := class_detail_panel.find_child("ClassDetailScroll", true, false) as ScrollContainer
	creation.show_step(2)
	await process_frame
	await process_frame
	check(class_scroll != null, "Class details use a native scroll area")
	if class_scroll != null:
		var class_scrollbar := class_scroll.get_v_scroll_bar()
		check(class_scrollbar.max_value > class_scrollbar.page, "Long Class details can scroll through all text")
		class_scroll.scroll_vertical = 100
		class_scroll.scroll_vertical = 0
		check(class_scroll.scroll_vertical == 0, "Returning Class details to the top shows the first line")
	creation._select_class(initial_class)
	var selected_ancestry = creation.catalog.ancestries[1]
	var visible_ancestry_list := creation.get_node("VBoxContainer/Ancestry/NinePatchRect/MarginContainer/HBoxContainer/VBoxContainer")
	var visible_ancestry_cards := visible_ancestry_list.get_children().filter(func(node): return node is NinePatchRect)
	visible_ancestry_cards[1].get_node("Button").pressed.emit()
	check(creation.draft.ancestry == selected_ancestry, "Clicking an authored Ancestry card updates CreationDraft")
	var ancestry_detail := "VBoxContainer/Ancestry/NinePatchRect2/NinePatchRect/MarginContainer/HBoxContainer/VBoxContainer"
	check(creation.get_node(ancestry_detail + "/Name").text == selected_ancestry.display_name, "Selecting an Ancestry updates its name in the center panel")
	check(creation.get_node(ancestry_detail + "/Traits").text.contains(selected_ancestry.description), "Selecting an Ancestry updates its description in the center panel")
	check(creation.get_node(ancestry_detail + "/Base Hp").text.contains(str(selected_ancestry.base_hp)), "Selecting an Ancestry updates Base HP")
	check(creation.get_node(ancestry_detail + "/Base Mana").text.contains(str(selected_ancestry.base_mana)), "Selecting an Ancestry updates Base Mana")
	check(creation.get_node(ancestry_detail + "/Ability Container/VBoxContainer/Ability Name").text == selected_ancestry.granted_abilities[0].display_name, "Selecting an Ancestry updates its granted Ability")
	var ancestry_character_detail := find_character_detail(creation.get_node("VBoxContainer/Ancestry"))
	check(ancestry_character_detail.find_child("Ancestry_Class", true, false).text.contains(selected_ancestry.display_name), "Selecting an Ancestry updates the right-side ancestry summary")
	check(ancestry_character_detail.find_child("Hp", true, false).text.contains(str(creation.draft.preview.max_hp)), "Selecting an Ancestry updates derived HP on the right")
	check(ancestry_character_detail.find_child("Mana", true, false).text.contains(str(creation.draft.preview.max_mana)), "Selecting an Ancestry updates derived Mana on the right")
	check(ancestry_character_detail.find_child("Abilitygranted", true, false).text.contains(selected_ancestry.granted_abilities[0].display_name), "Selecting an Ancestry updates granted Abilities on the right")
	var attribute_ability_list := creation.get_node("VBoxContainer/Attribute/Ability_That_Increase_Attribute/MarginContainer/HBoxContainer/VBoxContainer")
	var class_attribute_card := attribute_ability_list.get_node("Ability3")
	check(class_attribute_card.find_child("Label", true, false).text == creation.draft.character_class.granted_abilities[0].display_name, "Attribute page lists the selected Class Attribute Ability")
	var ancestry_choice_count: int = creation.draft.ancestry_choices.size()
	var class_choice_count: int = creation.draft.class_choices.size()
	creation._add_attribute_choice(0)
	check(creation.draft.ancestry_choices.size() == ancestry_choice_count and creation.draft.class_choices.size() == class_choice_count, "Attribute points cannot be assigned before choosing an Attribute Ability")
	class_attribute_card.get_node("Button").pressed.emit()
	var attribute_detail := creation.get_node("VBoxContainer/Attribute/AbilitiesAndAttribute_Detail/AbilitiesAndAttribute_Detail_Rect")
	check(attribute_detail.find_child("Name", true, false).text == creation.draft.character_class.granted_abilities[0].display_name, "Clicking an Attribute Ability updates the center detail")
	check(attribute_detail.find_child("Description", true, false).text.contains("Attribute condition:"), "Attribute Ability detail explains its selection condition")
	check(attribute_detail.find_child("Description", true, false).text.contains("INT") and attribute_detail.find_child("Description", true, false).text.contains("WIS"), "Class Attribute detail lists the allowed Attributes")
	creation._add_attribute_choice(3)
	check(creation.draft.class_choices.has(3) and creation.draft.ancestry_choices.size() == ancestry_choice_count, "Selected Class Ability assigns only its own Attribute point")
	creation._remove_attribute_choice(3)
	creation.show_step(1)
	await process_frame
	var long_ability_text := ancestry_character_detail.find_child("Abilitygranted", true, false) as Label
	long_ability_text.text = (selected_ancestry.granted_abilities[0].display_name + "\n").repeat(30)
	await process_frame
	creation._refresh_character_detail_scrollbars()
	var ancestry_scrollbar := ancestry_character_detail.find_child("VScrollBar", true, false) as VScrollBar
	ancestry_scrollbar.visible = true
	ancestry_scrollbar.page = 100.0
	ancestry_scrollbar.max_value = 300.0
	ancestry_scrollbar.value = 0.0
	var wheel_event := InputEventMouseButton.new()
	wheel_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_event.pressed = true
	wheel_event.position = ancestry_character_detail.get_global_rect().get_center()
	creation._input(wheel_event)
	check(ancestry_scrollbar.value > 0.0, "Mouse wheel scrolls while pointing anywhere inside Character Detail")
	creation.furthest_step = 4
	creation.show_step(4)
	await process_frame
	await process_frame
	var ability_list_scroll := creation.get_node("VBoxContainer/Abilities/Ability/AbilityListScroll") as ScrollContainer
	check(ability_list_scroll.get_v_scroll_bar().max_value > ability_list_scroll.get_v_scroll_bar().page, "Ability list provides scrolling when its cards exceed the panel")
	check(creation._ability_search_input == creation.get_node("VBoxContainer/Abilities/Ability/MarginContainer/HBoxContainer/VBoxContainer/Search"), "Ability Search uses the authored top-left field")
	check(creation._ability_filter_option == creation.get_node("VBoxContainer/Abilities/Ability/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/Filter"), "Ability Filter uses the authored top-left field")
	check(creation._ability_sort_option == creation.get_node("VBoxContainer/Abilities/Ability/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/Sort"), "Ability Sort uses the authored top-left field")
	check(creation._ability_search_input != null and creation._ability_filter_option != null and creation._ability_sort_option != null, "Ability page provides Search, Filter and Sort controls")
	var ability_list_frame: Control = creation.get_node("VBoxContainer/Abilities/Ability")
	check(ability_list_frame.get_global_rect().encloses(creation._ability_search_input.get_global_rect()), "Ability Search stays inside the left column")
	check(ability_list_frame.get_global_rect().encloses(creation._ability_filter_option.get_global_rect()), "Ability Filter stays inside the left column")
	check(ability_list_frame.get_global_rect().encloses(creation._ability_sort_option.get_global_rect()), "Ability Sort stays inside the left column")
	var ability_header: Control = creation.get_node("VBoxContainer/Abilities/Ability/MarginContainer/HBoxContainer/VBoxContainer/Header")
	check(ability_list_scroll.get_global_rect().position.y >= ability_header.get_global_rect().end.y, "Ability cards start below Search, Filter, Sort and the Ability heading")
	var search_target: AbilityData = creation.catalog.get_abilities().filter(func(ability): return ability.granted_skills.is_empty())[0]
	creation._on_ability_search_changed(search_target.display_name)
	var searched_cards: Array = creation._ability_list_content.get_children().filter(func(node): return node is NinePatchRect)
	check(not searched_cards.is_empty() and searched_cards.all(func(card): return creation.catalog.find_ability(card.get_meta("ability_id")).display_name.to_lower().contains(search_target.display_name.to_lower())), "Ability Search limits the list by name")
	creation._on_ability_search_changed("__no_matching_ability__")
	check(creation._ability_list_content.get_child_count() == 0, "An empty Ability search result stays blank without a warning label")
	creation._on_ability_search_changed("")
	creation._on_ability_filter_selected(4)
	var passive_cards: Array = creation._ability_list_content.get_children().filter(func(node): return node is NinePatchRect)
	check(not passive_cards.is_empty() and passive_cards.all(func(card): return creation.catalog.find_ability(card.get_meta("ability_id")).is_passive), "Ability Filter can show only Passive Abilities")
	creation._on_ability_filter_selected(0)
	creation._on_ability_sort_selected(4)
	var sorted_cards: Array = creation._ability_list_content.get_children().filter(func(node): return node is NinePatchRect)
	var levels_descending := true
	for index in range(1, sorted_cards.size()):
		var previous: AbilityData = creation.catalog.find_ability(sorted_cards[index - 1].get_meta("ability_id"))
		var current: AbilityData = creation.catalog.find_ability(sorted_cards[index].get_meta("ability_id"))
		levels_descending = levels_descending and previous.required_level >= current.required_level
	check(levels_descending, "Ability Sort orders Abilities by descending Level")
	creation._on_ability_sort_selected(0)
	var expected_icon_x: float = -1.0
	for ability_card in creation._ability_list_content.get_children():
		if not ability_card is NinePatchRect:
			continue
		var ability_icon := ability_card.find_child("Ability_Icon", true, false) as TextureRect
		if expected_icon_x < 0.0:
			expected_icon_x = ability_icon.position.x
		else:
			check(is_equal_approx(ability_icon.position.x, expected_icon_x), "Every Ability artwork uses the same horizontal position")
		var ability_name := ability_card.find_child("Name", true, false) as Label
		check(ability_name.clip_text, "Long Ability names stay inside the text column")
	var granted_ability = creation.draft.ancestry.granted_abilities[0]
	var granted_card := ability_list_scroll.find_child("Ability_%s" % granted_ability.id, true, false)
	check(granted_card != null and not granted_card.get_node("Button").disabled, "Granted Abilities remain clickable for inspection")
	var granted_card_content := granted_card.get_node("HBoxContainer") as Control
	check(granted_card_content.offset_left >= granted_card.patch_margin_left and granted_card_content.offset_right <= -granted_card.patch_margin_right, "Ability artwork stays inside its card border while scrolling")
	check(not granted_card_content.get_node("HSeparator").visible, "Ability artwork does not shift with the card name width")
	var learned_count: int = creation.draft.learned_ids.size()
	granted_card.get_node("Button").pressed.emit()
	var ability_detail_scroll := creation.get_node("VBoxContainer/Abilities/Detail/DetailRect/AbilityDetailScroll") as ScrollContainer
	check(ability_detail_scroll.find_child("Name", true, false).text == granted_ability.display_name, "Clicking an Ability shows its name in the center panel")
	check(ability_detail_scroll.find_child("Traits", true, false).text.contains(granted_ability.traits[0].display_name), "Ability center detail shows Traits")
	check(ability_detail_scroll.find_child("Description", true, false).text == granted_ability.description, "Ability center detail shows its Description")
	check(creation.draft.learned_ids.size() == learned_count, "Inspecting a granted Ability does not spend Ability Points")
	var ability_action: Button = creation._ability_action_button
	check(ability_action.disabled and ability_action.text == "Granted", "Granted Ability shows a non-purchasable action state")
	var learnable_ability: AbilityData
	for ability in creation.catalog.get_abilities():
		if creation.draft.progression.get_learn_ability_failure_reason(creation.draft.preview, ability).is_empty():
			learnable_ability = ability
			break
	check(learnable_ability != null, "The current character has an Ability available to equip")
	if learnable_ability != null:
		var learnable_card := ability_list_scroll.find_child("Ability_%s" % learnable_ability.id, true, false)
		learnable_card.get_node("Button").pressed.emit()
		check(not creation.draft.learned_ids.has(learnable_ability.id), "Selecting an Ability card only opens its details")
		check(not ability_action.disabled and ability_action.text == "Equip Ability", "Available Ability enables the center Equip button")
		ability_action.pressed.emit()
		check(creation.draft.learned_ids.has(learnable_ability.id) and ability_action.text == "Remove Ability", "Equip button spends the Ability Point and can remove the selection")
		ability_action.pressed.emit()
		check(not creation.draft.learned_ids.has(learnable_ability.id), "Remove Ability refunds the selection")
	var starting_class = creation.draft.character_class
	var arcanist = creation.catalog.classes.filter(func(entry): return entry.id == "arcanist")[0]
	creation._select_class(arcanist)
	var grantor_cards: Array = creation._spell_grantor_list_content.get_children().filter(func(node): return node is NinePatchRect)
	check(grantor_cards.size() == creation.draft.get_active_spell_grantors().size(), "Spell page lists only Abilities that grant Spell choices")
	var grantor = creation.draft.get_active_spell_grantors()[0]
	grantor_cards[0].get_node("Button").pressed.emit()
	var spell_detail := creation.get_node("VBoxContainer/Spell/Detail/DetailRect")
	check(spell_detail.find_child("Name", true, false).text == grantor.display_name, "Clicking a Spell-granting Ability shows its detail in the center")
	var spell_cards: Array = creation._spell_choices_content.get_children().filter(func(node): return node is NinePatchRect)
	check(not spell_cards.is_empty(), "Clicking a Spell-granting Ability lists its matching Spells in the center")
	var shown_training: AbilityData = creation.catalog.find_ability(String(spell_cards[0].name).trim_prefix("Spell_"))
	check(creation.draft.spell_training_matches_grantor(shown_training, grantor), "Every shown Spell matches the selected granting Ability")
	var learn_button := spell_cards[0].get_node("Button") as Button
	if not learn_button.disabled:
		learn_button.pressed.emit()
	check(not creation.draft.learned_spell_ids.is_empty(), "A Spell card spends a real Spell Choice through CreationDraft")
	creation._select_class(starting_class)
	creation.furthest_step = 7
	creation.show_step(6)
	await process_frame
	await process_frame
	check(creation.get_node("VBoxContainer/Equipment").visible, "Equipment navigation displays the authored Equipment page")
	var inventory_scroll := creation.get_node("VBoxContainer/Equipment/Inventory/MarginContainer/List/InventoryListScroll") as ScrollContainer
	check(inventory_scroll != null, "Equipment inventory uses a native vertical scroll area")
	if inventory_scroll != null:
		check(inventory_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Equipment inventory does not scroll sideways")
		var inventory_content := inventory_scroll.get_node("InventoryListContent") as VBoxContainer
		var inventory_cards := inventory_content.get_children().filter(func(node): return node is NinePatchRect)
		check(inventory_cards.size() == creation.catalog.equipment.size(), "Every Equipment card stays inside the vertical scroll area")
	var shield = creation.catalog.equipment.filter(func(item): return item.slot == EquipmentData.Slot.SHIELD)[0]
	creation._focus_equipment(shield)
	creation._equip_focused(3)
	check(creation.draft.equipment_slots.get(3) == shield, "Equipment action assigns a shield to Hand 2 through CreationDraft")
	check(creation.get_node("VBoxContainer/Equipment/EquipmentDetail/MarginContainer/Content/Slots/OffHand/Label").text.contains(shield.display_name), "Equipment slot label refreshes from the draft")
	creation.draft.character_name = "Mira"
	creation.draft.ancestry_choices.clear()
	for attribute in range(creation.draft.ancestry.attribute_choice_count):
		creation.draft.ancestry_choices.append(attribute)
	creation.draft.class_choices.clear()
	for attribute in creation.draft.character_class.attribute_choice_options:
		if creation.draft.class_choices.size() >= creation.draft.character_class.attribute_choice_count:
			break
		creation.draft.class_choices.append(attribute)
	creation.draft.rebuild()
	creation.refresh()
	for page_name in ["Identity", "Ancestry", "Class", "Attribute", "Abilities", "Spell", "Equipment"]:
		var character_detail := find_character_detail(creation.get_node("VBoxContainer/" + page_name))
		check(character_detail != null, page_name + " keeps a shared Character Detail panel")
		if character_detail != null:
			var name_label := character_detail.find_child("Name", true, false) as Label
			check(name_label != null and name_label.text == "Mira", page_name + " Character Detail refreshes from the shared draft")
	creation.show_step(7)
	check(creation.get_node("VBoxContainer/Review").visible, "Review navigation displays the authored Review page")
	check(creation.get_node("VBoxContainer/Review/CharacterSheet/MarginContainer/Content/Name").text == "MIRA", "Review reads the current character name")
	check(creation.get_node("VBoxContainer/Review/CharacterSheet/MarginContainer/Content/Stats/HP").text.contains(str(creation.draft.preview.max_hp)), "Review reads derived HP from the draft preview")
	creation.character_created.connect(func(character): emitted_character = character)
	creation.confirm_character()
	check(emitted_character != null and emitted_character.starting_equipment_slots.get(shield.id) == 3, "Create emits CharacterData with the selected Hand 2 equipment slot")
	creation.queue_free()
	await process_frame
	if failures.is_empty():
		print("CHARACTER_CREATION_LAYOUT_TEST: PASS")
	else:
		for failure in failures:
			push_error(failure)
		print("CHARACTER_CREATION_LAYOUT_TEST: FAIL")
	quit(0 if failures.is_empty() else 1)
