class_name MapObstacles
extends Node2D

var obstacles: Array[Dictionary] = []


func setup(p_obstacles: Array[Dictionary]) -> void:
	obstacles = p_obstacles.duplicate(true)
	queue_redraw()


func _draw() -> void:
	for obstacle in obstacles:
		var center: Vector2 = obstacle.get("center", Vector2.ZERO)
		var radius: float = float(obstacle.get("radius", 0.0))
		draw_circle(center, radius, Color("697582"))
		draw_arc(center, radius, 0.0, TAU, 32, Color("C5D0D9"), 2.0)
