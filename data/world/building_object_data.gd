class_name BuildingObjectData
extends Resource

@export var object_id: StringName = &"object"
@export var preset_id: StringName = &"crate"
@export var display_name: String = "Map Object"
@export var rect: Rect2
@export var height_feet: float = 3.0
@export var collision_enabled: bool = true
@export var blocks_movement: bool = true
@export var blocks_line_of_sight: bool = true
@export var color: Color = Color("8a6544")
@export var texture: Texture2D
@export_enum("Behind map image:0", "Above map image:1") var image_layer: int = 1
