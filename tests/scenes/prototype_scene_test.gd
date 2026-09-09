extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var prototype = load("res://scenes/prototype/PrototypeCombat.tscn").instantiate()
	root.add_child(prototype)
	await process_frame
	await process_frame
	check(not prototype.has_node("UILayer/Control/LevelUpButton"), "Combat must not expose Level Up controls")
	check(not prototype.has_node("UILayer/Control/LevelUpPanel"), "Combat must not contain the legacy Level Up panel")
	check(prototype.area_action_buttons.has("ability:shared_blessing"), "Unified targeting UI should list the current Devotee Circle Ability.")
	prototype.combat_system.combat_state.current_actor_id = "player"
	prototype.combat_system.combat_state.get_combatant("player").ap = prototype.combat_system.combat_state.get_combatant("player").max_ap
	prototype.combat_system.pending_action = null
	prototype.combat_system.pending_reaction = {}
	prototype.combat_system.pending_reaction_queue.clear()
	prototype.begin_ground_targeting("ability", "shared_blessing")
	check(prototype.ground_targeting_kind == "ability" and prototype.get_ground_targeting_data().id == "shared_blessing", "Ground Ability should enter the shared targeting mode.")
	prototype.cancel_ground_targeting()
	check(prototype.ground_targeting_id.is_empty(), "Cancelling should leave targeting mode without spending the Action.")
	check(not prototype.has_node("UILayer/Control/Player_panel"), "legacy Player and Action panel should be removed from the Combat scene")
	check(prototype.has_node("UILayer/Control/ActionSources"), "minimal non-visual Action sources should remain for Combat signals")
	check(prototype.get_node("UILayer/Control/ReferencePlayerHUD") != null, "reference-style Player HUD should replace the legacy panel")
	check(prototype.get_node("UILayer/Control/BottomActionRow") is HBoxContainer, "Action Bar and End Turn should share one HBoxContainer")
	check(prototype.get_node("UILayer/Control/BottomActionRow/ReferenceActionDock") != null, "reference-style horizontal Action Dock should be available")
	check(prototype.action_category_buttons.size() >= 4, "Action Bar should contain at least Attack, Move, Skill and Ability categories")
	check(prototype.action_category_buttons.has("attack") and prototype.action_category_buttons.has("move") and prototype.action_category_buttons.has("skill") and prototype.action_category_buttons.has("ability"), "Action Bar should expose the four required categories")
	check(prototype.action_category_buttons.has("basic") and not prototype.action_category_buttons.has("throw") and not prototype.action_category_buttons.has("escape"), "Throw and Escape should be grouped under Basic Action")
	var action_grid: GridContainer = prototype.get_node("UILayer/Control/BottomActionRow/ReferenceActionDock/ActionDockMargin/ActionDockColumn/ActionButtonGrid")
	check(action_grid.columns == 3 and action_grid.get_child_count() == 6, "Action Bar should use a two-row 3-column layout")
	check(prototype.action_category_buttons.values().all(func(button): return button.icon != null), "Every Action category should display its combat icon")
	prototype.show_action_menu("attack")
	check(prototype.action_menu_panel.visible and prototype.action_menu_list.get_child_count() > 0, "Attack category should list attacks from equipped items")
	prototype.action_menu_panel.visible = false
	check(prototype.get_node("UILayer/Control/BottomActionRow/ReferenceTurnHUD") != null, "reference-style AP and End Turn panel should be available")
	var action_dock: Control = prototype.get_node("UILayer/Control/BottomActionRow/ReferenceActionDock")
	var turn_hud: Control = prototype.get_node("UILayer/Control/BottomActionRow/ReferenceTurnHUD")
	check(action_dock.position.x + action_dock.size.x < turn_hud.position.x, "Action Dock should not overlap the End Turn panel")
	check(prototype.initiative_row != null, "Combat header should create the Initiative order bar")
	check(prototype.initiative_row.get_child_count() >= 5, "Initiative order should show every combatant with separators")
	var ally: CombatantState = prototype.combat_system.combat_state.get_combatant("ally")
	check(ally != null and ally.team == prototype.combat_system.combat_state.get_combatant("player").team, "Prototype should contain an Ally on the Player team")
	check(prototype.encounter_data.player_party.size() == 2, "EncounterData should define the Player party")
	check(prototype.party_nodes.size() == prototype.encounter_data.player_party.size(), "Every configured Player-party entry should receive a battlefield token")
	check(prototype.combat_system.combat_state.turn_order.has("ally"), "Ally should participate in Initiative")
	check(prototype.get_node("BattlefieldWorld/AllyCharacter").state == ally, "Ally should have a visible battlefield token")
	prototype.combat_system.combat_state.current_actor_id = "player"
	prototype.select_target_at(prototype.get_node("BattlefieldWorld/AllyCharacter").global_position)
	prototype.refresh_action_dock()
	prototype.refresh_end_turn_lock()
	check(prototype.selected_character_id == "ally" and prototype.get_node("BattlefieldWorld/AllyCharacter").selected, "An out-of-turn Ally should still be selectable and receive the ui03 frame")
	check(prototype.action_category_buttons.values().all(func(button): return not button.disabled), "An out-of-turn selected Ally may inspect its Action categories")
	check(prototype.reference_end_turn_button.disabled, "An out-of-turn selected Ally must not be allowed to end the active character's Turn")
	prototype.select_target_at(prototype.get_node("BattlefieldWorld/PlayerCharacter").global_position)
	prototype.refresh_action_dock()
	check(prototype.selected_character_id == "player" and prototype.get_node("BattlefieldWorld/PlayerCharacter").selected, "Clicking the active character should move the ui03 frame to it")
	check(prototype.action_category_buttons.values().all(func(button): return not button.disabled), "Selecting the active character should restore its Actions")
	prototype.combat_system.combat_state.current_actor_id = "ally"
	prototype.selected_character_id = ""
	prototype.update_target_selection()
	prototype.get_node("UILayer/Control").update_ui()
	prototype.refresh_action_dock()
	check(prototype.get_player_controlled_actor() == ally, "The Ally should become the player-controlled actor during its Turn")
	check(prototype.action_category_buttons.values().all(func(button): return not button.disabled), "The Action Bar should be enabled during the Ally's Turn")
	prototype.combat_system.combat_state.current_actor_id = "player"
	check(prototype.combat_round_label.text.contains("ROUND"), "Combat header should display the current Round")
	check(not prototype.get_node("UILayer/Control/CombatLogPanel").visible, "Combat Log should start collapsed")
	prototype.toggle_combat_log()
	check(prototype.get_node("UILayer/Control/CombatLogPanel").visible, "Combat Log drawer should open on the left")
	prototype.toggle_combat_log()
	check(not prototype.get_node("UILayer/Control/CombatLogPanel").visible, "Combat Log drawer should close")
	prototype.get_node("UILayer/Control").add_log_message("Older action failed")
	prototype.get_node("UILayer/Control").add_log_message("Latest action failed")
	var log_entries: VBoxContainer = prototype.get_node("UILayer/Control/CombatLogPanel/Margin/VBoxContainer/Scroll/Entries")
	var latest_index := -1
	var older_index := -1
	for index in range(log_entries.get_child_count()):
		var details: String = log_entries.get_child(index).get_node("Margin/Content/Details").text
		if details == "Latest action failed": latest_index = index
		if details == "Older action failed": older_index = index
	check(latest_index >= 0 and older_index >= 0 and latest_index < older_index, "Combat Log should show newer Action Cards before older cards")
	var encounter_enemy_id: String = prototype.get_enemy_nodes()[0].state.id
	check(prototype.combat_system.combat_state.has_combatant(encounter_enemy_id), "Prototype should contain the configured encounter Enemy")
	check(prototype.combat_system.combat_state.turn_order.has(encounter_enemy_id), "Configured Enemy should participate in Turn Order")
	prototype.select_target_at(prototype.get_enemy_nodes()[0].global_position)
	prototype.get_node("UILayer/Control").update_ui()
	check(prototype.get_node("UILayer/Control/Enemy_panel").visible, "Selecting an Enemy displays its compact Target card")
	check(prototype.get_node("UILayer/Control/Enemy_panel/VBoxContainer/Name").text == prototype.get_enemy_nodes()[0].state.display_name, "Target panel should display the configured Enemy")
	prototype.clear_selected_target()
	check(prototype.selected_target_id.is_empty(), "Right-click target clearing should remove the selected Target id")
	check(not prototype.get_node("UILayer/Control/Enemy_panel").visible, "Target card should hide when no Target is selected")
	prototype.selected_target_id = encounter_enemy_id
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
	var single_ability = player.available_abilities.filter(func(ability): return ability != null and ability.id == "heal_or_harm").front()
	prototype.use_ability_from_menu(single_ability)
	check(prototype.pending_single_target_kind == "ability", "Single-target Ability should enter the shared targeting mode")
	check(prototype.selected_target_id.is_empty(), "Single-target Ability should not reuse the previous selected Target")
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
