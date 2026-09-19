extends SceneTree

const RunMapScene := preload("res://scenes/run/RunMap.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func run_test() -> void:
	var run_map = RunMapScene.instantiate()
	root.add_child(run_map)
	await process_frame
	var members: Array[CombatantState] = []
	for member in run_map.run_state.party_progression_states.values():
		if member is CombatantState:
			members.append(member)
			check(member.hp == member.max_hp, "A newly created Run starts each party member at full HP after derived stats are applied.")
			member.hp = 1
			member.mana = 0
			member.faith = 0
	check(not members.is_empty(), "Run Map provides party states to the Rest node.")
	# Duplicate a party member so distinct actions can be verified in one camp.
	if members.size() == 1:
		var ally := CombatantState.new()
		ally.id = "rest_ally"
		ally.display_name = "Rest Ally"
		ally.base_max_hp = 20
		ally.base_max_mana = 10
		ally.base_max_faith = 6
		StatSystem.new().initialize_combatant(ally)
		ally.hp = 1
		ally.mana = 0
		ally.faith = 0
		run_map.run_state.party_progression_states[ally.id] = ally
		members.append(ally)
	run_map.open_rest(null)
	await process_frame
	var rows: VBoxContainer = run_map.rest_panel.get_node("Center/CampCard/Column/PartyRows")
	check(run_map.rest_panel.visible and rows.get_child_count() == members.size(), "Rest opens one camp card for every party member.")
	for row in rows.get_children():
		check(row.get_node("Content/Actions").get_child_count() == 3, "Each party member has three separate camp actions.")
	if "--capture-rest" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://work/rest-campfire.png")
	var first: CombatantState = members[0]
	var second: CombatantState = members[1]
	rows.get_node(first.id + "/Content/Actions/Wounds").pressed.emit()
	check(first.hp == mini(first.max_hp, 1 + maxi(1, ceili(first.max_hp * run_map.REST_RECOVERY_RATIO))), "First member can choose Tend Wounds.")
	check(run_map.rest_panel.visible, "Camp remains open until every member chooses.")
	var ability_points_before := second.ability_points
	rows.get_node(second.id + "/Content/Actions/Training").pressed.emit()
	check(second.ability_points == ability_points_before + 1, "Second member can independently train for one Ability Point.")
	check(not run_map.rest_panel.visible, "Camp closes only after every party member has chosen.")
	check(run_map.rest_panel.choices_by_actor.size() == members.size(), "Rest records one action per party member.")
	run_map.queue_free()
	for failure in failures:
		push_error(failure)
	print("REST_NODE_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
