extends Control

const NODE_SIZE := Vector2(40, 40)
const FLOOR_SPACING := 78.0
const LANE_SPACING := 50.0
const ENCOUNTER_CATALOG := preload("res://data/run/prototype_encounter_catalog.tres")
const COMBAT_SCENE := "res://scenes/prototype/PrototypeCombat.tscn"
const PLAYER_DATA := preload("res://data/character/player.tres")
const DEFAULT_PARTY_ENCOUNTER := preload("res://data/encounter/prototype_encounter.tres")

@onready var map_canvas: Control = $Margin/Layout/MapPanel/MapScroll/MapCanvas
@onready var seed_input: LineEdit = $Margin/Layout/Header/SeedInput
@onready var seed_label: Label = $Margin/Layout/Header/SeedLabel
@onready var location_label: Label = $Margin/Layout/Footer/LocationLabel
@onready var continue_button: Button = $Margin/Layout/Footer/ContinueButton
@onready var level_up_button: Button = $Margin/Layout/Header/LevelUpButton
@onready var level_up_panel: LevelUpPanel = $LevelUpPanel
@onready var party_inventory: HBoxContainer = $Margin/Layout/Footer/PartyInventory
@onready var character_panel: CharacterPanel = $CharacterPanel
@onready var event_panel: EventPanel = $EventPanel
@onready var rest_panel: Control = $RestPanel
@onready var shop_panel: Control = $ShopPanel

var run_state: RunState
var node_buttons: Dictionary = {}
var selected_node_id: String = ""
var reset_party_to_level_one_on_start: bool = false
var event_manager: EventManager
var encounter_manager: EncounterManager
var pending_encounter_from_event: bool = false

const REST_RECOVERY_RATIO := 0.5


func _ready() -> void:
	$Margin/Layout/Header/NewRunButton.pressed.connect(start_from_input)
	continue_button.pressed.connect(confirm_selected_node)
	level_up_button.pressed.connect(open_level_up)
	level_up_panel.choices_committed.connect(on_level_up_committed)
	rest_panel.action_selected.connect(resolve_rest_action)
	rest_panel.rest_completed.connect(finish_rest)
	shop_panel.purchase_requested.connect(purchase_shop_item)
	shop_panel.shop_closed.connect(finish_shop)
	if not character_panel.equipment_change_requested.is_connected(on_run_map_equipment_change):
		character_panel.equipment_change_requested.connect(on_run_map_equipment_change)
	if get_tree().has_meta("restart_run_seed"):
		var restart_seed := int(get_tree().get_meta("restart_run_seed"))
		get_tree().remove_meta("restart_run_seed")
		get_tree().remove_meta("restart_run_at_level_one")
		start_run(restart_seed, true)
	elif get_tree().has_meta("active_run_state"):
		run_state = get_tree().get_meta("active_run_state") as RunState
		seed_input.text = str(run_state.seed)
		seed_label.text = "RUN SEED  %d" % run_state.seed
		build_map()
		refresh_map_state()
	else:
		start_run(int(Time.get_unix_time_from_system()))
	ensure_player_progression_state()
	setup_event_flow()
	refresh_level_up_button()
	build_party_inventory_buttons()


func start_from_input() -> void:
	var requested_seed := seed_input.text.strip_edges()
	start_run(int(requested_seed) if requested_seed.is_valid_int() else int(Time.get_unix_time_from_system()))


func start_run(seed_value: int, reset_party_to_level_one: bool = false) -> void:
	reset_party_to_level_one_on_start = reset_party_to_level_one
	run_state = RunState.new()
	# Keep the generator instance separate. Chaining new().generate() can make
	# Godot's external-class resolver report generate as missing after a rescan.
	var generator: RunGenerator = RunGenerator.new()
	var generated_nodes: Array[MapNodeData] = generator.generate(seed_value, RunGenerator.DEFAULT_FLOORS, ENCOUNTER_CATALOG)
	run_state.setup(seed_value, generated_nodes)
	if get_tree().has_meta("active_party_characters"):
		run_state.party_character_data.assign(get_tree().get_meta("active_party_characters"))
		run_state.gold = 0
		for member in run_state.party_character_data:
			if member != null:
				run_state.gold += maxi(0, member.creation_gold)
	get_tree().set_meta("active_run_state", run_state)
	get_tree().remove_meta("active_run_node_id")
	get_tree().remove_meta("active_encounter_data")
	get_tree().remove_meta("active_event_encounter")
	get_tree().remove_meta("active_event_encounter_data")
	get_tree().remove_meta("pending_event_encounter_result")
	if event_manager != null:
		encounter_manager.active_encounter = null
		event_manager.active_event = null
		event_manager.configure(run_state.game_state, encounter_manager)
		event_panel.close()
	seed_input.text = str(seed_value)
	seed_label.text = "RUN SEED  %d" % seed_value
	selected_node_id = ""
	build_map()
	refresh_map_state()
	ensure_player_progression_state()
	refresh_level_up_button()
	build_party_inventory_buttons()
	reset_party_to_level_one_on_start = false


func ensure_player_progression_state() -> void:
	var entries := get_party_entries()
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var member_id := String(entry.get("id", "player" if index == 0 else "ally_%d" % index))
		if not run_state.party_progression_states.has(member_id):
			var source = entry.get("character", PLAYER_DATA)
			if bool(entry.get("use_created_character", false)):
				source = get_tree().get_meta("created_character_data", source)
			var state: CombatantState = source.create_combatant_state()
			if reset_party_to_level_one_on_start:
				prepare_level_one_restart_state(state)
			state.id = member_id
			state.display_name = String(entry.get("display_name", state.display_name))
			run_state.party_progression_states[member_id] = state
		var member: CombatantState = run_state.party_progression_states[member_id]
		if not member.has_meta("creation_rules_applied"):
			AncestrySystem.new().apply_ancestry(member)
			CharacterClassSystem.new().apply_class(member)
			ProgressionSystem.new().initialize_character(member)
			EquipmentSystem.new().initialize_combatant(member)
			EquipmentSystem.new().refresh_equipment(member)
			# A new Run starts with its party fully recovered after all derived stats
			# from Ancestry, Class, Progression, and Equipment have been applied.
			StatSystem.new().initialize_combatant(member)
			member.set_meta("creation_rules_applied", true)
		var applied := int(run_state.applied_party_ability_point_bonuses.get(member_id, 0))
		var unapplied := run_state.party_ability_point_bonus - applied
		if unapplied > 0:
			member.ability_points += unapplied
			run_state.applied_party_ability_point_bonuses[member_id] = applied + unapplied
	run_state.player_progression_state = run_state.party_progression_states.get("player")
	run_state.applied_party_ability_point_bonus = int(run_state.applied_party_ability_point_bonuses.get("player", 0))


func prepare_level_one_restart_state(state: CombatantState) -> void:
	state.level = 1
	state.experience = 0
	state.ability_points = 0
	state.attribute_points = 0
	state.progression_rewards_granted_through_level = 0
	state.pending_level_up_choices.clear()
	state.selected_level_attributes.clear()
	state.selected_ability_costs_applied = false
	var catalog = load("res://data/creation/default_creation_catalog.tres")
	var retained_selected: Array[String] = []
	for ability_id in state.selected_ability_ids:
		var ability = catalog.find_ability(ability_id)
		if ability != null and ability.required_level <= 1:
			retained_selected.append(ability_id)
	state.selected_ability_ids = retained_selected
	state.granted_ability_ids.clear()
	state.available_abilities = state.available_abilities.filter(func(ability): return ability != null and retained_selected.has(ability.id))
	state.equipped_abilities = state.equipped_abilities.filter(func(ability_id): return retained_selected.has(ability_id))


func get_party_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not run_state.party_character_data.is_empty():
		for index in range(run_state.party_character_data.size()):
			entries.append({"character": run_state.party_character_data[index], "id": "player" if index == 0 else "ally_%d" % index, "display_name": run_state.party_character_data[index].display_name, "use_created_character": false})
		return entries
	return DEFAULT_PARTY_ENCOUNTER.player_party.duplicate(true)


func open_level_up() -> void:
	ensure_player_progression_state()
	var members: Array[CombatantState] = []
	for entry in get_party_entries():
		var member: CombatantState = run_state.party_progression_states.get(String(entry.get("id", "")))
		if member != null:
			members.append(member)
	level_up_panel.open_for_party(members, "player")


func build_party_inventory_buttons() -> void:
	for child in party_inventory.get_children():
		child.queue_free()
	for entry in get_party_entries():
		var member_id := String(entry.get("id", ""))
		var member: CombatantState = run_state.party_progression_states.get(member_id)
		if member == null:
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(72, 32)
		button.icon = member.token_texture
		button.expand_icon = true
		button.add_theme_font_size_override("font_size", 7)
		button.text = "%s\nINV" % member.display_name
		button.tooltip_text = "Open %s's Inventory" % member.display_name
		button.pressed.connect(open_party_inventory.bind(member_id))
		party_inventory.add_child(button)


func open_party_inventory(member_id: String) -> void:
	var member: CombatantState = run_state.party_progression_states.get(member_id)
	if member == null:
		return
	level_up_panel.hide()
	character_panel.setup_standalone(member, "inventory", true)
	character_panel.show()


func on_run_map_equipment_change(item, slot: int) -> void:
	var member: CombatantState = character_panel.standalone_character
	if member == null:
		return
	var result := EquipmentSystem.new().toggle_equipment_without_cost(member, item, slot)
	location_label.text = "Equipment updated: %s" % item.display_name if result.success else "Equipment failed: %s" % result.failure_reason
	character_panel.refresh()


func on_level_up_committed() -> void:
	refresh_level_up_button()
	location_label.text = "Progression choices saved for the next Combat."


func refresh_level_up_button() -> void:
	var count := 0
	for state in run_state.party_progression_states.values():
		if state != null:
			count += state.ability_points + state.attribute_points
	level_up_button.text = "LEVEL UP (%d)" % count if count > 0 else "PROGRESSION"


func build_map() -> void:
	for child in map_canvas.get_children():
		child.queue_free()
	node_buttons.clear()
	var grouped: Dictionary = {}
	var max_floor := 0
	var max_lanes := 1
	for node in run_state.nodes:
		if not grouped.has(node.floor_index):
			grouped[node.floor_index] = []
		grouped[node.floor_index].append(node)
		max_floor = maxi(max_floor, node.floor_index)
		max_lanes = maxi(max_lanes, grouped[node.floor_index].size())
	var canvas_height := maxf(
		252.0,
		float(max_lanes - 1) * LANE_SPACING + NODE_SIZE.y + 24.0
	)
	map_canvas.custom_minimum_size = Vector2(
		40.0 + float(max_floor) * FLOOR_SPACING + NODE_SIZE.x + 24.0,
		canvas_height
	)
	var positions: Dictionary = {}
	for floor_index in grouped:
		var floor_nodes: Array = grouped[floor_index]
		for lane_index in range(floor_nodes.size()):
			positions[floor_nodes[lane_index].id] = Vector2(
				24.0 + float(floor_index) * FLOOR_SPACING,
				canvas_height * 0.5 + (float(lane_index) - float(floor_nodes.size() - 1) * 0.5) * LANE_SPACING - NODE_SIZE.y * 0.5
			)
	for node in run_state.nodes:
		for next_id in node.next_node_ids:
			var line := Line2D.new()
			line.width = 1.5
			line.default_color = Color("34465f")
			line.points = PackedVector2Array([positions[node.id] + NODE_SIZE * 0.5, positions[next_id] + NODE_SIZE * 0.5])
			map_canvas.add_child(line)
	for node in run_state.nodes:
		var button := Button.new()
		button.name = node.id
		button.position = positions[node.id]
		button.size = NODE_SIZE
		button.text = "%s\n%s" % [node.get_short_label(), node.get_display_name()]
		button.add_theme_font_size_override("font_size", 7)
		button.tooltip_text = "%s • Threat %d" % [node.get_display_name(), node.threat]
		button.pressed.connect(select_node.bind(node.id))
		map_canvas.add_child(button)
		node_buttons[node.id] = button


func select_node(node_id: String) -> void:
	if not run_state.can_enter(node_id):
		return
	selected_node_id = node_id
	var node := run_state.get_node(node_id)
	location_label.text = "Selected: %s  •  Threat %d" % [node.get_display_name(), node.threat]
	continue_button.disabled = false
	refresh_map_state()


func confirm_selected_node() -> void:
	if selected_node_id.is_empty() or not run_state.enter_node(selected_node_id):
		return
	var node := run_state.get_current_node()
	selected_node_id = ""
	continue_button.disabled = true
	refresh_map_state()
	if start_node_event(node):
		return
	if node.node_type == MapNodeData.NodeType.REST:
		open_rest(node)
		return
	if node.node_type == MapNodeData.NodeType.SHOP:
		open_shop(node)
		return
	if node.encounter_data != null:
		present_encounter(node.encounter_data, false)
		return
	get_tree().remove_meta("active_run_node_id")
	get_tree().remove_meta("active_encounter_data")
	location_label.text = "Entered %s — this Node does not start Combat." % node.get_display_name()


func open_rest(_node: MapNodeData) -> void:
	var party: Array[CombatantState] = []
	for member in run_state.party_progression_states.values():
		if member is CombatantState:
			party.append(member)
	rest_panel.open_for_party(party)


func resolve_rest_action(actor_id: String, action_id: String) -> void:
	var member: CombatantState = run_state.party_progression_states.get(actor_id)
	if member == null:
		return
	match action_id:
		"wounds":
			member.hp = mini(member.max_hp, member.hp + maxi(1, ceili(member.max_hp * REST_RECOVERY_RATIO)))
		"focus":
			member.mana = mini(member.max_mana, member.mana + maxi(1, ceili(member.max_mana * REST_RECOVERY_RATIO)))
		"training":
			member.ability_points += 1


func finish_rest() -> void:
	location_label.text = "Camp complete: each party member chose their own recovery."
	build_party_inventory_buttons()
	refresh_level_up_button()


func open_shop(_node: MapNodeData) -> void:
	var party: Array[CombatantState] = []
	for member in run_state.party_progression_states.values():
		if member is CombatantState:
			party.append(member)
	shop_panel.open_for_party(party, run_state.gold, _node.shop_data if _node != null else null)


func purchase_shop_item(actor_id: String, product: Resource, quantity: int, price: int) -> void:
	var member: CombatantState = run_state.party_progression_states.get(actor_id)
	if member == null or product == null or quantity <= 0 or price < 0 or run_state.gold < price:
		return
	run_state.gold -= price
	if product is ItemData:
		add_run_item(member, product, quantity)
	elif product is EquipmentData:
		for index in range(quantity):
			member.equipment_inventory.append(product.duplicate(true))
	else:
		run_state.gold += price
		return
	shop_panel.refresh_gold(run_state.gold)
	location_label.text = "%s bought %d %s." % [member.display_name, quantity, product.get("display_name")]


func add_run_item(member: CombatantState, item: ItemData, quantity: int) -> void:
	var remaining := quantity
	for stack in member.item_inventory:
		if stack != null and stack.item == item and stack.quantity < item.maximum_stack_size:
			var added := mini(remaining, item.maximum_stack_size - stack.quantity)
			stack.quantity += added
			remaining -= added
			if remaining <= 0:
				return
	while remaining > 0:
		var added := mini(remaining, item.maximum_stack_size)
		member.item_inventory.append(ItemStack.new(item, added))
		remaining -= added


func finish_shop() -> void:
	location_label.text = "Left the Shop with %d Gold." % run_state.gold
	build_party_inventory_buttons()

func start_node_event(node: MapNodeData) -> bool:
	if node == null:
		return false
	if node.event_data != null:
		event_manager.start_event(node.event_data, get_event_context())
		return true
	if node.event_table == null:
		return false
	var context := get_event_context()
	var selected_entry := node.event_table.pick_entry(context)
	if selected_entry == null:
		location_label.text = "Entered Event — no eligible Event was found."
		return true
	var selected_event: EventData = selected_entry.event
	var node_event := selected_event.duplicate(true) as EventData
	node_event.id = StringName("%s_%s" % [selected_event.id, node.id])
	node.event_data = node_event
	if selected_entry.remove_after_victory:
		node.removable_event_table_entry_key = node.event_table.get_entry_key(selected_entry)
	event_manager.start_event(node_event, context, true)
	return true


func setup_event_flow() -> void:
	encounter_manager = EncounterManager.new()
	encounter_manager.name = "EncounterManager"
	add_child(encounter_manager)
	event_manager = EventManager.new()
	event_manager.name = "EventManager"
	add_child(event_manager)
	event_manager.configure(run_state.game_state, encounter_manager)
	encounter_manager.combat_requested.connect(_on_event_encounter_requested)
	event_panel.encounter_confirmed.connect(start_presented_encounter)
	event_panel.setup(event_manager)
	resume_event_encounter_result()


func get_event_context() -> EventContext:
	var party: Array[CombatantState] = []
	for member in run_state.party_progression_states.values():
		if member is CombatantState:
			party.append(member)
	var context := EventContext.new(run_state.game_state, party)
	context.actor_id = "player"
	context.rng.seed = run_state.seed ^ run_state.current_node_id.hash()
	return context


func _on_event_encounter_requested(data: EncounterData) -> void:
	present_encounter(data, true)


func present_encounter(data: EncounterData, from_event: bool = false) -> void:
	pending_encounter_from_event = from_event
	event_panel.show_encounter(data)


func start_presented_encounter(data: EncounterData) -> void:
	get_tree().set_meta("active_run_state", run_state)
	get_tree().set_meta("active_run_node_id", run_state.current_node_id)
	get_tree().set_meta("active_encounter_data", data)
	if pending_encounter_from_event:
		get_tree().set_meta("active_event_encounter", true)
		get_tree().set_meta("active_event_encounter_data", data)
	else:
		get_tree().remove_meta("active_event_encounter")
		get_tree().remove_meta("active_event_encounter_data")
	var change_error := get_tree().change_scene_to_file(COMBAT_SCENE)
	if change_error != OK:
		location_label.text = "Could not open Encounter: %s" % error_string(change_error)


func resume_event_encounter_result() -> void:
	if not get_tree().has_meta("pending_event_encounter_result") or not get_tree().has_meta("active_event_encounter_data"):
		return
	var data := get_tree().get_meta("active_event_encounter_data") as EncounterData
	var result_type: EncounterResult.Type = int(get_tree().get_meta("pending_event_encounter_result")) as EncounterResult.Type
	get_tree().remove_meta("pending_event_encounter_result")
	get_tree().remove_meta("active_event_encounter")
	get_tree().remove_meta("active_event_encounter_data")
	get_tree().remove_meta("active_encounter_data")
	if result_type == EncounterResult.Type.VICTORY:
		var current_node := run_state.get_current_node()
		if current_node != null and not current_node.removable_event_table_entry_key.is_empty():
			run_state.game_state.remove_event_table_entry(current_node.removable_event_table_entry_key)
	if data != null and encounter_manager.resume_encounter(data, get_event_context()):
		encounter_manager.finish_encounter(EncounterResult.new(result_type))


func refresh_map_state() -> void:
	var available := run_state.get_available_node_ids()
	for node_id in node_buttons:
		var button: Button = node_buttons[node_id]
		button.disabled = not available.has(node_id)
		button.modulate = get_node_color(run_state.get_node(node_id), available.has(node_id), node_id == selected_node_id)
	var current := run_state.get_current_node()
	if selected_node_id.is_empty():
		location_label.text = "Current: %s  •  Choose a connected route" % current.get_display_name()
	continue_button.disabled = selected_node_id.is_empty()


func get_node_color(node: MapNodeData, available: bool, selected: bool) -> Color:
	if selected:
		return Color("f2c45e")
	if node.id == run_state.current_node_id:
		return Color("67d5b5")
	if run_state.is_completed(node.id):
		return Color("5f6878")
	if available:
		return Color.WHITE
	return Color("596171")
