extends "res://tests/helpers/idle_combat_ui.gd"

var reset_combat_requests := 0


func reset_combat() -> void:
	reset_combat_requests += 1
