class_name MapNodeData
extends Resource

enum NodeType { START, COMBAT, ELITE, EVENT, REST, SHOP, TREASURE, BOSS }

@export var id: String = ""
@export var node_type: NodeType = NodeType.COMBAT
@export var floor_index: int = 0
@export var lane_index: int = 0
@export var next_node_ids: Array[String] = []
@export var encounter_pool_id: String = ""
@export var encounter_data: EncounterData
@export var reward_pool_id: String = "default"
@export var threat: int = 1


func get_display_name() -> String:
	return ["Start", "Combat", "Elite", "Event", "Rest", "Shop", "Treasure", "Boss"][node_type]


func get_short_label() -> String:
	return ["S", "C", "E", "?", "R", "$", "T", "B"][node_type]
