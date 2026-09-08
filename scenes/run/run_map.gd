extends Control

const NODE_SIZE := Vector2(74, 74)
const FLOOR_SPACING := 122.0
const LANE_SPACING := 130.0
const ENCOUNTER_CATALOG := preload("res://data/run/prototype_encounter_catalog.tres")
const COMBAT_SCENE := "res://scenes/prototype/PrototypeCombat.tscn"
const PLAYER_DATA := preload("res://data/character/player.tres")
const DEFAULT_PARTY_ENCOUNTER := preload("res://data/encounter/prototype_encounter.tres")

@onready var map_canvas: Control = $Margin/Layout/MapPanel/MapCanvas
@onready var seed_input: LineEdit = $Margin/Layout/Header/SeedInput
@onready var seed_label: Label = $Margin/Layout/Header/SeedLabel
@onready var location_label: Label = $Margin/Layout/Footer/LocationLabel
@onready var continue_button: Button = $Margin/Layout/Footer/ContinueButton
@onready var level_up_button: Button = $Margin/Layout/Header/LevelUpButton
@onready var level_up_panel: LevelUpPanel = $LevelUpPanel
@onready var party_inventory: HBoxContainer = $Margin/Layout/Footer/PartyInventory
@onready var character_panel: CharacterPanel = $CharacterPanel

var run_state: RunState
var node_buttons: Dictionary = {}
var selected_node_id: String = ""


func _ready() -> void:
	$Margin/Layout/Header/NewRunButton.pressed.connect(start_from_input)
	continue_button.pressed.connect(confirm_selected_node)
	level_up_button.pressed.connect(open_level_up)
	level_up_panel.choices_committed.connect(on_level_up_committed)
	if get_tree().has_meta("active_run_state"):
		run_state = get_tree().get_meta("active_run_state") as RunState
		seed_input.text = str(run_state.seed)
		seed_label.text = "RUN SEED  %d" % run_state.seed
		build_map()
		refresh_map_state()
	else:
		start_run(int(Time.get_unix_time_from_system()))
	ensure_player_progression_state()
	refresh_level_up_button()
	build_party_inventory_buttons()


func start_from_input() -> void:
	var requested_seed := seed_input.text.strip_edges()
	start_run(int(requested_seed) if requested_seed.is_valid_int() else int(Time.get_unix_time_from_system()))


func start_run(seed_value: int) -> void:
	run_state = RunState.new()
	# Keep the generator instance separate. Chaining new().generate() can make
	# Godot's external-class resolver report generate as missing after a rescan.
	var generator: RunGenerator = RunGenerator.new()
	var generated_nodes: Array[MapNodeData] = generator.generate(seed_value, RunGenerator.DEFAULT_FLOORS, ENCOUNTER_CATALOG)
	run_state.setup(seed_value, generated_nodes)
	if get_tree().has_meta("active_party_characters"):
		run_state.party_character_data.assign(get_tree().get_meta("active_party_characters"))
	get_tree().set_meta("active_run_state", run_state)
	get_tree().remove_meta("active_run_node_id")
	get_tree().remove_meta("active_encounter_data")
	seed_input.text = str(seed_value)
	seed_label.text = "RUN SEED  %d" % seed_value
	selected_node_id = ""
	build_map()
	refresh_map_state()
	ensure_player_progression_state()
	refresh_level_up_button()
	build_party_inventory_buttons()


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
			member.set_meta("creation_rules_applied", true)
		var applied := int(run_state.applied_party_ability_point_bonuses.get(member_id, 0))
		var unapplied := run_state.party_ability_point_bonus - applied
		if unapplied > 0:
			member.ability_points += unapplied
			run_state.applied_party_ability_point_bonuses[member_id] = applied + unapplied
	run_state.player_progression_state = run_state.party_progression_states.get("player")
	run_state.applied_party_ability_point_bonus = int(run_state.applied_party_ability_point_bonuses.get("player", 0))


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
		button.custom_minimum_size = Vector2(122, 46)
		button.icon = member.token_texture
		button.expand_icon = true
		button.text = "%s\nINVENTORY" % member.display_name
		button.tooltip_text = "Open %s's Inventory" % member.display_name
		button.pressed.connect(open_party_inventory.bind(member_id))
		party_inventory.add_child(button)


func open_party_inventory(member_id: String) -> void:
	var member: CombatantState = run_state.party_progression_states.get(member_id)
	if member == null:
		return
	level_up_panel.hide()
	character_panel.setup_standalone(member, "inventory")
	character_panel.show()


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
	for node in run_state.nodes:
		if not grouped.has(node.floor_index):
			grouped[node.floor_index] = []
		grouped[node.floor_index].append(node)
		max_floor = maxi(max_floor, node.floor_index)
	var positions: Dictionary = {}
	for floor_index in grouped:
		var floor_nodes: Array = grouped[floor_index]
		for lane_index in range(floor_nodes.size()):
			positions[floor_nodes[lane_index].id] = Vector2(
				70.0 + float(floor_index) * FLOOR_SPACING,
				map_canvas.size.y * 0.5 + (float(lane_index) - float(floor_nodes.size() - 1) * 0.5) * LANE_SPACING
			)
	for node in run_state.nodes:
		for next_id in node.next_node_ids:
			var line := Line2D.new()
			line.width = 4.0
			line.default_color = Color("34465f")
			line.points = PackedVector2Array([positions[node.id] + NODE_SIZE * 0.5, positions[next_id] + NODE_SIZE * 0.5])
			map_canvas.add_child(line)
	for node in run_state.nodes:
		var button := Button.new()
		button.name = node.id
		button.position = positions[node.id]
		button.size = NODE_SIZE
		button.text = "%s\n%s" % [node.get_short_label(), node.get_display_name()]
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
	if node.encounter_data != null:
		get_tree().set_meta("active_run_state", run_state)
		get_tree().set_meta("active_run_node_id", node.id)
		get_tree().set_meta("active_encounter_data", node.encounter_data)
		var change_error := get_tree().change_scene_to_file(COMBAT_SCENE)
		if change_error != OK:
			location_label.text = "Could not open Encounter: %s" % error_string(change_error)
		return
	get_tree().remove_meta("active_run_node_id")
	get_tree().remove_meta("active_encounter_data")
	location_label.text = "Entered %s — this Node does not start Combat." % node.get_display_name()


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
