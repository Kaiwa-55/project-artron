extends "res://scenes/combat/combat_arena.gd"

const CharacterPanelScript := preload("res://scenes/ui/character_panel.gd")
const CombatActionIconAtlas := preload("res://assets/ui/combat_action_icons.png")
const DevoteeFallbackPortrait := preload("res://assets/character_creation/devotee.png")
const EnemyAIScript := preload("res://combat/ai/enemy_ai_system.gd")
const ObstacleVisualScript := preload("res://scenes/combat/obstacle_visual.gd")
const CombatantScript := preload("res://entities/combatant.gd")
const DefaultEncounter := preload("res://data/encounter/prototype_encounter.tres")
const EncounterDataScript := preload("res://data/encounter/encounter_data.gd")
const MAP_SIZE_FEET := Vector2(250.0, 250.0)

var inventory_drawer: PanelContainer
var inventory_list: VBoxContainer
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
var combat_round_label: Label
var initiative_row: HBoxContainer
var initiative_signature: String = ""
var reference_player_panel: PanelContainer
var reference_player_portrait: TextureRect
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
var party_nodes: Dictionary = {}
var selected_character_id: String = ""

# Coordinator extension points. PrototypeCombat overrides these with combat
# state and encounter behavior while this base owns the UI presentation.
func refresh_combatant_nodes() -> void: pass
func refresh_end_turn_lock() -> void: pass
func is_inactive_friendly_selected() -> bool: return false
func get_displayed_party_member() -> CombatantState: return null
func get_enemy_nodes() -> Array: return []
func get_all_combatant_nodes() -> Array: return []


func _apply_prototype_layout() -> void:
	RenderingServer.set_default_clear_color(Color("090e12"))
	$UILayer/Control/CombatLogPanel/Margin/VBoxContainer/ModeHint.add_theme_color_override("font_color", Color("7dd3fc"))
	$UILayer/Control/Enemy_panel/PanelTitle.text = "TARGET"
	$UILayer/Control/Enemy_panel.visible = true
	$UILayer/Control/Enemy_panel/PanelTitle.text = "SELECTED TARGET"
	$UILayer/Control/CombatLogPanel.z_index = 18
	$UILayer/Control/CombatLogPanel.visible = false
	$UILayer/Control/ReactionPrompt.z_index = 30
	$UILayer/Control/Header.z_index = 10
	$UILayer/Control/Enemy_panel.z_index = 10
	style_panel($UILayer/Control/Header, Color(0.035, 0.055, 0.065, 0.96), Color("806027"), 2)
	style_panel($UILayer/Control/Enemy_panel, Color(0.045, 0.055, 0.058, 0.94), Color("d5a84c"), 3)
	style_panel($UILayer/Control/CombatLogPanel, Color("10161b"), Color("59636a"), 3)
	style_panel($UILayer/Control/ReactionPrompt, Color("171d22"), Color("d5a84c"), 3)
	for button in $UILayer/Control/ActionSources.get_children():
		if button is Button:
			style_action_button(button)
	_build_shadow_step_button()
	_build_area_skill_button()
	_build_combat_log_toggle()
	$UILayer/Controllers/CombatHUD.build()
	$UILayer/Controllers/ActionBar.build()
	_apply_combat_typography()
	_apply_responsive_layout()
	if not $UILayer/Control.resized.is_connected(_apply_responsive_layout):
		$UILayer/Control.resized.connect(_apply_responsive_layout)


func _apply_responsive_layout() -> void:
	var viewport_size: Vector2 = $UILayer/Control.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var compact := viewport_size.x < 1050.0 or viewport_size.y < 650.0
	var edge := 10.0 if compact else 20.0
	var header_height := 52.0 if compact else 60.0
	var bottom_gap := 8.0 if compact else 20.0
	var dock_height := 104.0 if compact else 118.0
	var bottom_row: HBoxContainer = $UILayer/Control/BottomActionRow
	bottom_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_row.offset_left = edge
	bottom_row.offset_top = -dock_height - bottom_gap
	bottom_row.offset_right = -edge
	bottom_row.offset_bottom = -bottom_gap
	var dock: Control = $UILayer/Control/BottomActionRow/ReferenceActionDock
	dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header: Control = $UILayer/Control/Header
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = edge
	header.offset_top = edge
	header.offset_right = -edge
	header.offset_bottom = edge + header_height
	var side_width := minf(300.0 if compact else 340.0, viewport_size.x - edge * 2.0)
	var player_height := 118.0 if compact else 134.0
	var turn_height := 96.0 if compact else 104.0
	var player_panel: Control = $UILayer/Control/ReferencePlayerHUD
	player_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	player_panel.offset_left = -edge - side_width
	player_panel.offset_top = -dock_height - bottom_gap - player_height - 8.0
	player_panel.offset_right = -edge
	player_panel.offset_bottom = -dock_height - bottom_gap - 8.0
	var portrait: TextureRect = $UILayer/Control/ReferencePlayerHUD/Margin/Row/CharacterPortrait
	portrait.custom_minimum_size = Vector2(68, 82) if compact else Vector2(78, 96)
	var turn_panel: Control = $UILayer/Control/BottomActionRow/ReferenceTurnHUD
	turn_panel.custom_minimum_size = Vector2(250.0 if compact else 300.0, 0)
	var enemy_panel: Control = $UILayer/Control/Enemy_panel
	enemy_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	enemy_panel.offset_left = -edge - side_width
	enemy_panel.offset_top = edge + header_height + 10.0
	enemy_panel.offset_right = -edge
	enemy_panel.offset_bottom = edge + header_height + 160.0
	var log_panel: Control = $UILayer/Control/CombatLogPanel
	var log_width := minf(340.0, viewport_size.x - edge * 2.0)
	log_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	log_panel.offset_left = edge
	log_panel.offset_top = edge + header_height + 10.0
	log_panel.offset_right = edge + log_width
	log_panel.offset_bottom = -dock_height - bottom_gap - 8.0
	var action_menu: Control = $UILayer/Control/ActionMenu
	action_menu.set_anchors_preset(Control.PRESET_CENTER)
	var menu_width := minf(390.0, viewport_size.x - edge * 2.0)
	var menu_height := minf(300.0, viewport_size.y - header_height - dock_height - edge * 3.0)
	action_menu.offset_left = -menu_width * 0.5
	action_menu.offset_top = -menu_height * 0.5
	action_menu.offset_right = menu_width * 0.5
	action_menu.offset_bottom = menu_height * 0.5
	var character_panel: Control = $UILayer/Control/CharacterPanel
	character_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	character_panel.offset_left = edge * 2.0
	character_panel.offset_top = edge + header_height + 8.0
	character_panel.offset_right = -edge * 2.0
	character_panel.offset_bottom = -edge * 2.0


func _build_initiative_bar() -> void:
	combat_round_label = $UILayer/Control/Header/InitiativeTimeline/RoundLabel
	initiative_row = $UILayer/Control/Header/InitiativeTimeline/InitiativeRow
	refresh_initiative_bar(true)


func refresh_initiative_bar(force: bool = false) -> void:
	if initiative_row == null or combat_system == null or combat_system.get_combat_state() == null:
		return
	var state = combat_system.get_combat_state()
	combat_round_label.text = "ROUND %d    TURN: %s" % [state.current_round, state.current_actor_id.to_upper()]
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
		if actor.token_texture != null:
			chip.text = ""
			chip.icon = actor.token_texture
			chip.expand_icon = true
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
	$UILayer/Control/Enemy_panel/PanelTitle.add_theme_color_override("font_color", Color("d5a84c"))
	$UILayer/Control/ReactionPrompt/VBoxContainer/Title.add_theme_color_override("font_color", Color("d5a84c"))


func _build_shadow_step_button() -> void:
	shadow_step_button = Button.new()
	shadow_step_button.name = "ShadowStep"
	shadow_step_button.custom_minimum_size = Vector2(0, 36)
	shadow_step_button.text = "Shadow Step (1 AP)"
	shadow_step_button.tooltip_text = "Move up to 15 feet without triggering Reactions. Once per turn."
	shadow_step_button.pressed.connect(begin_shadow_step)
	$UILayer/Control/ActionSources.add_child(shadow_step_button)
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
	$UILayer/Control/ActionSources.add_child(button)
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
		$UILayer/Control.set_mode_hint("Shadow Step: click a destination up to 15 ft away.")
		$UILayer/Control.add_log_message("Shadow Step ready: choose a destination.")
	else:
		$UILayer/Control.add_log_message("Shadow Step failed: %s" % result.failure_reason)
	$UILayer/Control.update_ui()
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
	combat_log_button = $UILayer/Control/CombatLogButton
	style_action_button(combat_log_button)
	if not combat_log_button.pressed.is_connected(toggle_combat_log):
		combat_log_button.pressed.connect(toggle_combat_log)
	var close_button: Button = $UILayer/Control/CombatLogPanel/Margin/VBoxContainer/Header/Close
	style_action_button(close_button)
	if not close_button.pressed.is_connected(toggle_combat_log):
		close_button.pressed.connect(toggle_combat_log)


func toggle_combat_log() -> void:
	$UILayer/Controllers/CombatLog.toggle()
	combat_log_button.text = "CLOSE LOG" if $UILayer/Control/CombatLogPanel.visible else "COMBAT LOG"


func _build_essential_hud() -> void:
	_build_reference_player_panel()
	_build_reference_turn_panel()


func _build_reference_player_panel() -> void:
	reference_player_panel = $UILayer/Control/ReferencePlayerHUD
	style_panel(reference_player_panel, Color("151d23"), Color("5797aa"), 2)
	reference_player_portrait = $UILayer/Control/ReferencePlayerHUD/Margin/Row/CharacterPortrait
	reference_player_portrait.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			reference_player_portrait.accept_event()
			open_character_from_portrait()
	)
	essential_player_status = $UILayer/Control/ReferencePlayerHUD/Margin/Row/PlayerStatus
	essential_player_status.clip_text = false
	essential_player_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	essential_player_status.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING


func _build_reference_turn_panel() -> void:
	reference_turn_panel = $UILayer/Control/BottomActionRow/ReferenceTurnHUD
	style_panel(reference_turn_panel, Color("151d23"), Color("806027"), 2)
	essential_turn_status = $UILayer/Control/BottomActionRow/ReferenceTurnHUD/Margin/Column/TurnStatus
	@warning_ignore("shadowed_variable_base_class")
	reference_end_turn_button = $UILayer/Control/BottomActionRow/ReferenceTurnHUD/Margin/Column/EndTurn
	reference_end_turn_button.pressed.connect(func():
		refresh_end_turn_lock()
		if not reference_end_turn_button.disabled:
			$"UILayer/Control/ActionSources/End Turn".pressed.emit()
	)
	style_action_button(reference_end_turn_button)
	essential_target_status = $UILayer/Control/BottomActionRow/ReferenceTurnHUD/Margin/Column/TargetStatus


func _build_action_dock() -> void:
	var dock: PanelContainer = $UILayer/Control/BottomActionRow/ReferenceActionDock
	dock.z_index = 10
	style_panel(dock, Color(0.035, 0.045, 0.048, 0.96), Color("b58a3a"), 2)
	var action_grid: GridContainer = dock.get_node("ActionDockMargin/ActionDockColumn/ActionButtonGrid")
	action_category_buttons.clear()
	for category in ["attack", "move", "skill", "ability", "throw"]:
		var button: Button = action_grid.get_node(category.capitalize())
		button.icon = _get_action_category_icon(category)
		button.expand_icon = true
		button.tooltip_text = "Choose %s" % category.capitalize()
		var callback := _on_action_category_pressed.bind(category)
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)
		style_action_button(button)
		action_category_buttons[category] = button
	_build_action_menu()


func _get_action_category_icon(category: String) -> AtlasTexture:
	var icon_indexes := {
		"attack": 0,
		"move": 1,
		"skill": 2,
		"ability": 3,
		"throw": 4,
	}
	var icon := AtlasTexture.new()
	icon.atlas = CombatActionIconAtlas
	var cell_width: float = float(CombatActionIconAtlas.get_width()) / 8.0
	var icon_index: int = int(icon_indexes.get(category, 0))
	var crop_top: float = CombatActionIconAtlas.get_height() * 0.16
	var crop_height: float = CombatActionIconAtlas.get_height() * 0.68
	icon.region = Rect2(cell_width * icon_index, crop_top, cell_width, crop_height)
	return icon


func _build_action_menu() -> void:
	action_menu_panel = $UILayer/Control/ActionMenu
	style_panel(action_menu_panel, Color("151d23"), Color("d5a84c"), 3)
	action_menu_title = $UILayer/Control/ActionMenu/Margin/Column/Header/Title
	var close: Button = $UILayer/Control/ActionMenu/Margin/Column/Header/Close
	close.pressed.connect(func(): action_menu_panel.visible = false)
	action_menu_list = $UILayer/Control/ActionMenu/Margin/Column/Scroll/List


func _on_action_category_pressed(category: String) -> void:
	if category == "move":
		if is_inactive_friendly_selected():
			show_action_menu("move")
			return
		action_menu_panel.visible = false
		$UILayer/Control/ActionSources/Move.pressed.emit()
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
					var mana_cost: int = combat_system.skill_system.get_effective_mana_cost(player, skill)
					add_action_menu_button("%s · %d AP · %d Mana" % [skill.display_name, skill.ap_cost, mana_cost], skill.description, use_skill_from_menu.bind(skill))
			if player.available_skills.is_empty():
				add_action_menu_note("No Skills available.")
		"ability":
			var abilities: Array = combat_system.ability_system.get_active_abilities(player)
			for ability in abilities:
				if ability != null and not ability.is_passive and not ability.reaction_only:
					var ability_target: CombatantState = player
					if ability.target_mode == AbilityData.TargetMode.SINGLE_COMBATANT:
						ability_target = get_first_valid_ability_target(player, ability)
					var validation: ActionResult = combat_system.ability_system.validate_active_use(player, ability, ability_target)
					var faith_text := " · %d Faith" % ability.faith_cost if ability.faith_cost > 0 else ""
					var tooltip: String = ability.description if validation.success else "%s\nUnavailable: %s" % [ability.description, validation.failure_reason]
					add_action_menu_button("%s · %d AP%s" % [ability.display_name, ability.ap_cost, faith_text], tooltip, use_ability_from_menu.bind(ability))
					var ability_button := action_menu_list.get_child(action_menu_list.get_child_count() - 1) as Button
					ability_button.disabled = not validation.success
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


func get_first_valid_ability_target(actor: CombatantState, ability: AbilityData) -> CombatantState:
	if actor == null or ability == null or combat_system == null:
		return null
	for candidate in combat_system.get_combat_state().combatants.values():
		if candidate != null and not candidate.is_dying() and combat_system.ability_system.target_filter_matches(actor, candidate, ability):
			return candidate
	return null


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
	$UILayer/Control.set_mode_hint("%s: choose a highlighted target within %.1f ft. Right-click or Esc cancels." % [attack.display_name, attack.range_feet])
	$UILayer/Control.add_log_message("Attack Targeting active: %s." % attack.display_name)
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
			$UILayer/Control.set_mode_hint("%s is outside this attack's %.1f ft range." % [target.display_name, pending_target_attack.range_feet])
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
	$UILayer/Control.set_mode_hint("Choose a highlighted enemy, or right-click/Esc to cancel.")
	return false


func cancel_attack_targeting() -> void:
	if pending_target_attack == null:
		return
	var attack_name := pending_target_attack.display_name
	pending_target_attack = null
	$UILayer/Control.set_mode_hint("Choose an action.")
	$UILayer/Control.add_log_message("%s targeting cancelled." % attack_name)
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
			$UILayer/Control.set_mode_hint("%s: click a destination." % ability.display_name)
		else:
			$UILayer/Control.add_log_message("Ability failed: %s" % result.failure_reason)
		$UILayer/Control.update_ui()
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
	$UILayer/Control.set_mode_hint("%s: choose a highlighted target within %.1f ft. Right-click or Esc cancels." % [source.display_name, range_feet])
	$UILayer/Control.add_log_message("%s Targeting active: %s." % [kind.capitalize(), source.display_name])
	queue_redraw()


func get_single_target_range(kind: String, source) -> float:
	if kind == "skill":
		return combat_system.skill_system.get_effective_range_feet(get_player_controlled_actor(), source)
	var player: CombatantState = get_player_controlled_actor()
	return combat_system.ability_system.get_targeting_range(player, source)


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
			$UILayer/Control.set_mode_hint("%s is outside this action's %.1f ft range." % [target.display_name, range_feet])
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
	$UILayer/Control.set_mode_hint("Choose a highlighted valid target, or right-click/Esc to cancel.")
	return false


func cancel_single_targeting() -> void:
	if pending_single_target_kind.is_empty():
		return
	var source_name: String = pending_single_target_source.display_name if pending_single_target_source != null else "Action"
	pending_single_target_kind = ""
	pending_single_target_source = null
	$UILayer/Control.set_mode_hint("Choose an action.")
	$UILayer/Control.add_log_message("%s targeting cancelled." % source_name)
	queue_redraw()


func handle_menu_action_result(result: ActionResult) -> void:
	sync_move_mode_from_state()
	$UILayer/Control.record_action_result(result)
	if not result.success:
		$UILayer/Control.set_mode_hint("Action failed: %s" % result.failure_reason)
	if result.requires_reaction_choice:
		$UILayer/Control.show_reaction_prompt(result.reaction_prompt)
	refresh_combatant_nodes()


func refresh_action_dock() -> void:
	if combat_system != null and combat_system.get_combat_state() != null:
		var state = combat_system.get_combat_state()
		var locked: bool = state.is_finished() or not is_player_party_turn() or combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement()
		for category in action_category_buttons:
			action_category_buttons[category].disabled = locked
		var current_actor: CombatantState = state.get_current_actor()
		if action_category_buttons.has("move") and current_actor != null and is_player_party_turn():
			action_category_buttons["move"].disabled = locked or combat_system.movement_system.get_available_distance_feet(current_actor) <= 0.001
		if locked and action_menu_panel != null:
			action_menu_panel.visible = false


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
		if reference_player_portrait != null:
			reference_player_portrait.texture = player.token_texture if player.token_texture != null else DevoteeFallbackPortrait
		if player.max_faith > 0:
			essential_player_status.text = "%s\n%s · Lv %d\nHP %d/%d · Faith %d/%d\nTemp +%d · Move %.1f ft" % [player.display_name, player.class_display_name, player.level, player.hp, player.max_hp, player.faith, player.max_faith, player.temporary_faith, player.movement_remaining_feet]
		else:
			essential_player_status.text = "%s\n%s · Lv %d\nHP %d/%d · Mana %d/%d\nMove %.1f ft" % [player.display_name, player.class_display_name, player.level, player.hp, player.max_hp, player.mana, player.max_mana, player.movement_remaining_feet]
		essential_turn_status.text = "ACTION POINTS   %d / %d" % [player.ap, player.effective_max_ap]
		essential_target_status.text = "REACTION READY" if player.ap > 0 and not player.has_status("surprise") else "REACTION UNAVAILABLE"
		return
	essential_player_status.text = "PLAYER\nHP  %d / %d\nAP  %d / %d   |   %s" % [player.hp, player.max_hp, player.ap, player.effective_max_ap, get_combat_resource_text(player)]
	essential_target_status.text = "TARGET\n%s\nHP  %d / %d" % [target.display_name, target.hp, target.max_hp] if target != null else "TARGET\nNone"
	essential_turn_status.text = "ROUND %d\n%s's Turn\n%s" % [state.current_round, state.current_actor_id.capitalize(), $UILayer/Control/CombatLogPanel/Margin/VBoxContainer/ModeHint.text]


func get_combat_resource_text(player: CombatantState) -> String:
	if player.max_faith > 0:
		return "Faith %d / %d   |   Temporary +%d" % [player.faith, player.max_faith, player.temporary_faith]
	return "Mana %d / %d" % [player.mana, player.max_mana]


func _build_inventory_drawer() -> void:
	inventory_drawer = $UILayer/Control/CharacterPanel
	inventory_drawer.equipment_change_requested.connect(change_inventory_item)
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
	$UILayer/Control.add_child(inventory_drawer)

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
		refresh_inventory()


func open_character_from_portrait() -> void:
	if inventory_drawer == null or is_movement_animating():
		return
	if combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement():
		return
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
	add_character_summary_line("Status: %s" % $UILayer/Control.get_effect_names(player))


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
		$UILayer/Control.add_log_message("Inventory updated: %s." % item.display_name)
	else:
		$UILayer/Control.add_log_message("Inventory failed: %s" % result.failure_reason)
	$UILayer/Control.update_ui()
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
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)


func style_action_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.045, 0.060, 0.065, 0.96)
	normal.border_color = Color("745d31")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_color_override("font_color", Color("e7d8b8"))
	button.add_theme_color_override("font_hover_color", Color("fff1c7"))
	var hover := normal.duplicate()
	hover.bg_color = Color("19313a")
	hover.border_color = Color("4fc3dc")
	hover.set_border_width_all(2)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := hover.duplicate()
	pressed.bg_color = Color("0d2b35")
	button.add_theme_stylebox_override("pressed", pressed)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.03, 0.035, 0.038, 0.82)
	disabled.border_color = Color("423b2d")
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_disabled_color", Color("716b60"))
