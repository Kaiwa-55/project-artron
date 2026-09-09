extends RefCounted
## Replace/subclass this renderer to add a step; navigation and draft remain shared.
const UI = preload("res://scenes/character_creation/creation_widgets.gd")
const ATTRIBUTES = ["Strength", "Dexterity", "Constitution", "Intelligence", "Wisdom", "Charisma"]
const ATTRIBUTE_KEYS = ["strength", "dexterity", "constitution", "intelligence", "wisdom", "charisma"]

func build_identity(host) -> void:
	UI.label(host.left, "CHOOSE YOUR PORTRAIT", 18, UI.GOLD, true)
	var custom_label := "CHANGE CUSTOM IMAGE" if host.draft.custom_portrait != null else "CHOOSE IMAGE FROM COMPUTER"
	UI.button(host.left, custom_label, host.choose_custom_portrait)
	UI.label(host.left, "PNG, JPG or WebP - square images work best", 13, UI.MUTED)
	if host.draft.custom_portrait == null:
		UI.label(host.left, "No image selected.", 14, UI.MUTED)
	UI.label(host.center, "A NEW STORY", 32, UI.PAPER, true)
	UI.label(host.center, "Choose a name and a face for your journey.", 16, UI.MUTED)
	var portrait: Texture2D = host.draft.get_portrait_texture()
	if portrait != null:
		UI.square_art(host.center, portrait, 225)
	UI.label(host.center, "TOKEN PREVIEW", 15, UI.GOLD, true)
	var token_preview := UI.square_art(host.center, host.draft.get_token_texture(), 150)
	UI.label(host.center, "Zoom", 13, UI.MUTED)
	var zoom_slider := HSlider.new()
	zoom_slider.name = "TokenZoom"
	zoom_slider.min_value = 0.75
	zoom_slider.max_value = 2.5
	zoom_slider.step = 0.05
	zoom_slider.value = host.draft.token_zoom
	zoom_slider.custom_minimum_size.y = 28
	host.center.add_child(zoom_slider)
	UI.label(host.center, "Horizontal position", 13, UI.MUTED)
	var offset_x := HSlider.new()
	offset_x.name = "TokenOffsetX"
	offset_x.min_value = -96
	offset_x.max_value = 96
	offset_x.step = 2
	offset_x.value = host.draft.token_offset.x
	host.center.add_child(offset_x)
	UI.label(host.center, "Vertical position", 13, UI.MUTED)
	var offset_y := HSlider.new()
	offset_y.name = "TokenOffsetY"
	offset_y.min_value = -96
	offset_y.max_value = 96
	offset_y.step = 2
	offset_y.value = host.draft.token_offset.y
	host.center.add_child(offset_y)
	var update_token_preview := func():
		token_preview.texture = host.draft.get_token_texture()
		host.refresh_summary()
	zoom_slider.value_changed.connect(func(value):
		host.draft.token_zoom = float(value)
		update_token_preview.call())
	offset_x.value_changed.connect(func(value):
		host.draft.token_offset.x = float(value)
		update_token_preview.call())
	offset_y.value_changed.connect(func(value):
		host.draft.token_offset.y = float(value)
		update_token_preview.call())
	UI.button(host.center, "RESET TOKEN", func():
		host.draft.reset_token_customization()
		host.refresh())
	UI.label(host.center, "CHARACTER NAME", 15, UI.GOLD)
	var name_input := LineEdit.new()
	name_input.name = "CharacterName"
	name_input.max_length = 32
	name_input.text = host.draft.character_name
	name_input.placeholder_text = "Enter a name"
	name_input.custom_minimum_size.y = 44
	host.center.add_child(name_input)
	name_input.text_changed.connect(func(value):
		host.draft.character_name = value
		host.draft.rebuild()
		host.refresh_summary()
		host.refresh_navigation())
	var test_toggle := CheckButton.new()
	test_toggle.text = "Test mode: choose starting level"
	test_toggle.button_pressed = host.draft.level > 1
	host.center.add_child(test_toggle)
	var level := SpinBox.new()
	level.min_value = 1
	level.max_value = host.draft.progression.progression_data.max_level
	level.value = host.draft.level
	level.visible = test_toggle.button_pressed
	level.prefix = "Level "
	host.center.add_child(level)
	level.value_changed.connect(func(value):
		host.draft.set_level(int(value))
		host.refresh_summary()
		host.refresh_navigation())
	test_toggle.toggled.connect(func(enabled):
		level.visible = enabled
		if not enabled:
			level.value = 1)
	UI.label(host.center, "Normal creation starts at Level 1. Unspent level-up rewards remain available after creation.", 14, UI.MUTED)

func build_ancestry(host) -> void:
	UI.label(host.left, "CHOOSE YOUR ANCESTRY", 18, UI.GOLD, true)
	for ancestry in host.catalog.ancestries:
		UI.card(host.left, ancestry.display_name, ancestry.description, null, host.draft.ancestry == ancestry, func():
			host.draft.select_ancestry(ancestry)
			host.refresh())
	var ancestry = host.draft.ancestry
	if ancestry == null:
		return
	UI.label(host.center, ancestry.display_name.to_upper(), 34, UI.PAPER, true)
	UI.label(host.center, ancestry.description, 18, UI.MUTED)
	UI.line(host.center)
	UI.label(host.center, "HERITAGE", 18, UI.GOLD, true)
	UI.label(host.center, "Base HP +%d\nBase Mana +%d\nSpeed +%.0f ft\nChoose %d different Attributes, +%d each." % [ancestry.base_hp, ancestry.base_mana, ancestry.speed_feet, ancestry.attribute_choice_count, ancestry.attribute_bonus_per_choice])
	UI.label(host.center, UI.traits_text(ancestry), 15, UI.GOLD)
	for ability in ancestry.granted_abilities:
		feature(host.center, ability, "ANCESTRY FEATURE")
	UI.label(host.center, "Make your Attribute choices in the Attributes step.", 15, UI.MUTED)

func build_class(host) -> void:
	UI.label(host.left, "CHOOSE YOUR CLASS", 18, UI.GOLD, true)
	for character_class in host.catalog.classes:
		var visual = host.catalog.visual_for(character_class.id)
		UI.card(host.left, character_class.display_name, visual.subtitle if visual != null else UI.traits_text(character_class), visual.artwork if visual != null else null, host.draft.character_class == character_class, func():
			host.draft.select_class(character_class)
			host.refresh())
	UI.label(host.left, "Your class shapes your starting abilities and progression.", 14, UI.MUTED)
	var character_class = host.draft.character_class
	if character_class == null:
		return
	UI.label(host.center, character_class.display_name.to_upper(), 34, UI.PAPER, true)
	var visual = host.catalog.visual_for(character_class.id)
	UI.label(host.center, visual.subtitle if visual != null else UI.traits_text(character_class), 15, UI.GOLD)
	if visual != null:
		UI.art(host.center, visual.artwork, 140)
	UI.label(host.center, character_class.description, 16, UI.MUTED)
	var shown: Dictionary = {}
	var bonus_parts: PackedStringArray = []
	for attribute in character_class.fixed_attribute_bonuses:
		bonus_parts.append("%s +%d" % [ATTRIBUTES[int(attribute)], character_class.fixed_attribute_bonuses[attribute]])
	if character_class.attribute_choice_count > 0:
		var options: PackedStringArray = []
		for attribute in character_class.attribute_choice_options:
			options.append(ATTRIBUTES[attribute])
		bonus_parts.append("Choose %d: %s (+%d)" % [character_class.attribute_choice_count, " / ".join(options), character_class.attribute_bonus_per_choice])
	UI.label(host.center, "  ·  ".join(bonus_parts), 14, UI.GOLD)
	for ability in host.draft.preview.available_abilities:
		if host.draft.preview.granted_ability_ids.has(ability.id) and character_class.granted_abilities.has(ability):
			feature(host.center, ability, "CLASS FEATURE")
			shown[ability.id] = true
	for entry in character_class.progression_entries:
		for ability in entry.granted_abilities:
			if not shown.has(ability.id):
				UI.line(host.center)
				UI.label(host.center, "LV.%d   ·   %s" % [entry.level, ability.display_name], 19, UI.GOLD, true)
				shown[ability.id] = true
	if shown.is_empty():
		UI.label(host.center, "No class features configured yet.", 15, UI.MUTED)

func feature(parent: Node, ability: AbilityData, source: String) -> void:
	var frame := UI.panel(parent)
	var content := UI.column(frame, 6)
	UI.label(content, source + ("  /  PASSIVE" if ability.is_passive else ""), 12, UI.GOLD)
	UI.label(content, ability.display_name + (" Passive" if ability.is_passive else ""), 21, UI.PAPER, true)
	UI.label(content, ability.description, 15, UI.MUTED)

func build_attributes(host) -> void:
	UI.label(host.left, "SHAPE YOUR STRENGTHS", 20, UI.GOLD, true)
	UI.label(host.left, "Bonuses come from your Ancestry and Class. Each source requires different choices within its own group.", 16, UI.MUTED)
	UI.label(host.left, "These values are recalculated from the starting character, never added onto an old preview.", 14, UI.MUTED)
	UI.label(host.center, "ATTRIBUTES", 32, UI.PAPER, true)
	var ancestry = host.draft.ancestry
	var character_class = host.draft.character_class
	if ancestry == null or character_class == null:
		UI.label(host.center, "Choose an Ancestry and Class first.")
		return
	attribute_group(host, ancestry.display_name + " · " + feature_name(ancestry), "ancestry", ancestry.attribute_choice_count, [0, 1, 2, 3, 4, 5], ancestry.attribute_bonus_per_choice)
	UI.line(host.center)
	var fixed: PackedStringArray = []
	for key in character_class.fixed_attribute_bonuses:
		fixed.append("%s +%d" % [ATTRIBUTES[int(key)], character_class.fixed_attribute_bonuses[key]])
	UI.label(host.center, "Automatic class bonuses: " + (", ".join(fixed) if not fixed.is_empty() else "None"), 16, UI.GOLD)
	attribute_group(host, character_class.display_name + " · " + feature_name(character_class), "class", character_class.attribute_choice_count, character_class.attribute_choice_options, character_class.attribute_bonus_per_choice)
	UI.line(host.center)
	UI.label(host.center, "BASE   +   ANCESTRY   +   CLASS   =   FINAL", 14, UI.GOLD)
	for index in range(6):
		var base: int = host.catalog.base_character.get(ATTRIBUTE_KEYS[index])
		var heritage: int = ancestry.attribute_bonus_per_choice if host.draft.ancestry_choices.has(index) else 0
		var class_bonus: int = int(character_class.fixed_attribute_bonuses.get(index, 0))
		if host.draft.class_choices.has(index):
			class_bonus += character_class.attribute_bonus_per_choice
		UI.label(host.center, "%s     %d + %d + %d = %d" % [ATTRIBUTES[index], base, heritage, class_bonus, host.draft.preview.get(ATTRIBUTE_KEYS[index])], 15)

func feature_name(source) -> String:
	for ability in source.granted_abilities:
		if ability.is_passive:
			return ability.display_name + " Passive"
	return "Attribute choices"

func attribute_group(host, title: String, kind: String, count: int, options: Array, bonus: int) -> void:
	UI.label(host.center, title, 19, UI.PAPER, true)
	var choices: Array = host.draft.ancestry_choices if kind == "ancestry" else host.draft.class_choices
	for index in range(count):
		var selector := OptionButton.new()
		selector.custom_minimum_size.y = 38
		selector.add_item("Choice %d: select an Attribute (+%d)" % [index + 1, bonus], -1)
		selector.set_item_metadata(0, -1)
		for attribute in options:
			selector.add_item(ATTRIBUTES[attribute])
			selector.set_item_metadata(selector.item_count - 1, attribute)
			if index < choices.size() and choices[index] == attribute:
				selector.select(selector.item_count - 1)
		selector.item_selected.connect(func(selected):
			host.draft.choose_attribute(kind, index, int(selector.get_item_metadata(selected)))
			host.refresh())
		host.center.add_child(selector)

func build_abilities(host) -> void:
	UI.label(host.left, "ABILITIES", 20, UI.GOLD, true)
	var search := LineEdit.new()
	search.placeholder_text = "Search · press Enter"
	search.text = host.ability_search
	search.text_submitted.connect(func(value):
		host.ability_search = value
		host.refresh())
	host.left.add_child(search)
	var filter := OptionButton.new()
	for title in ["All abilities", "Basic", "My class", "Active", "Passive", "Reactive", "Learnable now"]:
		filter.add_item(title)
	filter.select(host.ability_filter)
	filter.item_selected.connect(func(index):
		host.ability_filter = index
		host.refresh())
	host.left.add_child(filter)
	var visible_abilities: Array = []
	for ability in host.catalog.get_abilities():
		if ability.granted_skills.is_empty() and matches_filter(host, ability):
			visible_abilities.append(ability)
	if visible_abilities.is_empty():
		UI.label(host.left, "No matching abilities.", 15, UI.MUTED)
	for automatic in [true, false]:
		UI.label(host.left, "GRANTED AUTOMATICALLY" if automatic else "CHOOSE TO LEARN", 13, UI.GOLD)
		for ability in visible_abilities:
			var granted: bool = host.draft.preview.granted_ability_ids.has(ability.id)
			if granted != automatic:
				continue
			var selected: bool = host.draft.learned_ids.has(ability.id)
			var suffix := "GRANTED" if granted else ("LEARNED" if selected else "%d point(s)" % ability.ability_point_cost)
			var node := UI.button(host.left, "%s\nLv.%d · %s" % [ability.display_name, ability.required_level, suffix], func():
				host.focused_ability_id = ability.id
				host.refresh(), host.focused_ability_id == ability.id)
			node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			node.custom_minimum_size.y = 70
	var chosen = host.catalog.find_ability(host.focused_ability_id)
	if chosen == null and not visible_abilities.is_empty():
		chosen = visible_abilities[0]
	if chosen == null:
		UI.label(host.center, "Select an Ability to inspect its effects.", 23, UI.PAPER, true)
		return
	var ability: AbilityData = chosen
	UI.label(host.center, ability.display_name.to_upper(), 29, UI.PAPER, true)
	UI.label(host.center, UI.traits_text(ability), 15, UI.GOLD)
	UI.label(host.center, "LEVEL %d   /   %d ABILITY POINT(S)" % [ability.required_level, ability.ability_point_cost], 14, UI.MUTED)
	UI.line(host.center)
	UI.label(host.center, ability.description, 18)
	if ability.is_passive:
		UI.label(host.center, "PASSIVE · No activation cost", 16, UI.GOLD)
	elif not ability.granted_reactions.is_empty():
		for reaction in ability.granted_reactions:
			UI.label(host.center, "REACTION · %d AP · %s" % [reaction.ap_cost, "%d use(s) per round" % reaction.uses_per_round if reaction.uses_per_round > 0 else "No per-round limit"], 16, UI.GOLD)
	else:
		UI.label(host.center, "AP %d%s    COOLDOWN %d turn(s)" % [ability.ap_cost, "    FAITH %d" % ability.faith_cost if ability.faith_cost > 0 else "", ability.cooldown_turns], 16, UI.GOLD)
		UI.label(host.center, "Target: %s\nRange: %.0f ft\nUses per turn: %s" % [["Single combatant", "Self", "Ground"][ability.target_mode], ability.targeting_range_feet if ability.targeting_range_feet > 0 else (ability.attack_data.range_feet if ability.attack_data != null else 0.0), str(ability.uses_per_turn) if ability.uses_per_turn > 0 else "No per-turn limit"], 16, UI.MUTED)
		for effect in ability.effects:
			if effect is AbilityEffectData and effect.effect_type == AbilityEffectData.Type.ABILITY_MOVEMENT:
				UI.label(host.center, "Movement: %.0f ft · %s" % [effect.movement_distance_feet, "Triggers Reactions" if effect.movement_triggers_reactions else "No Reactions"], 16, UI.GOLD)
	var granted: bool = host.draft.preview.granted_ability_ids.has(ability.id)
	var selected: bool = host.draft.learned_ids.has(ability.id)
	var reason: String = host.draft.progression.get_learn_ability_failure_reason(host.draft.preview, ability)
	var learn := UI.button(host.center, "GRANTED AUTOMATICALLY" if granted else ("REMOVE SELECTION" if selected else "LEARN ABILITY"), func():
		host.draft.toggle_ability(ability)
		host.refresh(), true)
	learn.disabled = granted or (not selected and not reason.is_empty())
	UI.label(host.center, "Included by your Ancestry or Class; no points spent." if granted else ("Removing a prerequisite also removes dependent selections and refunds their points." if selected else reason), 15, UI.MUTED)
	UI.label(host.center, "%d points remain. You may keep unused points for later." % host.draft.preview.ability_points, 15, UI.GOLD)


func build_spells(host) -> void:
	UI.label(host.left, "SPELLBOOK", 20, UI.GOLD, true)
	UI.label(host.left, "Spell Slots come from learned Abilities and do not spend Ability Points.", 14, UI.MUTED)
	var grantors: Array = []
	for ability in host.draft.preview.available_abilities:
		if ability == null or ability.spell_choices_granted <= 0:
			continue
		if host.draft.preview.granted_ability_ids.has(ability.id) or host.draft.preview.selected_ability_ids.has(ability.id):
			grantors.append(ability)
			UI.button(host.left, "%s\nGrants %d Spell Slot(s)" % [ability.display_name, ability.spell_choices_granted], Callable(), true)
	if grantors.is_empty():
		UI.label(host.left, "No learned Ability currently grants Spell Slots.", 15, UI.MUTED)
		UI.label(host.center, "NO SPELL SLOTS", 30, UI.PAPER, true)
		UI.label(host.center, "Learn or gain an Ability that grants Spell Choices first.", 17, UI.MUTED)
		return
	var choices: Array = []
	for ability in host.catalog.get_abilities():
		if ability.granted_skills.is_empty():
			continue
		if host.draft.character_class == null or not ability.required_trait_ids.has(host.draft.character_class.id):
			continue
		choices.append(ability)
	if choices.is_empty():
		UI.label(host.center, "NO AVAILABLE SPELLS", 30, UI.PAPER, true)
		return
	for grantor in grantors:
		var frame := UI.panel(host.center)
		var content := UI.column(frame, 8)
		UI.label(content, grantor.display_name.to_upper(), 23, UI.PAPER, true)
		UI.label(content, grantor.description, 14, UI.MUTED)
		UI.label(content, "GRANTS %d SPELL SLOT(S)" % grantor.spell_choices_granted, 14, UI.GOLD, true)
		for slot_index in range(grantor.spell_choices_granted):
			var selected_name := "Empty"
			if slot_index < host.draft.learned_spell_ids.size():
				var selected_training = host.catalog.find_ability(host.draft.learned_spell_ids[slot_index])
				if selected_training != null and not selected_training.granted_skills.is_empty():
					selected_name = selected_training.granted_skills[0].display_name
			UI.label(content, "SPELL SLOT %d    ·    %s" % [slot_index + 1, selected_name], 16, UI.GOLD)
		UI.line(content)
		UI.label(content, "CHOOSE A SPELL", 14, UI.GOLD, true)
		for training in choices:
			if not host.draft.spell_training_matches_grantor(training, grantor):
				continue
			var skill = training.granted_skills[0]
			var learned: bool = host.draft.learned_spell_ids.has(training.id)
			var range_feet: float = skill.targeting_range_feet if skill.targeting_range_feet > 0.0 else (skill.attack_data.range_feet if skill.attack_data != null else 0.0)
			var spell_button := UI.button(content, "%s%s · Lv.%d\n%d AP · %d Mana · %.0f ft · CD %d" % ["✓ " if learned else "", skill.display_name, skill.spell_level, skill.ap_cost, skill.mana_cost, range_feet, skill.cooldown_turns], func():
				host.draft.toggle_spell(training)
				host.refresh(), learned)
			var reason: String = host.draft.get_spell_learning_failure_reason(training)
			spell_button.disabled = not learned and not reason.is_empty()
			spell_button.tooltip_text = skill.description if reason.is_empty() or learned else reason
	UI.label(host.center, "%d / %d Spell Slot(s) remain. Ability Points are not used." % [host.draft.get_spell_choices_remaining(), host.draft.get_spell_choice_capacity()], 15, UI.GOLD)

func matches_filter(host, ability: AbilityData) -> bool:
	if not host.ability_search.is_empty() and not ability.display_name.to_lower().contains(host.ability_search.to_lower()):
		return false
	var tags: Array[String] = []
	for entry in ability.traits:
		tags.append(entry.id)
	match host.ability_filter:
		1: return tags.has("basic")
		2: return host.draft.character_class != null and tags.has(host.draft.character_class.id)
		3: return not ability.is_passive and not tags.has("reactive")
		4: return ability.is_passive or tags.has("passive")
		5: return tags.has("reactive")
		6: return host.draft.progression.can_learn_ability(host.draft.preview, ability)
	return true

func build_equipment(host) -> void:
	UI.label(host.left, "STARTING INVENTORY", 18, UI.GOLD, true)
	UI.label(host.left, "All items below belong to your starting kit. Equipping costs no AP here.", 14, UI.MUTED)
	for item in host.catalog.equipment:
		UI.card(host.left, item.display_name, ["Weapon", "Armor", "Shield"][item.slot], null, host.focused_item == item, func():
			host.focused_item = item
			host.refresh())
	UI.label(host.center, "EQUIPMENT", 32, UI.PAPER, true)
	for slot in [0, 3, 1]:
		var item = host.draft.equipment_slots.get(slot)
		var slot_name: String = {0: "HAND 1", 3: "HAND 2", 1: "ARMOR"}[slot]
		var row := HBoxContainer.new()
		host.center.add_child(row)
		UI.label(row, slot_name + "   ·   " + (item.display_name if item != null else "Empty"), 17, UI.GOLD)
		if item != null:
			var clear := UI.button(row, "Remove", func():
				host.draft.clear_slot(slot)
				host.refresh())
			clear.size_flags_horizontal = Control.SIZE_FILL
	UI.line(host.center)
	var item = host.focused_item
	if item == null and not host.catalog.equipment.is_empty():
		item = host.catalog.equipment[0]
	if item == null:
		return
	var selected_item = item
	UI.label(host.center, item.display_name, 26, UI.PAPER, true)
	UI.label(host.center, item.description, 16, UI.MUTED)
	if item.weapon_attack != null:
		var attack: AttackData = item.weapon_attack
		UI.label(host.center, "%s\nDamage %d · %.0f ft · %d AP" % [attack.display_name, attack.base_damage, attack.range_feet, attack.ap_cost], 17)
		UI.label(host.center, UI.traits_text(attack), 14, UI.GOLD)
		for ability in attack.granted_abilities:
			UI.label(host.center, "Grants: " + ability.display_name, 15, UI.MUTED)
	var two_handed: bool = host.draft.equipment_rules.is_two_handed(item)
	UI.label(host.center, "Two-Handed: occupies both hand slots." if two_handed else "Weapons and Shields share the two hand slots.", 15, UI.MUTED)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	host.center.add_child(row)
	if item.slot == EquipmentData.Slot.ARMOR:
		UI.button(row, "EQUIP ARMOR", func():
			host.draft.equip(selected_item, 1)
			host.refresh(), true)
	else:
		for slot in ([0] if two_handed else [0, 3]):
			UI.button(row, "EQUIP BOTH HANDS" if two_handed else ("EQUIP HAND 1" if slot == 0 else "EQUIP HAND 2"), func():
				host.draft.equip(selected_item, slot)
				host.refresh(), true)

func build_review(host) -> void:
	UI.label(host.left, "REVIEW YOUR CHARACTER", 19, UI.GOLD, true)
	UI.label(host.left, "You can edit any choice before entering the game.", 16, UI.MUTED)
	for index in range(host.catalog.steps.size() - 1):
		var step: Dictionary = host.catalog.steps[index]
		UI.button(host.left, "EDIT " + String(step.title), func(): host.show_step(index))
	UI.label(host.center, host.draft.character_name.to_upper(), 34, UI.PAPER, true)
	UI.label(host.center, "YOUR JOURNEY BEGINS", 17, UI.GOLD, true)
	var visual = host.catalog.visual_for(host.draft.portrait_id)
	if visual != null:
		UI.art(host.center, visual.artwork, 190)
	UI.label(host.center, "%s / %s · Level %d" % [host.draft.ancestry.display_name, host.draft.character_class.display_name, host.draft.level], 22, UI.PAPER, true)
	var reason: String = host.draft.validation_error()
	UI.label(host.center, "All required choices are complete." if reason.is_empty() else reason, 17, UI.GOLD)
	UI.label(host.center, "%d Ability Point(s) remain for later.\nStats on the right are calculated using the combat rules." % host.draft.preview.ability_points, 16, UI.MUTED)
	var names: PackedStringArray = []
	for item in host.draft.raw_character().starting_equipment:
		names.append(item.display_name)
	UI.label(host.center, "Starting equipment: " + (", ".join(names) if not names.is_empty() else "None"), 16)
