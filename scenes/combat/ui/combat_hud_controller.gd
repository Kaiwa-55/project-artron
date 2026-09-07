class_name CombatHUDController
extends Node

var host

func setup(p_host) -> void:
	host = p_host

func build() -> void:
	host._build_essential_hud()
	host._build_initiative_bar()

func refresh() -> void:
	host.refresh_essential_hud()
	host.refresh_initiative_bar()
	host.refresh_end_turn_lock()
