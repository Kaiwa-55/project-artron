class_name CombatLogController
extends Node

var combat_ui: Control
var panel: Control

func setup(p_combat_ui: Control) -> void:
	combat_ui = p_combat_ui
	panel = combat_ui.get_node("CombatLogPanel")

func toggle() -> void:
	panel.visible = not panel.visible

func add_message(message: String) -> void:
	combat_ui.add_log_message(message)

func record(result: ActionResult) -> void:
	combat_ui.record_action_result(result)
