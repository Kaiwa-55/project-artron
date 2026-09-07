class_name ActionBarController
extends Node

var host

func setup(p_host) -> void:
	host = p_host

func build() -> void:
	host._build_action_dock()

func refresh() -> void:
	host.refresh_action_dock()

func close_menu() -> void:
	if host.action_menu_panel != null:
		host.action_menu_panel.hide()
