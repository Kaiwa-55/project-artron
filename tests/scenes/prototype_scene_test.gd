extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var prototype = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	root.add_child(prototype)
	await process_frame
	await process_frame
	check(prototype.inventory_button != null, "Prototype should create an Inventory button")
	check(prototype.level_up_button != null, "Prototype should create a Level Up button")
	check(prototype.level_up_button.text.begins_with("LEVEL UP"), "Pending progression choices should be visible in the header")
	prototype.toggle_level_up_panel()
	check(prototype.level_up_panel.visible, "Level Up panel should open")
	check(prototype.level_up_list.get_child_count() > 4, "Level Up panel should list Ability choices")
	prototype.toggle_level_up_panel()
	check(not prototype.level_up_panel.visible, "Level Up panel should close")
	check(prototype.area_action_buttons.has("skill:arcane_burst"), "Unified targeting UI should list the Circle Skill.")
	check(prototype.area_action_buttons.has("skill:arcane_cone"), "Unified targeting UI should list the Cone Skill.")
	check(prototype.area_action_buttons.has("ability:ki_wave"), "Unified targeting UI should list the Line Ability.")
	prototype.combat_system.combat_state.current_actor_id = "player"
	prototype.combat_system.combat_state.get_combatant("player").ap = prototype.combat_system.combat_state.get_combatant("player").max_ap
	prototype.combat_system.pending_action = null
	prototype.combat_system.pending_reaction = {}
	prototype.combat_system.pending_reaction_queue.clear()
	prototype.begin_ground_targeting("ability", "ki_wave")
	check(prototype.ground_targeting_kind == "ability" and prototype.get_ground_targeting_data().id == "ki_wave", "Ground Ability should enter the shared targeting mode.")
	prototype.cancel_ground_targeting()
	check(prototype.ground_targeting_id.is_empty(), "Cancelling should leave targeting mode without spending the Action.")
	check(not prototype.has_node("Control/Player_panel"), "legacy Player and Action panel should be removed from the Combat scene")
	check(prototype.has_node("Control/ActionSources"), "minimal non-visual Action sources should remain for Combat signals")
	check(prototype.get_node("Control/ReferencePlayerHUD") != null, "reference-style Player HUD should replace the legacy panel")
	check(prototype.get_node("Control/ReferenceActionDock") != null, "reference-style horizontal Action Dock should be available")
	check(prototype.action_category_buttons.size() == 4, "Action Bar should contain Attack, Move, Skill and Ability categories")
	check(prototype.action_category_buttons.has("attack") and prototype.action_category_buttons.has("move") and prototype.action_category_buttons.has("skill") and prototype.action_category_buttons.has("ability"), "Action Bar should expose the four required categories")
	prototype.show_action_menu("attack")
	check(prototype.action_menu_panel.visible and prototype.action_menu_list.get_child_count() > 0, "Attack category should list attacks from equipped items")
	prototype.action_menu_panel.visible = false
	check(prototype.get_node("Control/ReferenceTurnHUD") != null, "reference-style AP and End Turn panel should be available")
	var action_dock: Control = prototype.get_node("Control/ReferenceActionDock")
	var turn_hud: Control = prototype.get_node("Control/ReferenceTurnHUD")
	check(action_dock.position.x + action_dock.size.x < turn_hud.position.x, "Action Dock should not overlap the End Turn panel")
	check(prototype.get_node("Control/Enemy_panel").visible, "compact selected Target card should remain visible on the battlefield")
	check(prototype.initiative_row != null, "Combat header should create the Initiative order bar")
	check(prototype.initiative_row.get_child_count() >= 5, "Initiative order should show every combatant with separators")
	var ally: CombatantState = prototype.combat_system.combat_state.get_combatant("ally")
	check(ally != null and ally.team == prototype.combat_system.combat_state.get_combatant("player").team, "Prototype should contain an Ally on the Player team")
	check(prototype.combat_system.combat_state.turn_order.has("ally"), "Ally should participate in Initiative")
	check(prototype.get_node("AllyCharacter").state == ally, "Ally should have a visible battlefield token")
	prototype.combat_system.combat_state.current_actor_id = "player"
	prototype.select_target_at(prototype.get_node("AllyCharacter").global_position)
	prototype.refresh_action_dock()
	prototype.refresh_end_turn_lock()
	check(prototype.selected_character_id == "ally" and prototype.get_node("AllyCharacter").selected, "An out-of-turn Ally should still be selectable and receive the ui03 frame")
	check(prototype.action_category_buttons.values().all(func(button): return not button.disabled), "An out-of-turn selected Ally may inspect its Action categories")
	check(prototype.reference_end_turn_button.disabled, "An out-of-turn selected Ally must not be allowed to end the active character's Turn")
	prototype.select_target_at(prototype.get_node("PlayerCharacter").global_position)
	prototype.refresh_action_dock()
	check(prototype.selected_character_id == "player" and prototype.get_node("PlayerCharacter").selected, "Clicking the active character should move the ui03 frame to it")
	check(prototype.action_category_buttons.values().all(func(button): return not button.disabled), "Selecting the active character should restore its Actions")
	prototype.combat_system.combat_state.current_actor_id = "ally"
	prototype.selected_character_id = ""
	prototype.update_target_selection()
	prototype.get_node("Control").update_ui()
	prototype.refresh_action_dock()
	check(prototype.get_player_controlled_actor() == ally, "The Ally should become the player-controlled actor during its Turn")
	check(prototype.action_category_buttons.values().all(func(button): return not button.disabled), "The Action Bar should be enabled during the Ally's Turn")
	prototype.combat_system.combat_state.current_actor_id = "player"
	check(prototype.combat_round_label.text.contains("ROUND"), "Combat header should display the current Round")
	check(not prototype.get_node("Control/CombatLogPanel").visible, "Combat Log should start collapsed")
	prototype.toggle_combat_log()
	check(prototype.get_node("Control/CombatLogPanel").visible, "Combat Log drawer should open on the left")
	prototype.toggle_combat_log()
	check(not prototype.get_node("Control/CombatLogPanel").visible, "Combat Log drawer should close")
	prototype.get_node("Control").add_log_message("Older message")
	prototype.get_node("Control").add_log_message("Latest message")
	var log_text: String = prototype.get_node("Control/CombatLogPanel/VBoxContainer/Entries").text
	check(log_text.find("Latest message") < log_text.find("Older message"), "Combat Log should show newest entries first")
	check(prototype.combat_system.combat_state.has_combatant("enemy_2"), "Prototype should contain a second Enemy")
	check(prototype.combat_system.combat_state.turn_order.has("enemy_2"), "second Enemy should participate in Turn Order")
	prototype.selected_target_id = "enemy_2"
	prototype.update_target_selection()
	prototype.get_node("Control").update_ui()
	check(prototype.get_node("Control/Enemy_panel/VBoxContainer/Name").text == "Giant Spider", "Target panel should display the Giant Spider")
	prototype.clear_selected_target()
	check(prototype.selected_target_id.is_empty(), "Right-click target clearing should remove the selected Target id")
	check(not prototype.get_node("Control/Enemy_panel").visible, "Target card should hide when no Target is selected")
	prototype.selected_target_id = "enemy_2"
	prototype.update_target_selection()
	prototype.combat_system.combat_state.current_actor_id = "player"
	prototype.combat_system.pending_action = null
	prototype.combat_system.pending_reaction = {}
	var player: CombatantState = prototype.combat_system.combat_state.get_combatant("player")
	player.ap = player.max_ap
	var equipped_attack: AttackData = player.equipped_weapon_attack
	prototype.selected_target_id = "enemy"
	prototype.begin_attack_targeting(equipped_attack)
	check(prototype.pending_target_attack == equipped_attack, "Choosing an equipment attack should enter Attack Targeting mode")
	check(prototype.selected_target_id.is_empty(), "Attack Targeting should not reuse a previously selected target")
	prototype.cancel_attack_targeting()
	check(prototype.pending_target_attack == null, "Attack Targeting should cancel without executing the attack")
	var single_skill = player.available_skills.filter(func(skill): return skill != null and skill.target_mode == SkillData.TargetMode.SINGLE_COMBATANT).front()
	prototype.use_skill_from_menu(single_skill)
	check(prototype.pending_single_target_kind == "skill", "Single-target Skill should enter the shared targeting mode")
	check(prototype.selected_target_id.is_empty(), "Single-target Skill should not reuse the previous selected Target")
	prototype.cancel_single_targeting()
	var reusable_panel = load("res://scenes/ui/CharacterPanel.tscn").instantiate()
	root.add_child(reusable_panel)
	reusable_panel.setup(prototype.combat_system, "player")
	check(reusable_panel.content_list != null, "CharacterPanel scene should initialize independently from another scene")
	check(reusable_panel.tab_buttons.size() == 3, "Reusable CharacterPanel should expose all character tabs")
	reusable_panel.queue_free()
	prototype.toggle_inventory()
	check(prototype.inventory_drawer.visible, "Inventory drawer should open")
	check(prototype.character_summary.get_child_count() > 4, "Character panel should show the Player summary from the Figma layout")
	check(prototype.character_tab_buttons.size() == 3, "Character panel should provide Abilities, Equipment and Inventory tabs")
	check(prototype.character_active_tab == "abilities", "Character panel should open on the Abilities tab")
	prototype.set_character_tab("equipment")
	check(prototype.inventory_list.get_child_count() > 4, "Equipment tab should show equipped slots and available items")
	check(prototype.inventory_list.get_child(0).text == "EQUIPPED", "Equipment tab should begin with equipped slots")
	var shield = null
	for item in player.equipment_inventory:
		if item != null and item.id == "buckler":
			shield = item
			break
	var ap_before := player.ap
	prototype.change_inventory_item(shield, 3)
	check(player.equipped_items.get(3) == shield, "Inventory should equip Shield in Hand slot 2")
	check(player.ap == ap_before - 1, "Inventory equipment action should use normal AP rules")

	prototype.queue_free()
	if failures.is_empty():
		print("PROTOTYPE_SCENE_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("PROTOTYPE_SCENE_TEST: FAIL (%d)" % failures.size())
		quit(1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
