extends Control

signal character_created(character: CharacterData)
signal creation_cancelled

@export var catalog: Resource = preload("res://data/creation/default_creation_catalog.tres")
@export var draft_script: Script = preload("res://scenes/character_creation/creation_draft.gd")
@export var auto_start_combat: bool = true
@export_file("*.tscn") var destination_scene: String = "res://scenes/prototype/PrototypeCombat.tscn"

const PAGE_NAMES := ["Identity", "Ancestry", "Class", "Attribute", "Abilities", "Spell", "Equipment", "Review"]
const NAV_NAMES := ["Identity_button", "Ancestry_button", "Class_button", "Attribute_button", "Abilities_button", "Spells_button", "Equipment_button", "Review_button"]
const ATTRIBUTE_KEYS := [&"strength", &"dexterity", &"constitution", &"intelligence", &"wisdom", &"charisma"]
const ATTRIBUTE_NODE_NAMES := ["Str", "Dex", "Con", "Int", "Wis", "Cha"]

var draft
var step_index := 0
var furthest_step := 0
var step_buttons: Array[Button] = []
var focused_item
var focused_ability_id := ""
var focused_spell_id := ""
var focused_spell_grantor_id := ""
var focused_attribute_ability_id := ""
var ability_filter := 0
var ability_search := ""
var ability_sort := 0
var left := VBoxContainer.new()
var center: Control
var footer_message: Label
var next_button: Button
var back_button: Button
var _inventory_template: NinePatchRect
var _inventory_list_content: VBoxContainer
var _inventory_list_scroll: ScrollContainer
var _ability_template: NinePatchRect
var _spell_template: NinePatchRect
var _character_detail_scrolls: Array[Dictionary] = []
var _class_detail_content: VBoxContainer
var _class_detail_scroll: ScrollContainer
var _attribute_ability_cards: Array[Control] = []
var _ability_list_content: VBoxContainer
var _ability_list_scroll: ScrollContainer
var _ability_detail_content: VBoxContainer
var _ability_detail_scroll: ScrollContainer
var _ability_action_button: Button
var _ability_search_input: LineEdit
var _ability_filter_option: OptionButton
var _ability_sort_option: OptionButton
var _spell_grantor_list_content: VBoxContainer
var _spell_grantor_list_scroll: ScrollContainer
var _spell_choices_content: VBoxContainer
var _spell_choices_scroll: ScrollContainer

@onready var _pages_root: VBoxContainer = $VBoxContainer
@warning_ignore("unused_private_class_variable")
@onready var _header: HBoxContainer = $VBoxContainer/MarginContainer/HBoxContainer
@onready var _footer: HBoxContainer = $VBoxContainer/HBoxContainer2

func _ready() -> void:
	draft = draft_script.new()
	draft.setup(catalog)
	_bind_navigation()
	_bind_identity()
	_bind_ancestry_and_class()
	_bind_attributes()
	_setup_ability_scrolls()
	_setup_spell_scrolls()
	_bind_abilities_and_spells()
	_bind_equipment()
	_bind_review()
	_setup_class_detail_scroll()
	_setup_character_detail_scrollbars()
	show_step(0)

func _bind_navigation() -> void:
	for index in range(mini(PAGE_NAMES.size(), NAV_NAMES.size())):
		var button := get_node_or_null("VBoxContainer/MarginContainer/HBoxContainer/%s/Button" % NAV_NAMES[index]) as Button
		if button == null:
			continue
		button.pressed.connect(navigate.bind(index))
		step_buttons.append(button)
	back_button = _cover_with_button($VBoxContainer/HBoxContainer2/NinePatchRect)
	next_button = _cover_with_button($VBoxContainer/HBoxContainer2/NinePatchRect2)
	back_button.pressed.connect(go_back)
	next_button.pressed.connect(go_next)
	footer_message = Label.new()
	footer_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_message.add_theme_font_size_override("font_size", 8)
	_footer.add_child(footer_message)
	_footer.move_child(footer_message, 1)

func _cover_with_button(panel: Control) -> Button:
	var button := Button.new()
	button.name = "Button"
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	panel.add_child(button)
	return button

func _bind_identity() -> void:
	var name_edit := get_node_or_null("VBoxContainer/Identity/Story/NinePatchRect/HBoxContainer/MarginContainer/VBoxContainer/Name_edit") as TextEdit
	if name_edit != null:
		name_edit.text = draft.character_name
		name_edit.text_changed.connect(func():
			draft.character_name = name_edit.text
			draft.rebuild()
			refresh())
	var image_button := get_node_or_null("VBoxContainer/Identity/Image_Story_Can_Select/MarginContainer/StoryContainer/Story_or_chooseImage/TextureRect/Button") as Button
	if image_button != null:
		image_button.pressed.connect(choose_custom_portrait)

func _bind_ancestry_and_class() -> void:
	var ancestry_container := get_node_or_null("VBoxContainer/Ancestry/NinePatchRect/MarginContainer/HBoxContainer/VBoxContainer")
	if ancestry_container != null:
		_populate_choice_cards(ancestry_container, catalog.ancestries, "Ancestry", _select_ancestry)
	var class_container := get_node_or_null("VBoxContainer/Class/Class_Select_Tab/MarginContainer/HBoxContainer/VBoxContainer")
	if class_container != null:
		_populate_choice_cards(class_container, catalog.classes, "Class", _select_class)

func _populate_choice_cards(container: Node, sources: Array, prefix: String, callback: Callable) -> void:
	var cards: Array[Node] = []
	for child in container.get_children():
		if child is NinePatchRect:
			cards.append(child)
	if cards.is_empty():
		return
	var template := cards[0].duplicate()
	for card in cards:
		container.remove_child(card)
		card.free()
	for index in range(sources.size()):
		var card := template.duplicate() as NinePatchRect
		card.name = "%s_%s" % [prefix, sources[index].id]
		container.add_child(card)
		_configure_choice_card(card, sources[index].display_name, callback.bind(sources[index]))

func _configure_choice_card(card: Control, caption: String, callback: Callable) -> void:
	var labels := card.find_children("*", "Label", true, false)
	if not labels.is_empty():
		(labels[0] as Label).text = caption
	var button := _cover_with_button(card)
	button.pressed.connect(callback)

func _select_ancestry(value) -> void:
	draft.select_ancestry(value)
	_reset_scroll_region(_pages_root.get_node_or_null("Ancestry/NinePatchRect2"))
	refresh()

func _select_class(value) -> void:
	draft.select_class(value)
	if _class_detail_scroll != null:
		_class_detail_scroll.scroll_vertical = 0
	_rebuild_ability_buttons()
	_rebuild_spell_buttons()
	refresh()

func _bind_attributes() -> void:
	var ability_container := get_node_or_null("VBoxContainer/Attribute/Ability_That_Increase_Attribute/MarginContainer/HBoxContainer/VBoxContainer")
	if ability_container != null:
		for card_name in ["Ability2", "Ability3"]:
			var card := ability_container.get_node_or_null(card_name) as Control
			if card == null:
				continue
			_attribute_ability_cards.append(card)
			var button := _cover_with_button(card)
			button.pressed.connect(_focus_attribute_ability.bind(_attribute_ability_cards.size() - 1))
	var grid_path := "VBoxContainer/Attribute/AbilitiesAndAttribute_Detail/AbilitiesAndAttribute_Detail_Rect/MarginContainer/HBoxContainer/VBoxContainer/Attribute Container/VBoxContainer/GridContainer"
	var grid := get_node_or_null(grid_path)
	if grid == null:
		return
	for index in range(ATTRIBUTE_NODE_NAMES.size()):
		var cell := grid.get_node_or_null(ATTRIBUTE_NODE_NAMES[index])
		if cell == null:
			continue
		var decrease := cell.get_node_or_null("HBoxContainer/ButtonDecrease") as Button
		var increase := cell.get_node_or_null("HBoxContainer/ButtonIncrease") as Button
		if decrease != null:
			decrease.pressed.connect(_remove_attribute_choice.bind(index))
		if increase != null:
			increase.pressed.connect(_add_attribute_choice.bind(index))

func _add_attribute_choice(attribute: int) -> void:
	var ability: AbilityData = _focused_attribute_ability()
	if ability == null:
		return
	if _is_ancestry_attribute_ability(ability) and draft.ancestry_choices.size() < draft.ancestry.attribute_choice_count and not draft.ancestry_choices.has(attribute):
		draft.ancestry_choices.append(attribute)
	elif _is_class_attribute_ability(ability) and draft.class_choices.size() < draft.character_class.attribute_choice_count and draft.character_class.attribute_choice_options.has(attribute) and not draft.class_choices.has(attribute):
		draft.class_choices.append(attribute)
	else:
		return
	draft.rebuild()
	refresh()

func _remove_attribute_choice(attribute: int) -> void:
	var ability: AbilityData = _focused_attribute_ability()
	if _is_ancestry_attribute_ability(ability) and draft.ancestry_choices.has(attribute):
		draft.ancestry_choices.erase(attribute)
	elif _is_class_attribute_ability(ability) and draft.class_choices.has(attribute):
		draft.class_choices.erase(attribute)
	else:
		return
	draft.rebuild()
	refresh()

func _focus_attribute_ability(index: int) -> void:
	var abilities := _get_attribute_abilities()
	if index < 0 or index >= abilities.size():
		return
	focused_attribute_ability_id = abilities[index].id
	_refresh_attribute_abilities()
	_refresh_attributes()

func _get_attribute_abilities() -> Array:
	var result: Array = []
	if draft.ancestry != null and not draft.ancestry.granted_abilities.is_empty():
		result.append(draft.ancestry.granted_abilities[0])
	if draft.character_class != null and not draft.character_class.granted_abilities.is_empty():
		result.append(draft.character_class.granted_abilities[0])
	return result

func _focused_attribute_ability() -> AbilityData:
	for ability in _get_attribute_abilities():
		if ability.id == focused_attribute_ability_id:
			return ability
	return null

func _is_ancestry_attribute_ability(ability: AbilityData) -> bool:
	return ability != null and draft.ancestry != null and not draft.ancestry.granted_abilities.is_empty() and draft.ancestry.granted_abilities[0] == ability

func _is_class_attribute_ability(ability: AbilityData) -> bool:
	return ability != null and draft.character_class != null and not draft.character_class.granted_abilities.is_empty() and draft.character_class.granted_abilities[0] == ability

func _refresh_attribute_abilities() -> void:
	var abilities := _get_attribute_abilities()
	for index in range(_attribute_ability_cards.size()):
		var card := _attribute_ability_cards[index]
		card.visible = index < abilities.size()
		if index < abilities.size():
			_set_card_label(card, "Label", abilities[index].display_name)
	var detail := get_node_or_null("VBoxContainer/Attribute/AbilitiesAndAttribute_Detail/AbilitiesAndAttribute_Detail_Rect")
	if detail == null:
		return
	var ability: AbilityData = _focused_attribute_ability()
	if ability == null:
		focused_attribute_ability_id = ""
		_set_descendant_label(detail, "Name", "Select an Attribute Ability")
		_set_descendant_label(detail, "Traits", "Choose an Ability from the left first.")
		_set_wrapped_descendant(detail, "Description", "Attribute points cannot be assigned until an Ability is selected.")
		return
	_set_descendant_label(detail, "Name", ability.display_name)
	var trait_names := _resource_names(ability.traits)
	_set_descendant_label(detail, "Traits", "Traits: %s" % (", ".join(trait_names) if not trait_names.is_empty() else "None"))
	_set_wrapped_descendant(detail, "Description", "%s\n\nAttribute condition: %s" % [ability.description, _attribute_condition_for(ability)])

func _attribute_condition_for(ability) -> String:
	if draft.ancestry != null and not draft.ancestry.granted_abilities.is_empty() and draft.ancestry.granted_abilities[0] == ability:
		return "Choose %d different Attribute(s). Each selected Attribute gains +%d; the same Attribute cannot be chosen twice." % [draft.ancestry.attribute_choice_count, draft.ancestry.attribute_bonus_per_choice]
	if draft.character_class == null:
		return "No Class Attribute choice."
	var rules := PackedStringArray()
	var fixed_names := PackedStringArray()
	for attribute in draft.character_class.fixed_attribute_bonuses:
		fixed_names.append("%s +%d" % [ATTRIBUTE_NODE_NAMES[int(attribute)].to_upper(), int(draft.character_class.fixed_attribute_bonuses[attribute])])
	if not fixed_names.is_empty():
		rules.append("Fixed bonus: %s." % ", ".join(fixed_names))
	var option_names := PackedStringArray()
	for attribute in draft.character_class.attribute_choice_options:
		option_names.append(ATTRIBUTE_NODE_NAMES[int(attribute)].to_upper())
	if draft.character_class.attribute_choice_count > 0:
		rules.append("Choose %d from %s; each selected Attribute gains +%d." % [draft.character_class.attribute_choice_count, " or ".join(option_names), draft.character_class.attribute_bonus_per_choice])
	return " ".join(rules) if not rules.is_empty() else "This feature grants no Attribute changes."

func _bind_abilities_and_spells() -> void:
	var ability_list := _ability_list_content
	if ability_list != null:
		_ability_template = ability_list.get_node_or_null("Ability") as NinePatchRect
		if _ability_template != null:
			_ability_template = _ability_template.duplicate()
	var spell_list := _spell_grantor_list_content
	if spell_list != null:
		_spell_template = spell_list.get_node_or_null("Abilitythatgivespell") as NinePatchRect
		if _spell_template != null:
			_spell_template = _spell_template.duplicate()
	_rebuild_ability_buttons()
	_rebuild_spell_buttons()

func _clear_direct_cards(container: Node) -> void:
	for child in container.get_children():
		if child is NinePatchRect:
			container.remove_child(child)
			child.free()

func _rebuild_ability_buttons() -> void:
	if _ability_template == null:
		return
	var container := _ability_list_content
	if container == null:
		return
	_clear_direct_cards(container)
	var abilities: Array[AbilityData] = []
	for ability in catalog.get_abilities():
		if ability.granted_skills.is_empty() and _ability_matches_search(ability) and _ability_matches_filter(ability):
			abilities.append(ability)
	if ability_sort > 0:
		abilities.sort_custom(_ability_sort_before)
	for ability in abilities:
		var card := _ability_template.duplicate() as NinePatchRect
		card.name = "Ability_%s" % ability.id
		card.set_meta("ability_id", ability.id)
		container.add_child(card)
		_stabilize_ability_card_layout(card)
		_set_card_label(card, "Name", ability.display_name)
		_set_card_label(card, "Level", "Level %d" % ability.required_level)
		_set_card_label(card, "Type", "Passive" if ability.is_passive else "Active")
		var granted: bool = draft.preview.granted_ability_ids.has(ability.id)
		var selected: bool = draft.learned_ids.has(ability.id)
		_set_card_label(card, "Select status", "Granted" if granted else ("Selected" if selected else "%d point(s)" % ability.ability_point_cost))
		var button := card.get_node_or_null("Button") as Button
		if button != null:
			button.disabled = false
			button.pressed.connect(_choose_ability.bind(ability))
	if _ability_list_scroll != null:
		_ability_list_scroll.scroll_vertical = 0


func _ability_matches_search(ability: AbilityData) -> bool:
	var query := ability_search.strip_edges().to_lower()
	if query.is_empty():
		return true
	var searchable := "%s %s %s %s" % [ability.display_name, ability.id, ability.description, " ".join(_resource_names(ability.traits))]
	return searchable.to_lower().contains(query)


func _ability_matches_filter(ability: AbilityData) -> bool:
	match ability_filter:
		1:
			return draft.preview.granted_ability_ids.has(ability.id) or draft.learned_ids.has(ability.id) or draft.progression.get_learn_ability_failure_reason(draft.preview, ability).is_empty()
		2:
			return draft.learned_ids.has(ability.id)
		3:
			return draft.preview.granted_ability_ids.has(ability.id)
		4:
			return ability.is_passive
		5:
			return not ability.is_passive
		6:
			return not draft.preview.granted_ability_ids.has(ability.id) and not draft.learned_ids.has(ability.id) and not draft.progression.get_learn_ability_failure_reason(draft.preview, ability).is_empty()
	return true


func _ability_sort_before(left_ability: AbilityData, right_ability: AbilityData) -> bool:
	match ability_sort:
		1:
			return left_ability.display_name.naturalnocasecmp_to(right_ability.display_name) < 0
		2:
			return left_ability.display_name.naturalnocasecmp_to(right_ability.display_name) > 0
		3:
			return left_ability.required_level < right_ability.required_level or (left_ability.required_level == right_ability.required_level and left_ability.display_name.naturalnocasecmp_to(right_ability.display_name) < 0)
		4:
			return left_ability.required_level > right_ability.required_level or (left_ability.required_level == right_ability.required_level and left_ability.display_name.naturalnocasecmp_to(right_ability.display_name) < 0)
		5:
			return left_ability.ability_point_cost < right_ability.ability_point_cost or (left_ability.ability_point_cost == right_ability.ability_point_cost and left_ability.display_name.naturalnocasecmp_to(right_ability.display_name) < 0)
	return false

func _stabilize_ability_card_layout(card: NinePatchRect) -> void:
	var content := card.get_node_or_null("HBoxContainer") as Control
	if content == null:
		return
	var leading_spacer := content.get_node_or_null("HSeparator") as Control
	if leading_spacer != null:
		leading_spacer.visible = false
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.clip_contents = true
	content.offset_left = float(card.patch_margin_left)
	content.offset_top = 0.0
	content.offset_right = -float(card.patch_margin_right)
	content.offset_bottom = 0.0
	var icon := content.get_node_or_null("Ability_Icon") as TextureRect
	if icon != null:
		icon.custom_minimum_size.x = 38.0
		icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var text_content := content.get_node_or_null("VBoxContainer") as VBoxContainer
	if text_content != null:
		text_content.custom_minimum_size.x = 0.0
		text_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for child in text_content.get_children():
			var label := child as Label
			if label == null:
				continue
			label.custom_minimum_size.x = 0.0
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.clip_text = true
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _choose_ability(ability: AbilityData) -> void:
	focused_ability_id = ability.id
	_refresh_ability_detail(ability)

func _toggle_focused_ability() -> void:
	var ability: AbilityData = catalog.find_ability(focused_ability_id)
	if ability == null or draft.preview.granted_ability_ids.has(ability.id):
		return
	draft.toggle_ability(ability)
	_rebuild_ability_buttons()
	_rebuild_spell_buttons()
	_refresh_ability_detail(ability)
	refresh()

func _refresh_ability_detail(ability: AbilityData) -> void:
	if _ability_detail_content == null:
		return
	_set_descendant_label(_ability_detail_content, "Name", ability.display_name)
	_set_descendant_label(_ability_detail_content, "Level", "Level %d" % ability.required_level)
	_set_descendant_label(_ability_detail_content, "Prequest", "Prerequisite: %s" % (ability.prerequisite_id if not ability.prerequisite_id.is_empty() else "None"))
	_set_descendant_label(_ability_detail_content, "Type", "Type: %s" % _ability_type(ability))
	var trait_names := _resource_names(ability.traits)
	_set_descendant_label(_ability_detail_content, "Traits", "Traits: %s" % (", ".join(trait_names) if not trait_names.is_empty() else "None"))
	_set_descendant_label(_ability_detail_content, "Cost", "Cost: %d Ability Point(s) · %d AP" % [ability.ability_point_cost, ability.ap_cost])
	_set_descendant_label(_ability_detail_content, "Target", "Target: %s" % _ability_target_text(ability))
	_set_descendant_label(_ability_detail_content, "Range", "Range: %s" % ("%.0f ft" % ability.targeting_range_feet if ability.targeting_range_feet > 0.0 else "Self / Melee"))
	_set_descendant_label(_ability_detail_content, "Area", "Area: %s" % _ability_area_text(ability))
	_set_descendant_label(_ability_detail_content, "Duration", "Duration: %s" % ("Permanent" if ability.is_passive else "Instant"))
	_set_descendant_label(_ability_detail_content, "Cooldown", "Cooldown: %d turn(s)" % ability.cooldown_turns)
	_set_wrapped_descendant(_ability_detail_content, "Description", ability.description)
	if _ability_detail_scroll != null:
		_ability_detail_scroll.scroll_vertical = 0
	_refresh_ability_action_button()

func _refresh_ability_action_button() -> void:
	if _ability_action_button == null:
		return
	var ability: AbilityData = catalog.find_ability(focused_ability_id)
	if ability == null:
		_ability_action_button.text = "Select an Ability"
		_ability_action_button.disabled = true
		_ability_action_button.tooltip_text = ""
		return
	if draft.preview.granted_ability_ids.has(ability.id):
		_ability_action_button.text = "Granted"
		_ability_action_button.disabled = true
		_ability_action_button.tooltip_text = "This Ability is granted automatically."
		return
	if draft.learned_ids.has(ability.id):
		_ability_action_button.text = "Remove Ability"
		_ability_action_button.disabled = false
		_ability_action_button.tooltip_text = "Refund this Ability Point selection."
		return
	var reason: String = draft.progression.get_learn_ability_failure_reason(draft.preview, ability)
	_ability_action_button.text = "Equip Ability" if reason.is_empty() else "Locked"
	_ability_action_button.disabled = not reason.is_empty()
	_ability_action_button.tooltip_text = reason

func _ability_target_text(ability: AbilityData) -> String:
	if ability.is_passive:
		return "Passive / Always active"
	match ability.target_mode:
		AbilityData.TargetMode.SELF:
			return "Self"
		AbilityData.TargetMode.GROUND:
			return "Ground area"
		_:
			match ability.target_filter:
				AbilityData.TargetFilter.ALLIES:
					return "One ally"
				AbilityData.TargetFilter.ALL_COMBATANTS:
					return "One combatant"
				_:
					return "One enemy"

func _ability_area_text(ability: AbilityData) -> String:
	match ability.area_shape:
		AbilityData.AreaShape.CIRCLE:
			return "Circle, %.0f ft radius" % ability.area_radius_feet
		AbilityData.AreaShape.LINE:
			return "Line, %.0f x %.0f ft" % [ability.line_length_feet, ability.line_width_feet]
		AbilityData.AreaShape.CONE:
			return "Cone, %.0f ft / %.0f degrees" % [ability.line_length_feet, ability.cone_angle_degrees]
		_:
			return "None"

func _rebuild_spell_buttons() -> void:
	if _spell_template == null:
		return
	if _spell_grantor_list_content == null:
		return
	_clear_direct_cards(_spell_grantor_list_content)
	var grantors: Array = draft.get_active_spell_grantors()
	for grantor in grantors:
		var card := _spell_template.duplicate() as NinePatchRect
		card.name = "SpellGrantor_%s" % grantor.id
		_spell_grantor_list_content.add_child(card)
		_stabilize_ability_card_layout(card)
		_set_card_label(card, "Name", grantor.display_name)
		_set_card_label(card, "Type", "Grants %d Spell(s)" % grantor.spell_choices_granted)
		_set_card_label(card, "Level", "Level %d" % grantor.required_level)
		var button := card.get_node_or_null("Button") as Button
		if button != null:
			button.disabled = false
			button.tooltip_text = grantor.description
			button.pressed.connect(_focus_spell_grantor.bind(grantor))
	if not grantors.any(func(grantor): return grantor.id == focused_spell_grantor_id):
		focused_spell_grantor_id = ""
		_clear_spell_grantor_detail()

func _focus_spell_grantor(grantor: AbilityData) -> void:
	focused_spell_grantor_id = grantor.id
	_refresh_spell_grantor_detail(grantor)
	_rebuild_spell_choices(grantor)

func _clear_spell_grantor_detail() -> void:
	var detail := get_node_or_null("VBoxContainer/Spell/Detail/DetailRect")
	if detail != null:
		_set_descendant_label(detail, "Name", "Select a Spell-granting Ability")
		_set_descendant_label(detail, "Level", "")
		_set_descendant_label(detail, "Prequest", "Choose an Ability from the left.")
		_set_descendant_label(detail, "Type", "")
		_set_descendant_label(detail, "Traits", "")
		_set_wrapped_descendant(detail, "Description", "Its available Spells will appear below.")
	if _spell_choices_content != null:
		_clear_direct_cards(_spell_choices_content)

func _refresh_spell_grantor_detail(grantor: AbilityData) -> void:
	var detail := get_node_or_null("VBoxContainer/Spell/Detail/DetailRect")
	if detail == null:
		return
	_set_descendant_label(detail, "Name", grantor.display_name)
	_set_descendant_label(detail, "Level", "Level %d" % grantor.required_level)
	_set_descendant_label(detail, "Prequest", "Prerequisite: %s" % (grantor.prerequisite_id if not grantor.prerequisite_id.is_empty() else "None"))
	_set_descendant_label(detail, "Type", "Spell-granting Ability · Choose %d" % grantor.spell_choices_granted)
	var trait_names := _resource_names(grantor.traits)
	_set_descendant_label(detail, "Traits", "Traits: %s" % (", ".join(trait_names) if not trait_names.is_empty() else "None"))
	_set_wrapped_descendant(detail, "Description", grantor.description)

func _rebuild_spell_choices(grantor: AbilityData) -> void:
	if _spell_choices_content == null:
		return
	_clear_direct_cards(_spell_choices_content)
	for training in catalog.get_abilities():
		if not draft.spell_training_matches_grantor(training, grantor):
			continue
		var skill = training.granted_skills[0]
		var card := _spell_template.duplicate() as NinePatchRect
		card.name = "Spell_%s" % training.id
		_spell_choices_content.add_child(card)
		_stabilize_ability_card_layout(card)
		_set_card_label(card, "Name", skill.display_name)
		_set_card_label(card, "Type", "Selected" if draft.learned_spell_ids.has(training.id) else "Spell")
		_set_card_label(card, "Level", "Level %d" % skill.spell_level)
		var button := card.get_node_or_null("Button") as Button
		if button != null:
			var reason: String = draft.get_spell_learning_failure_reason(training)
			button.disabled = not draft.learned_spell_ids.has(training.id) and not reason.is_empty()
			button.tooltip_text = reason if not reason.is_empty() else skill.description
			button.pressed.connect(_choose_spell.bind(training))

func _choose_spell(training: AbilityData) -> void:
	focused_spell_id = training.id
	draft.toggle_spell(training)
	var grantor: AbilityData = catalog.find_ability(focused_spell_grantor_id)
	if grantor != null:
		_rebuild_spell_choices(grantor)
	refresh()

func _set_card_label(card: Node, child_name: String, value: String) -> void:
	var label := card.find_child(child_name, true, false) as Label
	if label != null:
		label.text = value

func _bind_equipment() -> void:
	var list := get_node_or_null("VBoxContainer/Equipment/Inventory/MarginContainer/List")
	if list == null:
		return
	_inventory_list_content = VBoxContainer.new()
	_inventory_list_content.name = "InventoryListContent"
	_inventory_list_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_list_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_inventory_list_content.add_theme_constant_override("separation", 4)
	_inventory_list_scroll = ScrollContainer.new()
	_inventory_list_scroll.name = "InventoryListScroll"
	_inventory_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inventory_list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	list.add_child(_inventory_list_scroll)
	_inventory_list_scroll.add_child(_inventory_list_content)
	for child in list.get_children():
		if child is NinePatchRect:
			child.reparent(_inventory_list_content)
	_inventory_template = _inventory_list_content.get_node_or_null("Sword") as NinePatchRect
	for child_name in ["Buckler", "LeatherArmor"]:
		var old := _inventory_list_content.get_node_or_null(child_name)
		if old != null:
			_inventory_list_content.remove_child(old)
			old.free()
	var hand_1 := get_node_or_null("VBoxContainer/Equipment/EquipmentDetail/MarginContainer/Content/Actions/EquipHand1") as Button
	var hand_2 := get_node_or_null("VBoxContainer/Equipment/EquipmentDetail/MarginContainer/Content/Actions/EquipHand2") as Button
	if hand_1 != null:
		hand_1.pressed.connect(_equip_focused.bind(0))
	if hand_2 != null:
		hand_2.pressed.connect(_equip_focused.bind(3))
	for slot_data in [["MainHand", 0], ["OffHand", 3], ["Armour", 1]]:
		var slot_panel := get_node_or_null("VBoxContainer/Equipment/EquipmentDetail/MarginContainer/Content/Slots/%s" % slot_data[0]) as Control
		if slot_panel != null:
			var clear_button := _cover_with_button(slot_panel)
			clear_button.tooltip_text = "Remove equipped item"
			clear_button.pressed.connect(_clear_slot.bind(slot_data[1]))
	_rebuild_inventory_buttons()

func _rebuild_inventory_buttons() -> void:
	if _inventory_template == null:
		return
	var list := _inventory_template.get_parent()
	for child in list.get_children():
		if child is NinePatchRect and child != _inventory_template:
			list.remove_child(child)
			child.free()
	for index in range(catalog.equipment.size()):
		var item = catalog.equipment[index]
		var card: NinePatchRect = _inventory_template if index == 0 else _inventory_template.duplicate()
		if index > 0:
			list.add_child(card)
		card.name = "Item_%s" % item.id
		var label := card.get_node_or_null("Label") as Label
		if label != null:
			label.text = "%s\n%s" % [item.display_name, _equipment_type(item)]
		var button := card.get_node_or_null("Button") as Button
		if button != null:
			for connection in button.pressed.get_connections():
				button.pressed.disconnect(connection.callable)
			button.pressed.connect(_focus_equipment.bind(item))
	if focused_item == null and not catalog.equipment.is_empty():
		focused_item = catalog.equipment[0]

func _equipment_type(item) -> String:
	match item.slot:
		EquipmentData.Slot.ARMOR: return "Armor"
		EquipmentData.Slot.SHIELD: return "Shield"
		_: return "Weapon"

func _focus_equipment(item) -> void:
	focused_item = item
	refresh()

func _equip_focused(slot: int) -> void:
	if focused_item == null:
		return
	draft.equip(focused_item, slot)
	refresh()

func _clear_slot(slot: int) -> void:
	draft.clear_slot(slot)
	refresh()

func _bind_review() -> void:
	var edit_names := ["Identity", "Ancestry", "Class", "Attributes", "Abilities", "Spells", "Equipment"]
	for index in range(edit_names.size()):
		var button := get_node_or_null("VBoxContainer/Review/Checklist/MarginContainer/List/%s" % edit_names[index]) as Button
		if button != null:
			button.pressed.connect(show_step.bind(index))

func navigate(index: int) -> void:
	if index <= furthest_step:
		show_step(index)

func show_step(index: int) -> void:
	step_index = clampi(index, 0, PAGE_NAMES.size() - 1)
	for page_index in range(PAGE_NAMES.size()):
		var page := _pages_root.get_node_or_null(PAGE_NAMES[page_index]) as Control
		if page != null:
			page.visible = page_index == step_index
	center = _pages_root.get_node_or_null(PAGE_NAMES[step_index]) as Control
	if step_index == 4:
		call_deferred("_position_ability_list_scroll")
	_refresh_compatibility_controls()
	refresh()

func _refresh_compatibility_controls() -> void:
	for child in left.get_children():
		left.remove_child(child)
		child.free()
	if step_index == 0:
		var image_button := Button.new()
		image_button.text = "CHOOSE IMAGE FROM COMPUTER"
		image_button.pressed.connect(choose_custom_portrait)
		left.add_child(image_button)
	elif step_index == 2:
		for character_class in catalog.classes:
			var class_button := Button.new()
			class_button.text = character_class.display_name
			class_button.pressed.connect(_select_class.bind(character_class))
			left.add_child(class_button)

func refresh() -> void:
	_refresh_ancestry_detail()
	_refresh_class_detail()
	_refresh_character_details()
	_refresh_attribute_abilities()
	_refresh_attributes()
	_refresh_ability_action_button()
	_refresh_equipment()
	_refresh_review()
	_refresh_navigation()
	call_deferred("_refresh_character_detail_scrollbars")

func _setup_character_detail_scrollbars() -> void:
	_character_detail_scrolls.clear()
	for page_name in PAGE_NAMES:
		if page_name == "Review":
			continue
		var page := _pages_root.get_node_or_null(page_name)
		if page == null:
			continue
		var detail := page.get_node_or_null("Character Detail") as Control
		if detail == null:
			continue
		_register_scroll_region(detail)
	for path in ["Ancestry/NinePatchRect2"]:
		var center_detail := _pages_root.get_node_or_null(path) as Control
		if center_detail != null:
			_register_scroll_region(center_detail)
	call_deferred("_refresh_character_detail_scrollbars")

func _setup_ability_scrolls() -> void:
	var list_frame := get_node_or_null("VBoxContainer/Abilities/Ability") as Control
	var list_margin := list_frame.get_node_or_null("MarginContainer") as MarginContainer if list_frame != null else null
	var list_row := list_margin.get_node_or_null("HBoxContainer") as HBoxContainer if list_margin != null else null
	var authored_list := list_row.get_node_or_null("VBoxContainer") as VBoxContainer if list_row != null else null
	if list_frame != null and list_margin != null and list_row != null and authored_list != null:
		_ability_list_content = VBoxContainer.new()
		_ability_list_content.name = "AbilityListContent"
		for child in authored_list.get_children():
			if child is NinePatchRect:
				child.reparent(_ability_list_content)
		_ability_list_scroll = ScrollContainer.new()
		_ability_list_scroll.name = "AbilityListScroll"
		_ability_list_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_ability_list_scroll.offset_left = 8.0
		_ability_list_scroll.offset_top = 78.0
		_ability_list_scroll.offset_right = -8.0
		_ability_list_scroll.offset_bottom = -8.0
		_ability_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_ability_list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		list_frame.add_child(_ability_list_scroll)
		_ability_list_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ability_list_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_ability_list_scroll.add_child(_ability_list_content)
		_setup_ability_search_filter(authored_list)
		call_deferred("_position_ability_list_scroll")

	var detail_frame := get_node_or_null("VBoxContainer/Abilities/Detail/DetailRect") as Control
	var detail_margin := detail_frame.get_node_or_null("Ability Detail") as MarginContainer if detail_frame != null else null
	var detail_row := detail_margin.get_node_or_null("HBoxContainer") as HBoxContainer if detail_margin != null else null
	_ability_detail_content = detail_row.get_node_or_null("VBoxContainer") as VBoxContainer if detail_row != null else null
	if detail_frame != null and detail_margin != null and detail_row != null and _ability_detail_content != null:
		detail_row.remove_child(_ability_detail_content)
		detail_margin.visible = false
		_ability_detail_scroll = ScrollContainer.new()
		_ability_detail_scroll.name = "AbilityDetailScroll"
		_ability_detail_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_ability_detail_scroll.offset_left = 8.0
		_ability_detail_scroll.offset_top = 8.0
		_ability_detail_scroll.offset_right = -8.0
		_ability_detail_scroll.offset_bottom = -40.0
		_ability_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_ability_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		detail_frame.add_child(_ability_detail_scroll)
		_ability_detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ability_detail_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_ability_detail_scroll.add_child(_ability_detail_content)
		_setup_ability_action_button(detail_frame)


func _setup_ability_search_filter(controls: VBoxContainer) -> void:
	_ability_search_input = controls.get_node_or_null("Search") as LineEdit
	var selectors := controls.get_node_or_null("HBoxContainer") as HBoxContainer
	_ability_filter_option = selectors.get_node_or_null("Filter") as OptionButton if selectors != null else null
	_ability_sort_option = selectors.get_node_or_null("Sort") as OptionButton if selectors != null else null
	if _ability_search_input == null or _ability_filter_option == null or _ability_sort_option == null:
		return
	_ability_filter_option.fit_to_longest_item = false
	_ability_sort_option.fit_to_longest_item = false
	_ability_search_input.text_changed.connect(_on_ability_search_changed)
	_ability_filter_option.clear()
	for label in ["All", "Available", "Selected", "Granted", "Passive", "Active", "Locked"]:
		_ability_filter_option.add_item(label)
	_ability_filter_option.item_selected.connect(_on_ability_filter_selected)
	_ability_sort_option.clear()
	for label in ["Default", "Name A-Z", "Name Z-A", "Level ↑", "Level ↓", "Cost ↑"]:
		_ability_sort_option.add_item(label)
	_ability_sort_option.item_selected.connect(_on_ability_sort_selected)


func _position_ability_list_scroll() -> void:
	await get_tree().process_frame
	if _ability_list_scroll == null:
		return
	var list_frame := get_node_or_null("VBoxContainer/Abilities/Ability") as Control
	var header := get_node_or_null("VBoxContainer/Abilities/Ability/MarginContainer/HBoxContainer/VBoxContainer/Header") as Control
	if list_frame == null or header == null:
		return
	var header_bottom := header.get_global_rect().end.y - list_frame.get_global_rect().position.y
	_ability_list_scroll.offset_top = header_bottom + 3.0


func _on_ability_search_changed(text: String) -> void:
	ability_search = text
	_rebuild_ability_buttons()


func _on_ability_filter_selected(index: int) -> void:
	ability_filter = index
	_rebuild_ability_buttons()


func _on_ability_sort_selected(index: int) -> void:
	ability_sort = index
	_rebuild_ability_buttons()

func _setup_ability_action_button(detail_frame: Control) -> void:
	for button in detail_frame.find_children("*", "Button", true, false):
		if button.name in ["EquipAbility", "Equipt"] or String(button.text).to_lower().contains("equip"):
			_ability_action_button = button as Button
			break
	if _ability_action_button == null:
		_ability_action_button = Button.new()
		_ability_action_button.name = "EquipAbility"
		detail_frame.add_child(_ability_action_button)
	elif _ability_action_button.get_parent() != detail_frame:
		_ability_action_button.reparent(detail_frame)
	_ability_action_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ability_action_button.offset_left = -76.0
	_ability_action_button.offset_top = -32.0
	_ability_action_button.offset_right = -8.0
	_ability_action_button.offset_bottom = -8.0
	_ability_action_button.pressed.connect(_toggle_focused_ability)
	_refresh_ability_action_button()

func _setup_spell_scrolls() -> void:
	var list_frame := get_node_or_null("VBoxContainer/Spell/Ability") as Control
	var list_margin := list_frame.get_node_or_null("MarginContainer") as MarginContainer if list_frame != null else null
	var list_row := list_margin.get_node_or_null("HBoxContainer") as HBoxContainer if list_margin != null else null
	_spell_grantor_list_content = list_row.get_node_or_null("VBoxContainer") as VBoxContainer if list_row != null else null
	if list_frame != null and list_row != null and _spell_grantor_list_content != null:
		list_row.remove_child(_spell_grantor_list_content)
		list_row.visible = false
		_spell_grantor_list_scroll = ScrollContainer.new()
		_spell_grantor_list_scroll.name = "SpellGrantorScroll"
		_spell_grantor_list_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_spell_grantor_list_scroll.offset_left = 8.0
		_spell_grantor_list_scroll.offset_top = 8.0
		_spell_grantor_list_scroll.offset_right = -8.0
		_spell_grantor_list_scroll.offset_bottom = -8.0
		_spell_grantor_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_spell_grantor_list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		list_frame.add_child(_spell_grantor_list_scroll)
		_spell_grantor_list_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_spell_grantor_list_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_spell_grantor_list_scroll.add_child(_spell_grantor_list_content)

	var choices_host := get_node_or_null("VBoxContainer/Spell/Detail/DetailRect/Ability Detail/HBoxContainer/VBoxContainer/Spell_List") as VBoxContainer
	var old_row := choices_host.get_node_or_null("HBoxContainer") as HBoxContainer if choices_host != null else null
	if choices_host != null:
		if old_row != null:
			old_row.visible = false
		_spell_choices_scroll = ScrollContainer.new()
		_spell_choices_scroll.name = "SpellChoicesScroll"
		_spell_choices_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_spell_choices_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_spell_choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_spell_choices_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		choices_host.add_child(_spell_choices_scroll)
		_spell_choices_content = VBoxContainer.new()
		_spell_choices_content.name = "SpellChoices"
		_spell_choices_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_spell_choices_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_spell_choices_scroll.add_child(_spell_choices_content)

func _setup_class_detail_scroll() -> void:
	var frame := get_node_or_null("VBoxContainer/Class/Class_Detail/Class_Detail_Rect") as Control
	var old_margin := frame.get_node_or_null("MarginContainer") as MarginContainer if frame != null else null
	var old_row := old_margin.get_node_or_null("HBoxContainer") as HBoxContainer if old_margin != null else null
	_class_detail_content = old_row.get_node_or_null("VBoxContainer") as VBoxContainer if old_row != null else null
	if frame == null or old_margin == null or old_row == null or _class_detail_content == null:
		return
	old_row.remove_child(_class_detail_content)
	old_margin.visible = false
	_class_detail_scroll = ScrollContainer.new()
	_class_detail_scroll.name = "ClassDetailScroll"
	_class_detail_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_class_detail_scroll.offset_left = 8.0
	_class_detail_scroll.offset_top = 8.0
	_class_detail_scroll.offset_right = -8.0
	_class_detail_scroll.offset_bottom = -8.0
	_class_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_class_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	frame.add_child(_class_detail_scroll)
	_class_detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_class_detail_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_class_detail_scroll.add_child(_class_detail_content)

func _register_scroll_region(detail: Control) -> void:
	var viewport := detail.find_child("MarginContainer", true, false) as Control
	var content := viewport.find_child("VBoxContainer", true, false) as Control if viewport != null else null
	var scrollbar := detail.find_child("VScrollBar", true, false) as VScrollBar
	if viewport == null or content == null or scrollbar == null:
		return
	viewport.clip_contents = true
	scrollbar.step = 8.0
	scrollbar.value_changed.connect(_scroll_character_detail.bind(content))
	detail.resized.connect(_refresh_character_detail_scrollbars)
	_character_detail_scrolls.append({"detail": detail, "viewport": viewport, "content": content, "scrollbar": scrollbar})

func _refresh_character_detail_scrollbars() -> void:
	for binding in _character_detail_scrolls:
		var viewport: Control = binding.viewport
		var content: Control = binding.content
		var scrollbar: VScrollBar = binding.scrollbar
		var viewport_height := viewport.size.y
		var content_height := content.get_combined_minimum_size().y
		var needs_scroll := viewport_height > 0.0 and content_height > viewport_height + 1.0
		scrollbar.visible = needs_scroll
		scrollbar.page = viewport_height
		scrollbar.max_value = maxf(content_height, viewport_height)
		if not needs_scroll:
			scrollbar.value = 0.0
		else:
			scrollbar.value = minf(scrollbar.value, content_height - viewport_height)
		_scroll_character_detail(scrollbar.value, content)

func _scroll_character_detail(value: float, content: Control) -> void:
	content.position.y = -value

func _process(_delta: float) -> void:
	for binding in _character_detail_scrolls:
		var detail: Control = binding.detail
		if detail.is_visible_in_tree():
			_scroll_character_detail((binding.scrollbar as VScrollBar).value, binding.content as Control)

func _reset_scroll_region(detail: Node) -> void:
	if detail == null:
		return
	for binding in _character_detail_scrolls:
		if binding.detail == detail:
			var scrollbar: VScrollBar = binding.scrollbar
			scrollbar.value = 0.0
			_scroll_character_detail(0.0, binding.content as Control)
			return

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index not in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
		return
	for binding in _character_detail_scrolls:
		var detail: Control = binding.detail
		var scrollbar: VScrollBar = binding.scrollbar
		if not detail.is_visible_in_tree() or not scrollbar.visible or not detail.get_global_rect().has_point(event.position):
			continue
		var direction := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0
		scrollbar.value += scrollbar.step * 3.0 * direction
		get_viewport().set_input_as_handled()
		return

func _refresh_ancestry_detail() -> void:
	if draft == null or draft.ancestry == null:
		return
	var ancestry = draft.ancestry
	var base := "VBoxContainer/Ancestry/NinePatchRect2/NinePatchRect/MarginContainer/HBoxContainer/VBoxContainer"
	_set_label(base + "/Name", ancestry.display_name)
	var trait_names := _resource_names(ancestry.traits)
	_set_label(base + "/Traits", "%s\nTraits: %s" % [ancestry.description, ", ".join(trait_names) if not trait_names.is_empty() else "None"])
	_set_label(base + "/Base Hp", "Base HP  ·  %d" % ancestry.base_hp)
	_set_label(base + "/Speed", "Speed  ·  %.0f ft" % ancestry.speed_feet)
	_set_label(base + "/Base Mana", "Base Mana  ·  %d" % ancestry.base_mana)
	_set_label(base + "/Ability", "Granted Ability")
	var ability_base := base + "/Ability Container/VBoxContainer"
	if ancestry.granted_abilities.is_empty():
		_set_label(ability_base + "/Ability Name", "No granted ability")
		_set_label(ability_base + "/Ability Type", "")
		_set_label(ability_base + "/Ability Trait", "")
		_set_label(ability_base + "/Description", "")
		return
	var ability = ancestry.granted_abilities[0]
	_set_label(ability_base + "/Ability Name", ability.display_name)
	_set_label(ability_base + "/Ability Type", _ability_type(ability))
	var ability_traits := _resource_names(ability.traits)
	_set_label(ability_base + "/Ability Trait", "Traits: %s" % (", ".join(ability_traits) if not ability_traits.is_empty() else "None"))
	_set_label(ability_base + "/Description", ability.description)

func _refresh_class_detail() -> void:
	if draft == null or draft.character_class == null or _class_detail_content == null:
		return
	var character_class = draft.character_class
	_set_descendant_label(_class_detail_content, "Name", character_class.display_name)
	var class_traits := _resource_names(character_class.traits)
	_set_wrapped_descendant(_class_detail_content, "Traits", "%s\nTraits: %s" % [character_class.description, ", ".join(class_traits) if not class_traits.is_empty() else "None"])
	var level_one = character_class.get_progression_entry(1)
	var hp_gain := int(level_one.max_hp_gain) if level_one != null else 0
	_set_descendant_label(_class_detail_content, "Base Hp", "Level 1 HP Gain  ·  %d" % hp_gain)
	_set_descendant_label(_class_detail_content, "Speed", "Base Speed  ·  %s" % ("%.0f ft" % character_class.base_speed_feet if character_class.base_speed_feet >= 0.0 else "Unchanged"))
	var resource_text := "Base Mana  ·  %s" % (str(character_class.base_mana) if character_class.base_mana >= 0 else "Unchanged")
	if character_class.base_faith >= 0:
		resource_text += "  |  Base Faith  ·  %d" % character_class.base_faith
	_set_descendant_label(_class_detail_content, "Base Mana", resource_text)
	_set_descendant_label(_class_detail_content, "Ability", "Granted Abilities  ·  %d" % character_class.granted_abilities.size())
	var ability_names := PackedStringArray()
	var ability_types := PackedStringArray()
	var ability_traits := PackedStringArray()
	var ability_descriptions := PackedStringArray()
	for ability in character_class.granted_abilities:
		if ability == null:
			continue
		ability_names.append(ability.display_name)
		var type_name := _ability_type(ability)
		if not ability_types.has(type_name):
			ability_types.append(type_name)
		for trait_name in _resource_names(ability.traits):
			if not ability_traits.has(trait_name):
				ability_traits.append(trait_name)
		ability_descriptions.append("%s — %s" % [ability.display_name, ability.description])
	_set_wrapped_descendant(_class_detail_content, "Ability Name", ", ".join(ability_names) if not ability_names.is_empty() else "No granted abilities")
	_set_wrapped_descendant(_class_detail_content, "Ability Type", "Types: %s" % (", ".join(ability_types) if not ability_types.is_empty() else "None"))
	_set_wrapped_descendant(_class_detail_content, "Ability Trait", "Traits: %s" % (", ".join(ability_traits) if not ability_traits.is_empty() else "None"))
	_set_wrapped_descendant(_class_detail_content, "Description", "\n\n".join(ability_descriptions))

func _resource_names(resources: Array) -> PackedStringArray:
	var names := PackedStringArray()
	for resource in resources:
		if resource != null and not String(resource.display_name).is_empty():
			names.append(resource.display_name)
	return names

func _ability_type(ability: AbilityData) -> String:
	if ability.is_passive:
		return "Passive"
	if not ability.granted_reactions.is_empty():
		return "Reaction"
	return "Active"

func _refresh_character_details() -> void:
	if draft == null or draft.preview == null:
		return
	for page_name in PAGE_NAMES:
		if page_name == "Review":
			continue
		var page := _pages_root.get_node_or_null(page_name)
		if page == null:
			continue
		var detail: Node = null
		for detail_name in ["Character Detail", "Character_Detail", "Character_Details"]:
			detail = page.get_node_or_null(detail_name)
			if detail != null:
				break
		if detail != null:
			_refresh_character_detail(detail)

func _refresh_character_detail(detail: Node) -> void:
	var state: CombatantState = draft.preview
	_set_descendant_label(detail, "Name", draft.character_name.strip_edges() if not draft.character_name.strip_edges().is_empty() else "Unnamed")
	_set_descendant_label(detail, "Ancestry_Class", "%s / %s" % [_ancestry_name(), _class_name()])
	_set_descendant_label(detail, "Level", "Level %d" % draft.level)
	_set_descendant_label(detail, "Hp", "HP  %d" % state.max_hp)
	_set_descendant_label(detail, "Mana", "Mana  %d" % state.max_mana)
	_set_descendant_label(detail, "Ap", "AP  %d" % state.max_ap)
	_set_descendant_label(detail, "ClassDc", "Class DC  %d" % state.class_dc)
	_set_descendant_label(detail, "Speed", "Speed  %.0f ft" % state.speed)
	for attribute_data in [["Str", state.strength], ["Dex", state.dexterity], ["Con", state.constitution], ["Int", state.intelligence], ["Wis", state.wisdom], ["Cha", state.charisma]]:
		_set_descendant_label(detail, attribute_data[0], "%s  %d" % [String(attribute_data[0]).to_upper(), attribute_data[1]])
	_set_descendant_label(detail, "Fortitude", "Fortitude  %d" % state.fortitude)
	_set_descendant_label(detail, "Reflex", "Reflex  %d" % state.reflex)
	_set_descendant_label(detail, "Will", "Will  %d" % state.will)
	_set_descendant_label(detail, "Ability Point Avaliable", "Ability Points Available  ·  %d" % state.ability_points)
	var ability_names := PackedStringArray()
	for ability in state.available_abilities:
		if ability != null and ability.granted_skills.is_empty() and (state.granted_ability_ids.has(ability.id) or state.selected_ability_ids.has(ability.id)):
			ability_names.append(ability.display_name)
	_set_descendant_label(detail, "Ability", "Abilities")
	_set_descendant_label(detail, "Abilitygranted", ", ".join(ability_names) if not ability_names.is_empty() else "None")

func _set_descendant_label(root_node: Node, child_name: String, value: String) -> void:
	var label := root_node.find_child(child_name, true, false) as Label
	if label != null:
		label.text = value

func _set_wrapped_descendant(root_node: Node, child_name: String, value: String) -> void:
	var label := root_node.find_child(child_name, true, false) as Label
	if label != null:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = value

func _refresh_attributes() -> void:
	if draft == null or draft.preview == null:
		return
	var grid_path := "VBoxContainer/Attribute/AbilitiesAndAttribute_Detail/AbilitiesAndAttribute_Detail_Rect/MarginContainer/HBoxContainer/VBoxContainer/Attribute Container/VBoxContainer/GridContainer"
	var grid := get_node_or_null(grid_path)
	if grid == null:
		return
	var ability: AbilityData = _focused_attribute_ability()
	for index in range(ATTRIBUTE_NODE_NAMES.size()):
		var cell := grid.get_node_or_null(ATTRIBUTE_NODE_NAMES[index])
		var value := cell.get_node_or_null("Value") as Label if cell != null else null
		if value != null:
			value.text = str(draft.preview.get(ATTRIBUTE_KEYS[index]))
		if cell == null:
			continue
		var decrease := cell.get_node_or_null("HBoxContainer/ButtonDecrease") as Button
		var increase := cell.get_node_or_null("HBoxContainer/ButtonIncrease") as Button
		if _is_ancestry_attribute_ability(ability):
			if decrease != null:
				decrease.disabled = not draft.ancestry_choices.has(index)
			if increase != null:
				increase.disabled = draft.ancestry_choices.has(index) or draft.ancestry_choices.size() >= draft.ancestry.attribute_choice_count
		elif _is_class_attribute_ability(ability):
			if decrease != null:
				decrease.disabled = not draft.class_choices.has(index)
			if increase != null:
				increase.disabled = not draft.character_class.attribute_choice_options.has(index) or draft.class_choices.has(index) or draft.class_choices.size() >= draft.character_class.attribute_choice_count
		else:
			if decrease != null:
				decrease.disabled = true
			if increase != null:
				increase.disabled = true

func _refresh_equipment() -> void:
	if focused_item == null:
		return
	var content_path := "VBoxContainer/Equipment/EquipmentDetail/MarginContainer/Content"
	_set_label(content_path + "/ItemName", focused_item.display_name.to_upper())
	_set_label(content_path + "/ItemType", _equipment_type(focused_item).to_upper())
	_set_label(content_path + "/Description", focused_item.description)
	var stat_text := ""
	if focused_item.weapon_attack != null:
		var attack = focused_item.weapon_attack
		stat_text = "DAMAGE %d  ·  RANGE %.0f ft  ·  AP %d" % [attack.base_damage, attack.range_feet, attack.ap_cost]
	else:
		stat_text = "DEFENSE EQUIPMENT"
	_set_label(content_path + "/Stats", stat_text)
	for slot_data in [["MainHand", 0, "MAIN HAND"], ["OffHand", 3, "OFF HAND"], ["Armour", 1, "ARMOUR"]]:
		var equipped = draft.equipment_slots.get(slot_data[1])
		_set_label(content_path + "/Slots/%s/Label" % slot_data[0], "%s\n%s" % [slot_data[2], equipped.display_name if equipped != null else "Empty"])
	var hand_1 := get_node_or_null(content_path + "/Actions/EquipHand1") as Button
	var hand_2 := get_node_or_null(content_path + "/Actions/EquipHand2") as Button
	var armor: bool = focused_item.slot == EquipmentData.Slot.ARMOR
	var two_handed: bool = draft.equipment_rules.is_two_handed(focused_item)
	if hand_1 != null:
		hand_1.text = "Equip Armor" if armor else ("Equip Both Hands" if two_handed else "Equip Hand 1")
	if hand_2 != null:
		hand_2.visible = not armor and not two_handed
	_refresh_equipment_summary()

func _refresh_equipment_summary() -> void:
	var summary := "VBoxContainer/Equipment/Character_Details/MarginContainer/Summary"
	_set_label(summary + "/Name", draft.character_name.strip_edges() if not draft.character_name.strip_edges().is_empty() else "Unnamed")
	_set_label(summary + "/Origin", "%s / %s  ·  Level %d" % [_ancestry_name(), _class_name(), draft.level])
	_set_label(summary + "/Vitals", "HP %d   MANA %d   AP %d" % [draft.preview.max_hp, draft.preview.max_mana, draft.preview.max_ap])
	_set_label(summary + "/Defenses", "REF %d   FORT %d   WILL %d" % [draft.preview.reflex, draft.preview.fortitude, draft.preview.will])
	var lines := PackedStringArray(["LOADOUT", ""])
	for slot_data in [[0, "Hand 1"], [3, "Hand 2"], [1, "Armor"]]:
		var item = draft.equipment_slots.get(slot_data[0])
		lines.append("%s  ·  %s" % [slot_data[1], item.display_name if item != null else "Empty"])
	_set_label(summary + "/Loadout", "\n".join(lines))

func _refresh_review() -> void:
	var sheet := "VBoxContainer/Review/CharacterSheet/MarginContainer/Content"
	_set_label(sheet + "/Name", draft.character_name.strip_edges().to_upper() if not draft.character_name.strip_edges().is_empty() else "UNNAMED")
	_set_label(sheet + "/Origin", "%s / %s  ·  Level %d" % [_ancestry_name(), _class_name(), draft.level])
	_set_label(sheet + "/Stats/HP", "HP  %d" % draft.preview.max_hp)
	_set_label(sheet + "/Stats/Mana", "MANA  %d" % draft.preview.max_mana)
	_set_label(sheet + "/Stats/AP", "AP  %d" % draft.preview.max_ap)
	_set_label(sheet + "/Stats/Reflex", "REF  %d" % draft.preview.reflex)
	_set_label(sheet + "/Stats/Fortitude", "FORT  %d" % draft.preview.fortitude)
	_set_label(sheet + "/Stats/Will", "WILL  %d" % draft.preview.will)
	_set_label(sheet + "/Columns/Build", "ATTRIBUTES\nSTR  %d    DEX  %d\nCON  %d    INT  %d\nWIS  %d    CHA  %d\n\nSPEED  %.0f ft\nCLASS DC  %d" % [draft.preview.strength, draft.preview.dexterity, draft.preview.constitution, draft.preview.intelligence, draft.preview.wisdom, draft.preview.charisma, draft.preview.speed, draft.preview.class_dc])
	var equipment_names := PackedStringArray()
	for slot in [0, 3, 1]:
		var item = draft.equipment_slots.get(slot)
		if item != null and not equipment_names.has(item.display_name):
			equipment_names.append(item.display_name)
	var ability_names := PackedStringArray()
	for ability in draft.preview.available_abilities:
		if draft.preview.granted_ability_ids.has(ability.id) or draft.preview.selected_ability_ids.has(ability.id):
			ability_names.append(ability.display_name)
	_set_label(sheet + "/Columns/Choices", "STARTING LOADOUT\n%s\n\nABILITIES\n%s" % [", ".join(equipment_names) if not equipment_names.is_empty() else "None", ", ".join(ability_names) if not ability_names.is_empty() else "None"])
	var reason: String = draft.validation_error()
	_set_label(sheet + "/Status", "All required choices are complete." if reason.is_empty() else reason)
	_set_label("VBoxContainer/Review/Ready/MarginContainer/Content/Message", "Your choices have been checked. Review the character sheet, then create this character." if reason.is_empty() else "Complete the remaining required choice before creating this character.")
	_set_label("VBoxContainer/Review/Ready/MarginContainer/Content/AbilityPoints", "ABILITY POINTS LEFT\n%d" % draft.preview.ability_points)

func _refresh_navigation() -> void:
	for index in range(step_buttons.size()):
		step_buttons[index].disabled = index > furthest_step
	var current_id := String(catalog.steps[step_index].id)
	var reason: String = draft.validation_error() if step_index == PAGE_NAMES.size() - 1 else draft.step_error(current_id)
	next_button.disabled = not reason.is_empty()
	back_button.disabled = false
	$VBoxContainer/HBoxContainer2/NinePatchRect/Back.text = "Cancel" if step_index == 0 and not auto_start_combat else ("Start Over" if step_index == 0 else "Back")
	$VBoxContainer/HBoxContainer2/NinePatchRect2/Next.text = "Create Character" if step_index == PAGE_NAMES.size() - 1 else "Next"
	footer_message.text = reason if not reason.is_empty() else (draft.notice if not draft.notice.is_empty() else "Changes can be reviewed before creation.")

func refresh_navigation() -> void:
	_refresh_navigation()

func go_next() -> void:
	var step_id := String(catalog.steps[step_index].id)
	var reason: String = draft.validation_error() if step_index == PAGE_NAMES.size() - 1 else draft.step_error(step_id)
	if not reason.is_empty():
		footer_message.text = reason
		return
	if step_index == PAGE_NAMES.size() - 1:
		confirm_character()
		return
	furthest_step = maxi(furthest_step, step_index + 1)
	show_step(step_index + 1)

func go_back() -> void:
	if step_index > 0:
		show_step(step_index - 1)
	elif auto_start_combat:
		draft = draft_script.new()
		draft.setup(catalog)
		furthest_step = 0
		focused_item = catalog.equipment[0] if not catalog.equipment.is_empty() else null
		show_step(0)
	else:
		creation_cancelled.emit()

func choose_custom_portrait() -> void:
	var dialog := FileDialog.new()
	dialog.title = "Choose Character Image"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Image Files"])
	dialog.file_selected.connect(func(path: String):
		var image := Image.new()
		if image.load(path) == OK and not image.is_empty():
			draft.set_custom_portrait(ImageTexture.create_from_image(image), path)
			var preview := get_node_or_null("VBoxContainer/Identity/Story/NinePatchRect/HBoxContainer/MarginContainer/VBoxContainer/Image_Preview") as TextureRect
			if preview != null:
				preview.texture = draft.get_portrait_texture()
			refresh()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered_ratio(0.75)

func confirm_character() -> void:
	var character: CharacterData = draft.finish()
	if character == null:
		refresh()
		return
	character_created.emit(character)
	if get_tree().has_meta("party_creation_return_scene"):
		var party_state: PartySetupState = get_tree().get_meta("party_setup_state", PartySetupState.new()) as PartySetupState
		party_state.set_member(int(get_tree().get_meta("party_creation_slot", 0)), character)
		get_tree().set_meta("party_setup_state", party_state)
		return_to_party_setup()
	elif auto_start_combat:
		get_tree().set_meta("created_character_data", character)
		get_tree().change_scene_to_file(destination_scene)

func return_to_party_setup() -> void:
	var return_scene := String(get_tree().get_meta("party_creation_return_scene", "res://scenes/run/CreateParty.tscn"))
	get_tree().remove_meta("party_creation_return_scene")
	get_tree().remove_meta("party_creation_slot")
	get_tree().change_scene_to_file(return_scene)

func _set_label(path: String, value: String) -> void:
	var label := get_node_or_null(path) as Label
	if label != null:
		label.text = value

func _set_wrapped_label(path: String, value: String) -> void:
	var label := get_node_or_null(path) as Label
	if label != null:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = value

func _ancestry_name() -> String:
	return draft.ancestry.display_name if draft.ancestry != null else "Choose ancestry"

func _class_name() -> String:
	return draft.character_class.display_name if draft.character_class != null else "Choose class"
