extends Node2D

const Layout = preload("res://scenes/exploration/dungeon_layout.gd")
var visible_hostiles := true

func _draw() -> void:
	if not visible_hostiles:
		return
	for position in Layout.HOSTILE_POSITIONS:
		draw_circle(position + Vector2(0,5), 15, Color(0,0,0,0.45))
		draw_circle(position, 13, Color("4a1720"))
		draw_circle(position, 9, Color("e16855"))
		draw_arc(position, 18, 0, TAU, 20, Color("ffb19a"), 1.5, true)
