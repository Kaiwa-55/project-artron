extends "res://scenes/prototype/prototype_ui_controller.gd"

func start_test_combat() -> void:
	combat_system = CombatSystem.new()
	var map_size_world: Vector2 = MAP_SIZE_FEET * combat_system.map_rules.world_units_per_foot
	combat_system.map_rules.set_playable_bounds(MAP_SIZE_FEET, -map_size_world * 0.5)
	$BattlefieldCamera.configure(combat_system.map_rules.playable_bounds, Vector2.ZERO)
	for obstacle in PROTOTYPE_OBSTACLES:
		combat_system.map_rules.add_circular_obstacle(obstacle.center, obstacle.radius, obstacle.label)
	move_mode = false
	selected_target_id = ""
	var player_data = PlayerData
	if get_tree().has_meta("created_character_data"):
		player_data = get_tree().get_meta("created_character_data")
	var player: CombatantState = player_data.create_combatant_state()
	var ally: CombatantState = PlayerData.create_combatant_state()
	ally.id = "ally"
	ally.display_name = "Ally"
	ally.position = Vector2(390, 370)
	$BattlefieldWorld/PlayerCharacter.setup(player)
	$BattlefieldWorld/AllyCharacter.setup(ally)
	var enemies: Array[CombatantState] = create_encounter_enemies(encounter_data if encounter_data != null else DefaultEncounter)
	setup_enemy_nodes(enemies)
	var combatants: Array[CombatantState] = [player, ally]
	combatants.append_array(enemies)
	combat_system.start_combat(combatants)
	if not enemies.is_empty():
		selected_target_id = enemies[0].id
	$UILayer/Control.reset_for_combat()
	$UILayer/Control.setup(combat_system)
	if not $UILayer/Control.reaction_choice_selected.is_connected(resolve_reaction_choice):
		$UILayer/Control.reaction_choice_selected.connect(resolve_reaction_choice)
	update_target_selection()
	run_enemy_ai_if_needed()


func create_encounter_enemies(data: Resource) -> Array[CombatantState]:
	var states: Array[CombatantState] = []
	var used_ids: Dictionary = {"player": true, "ally": true}
	if data == null:
		return states
	for enemy_data in data.enemies:
		if enemy_data == null:
			continue
		var state: CombatantState = enemy_data.create_combatant_state()
		var base_id: String = state.id if not state.id.is_empty() else "enemy"
		var unique_id := base_id
		var suffix := 2
		while used_ids.has(unique_id):
			unique_id = "%s_%d" % [base_id, suffix]
			suffix += 1
		state.id = unique_id
		used_ids[unique_id] = true
		states.append(state)
	return states


func setup_enemy_nodes(states: Array[CombatantState]) -> void:
	for node in enemy_nodes.values():
		if is_instance_valid(node) and node != $BattlefieldWorld/EnemyCharacter:
			node.queue_free()
	enemy_nodes.clear()
	$BattlefieldWorld/EnemyCharacter.visible = not states.is_empty()
	for index in range(states.size()):
		var node: Combatant = $BattlefieldWorld/EnemyCharacter if index == 0 else CombatantScript.new()
		if index > 0:
			node.name = "EnemyCharacter%d" % (index + 1)
			$BattlefieldWorld.add_child(node)
		node.setup(states[index])
		enemy_nodes[states[index].id] = node


func get_enemy_nodes() -> Array:
	return enemy_nodes.values()


func get_all_combatant_nodes() -> Array:
	var nodes: Array = [$BattlefieldWorld/PlayerCharacter, $BattlefieldWorld/AllyCharacter]
	nodes.append_array(get_enemy_nodes())
	return nodes


func refresh_combatant_nodes() -> void:
	for node in get_all_combatant_nodes():
		if is_instance_valid(node) and node.state != null:
			node.refresh_from_state()


func run_enemy_ai_if_needed() -> void:
	if movement_presentation != null and movement_presentation.defer_until_settled(run_enemy_ai_if_needed):
		return
	var state = combat_system.get_combat_state()
	if combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement():
		return
	if state.is_finished():
		return
	var enemy: CombatantState = state.get_current_actor()
	var player: CombatantState = get_player_controlled_actor()
	if enemy == null or player == null or enemy.team == player.team or enemy.is_dying():
		return
	if enemy_actions_this_turn >= 32:
		advance_enemy_turn()
		return
	var decision: Dictionary = enemy_ai.choose_decision(combat_system, enemy)
	if int(decision.get("type", EnemyAIScript.DecisionType.END_TURN)) == EnemyAIScript.DecisionType.END_TURN:
		$UILayer/Control.add_log_message("%s ends its turn: %s" % [enemy.display_name, decision.get("reason", "No action.")])
		advance_enemy_turn()
		return
	$UILayer/Control.add_log_message("%s: %s" % [enemy.display_name, decision.get("reason", "Acts.")])
	var result: ActionResult = enemy_ai.execute_decision(combat_system, decision)
	enemy_actions_this_turn += 1
	$UILayer/Control.record_action_result(result)
	if result.requires_reaction_choice:
		$UILayer/Control.show_reaction_prompt(result.reaction_prompt)
		$UILayer/Control.set_mode_hint("Resolve the pending Reaction before Enemy AI continues.")
		return
	var enemy_node = get_enemy_node(enemy.id)
	if enemy_node != null:
		enemy_node.refresh_from_state()
	if not result.success:
		advance_enemy_turn()
	else:
		call_deferred("run_enemy_ai_if_needed")


func advance_enemy_turn() -> void:
	if movement_presentation != null and movement_presentation.defer_until_settled(advance_enemy_turn):
		return
	enemy_actions_this_turn = 0
	if combat_system.get_combat_state().is_finished():
		return
	combat_system.advance_turn()
	var actor: CombatantState = combat_system.get_combat_state().get_current_actor()
	var player: CombatantState = combat_system.get_combat_state().get_combatant("player")
	if actor != null and player != null and actor.team != player.team:
		call_deferred("run_enemy_ai_if_needed")


func get_enemy_node(enemy_id: String):
	return enemy_nodes.get(enemy_id)


func resolve_reaction_choice(reaction_index: int) -> void:
	$UILayer/Control.hide_reaction_prompt()
	var result := combat_system.resolve_pending_reaction(reaction_index)
	$UILayer/Control.record_action_result(result)
	refresh_combatant_nodes()
	if result.requires_reaction_choice:
		$UILayer/Control.show_reaction_prompt(result.reaction_prompt)
		$UILayer/Control.set_mode_hint("Choose whether to use Step Back after the attack.")
		$UILayer/Control.update_ui()
		return
	if combat_system.has_pending_step_back_move():
		move_mode = true
		$UILayer/Control.set_mode_hint("Step Back: click a destination up to half your Speed away.")
		$UILayer/Control.update_ui()
		return
	var actor: CombatantState = combat_system.get_combat_state().get_current_actor()
	var player: CombatantState = get_player_controlled_actor()
	if actor != null and player != null and actor.team != player.team:
		call_deferred("run_enemy_ai_if_needed")
	else:
		$UILayer/Control.set_mode_hint("Choose an action.")
	$UILayer/Control.update_ui()


func select_target_at(mouse_position: Vector2) -> bool:
	var selected_node = $UILayer/Controllers/TargetingSelection.find_combatant_at(mouse_position, get_all_combatant_nodes(), combat_system.map_rules.world_units_per_foot)
	if selected_node != null:
		var combatant_node = selected_node
		selected_character_id = combatant_node.state.id
		var primary: CombatantState = combat_system.get_combat_state().get_combatant("player")
		if primary != null and combatant_node.state.team != primary.team:
			selected_target_id = combatant_node.state.id
		move_mode = false
		update_target_selection()
		$UILayer/Control.add_log_message("Character selected: %s." % combatant_node.state.display_name)
		if is_inactive_friendly_selected():
			$UILayer/Control.set_mode_hint("Viewing %s. Only the character whose Turn it is can use Actions." % combatant_node.state.display_name)
		$UILayer/Control.update_ui()
		return true
	return false


func update_target_selection() -> void:
	$UILayer/Controllers/TargetingSelection.apply_selection(get_all_combatant_nodes(), selected_character_id)
	var inspected: CombatantState = combat_system.get_combat_state().get_combatant(selected_character_id)
	var primary: CombatantState = combat_system.get_combat_state().get_combatant("player")
	var show_as_enemy: bool = inspected != null and primary != null and inspected.team != primary.team
	$UILayer/Control.set_selected_target(inspected.display_name if show_as_enemy else "None", inspected.id if show_as_enemy else "")
	refresh_essential_hud()


func get_displayed_party_member() -> CombatantState:
	if combat_system == null or combat_system.get_combat_state() == null:
		return null
	var state = combat_system.get_combat_state()
	var selected_character: CombatantState = state.get_combatant(selected_character_id)
	var primary: CombatantState = state.get_combatant("player")
	if selected_character != null and primary != null and selected_character.team == primary.team:
		return selected_character
	return get_player_controlled_actor()


func is_inactive_friendly_selected() -> bool:
	if selected_character_id.is_empty() or combat_system == null or combat_system.get_combat_state() == null:
		return false
	var state = combat_system.get_combat_state()
	var selected_character: CombatantState = state.get_combatant(selected_character_id)
	var primary: CombatantState = state.get_combatant("player")
	var current: CombatantState = state.get_current_actor()
	return selected_character != null and primary != null and current != null \
		and selected_character.team == primary.team and selected_character.id != current.id


func clear_selected_target() -> void:
	selected_target_id = ""
	selected_character_id = ""
	update_target_selection()
	$UILayer/Control.add_log_message("Target selection cleared.")
	$UILayer/Control.set_mode_hint("Choose an action or select a target.")


func move_player(destination: Vector2) -> void:
	var was_step_back := combat_system.has_pending_step_back_move()
	var was_shadow_step := combat_system.has_pending_ability_movement()
	var acting_enemy_id: String = combat_system.get_combat_state().current_actor_id
	super.move_player(destination)
	$BattlefieldWorld/AllyCharacter.refresh_from_state()
	if was_shadow_step and not combat_system.has_pending_ability_movement():
		$UILayer/Control.add_log_message("Shadow Step completed without triggering Reactions.")
	if was_step_back and acting_enemy_id != "player" and not combat_system.has_pending_step_back_move():
		call_deferred("run_enemy_ai_if_needed")


func _ready() -> void:
	super._ready()
	$UILayer/Controllers/CombatHUD.setup(self)
	$UILayer/Controllers/ActionBar.setup(self)
	$UILayer/Controllers/ReactionPrompt.setup($UILayer/Control)
	$UILayer/Controllers/CombatLog.setup($UILayer/Control)
	_apply_prototype_layout()
	_build_obstacle_visuals()
	_build_inventory_drawer()
	_build_level_up_panel()
	$UILayer/Control.update_ui()


func _build_obstacle_visuals() -> void:
	for obstacle in PROTOTYPE_OBSTACLES:
		var visual := ObstacleVisualScript.new()
		visual.name = String(obstacle.label).replace(" ", "")
		$BattlefieldWorld.add_child(visual)
		visual.setup(float(obstacle.radius), String(obstacle.label))
		visual.position = Vector2(obstacle.center)


func _process(_delta: float) -> void:
	if combat_system == null or combat_system.get_combat_state() == null:
		return
	var state = combat_system.get_combat_state()
	var reaction_locked: bool = combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement()
	inventory_button.disabled = reaction_locked
	if inventory_drawer != null and inventory_drawer.get_script() == CharacterPanelScript:
		var displayed_actor := get_displayed_party_member()
		if displayed_actor != null and inventory_drawer.combatant_id != displayed_actor.id:
			inventory_drawer.setup(combat_system, displayed_actor.id)
		var current_actor: CombatantState = state.get_current_actor()
		var viewing_out_of_turn: bool = displayed_actor != null and (current_actor == null or displayed_actor.id != current_actor.id)
		inventory_drawer.set_changes_locked(reaction_locked or state.is_finished() or not is_player_party_turn() or viewing_out_of_turn)
	if reaction_locked and inventory_drawer.visible:
		inventory_drawer.visible = false
	$UILayer/Controllers/CombatHUD.refresh()
	refresh_shadow_step_button()
	refresh_area_skill_button()
	refresh_level_up_button()
	$UILayer/Controllers/ActionBar.refresh()
	queue_redraw()


func refresh_end_turn_lock() -> void:
	var end_turn_button: Button = $"UILayer/Control/ActionSources/End Turn"
	var state = combat_system.get_combat_state()
	var interaction_busy: bool = is_movement_animating() \
		or combat_system.has_pending_reaction() \
		or combat_system.has_pending_step_back_move() \
		or combat_system.has_pending_ability_movement() \
		or pending_target_attack != null \
		or not pending_single_target_kind.is_empty() \
		or not ground_targeting_id.is_empty() \
		or is_inactive_friendly_selected()
	end_turn_button.disabled = state.is_finished() or not is_player_party_turn() or interaction_busy
	end_turn_button.tooltip_text = "Finish the current action first." if interaction_busy else "End the current character's turn."
	if reference_end_turn_button != null:
		reference_end_turn_button.disabled = end_turn_button.disabled
		reference_end_turn_button.tooltip_text = end_turn_button.tooltip_text


func _draw() -> void:
	if combat_system == null:
		return
	if pending_target_attack != null:
		draw_attack_targeting()
	if not pending_single_target_kind.is_empty():
		draw_single_targeting()
	if ground_targeting_id.is_empty():
		return
	var player: CombatantState = get_player_controlled_actor()
	var source = get_ground_targeting_data()
	if player == null or source == null:
		return
	var center := get_global_mouse_position()
	var scale_per_foot: float = combat_system.map_rules.world_units_per_foot
	var preview: Dictionary = combat_system.targeting_system.get_targeting_preview(player, center, source, combat_system.get_combat_state(), combat_system.map_rules)
	var outline := Color("c084fc") if preview.valid else Color("fb7185")
	var fill := Color(0.45, 0.2, 0.9, 0.18) if preview.valid else Color(0.9, 0.15, 0.2, 0.12)
	match source.area_shape:
		SkillData.AreaShape.CIRCLE:
			var radius: float = source.area_radius_feet * scale_per_foot
			draw_circle(center, radius, fill)
			draw_arc(center, radius, 0.0, TAU, 64, outline, 2.0)
		SkillData.AreaShape.LINE:
			var direction: Vector2 = player.position.direction_to(center)
			var finish: Vector2 = player.position + direction * source.line_length_feet * scale_per_foot
			draw_line(player.position, finish, outline, source.line_width_feet * scale_per_foot, true)
		SkillData.AreaShape.CONE:
			var direction_angle: float = player.position.direction_to(center).angle()
			var half_angle := deg_to_rad(source.cone_angle_degrees * 0.5)
			var radius: float = source.targeting_range_feet * scale_per_foot
			var points := PackedVector2Array([player.position])
			for step in range(25):
				var angle := lerpf(direction_angle - half_angle, direction_angle + half_angle, step / 24.0)
				points.append(player.position + Vector2.from_angle(angle) * radius)
			draw_colored_polygon(points, fill)
			draw_polyline(points, outline, 2.0)
	for target in preview.targets:
		var target_radius: float = combat_system.map_rules.get_combatant_radius_world_units(target) + 6.0
		draw_arc(target.position, target_radius, 0.0, TAU, 32, Color("facc15"), 4.0)
	draw_arc(player.position, source.targeting_range_feet * scale_per_foot, 0.0, TAU, 96, Color(0.22, 0.75, 1.0, 0.65), 2.0)
	$UILayer/Control.set_mode_hint("%s | %s | %d target(s) | Left-click confirm, right-click/Esc cancel" % [source.display_name, preview.failure_reason if not preview.valid else "Valid target point", preview.targets.size()])
