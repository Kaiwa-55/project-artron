class_name BuildingWallData
extends Resource

@export var from_position: Vector2 = Vector2.ZERO
@export var to_position: Vector2 = Vector2.ZERO
@export_range(0.1, 100.0, 0.1) var width_feet: float = 1.5
@export_range(0.1, 100.0, 0.1) var height_feet: float = 9.0
