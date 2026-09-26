class_name BuildingMapCatalog
extends Resource

@export var maps: Array[BuildingMapData] = []

func get_map(map_id: StringName) -> BuildingMapData:
	for map_data in maps:
		if map_data != null and map_data.map_id == map_id:
			return map_data
	return null

func validate() -> Array[String]:
	var errors: Array[String] = []
	var ids: Dictionary = {}
	for map_data in maps:
		if map_data == null:
			errors.append("Catalog contains a null map.")
			continue
		if map_data.map_id == &"":
			errors.append("A map has no map_id.")
		elif ids.has(map_data.map_id):
			errors.append("Duplicate map_id: %s" % map_data.map_id)
		ids[map_data.map_id] = true
	return errors
