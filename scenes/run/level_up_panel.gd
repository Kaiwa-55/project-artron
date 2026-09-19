class_name LevelUpPanel
extends PanelContainer

signal choices_committed
signal closed

const CATALOG := preload("res://data/creation/default_creation_catalog.tres")

@onready var level_badge: Label = $Layout/Header/Margin/Row/LevelBadge/Level
@onready var title_label: Label = $Layout/Header/Margin/Row/Heading/Title
@onready var subtitle_label: Label = $Layout/Header/Margin/Row/Heading/Subtitle
@onready var points_label: Label = $Layout/Header/Margin/Row/Points
@onready var ability_hint: Label = $Layout/ContentScroll/Content/ChoiceZone/Margin/Column/AbilityHeader/Hint
@onready var ability_list: VBoxContainer = $Layout/ContentScroll/Content/ChoiceZone/Margin/Column/AbilityScroll/AbilityList
@onready var attribute_used: Label = $Layout/ContentScroll/Content/ChoiceZone/Margin/Column/AttributeHeader/Used
@onready var attribute_list: GridContainer = $Layout/ContentScroll/Content/ChoiceZone/Margin/Column/AttributeGrid
@onready var portrait: TextureRect = $Layout/ContentScroll/Content/Summary/Margin/Column/Portrait/Texture
@onready var character_name: Label = $Layout/ContentScroll/Content/Summary/Margin/Column/Name
@onready var class_label: Label = $Layout/ContentScroll/Content/Summary/Margin/Column/Class
@onready var preview_label: Label = $Layout/ContentScroll/Content/Summary/Margin/Column/Preview
@onready var party_roster_panel: PanelContainer = $Layout/PartyRoster
@onready var party_roster_margin: MarginContainer = $Layout/PartyRoster/Margin
@onready var party_roster_row: HBoxContainer = $Layout/PartyRoster/Margin/Row
@onready var party_roster_label: Label = $Layout/PartyRoster/Margin/Row/Label
@onready var party_roster: HBoxContainer = $Layout/PartyRoster/Margin/Row/Scroll/Characters
@onready var status_label: Label = $Layout/Footer/Margin/Row/Status
@onready var footer_row: HBoxContainer = $Layout/Footer/Margin/Row
@onready var confirm_button: Button = $Layout/Footer/Margin/Row/Confirm

var character: CombatantState
var progression_system := ProgressionSystem.new()
var selected_abilities: Array[AbilityData] = []
var selected_spells: Dictionary = {}
var staged_attributes: Dictionary = {}
var party: Array[CombatantState] = []


func _ready() -> void:
	$Layout/Footer/Margin/Row/Cancel.pressed.connect(cancel)
	confirm_button.pressed.connect(confirm)
	get_viewport().size_changed.connect(_apply_responsive_size)
	_apply_responsive_size()
	hide()


func _apply_responsive_size() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var compact := viewport_size.x <= 700.0 or viewport_size.y <= 400.0
	var panel_size := viewport_size - Vector2(12.0, 12.0) if compact else Vector2(
		minf(1180.0, maxf(560.0, viewport_size.x - 32.0)),
		minf(760.0, maxf(420.0, viewport_size.y - 32.0))
	)
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -panel_size.x * 0.5
	offset_top = -panel_size.y * 0.5
	offset_right = panel_size.x * 0.5
	offset_bottom = panel_size.y * 0.5
	var header: PanelContainer = $Layout/Header
	header.custom_minimum_size.y = 50.0 if compact else 76.0
	var header_margin: MarginContainer = $Layout/Header/Margin
	_set_margins(header_margin, 10 if compact else 20, 5 if compact else 12)
	var header_row: HBoxContainer = $Layout/Header/Margin/Row
	header_row.add_theme_constant_override("separation", 8 if compact else 16)
	var badge: PanelContainer = $Layout/Header/Margin/Row/LevelBadge
	badge.custom_minimum_size = Vector2(36.0, 36.0) if compact else Vector2(52.0, 52.0)
	level_badge.add_theme_font_size_override("font_size", 13 if compact else 18)
	title_label.add_theme_font_size_override("font_size", 16 if compact else 22)
	title_label.clip_text = compact
	subtitle_label.add_theme_font_size_override("font_size", 10 if compact else 13)
	points_label.add_theme_font_size_override("font_size", 9 if compact else 13)
	var steps: PanelContainer = $Layout/Steps
	steps.custom_minimum_size.y = 26.0 if compact else 40.0
	for step in $Layout/Steps/Row.get_children():
		if step is Label:
			step.add_theme_font_size_override("font_size", 9 if compact else 16)
	var choice_margin: MarginContainer = $Layout/ContentScroll/Content/ChoiceZone/Margin
	_set_margins(choice_margin, 8 if compact else 20, 6 if compact else 18)
	var choice_column: VBoxContainer = $Layout/ContentScroll/Content/ChoiceZone/Margin/Column
	choice_column.add_theme_constant_override("separation", 5 if compact else 12)
	ability_list.add_theme_constant_override("separation", 3 if compact else 9)
	$Layout/ContentScroll/Content/ChoiceZone/Margin/Column/AbilityHeader/Title.add_theme_font_size_override("font_size", 12 if compact else 17)
	ability_hint.add_theme_font_size_override("font_size", 9 if compact else 16)
	$Layout/ContentScroll/Content/ChoiceZone/Margin/Column/AttributeHeader/Title.add_theme_font_size_override("font_size", 12 if compact else 17)
	attribute_used.add_theme_font_size_override("font_size", 9 if compact else 16)
	var ability_scroll: ScrollContainer = $Layout/ContentScroll/Content/ChoiceZone/Margin/Column/AbilityScroll
	ability_scroll.custom_minimum_size.y = 150.0 if compact else 205.0
	attribute_list.columns = 3
	attribute_list.add_theme_constant_override("h_separation", 4 if compact else 8)
	attribute_list.add_theme_constant_override("v_separation", 4 if compact else 8)
	$Layout/ContentScroll/Content/Summary.visible = not compact
	var roster: PanelContainer = party_roster_panel
	roster.custom_minimum_size.y = 52.0 if compact else 92.0
	var roster_margin: MarginContainer = party_roster_margin
	_set_margins(roster_margin, 10 if compact else 20, 5 if compact else 8)
	party_roster_label.visible = not compact
	party_roster_label.custom_minimum_size.x = 65.0 if compact else 125.0
	party_roster_label.add_theme_font_size_override("font_size", 9 if compact else 16)
	party_roster_label.text = "PARTY\nHERO" if compact else "PARTY\nSELECT HERO"
	var footer: PanelContainer = $Layout/Footer
	footer.custom_minimum_size.y = 46.0 if compact else 70.0
	var footer_margin: MarginContainer = $Layout/Footer/Margin
	_set_margins(footer_margin, 10 if compact else 20, 5 if compact else 12)
	footer_row.add_theme_constant_override("separation", 6 if compact else 12)
	if compact and party_roster_row.get_parent() != footer_row:
		party_roster_row.reparent(footer_row)
		footer_row.move_child(party_roster_row, 0)
	elif not compact and party_roster_row.get_parent() != party_roster_margin:
		party_roster_row.reparent(party_roster_margin)
	party_roster_panel.visible = not compact
	party_roster_row.custom_minimum_size.x = 116.0 if compact else 0.0
	party_roster_row.size_flags_horizontal = Control.SIZE_FILL
	status_label.add_theme_font_size_override("font_size", 9 if compact else 12)
	status_label.clip_text = compact
	status_label.visible = not compact
	var cancel_button: Button = $Layout/Footer/Margin/Row/Cancel
	cancel_button.custom_minimum_size = Vector2(72.0, 32.0) if compact else Vector2(120.0, 42.0)
	confirm_button.custom_minimum_size = Vector2(126.0, 32.0) if compact else Vector2(190.0, 42.0)
	cancel_button.add_theme_font_size_override("font_size", 10 if compact else 16)
	confirm_button.add_theme_font_size_override("font_size", 10 if compact else 16)
	for ability_card in ability_list.get_children():
		if ability_card is Button:
			ability_card.custom_minimum_size.y = 34.0 if compact else 68.0
			ability_card.add_theme_font_size_override("font_size", 8 if compact else 13)
	for attribute_card in attribute_list.get_children():
		if attribute_card is PanelContainer and attribute_card.get_child_count() > 0:
			attribute_card.get_child(0).custom_minimum_size = Vector2(145.0, 38.0) if compact else Vector2(185.0, 62.0)
	for member_button in party_roster.get_children():
		if member_button is Button:
			member_button.custom_minimum_size = Vector2(110.0, 32.0) if compact else Vector2(170.0, 68.0)
			member_button.add_theme_font_size_override("font_size", 8 if compact else 13)
			member_button.add_theme_constant_override("icon_max_width", 24 if compact else 52)


func _set_margins(container: MarginContainer, horizontal: int, vertical: int) -> void:
	container.add_theme_constant_override("margin_left", horizontal)
	container.add_theme_constant_override("margin_right", horizontal)
	container.add_theme_constant_override("margin_top", vertical)
	container.add_theme_constant_override("margin_bottom", vertical)


func _uses_compact_layout() -> bool:
	var viewport_size := get_viewport_rect().size
	return viewport_size.x <= 700.0 or viewport_size.y <= 400.0


func open_for(p_character: CombatantState) -> void:
	open_for_party([p_character], p_character.id)


func open_for_party(p_party: Array[CombatantState], selected_id: String = "") -> void:
	party = p_party
	character = null
	for member in party:
		if member != null and (selected_id.is_empty() or member.id == selected_id):
			character = member
			break
	if character == null and not party.is_empty():
		character = party[0]
	if character == null:
		return
	selected_abilities.clear()
	selected_spells.clear()
	staged_attributes.clear()
	_normalize_spell_choice_tracking()
	status_label.text = "Choices apply only after Confirm. Unspent Ability Points are kept."
	show()
	rebuild()
	build_party_roster()


func select_party_member(member: CombatantState) -> void:
	if member == null or member == character:
		return
	character = member
	selected_abilities.clear()
	selected_spells.clear()
	staged_attributes.clear()
	_normalize_spell_choice_tracking()
	status_label.text = "Now improving %s. Unconfirmed choices on the previous hero were discarded." % member.display_name
	rebuild()
	build_party_roster()


func build_party_roster() -> void:
	_clear(party_roster)
	for member in party:
		if member == null:
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(110, 32) if _uses_compact_layout() else Vector2(170, 68)
		button.icon = member.token_texture
		button.expand_icon = true
		button.add_theme_font_size_override("font_size", 8 if _uses_compact_layout() else 13)
		button.add_theme_constant_override("icon_max_width", 24 if _uses_compact_layout() else 52)
		button.text = "%s\nLv.%d  •  %d choice%s" % [member.display_name, member.level, member.ability_points + member.attribute_points, "s" if member.ability_points + member.attribute_points != 1 else ""]
		button.tooltip_text = "Select %s for Level Up" % member.display_name
		button.add_theme_stylebox_override("normal", _ability_card_style(member == character))
		button.pressed.connect(select_party_member.bind(member))
		party_roster.add_child(button)


func cancel() -> void:
	selected_abilities.clear()
	selected_spells.clear()
	staged_attributes.clear()
	hide()
	closed.emit()


func rebuild() -> void:
	if character == null:
		return
	var class_display_name := _class_name()
	level_badge.text = "%02d" % character.level
	title_label.text = "LEVEL UP — %s" % character.display_name.to_upper()
	subtitle_label.text = "%s · Level %d" % [class_display_name, character.level]
	points_label.text = "ABILITY POINTS  %d\nATTRIBUTE IMPROVE  %d" % [_ability_points_left(), _attribute_points_left()]
	ability_hint.text = "%d point%s · may be saved" % [character.ability_points, "s" if character.ability_points != 1 else ""]
	var used_attributes := character.attribute_points - _attribute_points_left()
	attribute_used.text = "%d/%d increases selected" % [used_attributes, character.attribute_points]
	portrait.texture = character.token_texture
	character_name.text = character.display_name
	class_label.text = "%s · LEVEL %d PREVIEW" % [class_display_name.to_upper(), character.level]
	_clear(ability_list)
	_clear(attribute_list)
	_build_abilities()
	var show_attributes := character.attribute_points > 0
	$Layout/ContentScroll/Content/ChoiceZone/Margin/Column/Separator.visible = show_attributes
	$Layout/ContentScroll/Content/ChoiceZone/Margin/Column/AttributeHeader.visible = show_attributes
	attribute_list.visible = show_attributes
	if show_attributes:
		_build_attributes()
	_build_preview()
	confirm_button.disabled = (character.attribute_points > 0 and _attribute_points_left() > 0) or _has_unfilled_selected_spell_choices()


func _build_abilities() -> void:
	for ability in CATALOG.get_abilities():
		if ability == null:
			continue
		if not ability.granted_skills.is_empty():
			continue
		var learned := character.selected_ability_ids.has(ability.id) or character.granted_ability_ids.has(ability.id)
		var reason := progression_system.get_learn_ability_failure_reason(character, ability)
		var selected := selected_abilities.has(ability)
		if not reason.is_empty() and not learned and not selected:
			continue
		var card := Button.new()
		card.custom_minimum_size = Vector2(0, 34 if _uses_compact_layout() else 68)
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.add_theme_font_size_override("font_size", 8 if _uses_compact_layout() else 13)
		var spell_grant_text := " · Choose %d Spells" % ability.spell_choices_granted if ability.spell_choices_granted > 0 else ""
		card.text = "%s\n%s · Level %d · %d Point%s%s" % [ability.display_name, "Selected" if selected else ("Learned" if learned else _type_text(ability)), ability.required_level, ability.ability_point_cost, "s" if ability.ability_point_cost != 1 else "", spell_grant_text]
		card.tooltip_text = ability.description
		card.disabled = learned or (not selected and ability.ability_point_cost > _ability_points_left())
		card.add_theme_stylebox_override("normal", _ability_card_style(selected))
		card.add_theme_stylebox_override("hover", _ability_card_style(true))
		card.add_theme_color_override("font_color", Color("edf2f7"))
		card.pressed.connect(toggle_ability.bind(ability))
		ability_list.add_child(card)
		if ability.spell_choices_granted > 0 and (selected or learned):
			_build_spell_choices(ability)
	if ability_list.get_child_count() == 0:
		_add_note(ability_list, "No Ability is learnable now. You may keep the point for a later Level.")


func toggle_ability(ability: AbilityData) -> void:
	if selected_abilities.has(ability):
		selected_abilities.erase(ability)
		selected_spells.erase(ability.id)
	elif ability.ability_point_cost <= _ability_points_left():
		selected_abilities.append(ability)
	rebuild()


func _build_spell_choices(grantor: AbilityData) -> void:
	var remaining := _spell_choices_left(grantor)
	_add_note(ability_list, "Choose %d Spell%s for %s — no additional Ability Points" % [grantor.spell_choices_granted, "s" if grantor.spell_choices_granted != 1 else "", grantor.display_name])
	for training in CATALOG.get_abilities():
		if training == null or training.granted_skills.is_empty() or not progression_system.spell_training_matches_grantor(training, grantor):
			continue
		if character.level < training.required_level:
			continue
		var skill: SkillData = training.granted_skills[0]
		var staged: Array = selected_spells.get(grantor.id, [])
		var selected := staged.has(training)
		var learned := character.learned_spell_ids.has(training.id) or character.available_skills.has(skill)
		var card := Button.new()
		card.custom_minimum_size = Vector2(0, 30 if _uses_compact_layout() else 58)
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.add_theme_font_size_override("font_size", 8 if _uses_compact_layout() else 12)
		card.text = "  > %s  |  %s  |  Spell Lv.%d  |  Free" % [skill.display_name, "Selected" if selected else ("Learned" if learned else "Available"), skill.spell_level]
		card.tooltip_text = skill.description
		card.disabled = learned or (not selected and remaining <= 0)
		card.add_theme_stylebox_override("normal", _ability_card_style(selected))
		card.pressed.connect(toggle_spell.bind(training, grantor))
		ability_list.add_child(card)


func toggle_spell(training: AbilityData, grantor: AbilityData) -> void:
	var staged: Array = selected_spells.get(grantor.id, []).duplicate()
	if staged.has(training):
		staged.erase(training)
	elif _spell_choices_left(grantor) > 0:
		staged.append(training)
	selected_spells[grantor.id] = staged
	rebuild()


func _build_attributes() -> void:
	var entries := [["Strength", AttributeTypes.Type.STRENGTH, character.strength], ["Dexterity", AttributeTypes.Type.DEXTERITY, character.dexterity], ["Constitution", AttributeTypes.Type.CONSTITUTION, character.constitution], ["Intelligence", AttributeTypes.Type.INTELLIGENCE, character.intelligence], ["Wisdom", AttributeTypes.Type.WISDOM, character.wisdom], ["Charisma", AttributeTypes.Type.CHARISMA, character.charisma]]
	for entry in entries:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(145, 38) if _uses_compact_layout() else Vector2(185, 62)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _attribute_card_style())
		panel.add_child(row)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 8 if _uses_compact_layout() else 14)
		var added := int(staged_attributes.get(entry[1], 0))
		label.text = "%s  %d\n%s" % [String(entry[0]).left(3).to_upper(), entry[2] + added, "+%d selected" % added if added > 0 else "No change"]
		row.add_child(label)
		var minus := Button.new()
		minus.add_theme_font_size_override("font_size", 9 if _uses_compact_layout() else 16)
		minus.text = "−"
		minus.disabled = added <= 0
		minus.pressed.connect(change_attribute.bind(entry[1], -1))
		row.add_child(minus)
		var plus := Button.new()
		plus.add_theme_font_size_override("font_size", 9 if _uses_compact_layout() else 16)
		plus.text = "+"
		plus.disabled = _attribute_points_left() <= 0
		plus.pressed.connect(change_attribute.bind(entry[1], 1))
		row.add_child(plus)
		attribute_list.add_child(panel)
	if character.attribute_points <= 0:
		_add_note(attribute_list, "Attribute Improve is earned at Levels 3, 5, 7 and 9.")


func change_attribute(attribute: AttributeTypes.Type, amount: int) -> void:
	var current := int(staged_attributes.get(attribute, 0))
	if amount > 0 and _attribute_points_left() <= 0:
		return
	current = maxi(0, current + amount)
	if current == 0:
		staged_attributes.erase(attribute)
	else:
		staged_attributes[attribute] = current
	rebuild()


func confirm() -> void:
	if character == null:
		return
	if character.attribute_points > 0 and _attribute_points_left() > 0:
		status_label.text = "Attribute Improve must spend all %d increases before confirming." % character.attribute_points
		return
	for ability in selected_abilities:
		var result = progression_system.learn_ability(character, ability)
		if not result.success:
			status_label.text = result.failure_reason
			return
	for grantor_id in selected_spells:
		var grantor: AbilityData = CATALOG.find_ability(grantor_id)
		for training in selected_spells[grantor_id]:
			var spell_result = progression_system.learn_spell(character, training, grantor)
			if not spell_result.success:
				status_label.text = spell_result.failure_reason
				return
	for attribute in staged_attributes:
		for index in range(int(staged_attributes[attribute])):
			var result = progression_system.increase_attribute(character, attribute)
			if not result.success:
				status_label.text = result.failure_reason
				return
	selected_abilities.clear()
	selected_spells.clear()
	staged_attributes.clear()
	choices_committed.emit()
	hide()


func _build_preview() -> void:
	var con := character.constitution + int(staged_attributes.get(AttributeTypes.Type.CONSTITUTION, 0))
	var dex := character.dexterity + int(staged_attributes.get(AttributeTypes.Type.DEXTERITY, 0))
	var wis := character.wisdom + int(staged_attributes.get(AttributeTypes.Type.WISDOM, 0))
	var max_hp := maxi(1, character.base_max_hp + character.get_modifier(con) * character.level + character.max_hp_bonus)
	var reflex := 10 + character.get_modifier(dex) + character.reflex_stat_bonus + character.equipment_reflex_bonus
	var fortitude := 10 + character.get_modifier(con) + character.fortitude_stat_bonus + character.equipment_fortitude_bonus
	var will := 10 + character.get_modifier(wis) + character.will_stat_bonus + character.equipment_will_bonus
	preview_label.text = "Maximum HP               %d  →  %d\n\nAbility Points             %d  →  %d\n\nFortitude                       %d  →  %d\n\nReflex                            %d  →  %d\n\nWill                                %d  →  %d\n\n────────────────────\n\n%s" % [character.max_hp, max_hp, character.ability_points, _ability_points_left(), character.fortitude, fortitude, character.reflex, reflex, character.will, will, "Ability Point saved" if selected_abilities.is_empty() else _selected_ability_names()]


func _ability_points_left() -> int:
	var spent := 0
	for ability in selected_abilities:
		spent += ability.ability_point_cost
	return character.ability_points - spent


func _attribute_points_left() -> int:
	var spent := 0
	for value in staged_attributes.values():
		spent += int(value)
	return character.attribute_points - spent


func _selected_ability_names() -> String:
	if selected_abilities.is_empty() and selected_spells.is_empty():
		return "None"
	var names: Array[String] = []
	for ability in selected_abilities:
		names.append(ability.display_name)
	for grantor_id in selected_spells:
		for training in selected_spells[grantor_id]:
			if not training.granted_skills.is_empty():
				names.append("Spell: %s" % training.granted_skills[0].display_name)
	return "\n".join(names)


func _type_text(ability: AbilityData) -> String:
	if ability.spell_choices_granted > 0:
		return "Spell School"
	return "Passive" if ability.is_passive else ("Reaction" if ability.reaction_only else "Active")


func _spell_choices_left(grantor: AbilityData) -> int:
	var committed: Array = character.spell_choices_by_grantor.get(grantor.id, [])
	var staged: Array = selected_spells.get(grantor.id, [])
	return maxi(0, grantor.spell_choices_granted - committed.size() - staged.size())


func _has_unfilled_selected_spell_choices() -> bool:
	for ability in selected_abilities:
		if ability.spell_choices_granted > 0 and _spell_choices_left(ability) > 0:
			return true
	return false


func _normalize_spell_choice_tracking() -> void:
	for training in CATALOG.get_abilities():
		if training == null or training.granted_skills.is_empty():
			continue
		if character.available_skills.has(training.granted_skills[0]) and not character.learned_spell_ids.has(training.id):
			character.learned_spell_ids.append(training.id)
	var assigned: Array[String] = []
	for choices in character.spell_choices_by_grantor.values():
		for training_id in choices:
			if not assigned.has(training_id):
				assigned.append(training_id)
	for grantor in CATALOG.get_abilities():
		if grantor == null or grantor.spell_choices_granted <= 0:
			continue
		if not character.selected_ability_ids.has(grantor.id) and not character.granted_ability_ids.has(grantor.id):
			continue
		var choices: Array = character.spell_choices_by_grantor.get(grantor.id, []).duplicate()
		for training_id in character.learned_spell_ids:
			if choices.size() >= grantor.spell_choices_granted or assigned.has(training_id):
				continue
			var training: AbilityData = CATALOG.find_ability(training_id)
			if progression_system.spell_training_matches_grantor(training, grantor):
				choices.append(training_id)
				assigned.append(training_id)
		character.spell_choices_by_grantor[grantor.id] = choices


func _class_name() -> String:
	if character.has_meta("class_data"):
		var class_data = character.get_meta("class_data")
		if class_data != null and not String(class_data.display_name).is_empty():
			return class_data.display_name
	return "Adventurer"


func _ability_card_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1b2a38") if selected else Color("111d29")
	style.border_color = Color("d1a646") if selected else Color("2d4357")
	style.border_width_left = 4 if selected else 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 14
	style.content_margin_right = 14
	return style


func _attribute_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111d29")
	style.border_color = Color("2d4357")
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	return style


func _clear(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()


func _add_note(container: Container, message: String) -> void:
	var note := Label.new()
	note.text = message
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color("93a4b8"))
	container.add_child(note)
