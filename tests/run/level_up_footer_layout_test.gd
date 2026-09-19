extends SceneTree

const LevelUpPanelScene := preload("res://scenes/run/LevelUpPanel.tscn")


func _init() -> void:
	var panel = LevelUpPanelScene.instantiate()
	root.add_child(panel)
	var row: HBoxContainer = panel.get_node("Layout/Footer/Margin/Row")
	var spacer: Control = row.get_node("ActionsSpacer")
	var cancel: Button = row.get_node("Cancel")
	var confirm: Button = row.get_node("Confirm")
	var success := spacer.size_flags_horizontal == Control.SIZE_EXPAND_FILL \
		and row.get_children().find(spacer) < row.get_children().find(cancel) \
		and row.get_children().find(cancel) < row.get_children().find(confirm)
	print("LEVEL_UP_FOOTER_LAYOUT_TEST: " + ("PASS" if success else "FAIL"))
	quit(0 if success else 1)
