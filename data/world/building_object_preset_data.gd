class_name BuildingObjectPresetData
extends Resource

@export var preset_id: StringName
@export var display_name: String
@export var default_size_pixels: Vector2 = Vector2(40, 40)
@export var height_feet: float = 3.0
@export var collision_enabled: bool = true
@export var blocks_movement: bool = true
@export var blocks_line_of_sight: bool = true
@export var color: Color = Color("8a6544")
@export var texture: Texture2D
