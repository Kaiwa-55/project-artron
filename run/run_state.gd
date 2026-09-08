class_name RunState
extends Resource

signal node_entered(node: MapNodeData)

@export var seed: int = 0
@export var act: int = 1
@export var nodes: Array[MapNodeData] = []
@export var current_node_id: String = ""
@export var completed_node_ids: Array[String] = []
@export var reward_claimed_node_ids: Array[String] = []
@export var reward_history: Array[Dictionary] = []
@export var gold: int = 0
@export var party_max_hp_bonus: int = 0
@export var party_ability_point_bonus: int = 0
var player_progression_state: CombatantState
var applied_party_ability_point_bonus: int = 0
var party_progression_states: Dictionary = {}
var applied_party_ability_point_bonuses: Dictionary = {}
var party_character_data: Array[CharacterData] = []


func setup(p_seed: int, generated_nodes: Array[MapNodeData]) -> void:
	seed = p_seed
	nodes = generated_nodes
	current_node_id = "start"
	completed_node_ids = []
	reward_claimed_node_ids = []
	reward_history = []
	gold = 0
	party_max_hp_bonus = 0
	party_ability_point_bonus = 0
	player_progression_state = null
	applied_party_ability_point_bonus = 0
	party_progression_states.clear()
	applied_party_ability_point_bonuses.clear()
	party_character_data.clear()


func get_node(node_id: String) -> MapNodeData:
	for node in nodes:
		if node != null and node.id == node_id:
			return node
	return null


func get_current_node() -> MapNodeData:
	return get_node(current_node_id)


func get_available_node_ids() -> Array[String]:
	var current := get_current_node()
	return current.next_node_ids.duplicate() if current != null else []


func can_enter(node_id: String) -> bool:
	return get_available_node_ids().has(node_id) and not completed_node_ids.has(node_id)


func enter_node(node_id: String) -> bool:
	if not can_enter(node_id):
		return false
	if not completed_node_ids.has(current_node_id):
		completed_node_ids.append(current_node_id)
	current_node_id = node_id
	var node := get_current_node()
	if node != null:
		node_entered.emit(node)
	return true


func is_completed(node_id: String) -> bool:
	return completed_node_ids.has(node_id)


func get_signature() -> String:
	var parts: Array[String] = []
	for node in nodes:
		parts.append("%s:%d:%s" % [node.id, node.node_type, ",".join(node.next_node_ids)])
	return "|".join(parts)
