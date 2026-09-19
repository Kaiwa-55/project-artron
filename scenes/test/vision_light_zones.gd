extends Node2D


func _draw() -> void:
	draw_rect(Rect2(-480, -240, 320, 480), Color("fff0a8", 0.22), true)
	draw_rect(Rect2(-160, -240, 320, 480), Color("7180bb", 0.28), true)
	draw_rect(Rect2(160, -240, 320, 480), Color("111426", 0.60), true)
	# Keep labels below the combat header so they remain readable at every scale.
	draw_string(ThemeDB.fallback_font, Vector2(-430, -105), "BRIGHT +0", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(-105, -105), "DIM +1", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(210, -105), "DARKNESS +2", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
