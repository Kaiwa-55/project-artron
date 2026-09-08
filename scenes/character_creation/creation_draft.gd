extends RefCounted
## Rebuild from immutable inputs. Never apply Class or Ancestry twice to a preview.
const AncestryRules = preload("res://combat/ancestry/ancestry_system.gd")
const ClassRules = preload("res://combat/class/class_system.gd")
const ProgressionRules = preload("res://combat/progression/progression_system.gd")
const EquipmentRules = preload("res://combat/equipment/equipment_system.gd")
const Stats = preload("res://combat/stat/stat_system.gd")
const TokenBuilder = preload("res://scenes/character_creation/token_image_builder.gd")

var catalog
var character_name: String = "Kael"
var portrait_id: String = ""
var custom_portrait: Texture2D
var custom_portrait_path: String = ""
var token_zoom: float = 1.0
var token_offset: Vector2 = Vector2.ZERO
var ancestry
var character_class
var level: int = 1
var ancestry_choices: Array[int] = []
var class_choices: Array[int] = []
var learned_ids: Array[String] = []
var learned_spell_ids: Array[String] = []
var equipment_slots: Dictionary = {}
var preview: CombatantState
var notice: String = ""
var progression = ProgressionRules.new()
var equipment_rules = EquipmentRules.new()

func setup(source_catalog) -> void:
	catalog = source_catalog
	ancestry = catalog.ancestries[0] if not catalog.ancestries.is_empty() else null
	character_class = catalog.classes[0] if not catalog.classes.is_empty() else null
	# Portrait presets are class presentation only. A created character uses an
	# image explicitly chosen from the computer.
	portrait_id = ""
	var initial: CombatantState = catalog.base_character.create_combatant_state()
	equipment_rules.initialize_combatant(initial)
	equipment_slots = initial.equipped_items.duplicate()
	rebuild()

func select_ancestry(value) -> void:
	if ancestry == value:
		return
	ancestry = value
	ancestry_choices.clear()
	notice = "Ancestry changed. Choose its Attributes again."
	rebuild()

func select_class(value) -> void:
	if character_class == value:
		return
	character_class = value
	class_choices.clear()
	learned_spell_ids.clear()
	notice = "Class changed. Choose its Attributes again."
	rebuild()

func set_level(value: int) -> void:
	level = clampi(value, 1, progression.progression_data.max_level)
	rebuild()

func select_catalog_portrait(source_id: String) -> void:
	portrait_id = source_id
	custom_portrait = null
	custom_portrait_path = ""
	rebuild()

func set_custom_portrait(texture: Texture2D, source_path: String = "") -> void:
	custom_portrait = texture
	custom_portrait_path = source_path
	if texture != null:
		portrait_id = "__custom__"
	rebuild()

func get_portrait_texture() -> Texture2D:
	if custom_portrait != null:
		return custom_portrait
	var visual = catalog.visual_for(portrait_id)
	return visual.artwork if visual != null else null

func get_token_texture() -> Texture2D:
	return TokenBuilder.build(get_portrait_texture(), token_zoom, token_offset)

func reset_token_customization() -> void:
	token_zoom = 1.0
	token_offset = Vector2.ZERO

func raw_character() -> CharacterData:
	var result: CharacterData = catalog.base_character.duplicate()
	result.display_name = character_name.strip_edges()
	result.ancestry = ancestry
	result.character_class = character_class
	result.level = level
	result.experience = 0
	result.ancestry_attribute_choices = ancestry_choices.duplicate()
	result.class_attribute_choices = class_choices.duplicate()
	if result.has_meta("selected_class_attribute_choices"):
		result.remove_meta("selected_class_attribute_choices")
	result.available_abilities = []
	result.skills = []
	result.equipped_abilities = []
	result.selected_ability_ids = []
	result.granted_ability_ids = []
	result.selected_level_attributes = []
	result.pending_level_up_choices = []
	result.ability_points = 0
	result.attribute_points = 0
	result.progression_rewards_granted_through_level = 0
	result.selected_ability_costs_applied = false
	result.equipped_weapon_attack = null
	result.starting_equipment = []
	result.starting_equipment_slots = {}
	result.equipment_inventory = catalog.equipment.duplicate()
	for slot in [0, 3, 1]:
		var item = equipment_slots.get(slot)
		if item != null and not result.starting_equipment.has(item):
			result.starting_equipment.append(item)
			result.starting_equipment_slots[item.id] = slot
	result.portrait = get_portrait_texture()
	result.token_texture = get_token_texture()
	result.token_scale = 1.0
	result.token_offset = Vector2.ZERO
	return result

func rebuild() -> void:
	preview = raw_character().create_combatant_state()
	AncestryRules.new().apply_ancestry(preview)
	ClassRules.new().apply_class(preview)
	progression.initialize_character(preview)
	equipment_rules.initialize_combatant(preview)
	equipment_rules.refresh_equipment(preview)
	var retained: Array[String] = []
	var removed: PackedStringArray = []
	for ability_id in learned_ids:
		var ability = catalog.find_ability(ability_id)
		if ability != null and progression.learn_ability(preview, ability).success:
			retained.append(ability_id)
		else:
			removed.append(ability.display_name if ability != null else ability_id)
	learned_ids = retained
	if not removed.is_empty():
		notice = "Selections removed and points refunded: " + ", ".join(removed)
	_rebuild_spell_choices()
	Stats.new().initialize_combatant(preview)


func get_spell_choice_capacity() -> int:
	var capacity := 0
	if preview == null:
		return capacity
	for ability in preview.available_abilities:
		if ability != null and (preview.granted_ability_ids.has(ability.id) or preview.selected_ability_ids.has(ability.id)):
			capacity += ability.spell_choices_granted
	return capacity


func get_spell_choices_remaining() -> int:
	return maxi(0, get_spell_choice_capacity() - learned_spell_ids.size())


func get_spell_learning_failure_reason(training: AbilityData) -> String:
	if training == null or training.granted_skills.is_empty():
		return "Spell Training is invalid."
	if character_class == null or not training.required_trait_ids.has(character_class.id):
		return "This spell is not available to the selected class."
	if level < training.required_level:
		return "%s requires Level %d." % [training.granted_skills[0].display_name, training.required_level]
	if learned_spell_ids.has(training.id):
		return "%s is already learned." % training.granted_skills[0].display_name
	if get_spell_choices_remaining() <= 0:
		return "No Spell Choices remain."
	return ""


func toggle_spell(training: AbilityData) -> void:
	notice = ""
	if learned_spell_ids.has(training.id):
		learned_spell_ids.erase(training.id)
	else:
		var reason := get_spell_learning_failure_reason(training)
		if not reason.is_empty():
			notice = reason
			return
		learned_spell_ids.append(training.id)
	rebuild()


func _rebuild_spell_choices() -> void:
	var retained: Array[String] = []
	var capacity := get_spell_choice_capacity()
	for training_id in learned_spell_ids:
		if retained.size() >= capacity:
			break
		var training: AbilityData = catalog.find_ability(training_id)
		if training == null or training.granted_skills.is_empty() or level < training.required_level:
			continue
		if character_class == null or not training.required_trait_ids.has(character_class.id):
			continue
		retained.append(training_id)
		for skill in training.granted_skills:
			if skill != null and not preview.available_skills.has(skill):
				preview.available_skills.append(skill)
	learned_spell_ids = retained

func toggle_ability(ability: AbilityData) -> void:
	notice = ""
	if learned_ids.has(ability.id):
		learned_ids.erase(ability.id)
	else:
		var reason: String = progression.get_learn_ability_failure_reason(preview, ability)
		if not reason.is_empty():
			notice = reason
			return
		learned_ids.append(ability.id)
	rebuild()

func choose_attribute(kind: String, index: int, attribute: int) -> void:
	var choices: Array[int] = ancestry_choices if kind == "ancestry" else class_choices
	while choices.size() <= index:
		choices.append(-1)
	choices[index] = attribute
	rebuild()

func equip(item, slot: int) -> void:
	notice = ""
	if not catalog.equipment.has(item):
		notice = "This item is not in the starting inventory."
		return
	var temporary := CombatantState.new()
	temporary.equipped_items = equipment_slots.duplicate()
	if item.slot == EquipmentData.Slot.ARMOR:
		temporary.equipped_items[EquipmentData.Slot.ARMOR] = item
	else:
		equipment_rules.remove_hand_item_from_all_slots(temporary, item)
		equipment_rules.equip_hand_item_without_cost(temporary, item, slot)
	equipment_slots = temporary.equipped_items.duplicate()
	rebuild()

func clear_slot(slot: int) -> void:
	var item = equipment_slots.get(slot)
	if item != null and equipment_rules.is_two_handed(item):
		equipment_slots.erase(0)
		equipment_slots.erase(3)
	else:
		equipment_slots.erase(slot)
	rebuild()

func choice_error(choices: Array[int], count: int, options: Array) -> String:
	if choices.size() != count:
		return "Choose all %d Attributes." % count
	var seen: Dictionary = {}
	for value in choices:
		if not options.has(value):
			return "Choose a valid Attribute in every field."
		if seen.has(value):
			return "Each choice from the same source must be different."
		seen[value] = true
	return ""

func step_error(step_id: String) -> String:
	match step_id:
		"identity":
			if character_name.strip_edges().is_empty():
				return "Enter a character name."
		"ancestry":
			if ancestry == null:
				return "Choose an Ancestry."
		"class":
			if character_class == null:
				return "Choose a Class."
		"attributes":
			if ancestry == null or character_class == null:
				return "Choose an Ancestry and Class first."
			var reason := choice_error(ancestry_choices, ancestry.attribute_choice_count, [0, 1, 2, 3, 4, 5])
			if not reason.is_empty():
				return ancestry.display_name + ": " + reason
			reason = choice_error(class_choices, character_class.attribute_choice_count, character_class.attribute_choice_options)
			if not reason.is_empty():
				return character_class.display_name + ": " + reason
		"spells":
			if get_spell_choices_remaining() > 0:
				return "Choose %d more Spell(s)." % get_spell_choices_remaining()
	return ""

func validation_error() -> String:
	for step in catalog.steps:
		var reason := step_error(step.id)
		if not reason.is_empty():
			return reason
	return ""

func finish() -> CharacterData:
	rebuild()
	if not validation_error().is_empty():
		return null
	var result := raw_character()
	for ability_id in learned_ids:
		result.available_abilities.append(catalog.find_ability(ability_id))
		result.equipped_abilities.append(ability_id)
		result.selected_ability_ids.append(ability_id)
	for training_id in learned_spell_ids:
		var training: AbilityData = catalog.find_ability(training_id)
		if training == null:
			continue
		for skill in training.granted_skills:
			if skill != null and not result.skills.has(skill):
				result.skills.append(skill)
	return result
