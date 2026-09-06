class_name MapObstacleData
extends Resource

@export var id: String = ""
@export var display_name: String = "Obstacle"
@export var texture: Texture2D
@export_range(1.0, 500.0, 1.0) var base_collision_radius: float = 24.0
