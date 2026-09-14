extends SceneTree

const PrototypeScene := preload("res://scenes/prototype/PrototypeCombat.tscn")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var failures: Array[String] = []
	var scene = PrototypeScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var player: CombatantState = scene.combat_system.get_combat_state().get_combatant("player")
	scene.refresh_essential_hud()
	var bar := "UILayer/Control/CombatUI/Combat_bar/Combat_bar_Container/VBoxContainer/Combat_bar/MarginContainer/HBoxContainer/DefenseAndResource/HBoxContainer"
	check(scene.get_node(bar + "/Fortitude/Value").text == str(scene.combat_system.defense_system.get_defense(player, DefenseTypes.Type.FORTITUDE)), "Action Bar displays effective Fortitude", failures)
	check(scene.get_node(bar + "/Reflex/Value").text == str(scene.combat_system.defense_system.get_defense(player, DefenseTypes.Type.REFLEX)), "Action Bar displays effective Reflex", failures)
	check(scene.get_node(bar + "/Will/Value").text == str(scene.combat_system.defense_system.get_defense(player, DefenseTypes.Type.WILL)), "Action Bar displays effective Will", failures)
	scene.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("ACTION_BAR_DEFENSE_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
