class_name RunGenerator
extends RefCounted

const DEFAULT_FLOORS := 9
const MIN_LANES := 2
const MAX_LANES := 4


func generate(seed_value: int, floor_count: int = DEFAULT_FLOORS, encounter_catalog: RunEncounterCatalog = null) -> Array[MapNodeData]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var floors: Array[Array] = []
	floors.append([create_node("start", MapNodeData.NodeType.START, 0, 0, 0)])
	for floor_index in range(1, maxi(2, floor_count)):
		var floor_nodes: Array[MapNodeData] = []
		var lane_count := rng.randi_range(MIN_LANES, MAX_LANES)
		for lane_index in range(lane_count):
			var node_type := roll_node_type(rng, floor_index, floor_count)
			floor_nodes.append(create_node("f%d_n%d" % [floor_index, lane_index], node_type, floor_index, lane_index, floor_index))
		floors.append(floor_nodes)
	floors.append([create_node("boss", MapNodeData.NodeType.BOSS, floor_count, 0, floor_count + 2)])
	for floor_index in range(floors.size() - 1):
		connect_floors(floors[floor_index], floors[floor_index + 1], rng)
	var output: Array[MapNodeData] = []
	for floor_nodes in floors:
		output.append_array(floor_nodes)
	if encounter_catalog != null:
		assign_encounters(output, encounter_catalog, seed_value)
	return output


func assign_encounters(nodes: Array[MapNodeData], catalog: RunEncounterCatalog, seed_value: int) -> void:
	for node in nodes:
		if not node.encounter_pool_id.is_empty():
			node.encounter_data = catalog.pick_encounter(node.encounter_pool_id, seed_value, node.id)


func create_node(node_id: String, type: MapNodeData.NodeType, floor_index: int, lane_index: int, threat: int) -> MapNodeData:
	var node := MapNodeData.new()
	node.id = node_id
	node.node_type = type
	node.floor_index = floor_index
	node.lane_index = lane_index
	node.threat = maxi(0, threat)
	if type in [MapNodeData.NodeType.COMBAT, MapNodeData.NodeType.ELITE, MapNodeData.NodeType.BOSS]:
		node.encounter_pool_id = ["", "normal", "elite", "", "", "", "", "boss"][type]
	return node


func roll_node_type(rng: RandomNumberGenerator, floor_index: int, floor_count: int) -> MapNodeData.NodeType:
	# Put a recovery opportunity near the boss without forcing every route through it.
	if floor_index == floor_count - 1 and rng.randf() < 0.45:
		return MapNodeData.NodeType.REST
	var roll := rng.randi_range(0, 99)
	if roll < 48:
		return MapNodeData.NodeType.COMBAT
	if roll < 61:
		return MapNodeData.NodeType.EVENT
	if roll < 72:
		return MapNodeData.NodeType.REST
	if roll < 82:
		return MapNodeData.NodeType.SHOP
	if roll < 91:
		return MapNodeData.NodeType.TREASURE
	return MapNodeData.NodeType.ELITE


func connect_floors(previous: Array, next: Array, rng: RandomNumberGenerator) -> void:
	if previous.is_empty() or next.is_empty():
		return
	# Every node has an exit and every node in the next floor has an entrance.
	for index in range(previous.size()):
		add_connection(previous[index], next[mini(index, next.size() - 1)])
	for index in range(next.size()):
		add_connection(previous[mini(index, previous.size() - 1)], next[index])
	# Occasional adjacent branches create choices while keeping the graph readable.
	for index in range(previous.size()):
		if next.size() > 1 and rng.randf() < 0.55:
			var base_index := mini(index, next.size() - 1)
			var offset := -1 if base_index == next.size() - 1 else 1
			add_connection(previous[index], next[base_index + offset])


func add_connection(from_node: MapNodeData, to_node: MapNodeData) -> void:
	if not from_node.next_node_ids.has(to_node.id):
		from_node.next_node_ids.append(to_node.id)
