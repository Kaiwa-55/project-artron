class_name LevelUpPanel
extends PanelContainer

signal choices_committed
signal closed

const CATALOG := preload("res://data/creation/default_creation_catalog.tres")

@onready var level_badge: Label = $Layout/Header/Margin/Row/LevelBadge/Level
@onready var title_label: Label = $Layout/Header/Margin/Row/Heading/Title
@onready var subtitle_label: Label = $Layout/Header/Margin/Row/Heading/Subtitle
@onready var points_label: Label = $Layout/Header/Margin/Row/Points
@onready var ability_hint: Label = $Layout/Content/ChoiceZone/Margin/Column/AbilityHeader/Hint
@onready var ability_list: VBoxContainer = $Layout/Content/ChoiceZone/Margin/Column/AbilityScroll/AbilityList
@onready var attribute_used: Label = $Layout/Content/ChoiceZone/Margin/Column/AttributeHeader/Used
@onready var attribute_list: GridContainer = $Layout/Content/ChoiceZone/Margin/Column/AttributeGrid
@onready var portrait: TextureRect = $Layout/Content/Summary/Margin/Column/Portrait/Texture
@onready var character_name: Label = $Layout/Content/Summary/Margin/Column/Name
@onready var class_label: Label = $Layout/Content/Summary/Margin/Column/Class
@onready var preview_label: Label = $Layout/Content/Summary/Margin/Column/Preview
@onready var party_roster: HBoxContainer = $Layout/PartyRoster/Margin/Row/Scroll/Characters
@onready var status_label: Label = $Layout/Footer/Margin/Row/Status
@onready var confirm_button: Button = $Layout/Footer/Margin/Row/Confirm

var character: CombatantState
var progression_system := ProgressionSystem.new()
var selected_abilities: Array[AbilityData] = []
var staged_attributes: Dictionary = {}
var party: Array[CombatantState] = []


func _ready() -> void:
	$Layout/Footer/Margin/Row/Cancel.pressed.connect(cancel)
	confirm_button.pressed.connect(confirm)
	hide()


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
	staged_attributes.clear()
	status_label.text = "Choices apply only after Confirm. Unspent Ability Points are kept."
	show()
	rebuild()
	build_party_roster()


func select_party_member(member: CombatantState) -> void:
	if member == null or member == character:
		return
	character = member
	selected_abilities.clear()
	staged_attributes.clear()
	status_label.text = "Now improving %s. Unconfirmed choices on the previous hero were discarded." % member.display_name
	rebuild()
	build_party_roster()


func build_party_roster() -> void:
	_clear(party_roster)
	for member in party:
		if member == null:
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(170, 68)
		button.icon = member.token_texture
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 52)
		button.text = "%s\nLv.%d  •  %d choice%s" % [member.display_name, member.level, member.ability_points + member.attribute_points, "s" if member.ability_points + member.attribute_points != 1 else ""]
		button.tooltip_text = "Select %s for Level Up" % member.display_name
		button.add_theme_stylebox_override("normal", _ability_card_style(member == character))
		button.pressed.connect(select_party_member.bind(member))
		party_roster.add_child(button)


func cancel() -> void:
	selected_abilities.clear()
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
	_build_attributes()
	_build_preview()
	confirm_button.disabled = character.attribute_points > 0 and _attribute_points_left() > 0


func _build_abilities() -> void:
	for ability in CATALOG.get_abilities():
		if ability == null:
			continue
		var learned := character.selected_ability_ids.has(ability.id) or character.granted_ability_ids.has(ability.id)
		var reason := progression_system.get_learn_ability_failure_reason(character, ability)
		var selected := selected_abilities.has(ability)
		if not reason.is_empty() and not learned and not selected:
			continue
		var card := Button.new()
		card.custom_minimum_size = Vector2(0, 68)
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.text = "%s\n%s · Level %d · %d Point%s" % [ability.display_name, "Selected" if selected else ("Learned" if learned else _type_text(ability)), ability.required_level, ability.ability_point_cost, "s" if ability.ability_point_cost != 1 else ""]
		card.tooltip_text = ability.description
		card.disabled = learned or (not selected and ability.ability_point_cost > _ability_points_left())
		card.add_theme_stylebox_override("normal", _ability_card_style(selected))
		card.add_theme_stylebox_override("hover", _ability_card_style(true))
		card.add_theme_color_override("font_color", Color("edf2f7"))
		card.pressed.connect(toggle_ability.bind(ability))
		ability_list.add_child(card)
	if ability_list.get_child_count() == 0:
		_add_note(ability_list, "No Ability is learnable now. You may keep the point for a later Level.")


func toggle_ability(ability: AbilityData) -> void:
	if selected_abilities.has(ability):
		selected_abilities.erase(ability)
	elif ability.ability_point_cost <= _ability_points_left():
		selected_abilities.append(ability)
	rebuild()


func _build_attributes() -> void:
	var entries := [["Strength", AttributeTypes.Type.STRENGTH, character.strength], ["Dexterity", AttributeTypes.Type.DEXTERITY, character.dexterity], ["Constitution", AttributeTypes.Type.CONSTITUTION, character.constitution], ["Intelligence", AttributeTypes.Type.INTELLIGENCE, character.intelligence], ["Wisdom", AttributeTypes.Type.WISDOM, character.wisdom], ["Charisma", AttributeTypes.Type.CHARISMA, character.charisma]]
	for entry in entries:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(185, 62)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _attribute_card_style())
		panel.add_child(row)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var added := int(staged_attributes.get(entry[1], 0))
		label.text = "%s  %d\n%s" % [String(entry[0]).left(3).to_upper(), entry[2] + added, "+%d selected" % added if added > 0 else "No change"]
		row.add_child(label)
		var minus := Button.new()
		minus.text = "−"
		minus.disabled = added <= 0
		minus.pressed.connect(change_attribute.bind(entry[1], -1))
		row.add_child(minus)
		var plus := Button.new()
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
	for attribute in staged_attributes:
		for index in range(int(staged_attributes[attribute])):
			var result = progression_system.increase_attribute(character, attribute)
			if not result.success:
				status_label.text = result.failure_reason
				return
	selected_abilities.clear()
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
	if selected_abilities.is_empty():
		return "None"
	var names: Array[String] = []
	for ability in selected_abilities:
		names.append(ability.display_name)
	return "\n".join(names)


func _type_text(ability: AbilityData) -> String:
	return "Passive" if ability.is_passive else ("Reaction" if ability.reaction_only else "Active")


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
