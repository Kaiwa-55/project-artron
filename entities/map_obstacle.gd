class_name MapObstacle
extends Node2D

@export var obstacle_data: Resource
@export_range(0.1, 10.0, 0.1) var size_multiplier: float = 1.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	refresh_visual()


func refresh_visual() -> void:
	if obstacle_data != null and obstacle_data.texture != null:
		sprite.texture = obstacle_data.texture
		sprite.scale = Vector2.ONE * size_multiplier
		sprite.visible = true
	else:
		sprite.visible = false
	queue_redraw()


func register_on_map_rules(map_rules) -> void:
	if map_rules == null:
		return
	map_rules.add_circular_obstacle(global_position, get_collision_radius(), get_display_name())


func get_collision_radius() -> float:
	if obstacle_data == null:
		return 24.0 * size_multiplier
	return obstacle_data.base_collision_radius * size_multiplier


func get_display_name() -> String:
	if obstacle_data == null or obstacle_data.display_name.is_empty():
		return name
	return obstacle_data.display_name


func _draw() -> void:
	if obstacle_data != null and obstacle_data.texture != null:
		return
	var radius := get_collision_radius()
	draw_circle(Vector2.ZERO, radius, Color("697582"))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color("C5D0D9"), 2.0)
