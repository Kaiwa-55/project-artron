extends SceneTree

const Catalog = preload("res://data/creation/default_creation_catalog.tres")
const Draft = preload("res://scenes/character_creation/creation_draft.gd")
const WizardScene = preload("res://scenes/character_creation/CharacterCreation.tscn")
var failures: Array[String] = []
var emitted: CharacterData

func _init() -> void:
	call_deferred("run_tests")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func complete_attributes(draft) -> void:
	draft.ancestry_choices.assign([0, 1, 2])
	draft.class_choices.assign([int(draft.character_class.attribute_choice_options[0])])
	draft.rebuild()

func run_tests() -> void:
	var draft = Draft.new()
	draft.setup(Catalog)
	check(draft.level == 1, "Normal creation starts at Level 1")
	check(not draft.validation_error().is_empty(), "Missing Attribute choices block confirmation")
	draft.character_name = "   "
	check(not draft.step_error("identity").is_empty(), "Whitespace names are rejected")
	draft.character_name = "Kael"
	complete_attributes(draft)
	check(draft.validation_error().is_empty(), "Completed ancestry/class choices are valid")
	var custom_image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	custom_image.fill(Color.CORNFLOWER_BLUE)
	var custom_portrait := ImageTexture.create_from_image(custom_image)
	draft.set_custom_portrait(custom_portrait, "C:/test/custom_portrait.png")
	check(draft.get_portrait_texture() == custom_portrait, "Identity accepts a custom portrait texture")
	draft.token_zoom = 1.5
	draft.token_offset = Vector2(12, -8)
	check(draft.get_token_texture() != custom_portrait and draft.get_token_texture().get_size() == Vector2(256, 256), "Identity builds a separate 1:1 Token texture")
	draft.ancestry_choices.assign([0, 0, 1])
	check(not draft.step_error("attributes").is_empty(), "Duplicate ancestry choices are rejected")
	complete_attributes(draft)
	var dex_before: int = draft.preview.dexterity
	draft.rebuild()
	draft.rebuild()
	check(draft.preview.dexterity == dex_before, "Preview rebuild never stacks Attribute bonuses")
	var step_back: AbilityData = Catalog.find_ability("step_back")
	var points_before: int = draft.preview.ability_points
	draft.toggle_ability(step_back)
	check(draft.learned_ids.has("step_back") and draft.preview.ability_points == points_before - step_back.ability_point_cost, "Learning uses central point rules")
	draft.toggle_ability(step_back)
	check(draft.preview.ability_points == points_before, "Removing selections refunds points")
	var precise_strike: AbilityData = Catalog.find_ability("precise_strike")
	draft.toggle_ability(precise_strike)
	check(draft.learned_ids.has("precise_strike"), "Level 1 Assassin can learn a class Ability")
	draft.toggle_ability(precise_strike)
	var shadow_step: AbilityData = Catalog.find_ability("shadow_step")
	draft.toggle_ability(shadow_step)
	check(not draft.learned_ids.has("shadow_step"), "Shadow Step remains locked before Level 3")
	var level_three_draft = Draft.new()
	level_three_draft.setup(Catalog)
	level_three_draft.set_level(3)
	level_three_draft.toggle_ability(shadow_step)
	check(level_three_draft.learned_ids.has("shadow_step"), "Level 3 Assassin can spend an Ability Point on Shadow Step")
	draft.toggle_ability(step_back)

	# Output contains raw inputs, not already-applied bonuses.
	var character: CharacterData = draft.finish()
	check(character != null and character.portrait == custom_portrait, "Valid output persists a custom portrait")
	check(character.token_texture != null and character.token_texture.get_size() == Vector2(256, 256), "Customized circular Token survives character creation")
	var state: CombatantState = character.create_combatant_state()
	var system := CombatSystem.new()
	system.start_combat([state])
	for key in ["max_hp", "max_mana", "max_ap", "speed", "strength", "dexterity", "constitution", "intelligence", "wisdom", "charisma", "reflex", "fortitude", "will", "ability_points"]:
		check(state.get(key) == draft.preview.get(key), "Preview matches actual Combat for " + key)
	check(state.equipped_abilities.has("step_back"), "Learned ability survives handoff")
	check(state.active_reactions.any(func(reaction): return reaction.id == "step_back"), "Learned Reaction is wired during combat initialization")

	var spear = load("res://data/equipment/long_spear.tres")
	var shield = load("res://data/equipment/buckler.tres")
	draft.equip(spear, 0)
	check(draft.equipment_slots.get(0) == spear and draft.equipment_slots.get(3) == spear, "Two-Handed occupies both slots")
	draft.equip(shield, 3)
	check(not draft.equipment_slots.has(0) and draft.equipment_slots.get(3) == shield, "Shield replaces a Two-Handed weapon correctly")
	character = draft.finish()
	state = character.create_combatant_state()
	system = CombatSystem.new()
	system.start_combat([state])
	check(state.equipped_items.get(3) == shield and not state.equipped_items.has(0), "Hand 2 assignment survives handoff")
	check(state.ap == state.max_ap, "Creation equipment costs no AP")

	# New catalog classes/abilities require no UI special cases.
	var custom_catalog = Catalog.duplicate()
	var extra_class := CharacterClassData.new()
	extra_class.id = "test_ranger"
	extra_class.display_name = "Test Ranger"
	custom_catalog.classes = Catalog.classes.duplicate()
	custom_catalog.classes.append(extra_class)
	var prerequisite := AbilityData.new()
	prerequisite.id = "test_assassin_prerequisite"
	prerequisite.display_name = "Test prerequisite"
	prerequisite.required_trait_ids = ["assassin"]
	var dependent := AbilityData.new()
	dependent.id = "test_dependent"
	dependent.display_name = "Test dependent"
	dependent.prerequisite_id = prerequisite.id
	custom_catalog.abilities = Catalog.abilities.duplicate()
	custom_catalog.abilities.append(prerequisite)
	custom_catalog.abilities.append(dependent)
	var custom = Draft.new()
	custom.setup(custom_catalog)
	custom.set_level(2)
	custom.toggle_ability(dependent)
	check(custom.learned_ids.is_empty(), "Central prerequisite validation rejects missing prerequisite")
	custom.toggle_ability(prerequisite)
	custom.toggle_ability(dependent)
	check(custom.learned_ids.size() == 2, "Prerequisite chain can be learned with sufficient points")
	custom.select_class(Catalog.classes[1])
	check(custom.learned_ids.is_empty() and custom.preview.ability_points == 2, "Class switch removes invalid chain and refunds its points")
	check(not custom.notice.is_empty() and custom.class_choices.is_empty(), "Context changes explain removed choices")
	custom.select_class(Catalog.classes[0])
	check(custom.preview.dexterity == 11, "Class switching never retains old bonuses")
	check(Catalog.base_character.level == 2 and Catalog.base_character.display_name == "Player", "Shared template is untouched")

	var wizard = WizardScene.instantiate()
	wizard.catalog = custom_catalog
	wizard.auto_start_combat = false
	root.add_child(wizard)
	await process_frame
	check(wizard.step_buttons.size() == 7 and wizard.step_index == 0, "New wizard creates seven steps")
	wizard.show_step(2)
	var class_cards: Array = wizard.left.get_children().filter(func(node): return node is Button)
	check(class_cards.size() == Catalog.classes.size() + 1, "New catalog class appears without a renderer change")
	class_cards[class_cards.size() - 1].pressed.emit()
	check(wizard.draft.character_class == extra_class, "Catalog class card is clickable without special cases")
	wizard.draft.select_class(Catalog.classes[0])
	wizard.show_step(0)
	await process_frame
	var identity_portrait: TextureRect = wizard.center.find_child("PortraitArt", true, false)
	check(identity_portrait != null and identity_portrait.custom_minimum_size == Vector2(225, 225), "Identity portrait uses a 1:1 frame")
	wizard.character_created.connect(func(data): emitted = data)
	wizard.draft.character_name = ""
	wizard.draft.rebuild()
	wizard.refresh_navigation()
	check(wizard.next_button.disabled, "Next is disabled for missing name")
	wizard.draft.character_name = "Kael"
	wizard.draft.rebuild()
	complete_attributes(wizard.draft)
	wizard.furthest_step = 6
	for index in range(7):
		wizard.show_step(index)
		await process_frame
		check(wizard.center.get_child_count() > 0, "Page renders: " + str(index))
	for filter_index in range(7):
		wizard.ability_filter = filter_index
		wizard.show_step(4)
	wizard.show_step(6)
	wizard.confirm_character()
	check(emitted != null and emitted.display_name == "Kael", "Embedded scene returns CharacterData without changing scenes")
	wizard.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("CHARACTER_CREATION_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
