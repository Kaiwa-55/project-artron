extends "res://scenes/combat/combat_arena.gd"

const LevelUpAbilities: Array = [
	preload("res://data/ability/human_adapt.tres"),
	preload("res://data/ability/build_up_body.tres"),
	preload("res://data/ability/killer_instinct.tres"),
	preload("res://data/ability/combo_techniques.tres"),
	preload("res://data/ability/step_back.tres"),
	preload("res://data/ability/shadow_step.tres"),
	preload("res://data/ability/martial_training.tres"),
	preload("res://data/ability/long_reach.tres"),
	preload("res://data/ability/defensive_stance.tres")
]
const CharacterPanelScene := preload("res://scenes/ui/CharacterPanel.tscn")
const CharacterPanelScript := preload("res://scenes/ui/character_panel.gd")
const EnemyAIScript := preload("res://combat/ai/enemy_ai_system.gd")
const ObstacleVisualScript := preload("res://scenes/combat/obstacle_visual.gd")
const CombatantScript := preload("res://entities/combatant.gd")
const DefaultEncounter := preload("res://data/encounter/prototype_encounter.tres")
const EncounterDataScript := preload("res://data/encounter/encounter_data.gd")

const PROTOTYPE_OBSTACLES: Array[Dictionary] = [
	{"center": Vector2(590, 365), "radius": 34.0, "label": "Stone Pillar"}
]

var inventory_drawer: PanelContainer
var inventory_list: VBoxContainer
var inventory_button: Button
var inventory_status: Label
var character_summary: VBoxContainer
var character_page_title: Label
var character_tab_buttons: Dictionary = {}
var character_active_tab: String = "abilities"
var combat_log_button: Button
var essential_player_status: Label
var essential_target_status: Label
var essential_turn_status: Label
var shadow_step_button: Button
var area_skill_button: Button
var area_action_buttons: Dictionary = {}
var level_up_button: Button
var level_up_panel: PanelContainer
var level_up_list: VBoxContainer
var level_up_summary: Label
var combat_round_label: Label
var initiative_row: HBoxContainer
var initiative_signature: String = ""
var action_dock_links: Dictionary = {}
var reference_player_panel: PanelContainer
var reference_turn_panel: PanelContainer
var reference_end_turn_button: Button
var action_menu_panel: PanelContainer
var action_menu_title: Label
var action_menu_list: VBoxContainer
var action_category_buttons: Dictionary = {}
var enemy_ai = EnemyAIScript.new()
var enemy_actions_this_turn: int = 0
@export var encounter_data: Resource
var enemy_nodes: Dictionary = {}
var selected_character_id: String = ""


func start_test_combat() -> void:
	combat_system = CombatSystem.new()
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
	$PlayerCharacter.setup(player)
	$AllyCharacter.setup(ally)
	var enemies: Array[CombatantState] = create_encounter_enemies(encounter_data if encounter_data != null else DefaultEncounter)
	setup_enemy_nodes(enemies)
	var combatants: Array[CombatantState] = [player, ally]
	combatants.append_array(enemies)
	combat_system.start_combat(combatants)
	if not enemies.is_empty():
		selected_target_id = enemies[0].id
	$Control.reset_for_combat()
	$Control.setup(combat_system)
	if not $Control.reaction_choice_selected.is_connected(resolve_reaction_choice):
		$Control.reaction_choice_selected.connect(resolve_reaction_choice)
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
		if is_instance_valid(node) and node != $EnemyCharacter:
			node.queue_free()
	enemy_nodes.clear()
	$EnemyCharacter.visible = not states.is_empty()
	for index in range(states.size()):
		var node: Combatant = $EnemyCharacter if index == 0 else CombatantScript.new()
		if index > 0:
			node.name = "EnemyCharacter%d" % (index + 1)
			add_child(node)
		node.setup(states[index])
		enemy_nodes[states[index].id] = node


func get_enemy_nodes() -> Array:
	return enemy_nodes.values()


func get_all_combatant_nodes() -> Array:
	var nodes: Array = [$PlayerCharacter, $AllyCharacter]
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
		$Control.add_log_message("%s ends its turn: %s" % [enemy.display_name, decision.get("reason", "No action.")])
		advance_enemy_turn()
		return
	$Control.add_log_message("%s: %s" % [enemy.display_name, decision.get("reason", "Acts.")])
	var result: ActionResult = enemy_ai.execute_decision(combat_system, decision)
	enemy_actions_this_turn += 1
	$Control.record_action_result(result)
	if result.requires_reaction_choice:
		$Control.show_reaction_prompt(result.reaction_prompt)
		$Control.set_mode_hint("Resolve the pending Reaction before Enemy AI continues.")
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
	$Control.hide_reaction_prompt()
	var result := combat_system.resolve_pending_reaction(reaction_index)
	$Control.record_action_result(result)
	refresh_combatant_nodes()
	if result.requires_reaction_choice:
		$Control.show_reaction_prompt(result.reaction_prompt)
		$Control.set_mode_hint("Choose whether to use Step Back after the attack.")
		$Control.update_ui()
		return
	if combat_system.has_pending_step_back_move():
		move_mode = true
		$Control.set_mode_hint("Step Back: click a destination up to half your Speed away.")
		$Control.update_ui()
		return
	var actor: CombatantState = combat_system.get_combat_state().get_current_actor()
	var player: CombatantState = get_player_controlled_actor()
	if actor != null and player != null and actor.team != player.team:
		call_deferred("run_enemy_ai_if_needed")
	else:
		$Control.set_mode_hint("Choose an action.")
	$Control.update_ui()


func select_target_at(mouse_position: Vector2) -> bool:
	for combatant_node in get_all_combatant_nodes():
		if combatant_node.state == null or combatant_node.state.is_dying():
			continue
		var radius: float = combatant_node.state.collision_radius_feet * combat_system.map_rules.world_units_per_foot
		if mouse_position.distance_to(combatant_node.global_position) <= radius:
			selected_character_id = combatant_node.state.id
			var primary: CombatantState = combat_system.get_combat_state().get_combatant("player")
			if primary != null and combatant_node.state.team != primary.team:
				selected_target_id = combatant_node.state.id
			move_mode = false
			update_target_selection()
			$Control.add_log_message("Character selected: %s." % combatant_node.state.display_name)
			if is_inactive_friendly_selected():
				$Control.set_mode_hint("Viewing %s. Only the character whose Turn it is can use Actions." % combatant_node.state.display_name)
			$Control.update_ui()
			return true
	return false


func update_target_selection() -> void:
	$PlayerCharacter.set_selected($PlayerCharacter.state != null and $PlayerCharacter.state.id == selected_character_id)
	$AllyCharacter.set_selected($AllyCharacter.state != null and $AllyCharacter.state.id == selected_character_id)
	for enemy_node in get_enemy_nodes():
		enemy_node.set_selected(enemy_node.state != null and enemy_node.state.id == selected_character_id)
	var inspected: CombatantState = combat_system.get_combat_state().get_combatant(selected_character_id)
	var primary: CombatantState = combat_system.get_combat_state().get_combatant("player")
	var show_as_enemy: bool = inspected != null and primary != null and inspected.team != primary.team
	$Control.set_selected_target(inspected.display_name if show_as_enemy else "None", inspected.id if show_as_enemy else "")
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
	$Control.add_log_message("Target selection cleared.")
	$Control.set_mode_hint("Choose an action or select a target.")


func move_player(destination: Vector2) -> void:
	var was_step_back := combat_system.has_pending_step_back_move()
	var was_shadow_step := combat_system.has_pending_ability_movement()
	var acting_enemy_id: String = combat_system.get_combat_state().current_actor_id
	super.move_player(destination)
	$AllyCharacter.refresh_from_state()
	if was_shadow_step and not combat_system.has_pending_ability_movement():
		$Control.add_log_message("Shadow Step completed without triggering Reactions.")
	if was_step_back and acting_enemy_id != "player" and not combat_system.has_pending_step_back_move():
		call_deferred("run_enemy_ai_if_needed")


func _ready() -> void:
	super._ready()
	_apply_prototype_layout()
	_build_obstacle_visuals()
	_build_inventory_drawer()
	_build_level_up_panel()
	$Control.update_ui()


func _build_obstacle_visuals() -> void:
	var battlefield: Control = $Control/Battlefield
	for obstacle in PROTOTYPE_OBSTACLES:
		var visual := ObstacleVisualScript.new()
		visual.name = String(obstacle.label).replace(" ", "")
		battlefield.add_child(visual)
		visual.position = Vector2(obstacle.center) - battlefield.position
		visual.setup(float(obstacle.radius), String(obstacle.label))
		visual.position += Vector2(obstacle.center) - battlefield.position


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
	refresh_essential_hud()
	refresh_shadow_step_button()
	refresh_area_skill_button()
	refresh_level_up_button()
	refresh_initiative_bar()
	refresh_end_turn_lock()
	refresh_action_dock()
	queue_redraw()


func refresh_end_turn_lock() -> void:
	var end_turn_button: Button = $"Control/ActionSources/End Turn"
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
	$Control.set_mode_hint("%s | %s | %d target(s) | Left-click confirm, right-click/Esc cancel" % [source.display_name, preview.failure_reason if not preview.valid else "Valid target point", preview.targets.size()])


func _apply_prototype_layout() -> void:
	RenderingServer.set_default_clear_color(Color("090e12"))
	$Control/Header/Title.text = "PROJECT ARTON"
	$Control/Header/Title.add_theme_color_override("font_color", Color("eee3d2"))
	$Control/Header/Guide.visible = false
	$Control/Battlefield/Label.text = "BATTLEFIELD  |  Select Move, then click a destination"
	$Control/CombatLogPanel/VBoxContainer/ModeHint.add_theme_color_override("font_color", Color("7dd3fc"))
	$Control/Enemy_panel/PanelTitle.text = "TARGET"
	$Control/Enemy_panel.visible = true
	$Control/Enemy_panel.position = Vector2(744, 88)
	$Control/Enemy_panel.size = Vector2(241, 178)
	$Control/Enemy_panel/PanelTitle.text = "SELECTED TARGET"
	$Control/Enemy_panel/VBoxContainer.position = Vector2(14, 44)
	$Control/Enemy_panel/VBoxContainer.size = Vector2(213, 122)
	for child in $Control/Enemy_panel/VBoxContainer.get_children():
		child.visible = child.name in ["Name", "Hp", "Effects"]
	$Control/Battlefield.position = Vector2(20, 82)
	$Control/Battlefield.size = Vector2(1240, 472)
	$Control/Battlefield/Label.visible = false
	$Control/CombatLogPanel.position = Vector2(20, 84)
	$Control/CombatLogPanel.size = Vector2(445, 610)
	$Control/CombatLogPanel.z_index = 18
	$Control/CombatLogPanel.visible = false
	$Control/CombatLogPanel/VBoxContainer.position = Vector2(14, 12)
	$Control/CombatLogPanel/VBoxContainer.size = Vector2(417, 580)
	$Control/CombatLogPanel/VBoxContainer/Entries.custom_minimum_size = Vector2(0, 465)
	$Control/ReactionPrompt.z_index = 30
	$Control/Header.z_index = 10
	$Control/Enemy_panel.z_index = 10
	style_panel($Control/Header, Color("151d23"), Color("806027"), 2)
	style_panel($Control/Enemy_panel, Color("171d22"), Color("d5a84c"), 3)
	style_panel($Control/CombatLogPanel, Color("10161b"), Color("59636a"), 3)
	style_panel($Control/ReactionPrompt, Color("171d22"), Color("d5a84c"), 3)
	for button in $Control/ActionSources.get_children():
		if button is Button:
			style_action_button(button)
	_build_shadow_step_button()
	_build_area_skill_button()
	_build_combat_log_toggle()
	_build_essential_hud()
	_build_action_dock()
	_build_initiative_bar()
	_apply_combat_typography()


func _build_initiative_bar() -> void:
	var timeline := HBoxContainer.new()
	timeline.name = "InitiativeTimeline"
	timeline.position = Vector2(300, 5)
	timeline.size = Vector2(570, 48)
	timeline.alignment = BoxContainer.ALIGNMENT_CENTER
	timeline.add_theme_constant_override("separation", 8)
	$Control/Header.add_child(timeline)
	combat_round_label = Label.new()
	combat_round_label.custom_minimum_size = Vector2(115, 42)
	combat_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combat_round_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combat_round_label.add_theme_color_override("font_color", Color("d5a84c"))
	combat_round_label.add_theme_font_size_override("font_size", 14)
	timeline.add_child(combat_round_label)
	var separator := VSeparator.new()
	separator.custom_minimum_size = Vector2(1, 36)
	timeline.add_child(separator)
	initiative_row = HBoxContainer.new()
	initiative_row.alignment = BoxContainer.ALIGNMENT_CENTER
	initiative_row.add_theme_constant_override("separation", 5)
	timeline.add_child(initiative_row)
	refresh_initiative_bar(true)


func refresh_initiative_bar(force: bool = false) -> void:
	if initiative_row == null or combat_system == null or combat_system.get_combat_state() == null:
		return
	var state = combat_system.get_combat_state()
	combat_round_label.text = "ROUND %d\n%s TURN" % [state.current_round, state.current_actor_id.to_upper()]
	var signature := "%s|%s|%d" % [",".join(state.turn_order), state.current_actor_id, state.current_round]
	if not force and signature == initiative_signature:
		return
	initiative_signature = signature
	for child in initiative_row.get_children():
		initiative_row.remove_child(child)
		child.queue_free()
	for index in range(state.turn_order.size()):
		var actor_id: String = state.turn_order[index]
		var actor: CombatantState = state.get_combatant(actor_id)
		if actor == null:
			continue
		var chip := Button.new()
		chip.custom_minimum_size = Vector2(38, 38)
		chip.text = actor.display_name.left(1).to_upper()
		chip.tooltip_text = "%d. %s%s" % [index + 1, actor.display_name, " - Current Turn" if actor_id == state.current_actor_id else ""]
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		style_initiative_chip(chip, actor_id == state.current_actor_id, actor.team != state.get_combatant("player").team)
		initiative_row.add_child(chip)
		if index < state.turn_order.size() - 1:
			var arrow := Label.new()
			arrow.text = ">"
			arrow.add_theme_color_override("font_color", Color("a99d8b"))
			initiative_row.add_child(arrow)


func style_initiative_chip(button: Button, current: bool, enemy: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1d262d")
	style.border_color = Color("d5a84c") if current else (Color("b74742") if enemy else Color("5797aa"))
	style.set_border_width_all(2 if current else 1)
	style.set_corner_radius_all(19)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override("font_color", Color("d5a84c") if current else Color("eee3d2"))


func _apply_combat_typography() -> void:
	$Control/Enemy_panel/PanelTitle.add_theme_color_override("font_color", Color("d5a84c"))
	$Control/Battlefield/Label.add_theme_color_override("font_color", Color("a99d8b"))
	$Control/ReactionPrompt/VBoxContainer/Title.add_theme_color_override("font_color", Color("d5a84c"))


func _build_shadow_step_button() -> void:
	shadow_step_button = Button.new()
	shadow_step_button.name = "ShadowStep"
	shadow_step_button.custom_minimum_size = Vector2(0, 36)
	shadow_step_button.text = "Shadow Step (1 AP)"
	shadow_step_button.tooltip_text = "Move up to 15 feet without triggering Reactions. Once per turn."
	shadow_step_button.pressed.connect(begin_shadow_step)
	$Control/ActionSources.add_child(shadow_step_button)
	style_action_button(shadow_step_button)
	refresh_shadow_step_button()


func _build_area_skill_button() -> void:
	area_action_buttons.clear()
	var player: CombatantState = get_player_controlled_actor()
	for skill in player.available_skills:
		if skill != null and skill.target_mode == SkillData.TargetMode.GROUND and skill.area_shape != SkillData.AreaShape.NONE:
			_add_area_action_button("skill", skill)
	for ability in combat_system.ability_system.get_active_abilities(player):
		if ability != null and ability.target_mode == AbilityData.TargetMode.GROUND and ability.area_shape != AbilityData.AreaShape.NONE:
			_add_area_action_button("ability", ability)
	area_skill_button = area_action_buttons.get("skill:arcane_burst")
	refresh_area_skill_button()


func _add_area_action_button(kind: String, source) -> void:
	var button := Button.new()
	button.name = "Area_%s_%s" % [kind, source.id]
	button.custom_minimum_size = Vector2(0, 36)
	button.tooltip_text = source.description
	button.pressed.connect(begin_ground_targeting.bind(kind, source.id))
	$Control/ActionSources.add_child(button)
	style_action_button(button)
	area_action_buttons["%s:%s" % [kind, source.id]] = button


func refresh_area_skill_button() -> void:
	if combat_system == null or combat_system.get_combat_state() == null:
		return
	var player: CombatantState = get_player_controlled_actor()
	var actor_id := player.id if player != null else ""
	for key in area_action_buttons:
		var parts: PackedStringArray = String(key).split(":", false, 1)
		var kind := parts[0]
		var source_id := parts[1]
		var source = combat_system.get_ground_skill(player, source_id) if kind == "skill" else combat_system.ability_system.get_available_ability(player, source_id)
		var button: Button = area_action_buttons[key]
		if source == null:
			button.visible = false
			continue
		var validation: ActionResult = combat_system.validate_ground_skill_start(actor_id, source_id) if kind == "skill" else combat_system.validate_ground_ability_start(actor_id, source_id)
		var shape_name: String = ["None", "Circle", "Line", "Cone"][source.area_shape]
		button.text = "%s — %s" % [source.display_name, shape_name]
		button.disabled = not validation.success
		button.tooltip_text = source.description if validation.success else validation.failure_reason


func cast_ground_skill(target_point: Vector2) -> void:
	super.cast_ground_skill(target_point)
	refresh_combatant_nodes()
	refresh_area_skill_button()


func confirm_ground_targeting(target_point: Vector2) -> void:
	super.confirm_ground_targeting(target_point)
	refresh_combatant_nodes()
	refresh_area_skill_button()


func begin_shadow_step() -> void:
	var result := combat_system.begin_ability_movement(get_player_controlled_actor_id(), "shadow_step")
	if result.success:
		move_mode = true
		$Control.set_mode_hint("Shadow Step: click a destination up to 15 ft away.")
		$Control.add_log_message("Shadow Step ready: choose a destination.")
	else:
		$Control.add_log_message("Shadow Step failed: %s" % result.failure_reason)
	$Control.update_ui()
	refresh_shadow_step_button()


func refresh_shadow_step_button() -> void:
	if shadow_step_button == null or combat_system == null or combat_system.get_combat_state() == null:
		return
	var state = combat_system.get_combat_state()
	var player: CombatantState = get_player_controlled_actor()
	var ability = combat_system.ability_system.get_available_ability(player, "shadow_step") if player != null else null
	shadow_step_button.visible = ability != null
	if ability == null:
		return
	var used: int = int(player.ability_uses_this_turn.get("shadow_step", 0))
	shadow_step_button.text = "Shadow Step (Used)" if used >= ability.uses_per_turn else "Shadow Step (1 AP)"
	shadow_step_button.disabled = state.is_finished() or not is_player_party_turn() or player.level < ability.required_level or not player.equipped_abilities.has("shadow_step") or player.ap < ability.ap_cost or used >= ability.uses_per_turn or player.has_status("rooted") or combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement()


func _build_combat_log_toggle() -> void:
	combat_log_button = Button.new()
	combat_log_button.text = "COMBAT LOG"
	combat_log_button.position = Vector2(1060, 28)
	combat_log_button.size = Vector2(120, 34)
	combat_log_button.z_index = 20
	style_action_button(combat_log_button)
	combat_log_button.pressed.connect(toggle_combat_log)
	$Control.add_child(combat_log_button)


func _build_level_up_panel() -> void:
	level_up_button = Button.new()
	level_up_button.name = "LevelUpButton"
	level_up_button.position = Vector2(920, 28)
	level_up_button.size = Vector2(130, 34)
	level_up_button.z_index = 20
	level_up_button.pressed.connect(toggle_level_up_panel)
	style_action_button(level_up_button)
	$Control.add_child(level_up_button)

	level_up_panel = PanelContainer.new()
	level_up_panel.name = "LevelUpPanel"
	level_up_panel.position = Vector2(300, 76)
	level_up_panel.size = Vector2(650, 620)
	level_up_panel.z_index = 40
	level_up_panel.visible = false
	style_panel(level_up_panel, Color("101a2a"), Color("a78bfa"), 14)
	$Control.add_child(level_up_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	level_up_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "LEVEL UP CHOICES"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(toggle_level_up_panel)
	header.add_child(close)
	level_up_summary = Label.new()
	level_up_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	level_up_summary.add_theme_color_override("font_color", Color("ddd6fe"))
	column.add_child(level_up_summary)
	column.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	level_up_list = VBoxContainer.new()
	level_up_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_up_list.add_theme_constant_override("separation", 8)
	scroll.add_child(level_up_list)
	refresh_level_up_button()


func toggle_level_up_panel() -> void:
	if level_up_panel == null:
		return
	level_up_panel.visible = not level_up_panel.visible
	if level_up_panel.visible:
		if inventory_drawer != null:
			inventory_drawer.visible = false
		refresh_level_up_panel()


func refresh_level_up_button() -> void:
	if level_up_button == null or combat_system == null or combat_system.get_combat_state() == null:
		return
	var player: CombatantState = get_player_controlled_actor()
	if player == null:
		return
	var pending: bool = combat_system.progression_system.has_pending_choices(player)
	level_up_button.text = "LEVEL UP (%d)" % (player.ability_points + player.attribute_points) if pending else "PROGRESSION"
	level_up_button.disabled = combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement()


func refresh_level_up_panel() -> void:
	if level_up_list == null:
		return
	for child in level_up_list.get_children():
		child.queue_free()
	var player: CombatantState = combat_system.get_combat_state().get_combatant("player")
	if player == null:
		return
	level_up_summary.text = "Level %d   |   XP %d   |   Ability Points %d   |   Attribute Points %d" % [player.level, player.experience, player.ability_points, player.attribute_points]
	add_level_up_heading("LEARN ABILITY")
	for ability in LevelUpAbilities:
		add_level_up_ability(player, ability)
	add_level_up_heading("INCREASE ATTRIBUTE")
	if player.attribute_points <= 0:
		add_level_up_note("No Attribute Points available.")
	else:
		var attributes := [
			["Strength", AttributeTypes.Type.STRENGTH, player.strength],
			["Dexterity", AttributeTypes.Type.DEXTERITY, player.dexterity],
			["Constitution", AttributeTypes.Type.CONSTITUTION, player.constitution],
			["Intelligence", AttributeTypes.Type.INTELLIGENCE, player.intelligence],
			["Wisdom", AttributeTypes.Type.WISDOM, player.wisdom],
			["Charisma", AttributeTypes.Type.CHARISMA, player.charisma]
		]
		for entry in attributes:
			var button := Button.new()
			button.text = "%s %d  →  %d" % [entry[0], entry[2], entry[2] + 1]
			button.pressed.connect(choose_level_up_attribute.bind(entry[1]))
			level_up_list.add_child(button)


func add_level_up_heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("c4b5fd"))
	level_up_list.add_child(label)


func add_level_up_note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("94a3b8"))
	level_up_list.add_child(label)


func add_level_up_ability(player: CombatantState, ability: AbilityData) -> void:
	var card := VBoxContainer.new()
	var learned := player.selected_ability_ids.has(ability.id) or player.granted_ability_ids.has(ability.id)
	var reason: String = combat_system.progression_system.get_learn_ability_failure_reason(player, ability)
	var button := Button.new()
	button.text = "%s — %d Point%s" % [ability.display_name, ability.ability_point_cost, "s" if ability.ability_point_cost != 1 else ""]
	button.disabled = not reason.is_empty()
	if learned:
		button.text = "%s — Learned" % ability.display_name
	button.tooltip_text = ability.description if reason.is_empty() else reason
	button.pressed.connect(learn_level_up_ability.bind(ability))
	card.add_child(button)
	var details := Label.new()
	details.text = ability.description if reason.is_empty() else reason
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_color_override("font_color", Color("94a3b8") if not reason.is_empty() else Color("fda4af"))
	card.add_child(details)
	level_up_list.add_child(card)


func learn_level_up_ability(ability: AbilityData) -> void:
	var player: CombatantState = get_player_controlled_actor()
	var result = combat_system.progression_system.learn_ability(player, ability)
	if result.success:
		$Control.add_log_message("Learned %s. %d Ability Point(s) remain." % [result.ability_name, result.remaining_ability_points])
		combat_system.ability_system.sync_granted_reactions(player)
	else:
		$Control.add_log_message("Cannot learn Ability: %s" % result.failure_reason)
	$Control.update_ui()
	refresh_level_up_panel()
	refresh_level_up_button()


func choose_level_up_attribute(attribute: AttributeTypes.Type) -> void:
	var player: CombatantState = get_player_controlled_actor()
	var result = combat_system.progression_system.increase_attribute(player, attribute)
	if result.success:
		$Control.add_log_message("Attribute increased to %d." % result.new_value)
	else:
		$Control.add_log_message("Cannot increase Attribute: %s" % result.failure_reason)
	$Control.update_ui()
	refresh_level_up_panel()
	refresh_level_up_button()


func toggle_combat_log() -> void:
	$Control/CombatLogPanel.visible = not $Control/CombatLogPanel.visible
	combat_log_button.text = "CLOSE LOG" if $Control/CombatLogPanel.visible else "COMBAT LOG"


func _build_essential_hud() -> void:
	_build_reference_player_panel()
	_build_reference_turn_panel()
	return
	@warning_ignore("unreachable_code")
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 515)
	panel.size = Vector2(965, 120)
	style_panel(panel, Color("101c2d"), Color("31557c"), 10)
	$Control.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	margin.add_child(row)
	essential_player_status = Label.new()
	essential_player_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	essential_player_status.add_theme_font_size_override("font_size", 17)
	row.add_child(essential_player_status)
	essential_target_status = Label.new()
	essential_target_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	essential_target_status.add_theme_font_size_override("font_size", 17)
	row.add_child(essential_target_status)
	essential_turn_status = Label.new()
	essential_turn_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	essential_turn_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	essential_turn_status.add_theme_color_override("font_color", Color("7dd3fc"))
	row.add_child(essential_turn_status)
	refresh_essential_hud()


func _build_reference_player_panel() -> void:
	reference_player_panel = PanelContainer.new()
	reference_player_panel.z_index = 10
	reference_player_panel.name = "ReferencePlayerHUD"
	reference_player_panel.position = Vector2(20, 566)
	reference_player_panel.size = Vector2(300, 130)
	reference_player_panel.clip_contents = true
	style_panel(reference_player_panel, Color("151d23"), Color("5797aa"), 2)
	$Control.add_child(reference_player_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_bottom", 10)
	reference_player_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var portrait := ColorRect.new()
	portrait.name = "CharacterPortrait"
	portrait.custom_minimum_size = Vector2(76, 104)
	portrait.color = Color("29343a")
	portrait.tooltip_text = "Click to open Character"
	portrait.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	portrait.mouse_filter = Control.MOUSE_FILTER_STOP
	portrait.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			portrait.accept_event()
			open_character_from_portrait()
	)
	row.add_child(portrait)
	essential_player_status = Label.new()
	essential_player_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	essential_player_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	essential_player_status.clip_text = true
	essential_player_status.add_theme_font_size_override("font_size", 14)
	row.add_child(essential_player_status)


func _build_reference_turn_panel() -> void:
	reference_turn_panel = PanelContainer.new()
	reference_turn_panel.z_index = 10
	reference_turn_panel.name = "ReferenceTurnHUD"
	reference_turn_panel.position = Vector2(1010, 566)
	reference_turn_panel.size = Vector2(250, 130)
	style_panel(reference_turn_panel, Color("151d23"), Color("806027"), 2)
	$Control.add_child(reference_turn_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	reference_turn_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)
	essential_turn_status = Label.new()
	essential_turn_status.add_theme_color_override("font_color", Color("d5a84c"))
	column.add_child(essential_turn_status)
	@warning_ignore("shadowed_variable_base_class")
	reference_end_turn_button = Button.new()
	reference_end_turn_button.text = "END TURN"
	reference_end_turn_button.custom_minimum_size = Vector2(0, 40)
	reference_end_turn_button.pressed.connect(func():
		refresh_end_turn_lock()
		if not reference_end_turn_button.disabled:
			$"Control/ActionSources/End Turn".pressed.emit()
	)
	style_action_button(reference_end_turn_button)
	column.add_child(reference_end_turn_button)
	essential_target_status = Label.new()
	essential_target_status.add_theme_color_override("font_color", Color("a99d8b"))
	column.add_child(essential_target_status)


func _build_action_dock() -> void:
	var dock := PanelContainer.new()
	dock.z_index = 10
	dock.name = "ReferenceActionDock"
	dock.position = Vector2(332, 566)
	dock.size = Vector2(654, 130)
	dock.clip_contents = true
	style_panel(dock, Color("151d23"), Color("59636a"), 2)
	$Control.add_child(dock)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	dock.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var title := Label.new()
	title.text = "ACTION BAR"
	title.add_theme_color_override("font_color", Color("a99d8b"))
	title.add_theme_font_size_override("font_size", 11)
	column.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.clip_contents = true
	column.add_child(row)
	for category in ["attack", "throw", "move", "skill", "ability"]:
		var button := Button.new()
		button.text = category.to_upper()
		button.custom_minimum_size = Vector2(116, 66)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = "Choose %s" % category.capitalize()
		button.pressed.connect(_on_action_category_pressed.bind(category))
		style_action_button(button)
		row.add_child(button)
		action_category_buttons[category] = button
	_build_action_menu()


func _build_action_menu() -> void:
	action_menu_panel = PanelContainer.new()
	action_menu_panel.name = "ActionMenu"
	action_menu_panel.position = Vector2(430, 300)
	action_menu_panel.size = Vector2(460, 255)
	action_menu_panel.z_index = 24
	action_menu_panel.visible = false
	style_panel(action_menu_panel, Color("151d23"), Color("d5a84c"), 3)
	$Control.add_child(action_menu_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	action_menu_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	action_menu_title = Label.new()
	action_menu_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_menu_title.add_theme_font_size_override("font_size", 18)
	action_menu_title.add_theme_color_override("font_color", Color("d5a84c"))
	header.add_child(action_menu_title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func(): action_menu_panel.visible = false)
	header.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	action_menu_list = VBoxContainer.new()
	action_menu_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_menu_list.add_theme_constant_override("separation", 6)
	scroll.add_child(action_menu_list)


func _on_action_category_pressed(category: String) -> void:
	if category == "move":
		if is_inactive_friendly_selected():
			show_action_menu("move")
			return
		action_menu_panel.visible = false
		$Control/ActionSources/Move.pressed.emit()
		return
	show_action_menu(category)


func show_action_menu(category: String) -> void:
	for child in action_menu_list.get_children():
		action_menu_list.remove_child(child)
		child.queue_free()
	action_menu_title.text = category.to_upper()
	var player: CombatantState = get_displayed_party_member()
	if player == null:
		return
	match category:
		"move":
			add_action_menu_note("Speed %.1f ft · Move remaining %.1f ft" % [player.get_effective_speed(), player.movement_remaining_feet])
			add_action_menu_note("This character can Move during their Turn.")
		"attack":
			var listed_items: Array = []
			for slot in [0, 3]:
				var item = player.equipped_items.get(slot)
				if item != null and item.weapon_attack != null and not listed_items.has(item):
					listed_items.append(item)
					add_action_menu_button("%s · %d AP" % [item.weapon_attack.display_name, item.weapon_attack.ap_cost], item.description, use_equipment_attack.bind(item.weapon_attack))
			if player.unarmed_attack != null:
				var free_hand: bool = combat_system.equipment_system.has_free_hand(player)
				var unarmed_hint := "Melee · Unarmed · Requires at least one free hand."
				if not free_hand:
					unarmed_hint += " Both hands are occupied."
				add_action_menu_button("%s · %d AP" % [player.unarmed_attack.display_name, player.unarmed_attack.ap_cost], unarmed_hint, use_equipment_attack.bind(player.unarmed_attack))
				var unarmed_button := action_menu_list.get_child(action_menu_list.get_child_count() - 1) as Button
				unarmed_button.disabled = not free_hand or player.ap < player.unarmed_attack.ap_cost
			if listed_items.is_empty() and player.unarmed_attack == null:
				add_action_menu_note("No equipped weapon attacks.")
		"throw":
			var listed_items: Array = []
			for item in player.equipment_inventory:
				if item == null or listed_items.has(item):
					continue
				var thrown_attack: AttackData = combat_system.equipment_system.create_throw_attack(item)
				if thrown_attack == null:
					continue
				listed_items.append(item)
				var held: bool = combat_system.equipment_system.find_hand_slot(player, item) >= 0
				var returning: bool = combat_system.trait_system.attack_has_trait(thrown_attack, "returning")
				var hint := "Range %.0f ft. %s" % [thrown_attack.range_feet, "Returning: weapon is kept." if returning else "Weapon is consumed when thrown."]
				if not held:
					hint += " Equip this item in a hand slot first."
				elif player.ap < thrown_attack.ap_cost:
					hint += " Not enough AP."
				add_action_menu_button("%s - %d AP%s" % [item.display_name, thrown_attack.ap_cost, " (Equip first)" if not held else ""], hint, use_equipment_attack.bind(thrown_attack))
				var button := action_menu_list.get_child(action_menu_list.get_child_count() - 1) as Button
				button.disabled = not held or player.ap < thrown_attack.ap_cost
			if listed_items.is_empty():
				add_action_menu_note("No throwable items in inventory.")
		"skill":
			for skill in player.available_skills:
				if skill != null:
					add_action_menu_button("%s · %d AP · %d Mana" % [skill.display_name, skill.ap_cost, skill.mana_cost], skill.description, use_skill_from_menu.bind(skill))
			if player.available_skills.is_empty():
				add_action_menu_note("No Skills available.")
		"ability":
			var abilities: Array = combat_system.ability_system.get_active_abilities(player)
			for ability in abilities:
				if ability != null and not ability.is_passive and not ability.reaction_only:
					var faith_text := " · %d Faith" % ability.faith_cost if ability.faith_cost > 0 else ""
					add_action_menu_button("%s · %d AP%s" % [ability.display_name, ability.ap_cost, faith_text], ability.description, use_ability_from_menu.bind(ability))
			if action_menu_list.get_child_count() == 0:
				add_action_menu_note("No Active Abilities available.")
	var current_actor: CombatantState = combat_system.get_combat_state().get_current_actor()
	var read_only: bool = current_actor == null or current_actor.id != player.id
	if read_only:
		for child in action_menu_list.get_children():
			if child is Button:
				child.disabled = true
				child.tooltip_text = "This character can only use Actions during their Turn."
	action_menu_panel.visible = true


func add_action_menu_button(text: String, tooltip: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(0, 38)
	button.pressed.connect(func():
		action_menu_panel.visible = false
		action.call()
	)
	style_action_button(button)
	action_menu_list.add_child(button)


func add_action_menu_note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("a99d8b"))
	action_menu_list.add_child(label)


func use_equipment_attack(attack: AttackData) -> void:
	begin_attack_targeting(attack)


func begin_attack_targeting(attack: AttackData) -> void:
	if attack == null:
		return
	pending_target_attack = attack
	ground_targeting_kind = ""
	ground_targeting_id = ""
	move_mode = false
	selected_target_id = ""
	update_target_selection()
	$Control.set_mode_hint("%s: choose a highlighted target within %.1f ft. Right-click or Esc cancels." % [attack.display_name, attack.range_feet])
	$Control.add_log_message("Attack Targeting active: %s." % attack.display_name)
	queue_redraw()


func draw_attack_targeting() -> void:
	var state = combat_system.get_combat_state()
	var player: CombatantState = get_displayed_party_member()
	if player == null:
		return
	var range_world: float = combat_system.map_rules.get_targeting_preview_radius_world_units(player, pending_target_attack.range_feet)
	draw_circle(player.position, range_world, Color(0.34, 0.59, 0.67, 0.10))
	draw_arc(player.position, range_world, 0.0, TAU, 96, Color("78bed0"), 2.0)
	for target in state.combatants.values():
		if target == null or target.team == player.team or target.is_dying():
			continue
		var in_range: bool = combat_system.map_rules.is_target_in_range(player, target, pending_target_attack.range_feet)
		var color := Color("d5a84c") if in_range else Color(0.55, 0.58, 0.60, 0.45)
		var radius: float = combat_system.map_rules.get_combatant_radius_world_units(target) + 7.0
		draw_arc(target.position, radius, 0.0, TAU, 40, color, 4.0 if in_range else 2.0)


func confirm_attack_target(mouse_position: Vector2) -> bool:
	var player: CombatantState = get_player_controlled_actor()
	for combatant_node in get_enemy_nodes():
		if combatant_node.state == null or combatant_node.state.is_dying():
			continue
		var target: CombatantState = combatant_node.state
		var radius: float = target.collision_radius_feet * combat_system.map_rules.world_units_per_foot
		if mouse_position.distance_to(target.position) > radius + 8.0:
			continue
		if not combat_system.map_rules.is_target_in_range(player, target, pending_target_attack.range_feet):
			$Control.set_mode_hint("%s is outside this attack's %.1f ft range." % [target.display_name, pending_target_attack.range_feet])
			return true
		var attack := pending_target_attack
		pending_target_attack = null
		selected_target_id = target.id
		selected_character_id = target.id
		update_target_selection()
		var request := ActionRequest.new(player.id, ActionTypes.Type.ATTACK)
		request.target_id = target.id
		request.attack_data = attack
		handle_menu_action_result(combat_system.execute_action(request))
		queue_redraw()
		return true
	$Control.set_mode_hint("Choose a highlighted enemy, or right-click/Esc to cancel.")
	return false


func cancel_attack_targeting() -> void:
	if pending_target_attack == null:
		return
	var attack_name := pending_target_attack.display_name
	pending_target_attack = null
	$Control.set_mode_hint("Choose an action.")
	$Control.add_log_message("%s targeting cancelled." % attack_name)
	queue_redraw()


func execute_selected_equipment_attack(attack: AttackData) -> void:
	var request := ActionRequest.new(get_player_controlled_actor_id(), ActionTypes.Type.ATTACK)
	request.target_id = selected_target_id
	request.attack_data = attack
	handle_menu_action_result(combat_system.execute_action(request))


func use_skill_from_menu(skill: SkillData) -> void:
	if skill.target_mode == SkillData.TargetMode.GROUND:
		begin_ground_targeting("skill", skill.id)
		return
	begin_single_targeting("skill", skill)


func use_ability_from_menu(ability: AbilityData) -> void:
	if ability.target_mode == AbilityData.TargetMode.GROUND:
		begin_ground_targeting("ability", ability.id)
		return
	if combat_system.ability_system.get_movement_effect(ability) != null:
		var result := combat_system.begin_ability_movement(get_player_controlled_actor_id(), ability.id)
		if result.success:
			move_mode = true
			$Control.set_mode_hint("%s: click a destination." % ability.display_name)
		else:
			$Control.add_log_message("Ability failed: %s" % result.failure_reason)
		$Control.update_ui()
		return
	if ability.target_mode == AbilityData.TargetMode.SELF:
		var actor_id := get_player_controlled_actor_id()
		handle_menu_action_result(combat_system.use_active_ability(actor_id, actor_id, ability.id))
		return
	begin_single_targeting("ability", ability)


func begin_single_targeting(kind: String, source) -> void:
	pending_single_target_kind = kind
	pending_single_target_source = source
	pending_target_attack = null
	ground_targeting_kind = ""
	ground_targeting_id = ""
	move_mode = false
	selected_target_id = ""
	update_target_selection()
	var range_feet: float = get_single_target_range(kind, source)
	$Control.set_mode_hint("%s: choose a highlighted target within %.1f ft. Right-click or Esc cancels." % [source.display_name, range_feet])
	$Control.add_log_message("%s Targeting active: %s." % [kind.capitalize(), source.display_name])
	queue_redraw()


func get_single_target_range(kind: String, source) -> float:
	if kind == "skill":
		return source.attack_data.range_feet if source.attack_data != null else 0.0
	if source.targeting_range_feet > 0.0:
		return source.targeting_range_feet
	var player: CombatantState = get_player_controlled_actor()
	var attack: AttackData = combat_system.ability_system.get_attack_data(player, source)
	return attack.range_feet if attack != null else 0.0


func draw_single_targeting() -> void:
	var state = combat_system.get_combat_state()
	var player: CombatantState = get_player_controlled_actor()
	var range_feet: float = get_single_target_range(pending_single_target_kind, pending_single_target_source)
	var range_world: float = combat_system.map_rules.get_targeting_preview_radius_world_units(player, range_feet)
	draw_circle(player.position, range_world, Color(0.34, 0.59, 0.67, 0.10))
	draw_arc(player.position, range_world, 0.0, TAU, 96, Color("78bed0"), 2.0)
	for target in state.combatants.values():
		if target == null or target.is_dying() or not is_valid_single_target(player, target):
			continue
		var in_range: bool = combat_system.map_rules.is_target_in_range(player, target, range_feet)
		var color := Color("d5a84c") if in_range else Color(0.55, 0.58, 0.60, 0.45)
		draw_arc(target.position, combat_system.map_rules.get_combatant_radius_world_units(target) + 7.0, 0.0, TAU, 40, color, 4.0 if in_range else 2.0)


func is_valid_single_target(player: CombatantState, target: CombatantState) -> bool:
	if pending_single_target_kind == "skill":
		match pending_single_target_source.target_filter:
			SkillData.TargetFilter.ENEMIES: return target.team != player.team
			SkillData.TargetFilter.ALLIES: return target.team == player.team
			_: return true
	match pending_single_target_source.target_filter:
		AbilityData.TargetFilter.ENEMIES: return target.team != player.team
		AbilityData.TargetFilter.ALLIES: return target.team == player.team
		_: return true


func confirm_single_target(mouse_position: Vector2) -> bool:
	var state = combat_system.get_combat_state()
	var player: CombatantState = get_player_controlled_actor()
	var range_feet: float = get_single_target_range(pending_single_target_kind, pending_single_target_source)
	for combatant_node in get_all_combatant_nodes():
		var target: CombatantState = combatant_node.state
		if target == null or target.is_dying() or not is_valid_single_target(player, target):
			continue
		var radius: float = target.collision_radius_feet * combat_system.map_rules.world_units_per_foot
		if mouse_position.distance_to(target.position) > radius + 8.0:
			continue
		if not combat_system.map_rules.is_target_in_range(player, target, range_feet):
			$Control.set_mode_hint("%s is outside this action's %.1f ft range." % [target.display_name, range_feet])
			return true
		var kind := pending_single_target_kind
		var source = pending_single_target_source
		pending_single_target_kind = ""
		pending_single_target_source = null
		selected_target_id = target.id
		selected_character_id = target.id
		update_target_selection()
		if kind == "skill":
			var request := ActionRequest.new(player.id, ActionTypes.Type.SKILL)
			request.target_id = target.id
			request.skill_data = source
			handle_menu_action_result(combat_system.execute_action(request))
		else:
			handle_menu_action_result(combat_system.use_active_ability(player.id, target.id, source.id))
		queue_redraw()
		return true
	$Control.set_mode_hint("Choose a highlighted valid target, or right-click/Esc to cancel.")
	return false


func cancel_single_targeting() -> void:
	if pending_single_target_kind.is_empty():
		return
	var source_name: String = pending_single_target_source.display_name if pending_single_target_source != null else "Action"
	pending_single_target_kind = ""
	pending_single_target_source = null
	$Control.set_mode_hint("Choose an action.")
	$Control.add_log_message("%s targeting cancelled." % source_name)
	queue_redraw()


func handle_menu_action_result(result: ActionResult) -> void:
	sync_move_mode_from_state()
	$Control.record_action_result(result)
	if result.requires_reaction_choice:
		$Control.show_reaction_prompt(result.reaction_prompt)
	refresh_combatant_nodes()


func _add_action_dock_button(row: HBoxContainer, original: Button) -> void:
	var proxy := Button.new()
	proxy.custom_minimum_size = Vector2(68, 66)
	proxy.clip_text = true
	proxy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	proxy.text = original.text
	proxy.tooltip_text = original.tooltip_text
	proxy.pressed.connect(func(): original.pressed.emit())
	style_action_button(proxy)
	row.add_child(proxy)
	action_dock_links[proxy] = original


func refresh_action_dock() -> void:
	if combat_system != null and combat_system.get_combat_state() != null:
		var state = combat_system.get_combat_state()
		var locked: bool = state.is_finished() or not is_player_party_turn() or combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement()
		for category in action_category_buttons:
			action_category_buttons[category].disabled = locked
		if locked and action_menu_panel != null:
			action_menu_panel.visible = false
	for proxy in action_dock_links:
		var original: Button = action_dock_links[proxy]
		if not is_instance_valid(proxy) or not is_instance_valid(original):
			continue
		proxy.text = original.text
		proxy.tooltip_text = original.tooltip_text
		proxy.disabled = original.disabled
		proxy.visible = original.visible


func refresh_essential_hud() -> void:
	if essential_player_status == null or combat_system == null:
		return
	var state = combat_system.get_combat_state()
	if state == null:
		return
	var player: CombatantState = get_displayed_party_member()
	var target: CombatantState = state.get_combatant(selected_target_id)
	if player == null:
		return
	if reference_player_panel != null:
		if player.max_faith > 0:
			essential_player_status.text = "%s\n%s · Lv %d\nHP %d/%d · Faith %d/%d\nTemp +%d · Move %.1f ft" % [player.display_name, player.class_display_name, player.level, player.hp, player.max_hp, player.faith, player.max_faith, player.temporary_faith, player.movement_remaining_feet]
		else:
			essential_player_status.text = "%s\n%s · Lv %d\nHP %d/%d · Mana %d/%d\nMove %.1f ft" % [player.display_name, player.class_display_name, player.level, player.hp, player.max_hp, player.mana, player.max_mana, player.movement_remaining_feet]
		essential_turn_status.text = "ACTION POINTS   %d / %d" % [player.ap, player.effective_max_ap]
		essential_target_status.text = "REACTION READY" if player.ap > 0 and not player.has_status("surprise") else "REACTION UNAVAILABLE"
		return
	essential_player_status.text = "PLAYER\nHP  %d / %d\nAP  %d / %d   |   %s" % [player.hp, player.max_hp, player.ap, player.effective_max_ap, get_combat_resource_text(player)]
	essential_target_status.text = "TARGET\n%s\nHP  %d / %d" % [target.display_name, target.hp, target.max_hp] if target != null else "TARGET\nNone"
	essential_turn_status.text = "ROUND %d\n%s's Turn\n%s" % [state.current_round, state.current_actor_id.capitalize(), $Control/CombatLogPanel/VBoxContainer/ModeHint.text]


func get_combat_resource_text(player: CombatantState) -> String:
	if player.max_faith > 0:
		return "Faith %d / %d   |   Temporary +%d" % [player.faith, player.max_faith, player.temporary_faith]
	return "Mana %d / %d" % [player.mana, player.max_mana]


func _build_inventory_drawer() -> void:
	inventory_button = Button.new()
	inventory_button.name = "InventoryButton"
	inventory_button.text = "CHARACTER"
	inventory_button.tooltip_text = "Open character, abilities, equipment and inventory"
	inventory_button.position = Vector2(1090, 29)
	inventory_button.size = Vector2(145, 38)
	inventory_button.z_index = 20
	inventory_button.visible = false
	style_action_button(inventory_button)
	inventory_button.pressed.connect(toggle_inventory)
	$Control.add_child(inventory_button)

	inventory_drawer = CharacterPanelScene.instantiate()
	inventory_drawer.name = "CharacterPanel"
	inventory_drawer.position = Vector2(65, 82)
	inventory_drawer.size = Vector2(1175, 610)
	inventory_drawer.z_index = 19
	inventory_drawer.visible = false
	inventory_drawer.equipment_change_requested.connect(change_inventory_item)
	$Control.add_child(inventory_drawer)
	inventory_drawer.setup(combat_system, "player")
	inventory_list = inventory_drawer.content_list
	inventory_status = inventory_drawer.status_label
	character_summary = inventory_drawer.summary
	character_page_title = inventory_drawer.page_title
	character_tab_buttons = inventory_drawer.tab_buttons
	return

	@warning_ignore("unreachable_code")
	inventory_drawer = PanelContainer.new()
	inventory_drawer.name = "InventoryDrawer"
	inventory_drawer.position = Vector2(65, 82)
	inventory_drawer.size = Vector2(1175, 610)
	inventory_drawer.z_index = 19
	inventory_drawer.visible = false
	style_panel(inventory_drawer, Color("101a2a"), Color("38bdf8"), 14)
	$Control.add_child(inventory_drawer)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	inventory_drawer.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)
	var header_row := HBoxContainer.new()
	column.add_child(header_row)
	var title := Label.new()
	title.text = "CHARACTER"
	title.add_theme_font_size_override("font_size", 21)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(toggle_inventory)
	header_row.add_child(close)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	column.add_child(body)
	var summary_panel := PanelContainer.new()
	summary_panel.custom_minimum_size = Vector2(400, 0)
	style_panel(summary_panel, Color("0d1827"), Color("294766"), 10)
	body.add_child(summary_panel)
	var summary_margin := MarginContainer.new()
	summary_margin.add_theme_constant_override("margin_left", 16)
	summary_margin.add_theme_constant_override("margin_right", 16)
	summary_margin.add_theme_constant_override("margin_top", 14)
	summary_margin.add_theme_constant_override("margin_bottom", 14)
	summary_panel.add_child(summary_margin)
	character_summary = VBoxContainer.new()
	character_summary.add_theme_constant_override("separation", 8)
	summary_margin.add_child(character_summary)
	var content_panel := PanelContainer.new()
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_panel(content_panel, Color("111d2e"), Color("31557c"), 10)
	body.add_child(content_panel)
	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 16)
	content_margin.add_theme_constant_override("margin_right", 16)
	content_margin.add_theme_constant_override("margin_top", 14)
	content_margin.add_theme_constant_override("margin_bottom", 14)
	content_panel.add_child(content_margin)
	var content_column := VBoxContainer.new()
	content_column.add_theme_constant_override("separation", 9)
	content_margin.add_child(content_column)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	content_column.add_child(tabs)
	for tab_id in ["abilities", "equipment", "inventory"]:
		var tab_button := Button.new()
		tab_button.text = tab_id.capitalize()
		tab_button.toggle_mode = true
		tab_button.pressed.connect(set_character_tab.bind(tab_id))
		tabs.add_child(tab_button)
		character_tab_buttons[tab_id] = tab_button
	character_page_title = Label.new()
	character_page_title.add_theme_font_size_override("font_size", 20)
	character_page_title.add_theme_color_override("font_color", Color("7dd3fc"))
	content_column.add_child(character_page_title)
	inventory_status = Label.new()
	inventory_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory_status.add_theme_color_override("font_color", Color("bae6fd"))
	content_column.add_child(inventory_status)
	content_column.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_column.add_child(scroll)
	inventory_list = VBoxContainer.new()
	inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_list.add_theme_constant_override("separation", 8)
	scroll.add_child(inventory_list)
	var help := Label.new()
	help.text = "Weapon / Shield changes cost 1 AP and forfeit remaining Move. Armor is locked during Combat. Equipment cannot change while a Reaction is pending."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color("94a3b8"))
	column.add_child(help)


func toggle_inventory() -> void:
	inventory_drawer.visible = not inventory_drawer.visible
	if inventory_drawer.visible:
		if level_up_panel != null:
			level_up_panel.visible = false
		refresh_inventory()


func open_character_from_portrait() -> void:
	if inventory_drawer == null or is_movement_animating():
		return
	if combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement():
		return
	if level_up_panel != null:
		level_up_panel.hide()
	if action_menu_panel != null:
		action_menu_panel.hide()
	inventory_drawer.show()
	refresh_inventory()


func set_character_tab(tab_id: String) -> void:
	character_active_tab = tab_id
	if inventory_drawer != null and inventory_drawer.get_script() == CharacterPanelScript:
		inventory_drawer.set_tab(tab_id)
		return
	refresh_inventory()


func refresh_inventory() -> void:
	if inventory_drawer != null and inventory_drawer.get_script() == CharacterPanelScript:
		var displayed_actor := get_displayed_party_member()
		if displayed_actor != null and inventory_drawer.combatant_id != displayed_actor.id:
			inventory_drawer.setup(combat_system, displayed_actor.id)
		inventory_drawer.refresh()
		character_active_tab = inventory_drawer.active_tab
		return
	for child in inventory_list.get_children():
		inventory_list.remove_child(child)
		child.queue_free()
	var player: CombatantState = get_displayed_party_member()
	if player == null:
		return
	refresh_character_summary(player)
	for tab_id in character_tab_buttons:
		character_tab_buttons[tab_id].button_pressed = tab_id == character_active_tab
	character_page_title.text = character_active_tab.capitalize()
	inventory_status.text = "AP %d / %d   |   Speed %.1f ft   |   %s" % [player.ap, player.effective_max_ap, player.get_effective_speed(), get_combat_resource_text(player)]
	match character_active_tab:
		"abilities":
			add_ability_sections(player)
		"equipment":
			add_inventory_heading("EQUIPPED")
			add_slot_card(player, "Weapon Slot 1", 0)
			add_slot_card(player, "Weapon Slot 2", 3)
			add_slot_card(player, "Armor", 1)
			add_inventory_heading("AVAILABLE EQUIPMENT")
			for item in player.equipment_inventory:
				if item != null:
					add_inventory_item(player, item)
		"inventory":
			add_inventory_heading("BACKPACK")
			for item in player.equipment_inventory:
				if item != null:
					add_inventory_item(player, item)


func refresh_character_summary(player: CombatantState) -> void:
	for child in character_summary.get_children():
		character_summary.remove_child(child)
		child.queue_free()
	var name_label := Label.new()
	name_label.text = player.display_name
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color("f8fafc"))
	character_summary.add_child(name_label)
	add_character_summary_line("Level %d  |  %s  |  %s" % [player.level, player.ancestry_display_name, player.class_display_name])
	var portrait := ColorRect.new()
	portrait.custom_minimum_size = Vector2(0, 155)
	portrait.color = Color("17243a")
	portrait.tooltip_text = "Character portrait"
	character_summary.add_child(portrait)
	add_character_summary_line("HP  %d / %d" % [player.hp, player.max_hp])
	add_character_summary_line("STR %d   DEX %d   CON %d" % [player.strength, player.dexterity, player.constitution])
	add_character_summary_line("INT %d   WIS %d   CHA %d" % [player.intelligence, player.wisdom, player.charisma])
	add_character_summary_line("Fortitude %d   Reflex %d   Will %d" % [player.fortitude + combat_system.effect_system.get_fortitude_bonus(player), player.reflex + combat_system.effect_system.get_reflex_bonus(player), player.will + combat_system.effect_system.get_will_bonus(player)])
	add_character_summary_line("Speed %.1f ft   %s" % [player.get_effective_speed(), get_combat_resource_text(player)])
	add_character_summary_line("Status: %s" % $Control.get_effect_names(player))


func add_character_summary_line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("cbd5e1"))
	character_summary.add_child(label)


func add_ability_sections(player: CombatantState) -> void:
	var groups := {
		"CLASS ABILITY": [],
		"ANCESTRY ABILITY": [],
		"BASIC ABILITY": []
	}
	for ability in combat_system.ability_system.get_active_abilities(player):
		if ability == null:
			continue
		var heading := "BASIC ABILITY"
		if ability.required_trait_ids.has(player.class_id):
			heading = "CLASS ABILITY"
		elif ability.id == "human_adapt":
			heading = "ANCESTRY ABILITY"
		groups[heading].append(ability)
	for heading in groups:
		add_inventory_heading(heading)
		if groups[heading].is_empty():
			add_character_detail("No abilities")
		for ability in groups[heading]:
			add_ability_card(ability)


func add_ability_card(ability: AbilityData) -> void:
	var name_label := Label.new()
	name_label.text = "%s  |  %d AP  |  Cooldown %d" % [ability.display_name, ability.ap_cost, ability.cooldown_turns]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.tooltip_text = ability.description
	inventory_list.add_child(name_label)
	var details := Label.new()
	details.text = ability.description
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_color_override("font_color", Color("94a3b8"))
	inventory_list.add_child(details)


func add_inventory_heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("38bdf8"))
	inventory_list.add_child(label)


func add_character_detail(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("cbd5e1"))
	inventory_list.add_child(label)


func add_slot_card(player: CombatantState, label_text: String, slot: int) -> void:
	var item = player.equipped_items.get(slot)
	var row := Label.new()
	var active := "  [ACTIVE]" if (slot == 0 or slot == 3) and player.active_weapon_slot == slot and item != null else ""
	row.text = "%s: %s%s" % [label_text, item.display_name if item != null else "Empty", active]
	row.add_theme_color_override("font_color", Color("e2e8f0"))
	inventory_list.add_child(row)


func add_inventory_item(player: CombatantState, item) -> void:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 3)
	var name_label := Label.new()
	name_label.text = item.display_name
	name_label.add_theme_font_size_override("font_size", 16)
	card.add_child(name_label)
	var description := Label.new()
	description.text = item.description
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", Color("94a3b8"))
	card.add_child(description)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	card.add_child(actions)
	var equipment_locked := inventory_changes_locked()
	if item.slot == 1:
		add_inventory_action(actions, "Armor locked", item, -1, true)
	elif item.slot == 2:
		add_inventory_action(actions, hand_action_text(player, item, 0), item, 0, equipment_locked or player.ap < 1)
		add_inventory_action(actions, hand_action_text(player, item, 3), item, 3, equipment_locked or player.ap < 1)
	elif is_two_handed_item(item):
		var equipped: bool = player.equipped_items.get(0) == item
		add_inventory_action(actions, ("Unequip" if equipped else "Equip") + " W1+W2 - 1 AP", item, 0, equipment_locked or player.ap < 1)
	else:
		add_inventory_action(actions, hand_action_text(player, item, 0), item, 0, equipment_locked or player.ap < 1)
		add_inventory_action(actions, hand_action_text(player, item, 3), item, 3, equipment_locked or player.ap < 1)
	inventory_list.add_child(card)
	inventory_list.add_child(HSeparator.new())


func hand_action_text(player: CombatantState, item, slot: int) -> String:
	var number := 1 if slot == 0 else 2
	if player.equipped_items.get(slot) == item:
		return "Unequip Hand %d - 1 AP" % number
	if player.equipped_items.get(0 if slot == 3 else 3) == item:
		return "Move to Hand %d - 1 AP" % number
	return "Equip Hand %d - 1 AP" % number


func inventory_changes_locked() -> bool:
	var state = combat_system.get_combat_state()
	return state == null or state.is_finished() or not is_player_party_turn() or combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement()


func add_inventory_action(parent: HBoxContainer, text: String, item, slot: int, disabled: bool) -> void:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.pressed.connect(change_inventory_item.bind(item, slot))
	parent.add_child(button)


func change_inventory_item(item, slot: int) -> void:
	var result := combat_system.toggle_equipment(get_player_controlled_actor_id(), item, slot)
	sync_move_mode_from_state()
	if result.success:
		$Control.add_log_message("Inventory updated: %s." % item.display_name)
	else:
		$Control.add_log_message("Inventory failed: %s" % result.failure_reason)
	$Control.update_ui()
	refresh_inventory()


func is_two_handed_item(item) -> bool:
	if item == null or item.weapon_attack == null:
		return false
	for trait_data in item.weapon_attack.traits:
		if trait_data != null and trait_data.id == "two_handed":
			return true
	return false


func style_panel(panel: Control, background: Color, border: Color, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", style)


func style_action_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("1d3550")
	normal.set_corner_radius_all(7)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color("28557b")
	button.add_theme_stylebox_override("hover", hover)
