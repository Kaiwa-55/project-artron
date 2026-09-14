extends Control

const RUN_MAP_SCENE := "res://scenes/run/RunMap.tscn"

@onready var title_label: Label = $Margin/Layout/Title
@onready var subtitle_label: Label = $Margin/Layout/Subtitle
@onready var cards: GridContainer = $Margin/Layout/Cards
@onready var status_label: Label = $Margin/Layout/Status

var run_state: RunState
var node: MapNodeData
var reward_system := RewardSystem.new()


func _ready() -> void:
	_apply_responsive_layout()
	if not resized.is_connected(_apply_responsive_layout):
		resized.connect(_apply_responsive_layout)
	if not get_tree().has_meta("active_run_state"):
		show_error("No active Run was found.")
		return
	run_state = get_tree().get_meta("active_run_state") as RunState
	var node_id := String(get_tree().get_meta("active_run_node_id", run_state.current_node_id))
	node = run_state.get_node(node_id)
	if node == null:
		show_error("The completed Map Node no longer exists.")
		return
	if run_state.reward_claimed_node_ids.has(node.id):
		return_to_map()
		return
	title_label.text = "VICTORY REWARD"
	subtitle_label.text = "%s • Choose one reward" % node.get_display_name()
	build_cards(reward_system.generate_choices(run_state, node))
	status_label.text = "Run Gold: %d" % run_state.gold


func build_cards(rewards: Array[RewardOptionData]) -> void:
	for child in cards.get_children():
		child.queue_free()
	for reward in rewards:
		var card := Button.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.set_meta("reward", reward)
		card.tooltip_text = reward.description
		card.pressed.connect(select_reward.bind(reward))
		cards.add_child(card)
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var compact := size.x <= 700.0 or size.y <= 400.0
	var margin: MarginContainer = $Margin
	margin.offset_left = 16.0 if compact else 72.0
	margin.offset_top = 10.0 if compact else 46.0
	margin.offset_right = -16.0 if compact else -72.0
	margin.offset_bottom = -10.0 if compact else -46.0
	var layout: VBoxContainer = $Margin/Layout
	layout.add_theme_constant_override("separation", 6 if compact else 18)
	title_label.custom_minimum_size = Vector2(0.0, 34.0 if compact else 54.0)
	title_label.add_theme_font_size_override("font_size", 20 if compact else 30)
	subtitle_label.add_theme_font_size_override("font_size", 12 if compact else 18)
	status_label.custom_minimum_size = Vector2(0.0, 26.0 if compact else 46.0)
	status_label.add_theme_font_size_override("font_size", 11 if compact else 16)
	cards.columns = 2 if compact else 4
	cards.add_theme_constant_override("h_separation", 8 if compact else 22)
	cards.add_theme_constant_override("v_separation", 8 if compact else 22)
	for card in cards.get_children():
		if not card is Button:
			continue
		var reward = card.get_meta("reward", null)
		if reward == null:
			continue
		card.custom_minimum_size = Vector2(0.0, 104.0 if compact else 300.0)
		card.add_theme_font_size_override("font_size", 10 if compact else 16)
		card.text = "%s\n%s\n%s\nSELECT" % [reward.display_name, reward.get_value_text(), reward.description] if compact else "%s\n\n%s\n\n%s\n\nSELECT" % [reward.display_name, reward.get_value_text(), reward.description]


func select_reward(reward: RewardOptionData) -> void:
	if not reward_system.claim(run_state, node.id, reward):
		return
	for card in cards.get_children():
		if card is Button:
			card.disabled = true
	status_label.text = "%s received. Returning to the map..." % reward.get_value_text()
	await get_tree().create_timer(0.35).timeout
	return_to_map()


func return_to_map() -> void:
	get_tree().set_meta("active_run_state", run_state)
	get_tree().remove_meta("active_encounter_data")
	var change_error := get_tree().change_scene_to_file(RUN_MAP_SCENE)
	if change_error != OK:
		show_error("Could not return to Run Map: %s" % error_string(change_error))


func show_error(message: String) -> void:
	status_label.text = message
	for card in cards.get_children():
		card.queue_free()
