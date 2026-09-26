extends Node2D

const Layout = preload("res://scenes/exploration/dungeon_layout.gd")
var floor_id := 0
var debug_walls := false

func _draw() -> void:
	if debug_walls:
		for rect in Layout.walls(floor_id):
			draw_rect(rect, Color(1,0.3,0.25,0.4))
			draw_rect(rect, Color(1,0.6,0.35,0.9), false, 1)
	draw_rect(Layout.STAIRS, Color(0.35,0.92,0.78,0.1))
	draw_rect(Layout.STAIRS, Color(0.55,0.95,0.8,0.7), false, 2)
	var center := Vector2(235,745)
	var sign_y := -1.0 if floor_id == 0 else 1.0
	draw_line(center + Vector2(0,-18 * sign_y),center + Vector2(0,18 * sign_y),Color("b4ffe3"),3,true)
	draw_line(center + Vector2(-8,10 * sign_y),center + Vector2(0,18 * sign_y),Color("b4ffe3"),3,true)
	draw_line(center + Vector2(8,10 * sign_y),center + Vector2(0,18 * sign_y),Color("b4ffe3"),3,true)
