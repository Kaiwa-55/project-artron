class_name BuildingMapData
extends Resource

@export var map_id: StringName
@export var display_name: String
@export var data_version: int = 1
@export var source_size: Vector2 = Vector2(1600,1600)
@export var pixels_per_foot: float = 12.0
@export var surfaces: Array[BuildingSurfaceData] = []
@export var transitions: Array[BuildingTransitionData] = []
@export var light_points: Array[Dictionary] = []

func get_surface(surface_id: StringName) -> BuildingSurfaceData:
	for surface in surfaces:
		if surface != null and surface.surface_id == surface_id:
			return surface
	return null

func map_to_logic(position: Vector2) -> Vector2:
	return position - source_size * 0.5

func logic_to_map(position: Vector2) -> Vector2:
	return position + source_size * 0.5

func logic_to_world(position: Vector2, elevation_feet: float) -> Vector3:
	return Vector3(position.x / pixels_per_foot, elevation_feet, position.y / pixels_per_foot)

func world_to_logic(position: Vector3) -> Vector2:
	return Vector2(position.x, position.z) * pixels_per_foot
