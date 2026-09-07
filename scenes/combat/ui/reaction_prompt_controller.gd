class_name ReactionPromptController
extends Node

var combat_ui: Control

func setup(p_combat_ui: Control) -> void:
	combat_ui = p_combat_ui

func show(prompt: Dictionary) -> void:
	combat_ui.show_reaction_prompt(prompt)

func hide() -> void:
	combat_ui.hide_reaction_prompt()

func is_visible() -> bool:
	return combat_ui != null and combat_ui.get_node("ReactionPrompt").visible
