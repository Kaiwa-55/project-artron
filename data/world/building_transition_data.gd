class_name BuildingTransitionData
extends Resource

@export var transition_id: StringName
@export var from_surface_id: StringName
@export var to_surface_id: StringName
@export var from_area: Rect2
@export var to_area: Rect2
@export var from_position: Vector2
@export var to_position: Vector2
@export var use_custom_elevations: bool = false
@export var from_elevation_feet: float = 0.0
@export var to_elevation_feet: float = 0.0
@export var traversal_cost_feet: float = 10.0
@export var bidirectional: bool = true
@export var width_feet: float = 9.0
@export var render_as_wedge: bool = true

func get_from_elevation(default_elevation: float) -> float:
	return from_elevation_feet if use_custom_elevations else default_elevation

func get_to_elevation(default_elevation: float) -> float:
	return to_elevation_feet if use_custom_elevations else default_elevation
