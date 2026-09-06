extends Control

var radius: float = 32.0
var obstacle_label: String = "Obstacle"


func setup(new_radius: float, new_label: String) -> void:
	radius = new_radius
	obstacle_label = new_label
	position = -Vector2.ONE * radius
	size = Vector2.ONE * radius * 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var center := Vector2.ONE * radius
	draw_circle(center + Vector2(3.0, 5.0), radius, Color(0.02, 0.03, 0.04, 0.45))
	draw_circle(center, radius, Color("37444b"))
	draw_circle(center, radius * 0.78, Color("4c5a60"))
	draw_arc(center, radius, 0.0, TAU, 48, Color("a18a5b"), 3.0, true)
	draw_arc(center - Vector2(radius * 0.12, radius * 0.12), radius * 0.52, PI, TAU, 24, Color("718087"), 3.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(center.x - radius, radius * 2.0 + 17.0), obstacle_label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 12, Color("cbd5d8"))
