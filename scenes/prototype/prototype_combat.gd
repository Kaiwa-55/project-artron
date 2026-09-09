extends "res://scenes/prototype/prototype_ui_controller.gd"

const REWARD_SCENE := "res://scenes/run/RewardSelection.tscn"
const RUN_MAP_SCENE := "res://scenes/run/RunMap.tscn"

var post_combat_transition_started: bool = false

func start_test_combat() -> void:
	combat_system = CombatSystem.new()
	var active_encounter: Resource = get_active_encounter_data()
	var map_size_feet: Vector2 = active_encounter.map_size_feet if active_encounter != null else MAP_SIZE_FEET
	var map_size_world: Vector2 = map_size_feet * combat_system.map_rules.world_units_per_foot
	combat_system.map_rules.set_playable_bounds(map_size_feet, -map_size_world * 0.5)
	_configure_encounter_background(active_encounter, map_size_world)
	$BattlefieldCamera.configure(combat_system.map_rules.playable_bounds, Vector2.ZERO)
	for object_data in _get_encounter_objects(active_encounter):
		if String(object_data.get("kind", "")) != "obstacle" or not bool(object_data.get("blocks_movement", true)):
			continue
		var center: Vector2 = Vector2(object_data.get("position_feet", Vector2.ZERO)) * combat_system.map_rules.world_units_per_foot
		var radius: float = float(object_data.get("radius_feet", 0.0)) * combat_system.map_rules.world_units_per_foot
		combat_system.map_rules.add_circular_obstacle(center, radius, String(object_data.get("label", "Obstacle")))
	move_mode = false
	selected_target_id = ""
	var party: Array[CombatantState] = create_encounter_player_party(active_encounter)
	setup_party_nodes(party)
	var enemies: Array[CombatantState] = create_encounter_enemies(active_encounter)
	setup_enemy_nodes(enemies)
	var combatants: Array[CombatantState] = party.duplicate()
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


func _configure_encounter_background(data: Resource, map_size_world: Vector2) -> void:
	var map_sprite: Sprite2D = $BattlefieldWorld/BattlefieldBackground
	map_sprite.texture = data.battlefield_texture if data != null else null
	map_sprite.position = Vector2.ZERO
	if map_sprite.texture == null:
		map_sprite.scale = Vector2.ONE
		return
	var texture_size: Vector2 = map_sprite.texture.get_size()
	map_sprite.scale = Vector2(
		map_size_world.x / maxf(1.0, texture_size.x),
		map_size_world.y / maxf(1.0, texture_size.y)
	)


func get_active_encounter_data() -> Resource:
	if get_tree().has_meta("active_encounter_data"):
		var run_encounter = get_tree().get_meta("active_encounter_data")
		if run_encounter is EncounterDataScript:
			return run_encounter
	return encounter_data if encounter_data != null else DefaultEncounter


func _get_encounter_objects(data: Resource) -> Array[Dictionary]:
	return data.map_objects if data != null else []


func create_encounter_player_party(data: Resource) -> Array[CombatantState]:
	var states: Array[CombatantState] = []
	var entries: Array[Dictionary] = data.player_party if data != null else []
	if get_tree().has_meta("active_run_state"):
		var active_run = get_tree().get_meta("active_run_state")
		if active_run is RunState and not active_run.party_character_data.is_empty():
			entries = []
			for index in range(active_run.party_character_data.size()):
				var member: CharacterData = active_run.party_character_data[index]
				entries.append({"character": member, "id": "player" if index == 0 else "ally_%d" % index, "display_name": member.display_name, "use_created_character": false})
	if entries.is_empty():
		entries = [
			{"character": PlayerData, "id": "player", "display_name": "Player", "position_feet": Vector2(-40, -83.3333), "use_created_character": true},
			{"character": PlayerData, "id": "ally", "display_name": "Ally", "position_feet": Vector2(-60, -63.3333)},
		]
	var used_ids: Dictionary = {}
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var character_data = entry.get("character")
		if bool(entry.get("use_created_character", false)) and get_tree().has_meta("created_character_data"):
			character_data = get_tree().get_meta("created_character_data")
		if character_data == null:
			continue
		var state: CombatantState = character_data.create_combatant_state()
		var fallback_id := "player" if index == 0 else "ally_%d" % index
		var requested_id := String(entry.get("id", fallback_id))
		var unique_id := requested_id
		var suffix := 2
		while used_ids.has(unique_id):
			unique_id = "%s_%d" % [requested_id, suffix]
			suffix += 1
		state.id = unique_id
		state.display_name = String(entry.get("display_name", state.display_name))
		state.team = data.player_team if data != null else 1
		apply_active_run_bonuses(state)
		var spawn_position_feet: Vector2 = data.get_player_spawn_position_feet(index, entry) if data != null else Vector2(entry.get("position_feet", Vector2.ZERO))
		state.position = spawn_position_feet * combat_system.map_rules.world_units_per_foot
		used_ids[unique_id] = true
		states.append(state)
	return states


func apply_active_run_bonuses(state: CombatantState) -> void:
	if state == null or not get_tree().has_meta("active_run_state"):
		return
	var active_run = get_tree().get_meta("active_run_state")
	if not active_run is RunState:
		return
	state.max_hp_bonus += active_run.party_max_hp_bonus
	var progression_state: CombatantState = active_run.party_progression_states.get(state.id)
	if progression_state == null and state.id == "player":
		progression_state = active_run.player_progression_state
	if progression_state != null:
		apply_run_progression_state(state, progression_state)
	combat_system.refresh_stats(state)
	state.hp = state.max_hp


func apply_run_progression_state(target: CombatantState, source: CombatantState) -> void:
	target.level = source.level
	target.experience = source.experience
	target.ability_points = source.ability_points
	target.attribute_points = source.attribute_points
	target.progression_rewards_granted_through_level = source.progression_rewards_granted_through_level
	target.pending_level_up_choices = source.pending_level_up_choices.duplicate(true)
	target.selected_ability_ids = source.selected_ability_ids.duplicate()
	target.selected_level_attributes = source.selected_level_attributes.duplicate()
	target.strength = source.strength
	target.dexterity = source.dexterity
	target.constitution = source.constitution
	target.intelligence = source.intelligence
	target.wisdom = source.wisdom
	target.charisma = source.charisma
	target.base_max_hp = source.base_max_hp
	target.base_max_mana = source.base_max_mana
	target.ancestry_max_mana_bonus = source.ancestry_max_mana_bonus
	target.base_max_faith = source.base_max_faith
	target.max_faith = source.max_faith
	target.max_finishing_gauge = source.max_finishing_gauge
	target.base_speed = source.base_speed
	target.ancestry_id = source.ancestry_id
	target.ancestry_display_name = source.ancestry_display_name
	target.class_id = source.class_id
	target.class_display_name = source.class_display_name
	target.active_traits = source.active_traits.duplicate()
	target.granted_ability_ids = source.granted_ability_ids.duplicate()
	target.available_abilities = source.available_abilities.duplicate()
	target.equipped_abilities = source.equipped_abilities.duplicate()
	target.item_inventory = duplicate_item_inventory(source.item_inventory)
	target.set_meta("creation_rules_applied", true)
	var catalog = load("res://data/creation/default_creation_catalog.tres")
	for ability_id in target.selected_ability_ids:
		var ability = catalog.find_ability(ability_id)
		if ability != null and not target.available_abilities.has(ability):
			target.available_abilities.append(ability)
		if ability != null and not target.equipped_abilities.has(ability_id):
			target.equipped_abilities.append(ability_id)


func duplicate_item_inventory(source_inventory: Array[ItemStack]) -> Array[ItemStack]:
	var result: Array[ItemStack] = []
	for stack in source_inventory:
		if stack != null and stack.item != null and stack.quantity > 0:
			result.append(ItemStack.new(stack.item, stack.quantity))
	return result


func sync_run_item_inventories() -> void:
	if not get_tree().has_meta("active_run_state"):
		return
	var active_run = get_tree().get_meta("active_run_state")
	if not active_run is RunState:
		return
	for combatant in combat_system.get_combat_state().combatants.values():
		if combatant == null or not combat_system.is_player_controlled(combatant):
			continue
		var progression_state: CombatantState = active_run.party_progression_states.get(combatant.id)
		if progression_state != null:
			progression_state.item_inventory = duplicate_item_inventory(combatant.item_inventory)


func setup_party_nodes(states: Array[CombatantState]) -> void:
	for node in party_nodes.values():
		if is_instance_valid(node) and node not in [$BattlefieldWorld/PlayerCharacter, $BattlefieldWorld/AllyCharacter]:
			node.queue_free()
	party_nodes.clear()
	$BattlefieldWorld/PlayerCharacter.visible = states.size() > 0
	$BattlefieldWorld/AllyCharacter.visible = states.size() > 1
	for index in range(states.size()):
		var node: Combatant
		if index == 0:
			node = $BattlefieldWorld/PlayerCharacter
		elif index == 1:
			node = $BattlefieldWorld/AllyCharacter
		else:
			node = CombatantScript.new()
			node.name = "PartyCharacter%d" % (index + 1)
			$BattlefieldWorld.add_child(node)
		node.setup(states[index])
		party_nodes[states[index].id] = node


func create_encounter_enemies(data: Resource) -> Array[CombatantState]:
	var states: Array[CombatantState] = []
	var used_ids: Dictionary = {}
	for party_id in party_nodes:
		used_ids[party_id] = true
	if data == null:
		return states
	for enemy_data in data.enemies:
		if enemy_data == null:
			continue
		var state: CombatantState = enemy_data.create_combatant_state()
		# CharacterData positions predate centered encounter coordinates and are
		# authored from the map's top-left corner. Convert them at the boundary.
		if state.position != Vector2.ZERO:
			state.position += combat_system.map_rules.playable_bounds.position
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
	var nodes: Array = party_nodes.values()
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


func has_selected_character() -> bool:
	return not selected_character_id.is_empty()


func move_player(destination: Vector2) -> void:
	var was_step_back := combat_system.has_pending_step_back_move()
	var was_shadow_step := combat_system.has_pending_ability_movement()
	var acting_enemy_id: String = combat_system.get_combat_state().current_actor_id
	super.move_player(destination)
	refresh_combatant_nodes()
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
	$UILayer/Control/DefeatOverlay/Panel/Margin/Column/RestartButton.pressed.connect(restart_run_after_defeat)
	$UILayer/Control/DefeatOverlay.hide()
	$UILayer/Control.update_ui()


func _build_obstacle_visuals() -> void:
	var active_encounter: Resource = get_active_encounter_data()
	for object_data in _get_encounter_objects(active_encounter):
		if String(object_data.get("kind", "")) != "obstacle":
			continue
		var obstacle := {
			"center": Vector2(object_data.get("position_feet", Vector2.ZERO)) * combat_system.map_rules.world_units_per_foot,
			"radius": float(object_data.get("radius_feet", 0.0)) * combat_system.map_rules.world_units_per_foot,
			"label": String(object_data.get("label", "Obstacle")),
		}
		var visual := ObstacleVisualScript.new()
		visual.name = String(object_data.get("id", obstacle.label)).replace(" ", "")
		$BattlefieldWorld.add_child(visual)
		visual.setup(float(obstacle.radius), String(obstacle.label))
		visual.position = Vector2(obstacle.center)


func _process(_delta: float) -> void:
	if combat_system == null or combat_system.get_combat_state() == null:
		return
	var state = combat_system.get_combat_state()
	if state.is_finished() and state.combat_result == CombatEnums.CombatResult.VICTORY and get_tree().has_meta("active_run_state") and not post_combat_transition_started:
		post_combat_transition_started = true
		sync_run_item_inventories()
		open_reward_after_victory()
	$UILayer/Control/DefeatOverlay.visible = state.is_finished() and state.combat_result == CombatEnums.CombatResult.DEFEAT
	var reaction_locked: bool = combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement()
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
	$UILayer/Controllers/ActionBar.refresh()
	queue_redraw()


func open_reward_after_victory() -> void:
	await get_tree().create_timer(0.75).timeout
	var change_error := get_tree().change_scene_to_file(REWARD_SCENE)
	if change_error != OK:
		post_combat_transition_started = false
		$UILayer/Control.add_log_message("Could not open Reward Selection: %s" % error_string(change_error))


func restart_run_after_defeat() -> void:
	var previous_seed := 0
	if get_tree().has_meta("active_run_state"):
		var previous_run = get_tree().get_meta("active_run_state")
		if previous_run is RunState:
			previous_seed = previous_run.seed
			if not previous_run.party_character_data.is_empty():
				get_tree().set_meta("active_party_characters", previous_run.party_character_data.duplicate())
	get_tree().remove_meta("active_run_state")
	get_tree().remove_meta("active_run_node_id")
	get_tree().remove_meta("active_encounter_data")
	get_tree().set_meta("restart_run_seed", RunState.generate_restart_seed(previous_seed))
	get_tree().set_meta("restart_run_at_level_one", true)
	var change_error := get_tree().change_scene_to_file(RUN_MAP_SCENE)
	if change_error != OK:
		$UILayer/Control.add_log_message("Could not restart Run: %s" % error_string(change_error))


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
	draw_active_auras()
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
	var effective_range: float = combat_system.skill_system.get_effective_range_feet(player, source) if ground_targeting_kind == "skill" else source.targeting_range_feet
	var preview: Dictionary = combat_system.targeting_system.get_targeting_preview(player, center, source, combat_system.get_combat_state(), combat_system.map_rules, effective_range)
	var outline := Color("c084fc") if preview.valid else Color("fb7185")
	var fill := Color(0.45, 0.2, 0.9, 0.18) if preview.valid else Color(0.9, 0.15, 0.2, 0.12)
	match source.area_shape:
		SkillData.AreaShape.CIRCLE:
			var radius: float = source.area_radius_feet * scale_per_foot
			draw_circle(center, radius, fill)
			draw_arc(center, radius, 0.0, TAU, 64, outline, 2.0)
		SkillData.AreaShape.LINE:
			var direction: Vector2 = player.position.direction_to(center)
			var finish: Vector2 = player.position + direction * effective_range * scale_per_foot
			draw_line(player.position, finish, outline, source.line_width_feet * scale_per_foot, true)
		SkillData.AreaShape.CONE:
			var direction_angle: float = player.position.direction_to(center).angle()
			var half_angle := deg_to_rad(source.cone_angle_degrees * 0.5)
			var radius: float = effective_range * scale_per_foot
			var points := PackedVector2Array([player.position])
			for step in range(25):
				var angle := lerpf(direction_angle - half_angle, direction_angle + half_angle, step / 24.0)
				points.append(player.position + Vector2.from_angle(angle) * radius)
			draw_colored_polygon(points, fill)
			draw_polyline(points, outline, 2.0)
	for target in preview.targets:
		var target_radius: float = combat_system.map_rules.get_combatant_radius_world_units(target) + 6.0
		draw_arc(target.position, target_radius, 0.0, TAU, 32, Color("facc15"), 4.0)
	draw_arc(player.position, effective_range * scale_per_foot, 0.0, TAU, 96, Color(0.22, 0.75, 1.0, 0.65), 2.0)
	$UILayer/Control.set_mode_hint("%s | %s | %d target(s) | Left-click confirm, right-click/Esc cancel" % [source.display_name, preview.failure_reason if not preview.valid else "Valid target point", preview.targets.size()])


func draw_active_auras() -> void:
	var state = combat_system.get_combat_state()
	if state == null:
		return
	var scale_per_foot: float = combat_system.map_rules.world_units_per_foot
	for source in state.combatants.values():
		if source == null or source.is_dying():
			continue
		for instance in source.effects:
			if instance == null or instance.data == null or instance.data.aura_radius_feet <= 0.0:
				continue
			var radius: float = instance.data.aura_radius_feet * scale_per_foot
			var fill: Color = instance.data.aura_color
			var outline := Color(fill.r, fill.g, fill.b, minf(fill.a + 0.55, 1.0))
			draw_circle(source.position, radius, fill)
			draw_arc(source.position, radius, 0.0, TAU, 64, outline, 2.0)
