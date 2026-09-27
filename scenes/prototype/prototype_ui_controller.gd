extends "res://scenes/combat/combat_arena.gd"

const CharacterPanelControllerScript := preload("res://scenes/prototype/prototype_character_panel_controller.gd")
const UITheme := preload("res://scenes/ui/artron_ui_theme.gd")
const CombatTheme := preload("res://scenes/ui/combat_ui_theme.gd")
const DevoteeFallbackPortrait := preload("res://assets/character_creation/devotee.png")
const EnemyAIScript := preload("res://combat/ai/enemy_ai_system.gd")
const ObstacleVisualScript := preload("res://scenes/combat/obstacle_visual.gd")
const CombatantScript := preload("res://entities/combatant.gd")
const DefaultEncounter := preload("res://data/encounter/prototype_encounter.tres")
const EncounterDataScript := preload("res://data/encounter/encounter_data.gd")
const GMConsoleControllerScript := preload("res://scenes/prototype/prototype_gm_console_controller.gd")
const ActionMenuScript := preload("res://scenes/prototype/prototype_action_menu.gd")
const MAP_SIZE_FEET := Vector2(250.0, 250.0)
const ACTION_DOCK_WIDTH := 290.0

var inventory_drawer: Control
var character_panel_controller: RefCounted
var inventory_list: VBoxContainer
var inventory_status: Label
var character_summary: VBoxContainer
var character_page_title: Label
var character_tab_buttons: Dictionary = {}
var character_active_tab: String = "abilities"
var combat_log_button: Button
var essential_turn_status: Label
var shadow_step_button: Button
var area_skill_button: Button
var area_action_buttons: Dictionary = {}
var combat_round_label: Label
var initiative_row: HBoxContainer
var initiative_signature: String = ""
var reference_player_panel: Control
var reference_player_portrait: TextureRect
var reference_turn_panel: Control
var reference_end_turn_button: Button
var action_menu_panel: PanelContainer
var action_menu_title: Label
var action_menu_list: Container
var minor_action_scroll: ScrollContainer
var minor_action_list: GridContainer
var minor_action_title: Label
var action_category_buttons: Dictionary = {}
var action_menu_controller: RefCounted
var enemy_ai = EnemyAIScript.new()
var enemy_actions_this_turn: int = 0
@export var encounter_data: Resource
var enemy_nodes: Dictionary = {}
var party_nodes: Dictionary = {}
var selected_character_id: String = ""
var gm_console
var gm_console_controller: RefCounted

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
	$UILayer/Control/CombatLogPanel/Margin/VBoxContainer/ModeHint.add_theme_color_override("font_color", UITheme.MUTED)
	$UILayer/Control/Enemy_panel/VBoxContainer/PanelTitle.text = "TARGET"
	$UILayer/Control/Enemy_panel.visible = true
	$UILayer/Control/Enemy_panel/VBoxContainer/PanelTitle.text = "SELECTED TARGET"
	$UILayer/Control/CombatLogPanel.z_index = 18
	$UILayer/Control/CombatLogPanel.visible = false
	$UILayer/Control/ReactionPrompt.z_index = 30
	$UILayer/Control/Header.z_index = 10
	$UILayer/Control/Enemy_panel.z_index = 10
	style_panel($UILayer/Control/Header, UITheme.WINDOW_BACKGROUND, UITheme.WINDOW_BORDER, 4)
	style_panel($UILayer/Control/Enemy_panel, UITheme.CARD_BACKGROUND, UITheme.GOLD, 4)
	style_panel($UILayer/Control/ReactionPrompt, UITheme.CARD_BACKGROUND, UITheme.GOLD, 4)
	for button in $UILayer/Control/ActionSources.get_children():
		if button is Button:
			style_action_button(button)
	_build_shadow_step_button()
	_build_area_skill_button()
	_build_combat_log_toggle()
	_build_gm_console()
	$UILayer/Controllers/CombatHUD.build()
	$UILayer/Controllers/ActionBar.build()
	_apply_combat_theme()
	_style_combat_log_strip()
	_apply_combat_typography()
	_apply_responsive_layout()
	if not $UILayer/Control.resized.is_connected(_apply_responsive_layout):
		$UILayer/Control.resized.connect(_apply_responsive_layout)


func _apply_responsive_layout() -> void:
	var viewport_size: Vector2 = $UILayer/Control.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var compact := viewport_size.x < 1050.0 or viewport_size.y < 650.0
	var small_screen := viewport_size.x <= 700.0 or viewport_size.y <= 400.0
	var edge := 6.0 if small_screen else (10.0 if compact else 20.0)
	var header_height := CombatTheme.HEADER_HEIGHT
	var bottom_gap := 4.0 if small_screen else (8.0 if compact else 20.0)
	var dock_height := CombatTheme.DOCK_HEIGHT
	var log_panel: Control = $UILayer/Control/CombatLogPanel
	var log_width := clampf(viewport_size.x * 0.22, 210.0, 420.0)
	var log_inset := log_width if log_panel.visible else 0.0
	var combat_ui: Control = $UILayer/Control/CombatUI
	combat_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var combat_bar: Control = $UILayer/Control/CombatUI/Combat_bar
	combat_bar.scale = Vector2.ONE
	combat_bar.offset_left = edge
	combat_bar.custom_minimum_size = Vector2.ZERO
	combat_bar.offset_top = -dock_height - edge
	combat_bar.offset_bottom = -edge
	combat_bar.offset_right = edge + minf(ACTION_DOCK_WIDTH, viewport_size.x - 120.0)
	var combat_bar_container: MarginContainer = $UILayer/Control/CombatUI/Combat_bar/Combat_bar_Container
	combat_bar_container.custom_minimum_size = Vector2.ZERO
	combat_bar_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var combat_status_bar: HBoxContainer = $UILayer/Control/CombatUI/Combat_bar/Combat_bar_Container/VBoxContainer/StatusBar
	combat_status_bar.custom_minimum_size = Vector2(0.0, 14.0)
	combat_status_bar.size_flags_vertical = Control.SIZE_FILL
	var combat_bar_frame: NinePatchRect = $UILayer/Control/CombatUI/Combat_bar/Combat_bar_Container/VBoxContainer/Combat_bar
	combat_bar_frame.custom_minimum_size = Vector2(0.0, 56.0)
	var background := combat_bar_frame.get_node_or_null("BG") as Control
	if background != null:
		background.custom_minimum_size = Vector2.ZERO
	var content_margin: MarginContainer = combat_bar_frame.get_node("MarginContainer")
	content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_margin.offset_left = 3
	content_margin.offset_top = 3
	content_margin.offset_right = -3
	content_margin.offset_bottom = -3
	content_margin.add_theme_constant_override("margin_left", 3)
	content_margin.add_theme_constant_override("margin_right", 3)
	var dock_content: HBoxContainer = content_margin.get_node("HBoxContainer")
	dock_content.add_theme_constant_override("separation", 4)
	var profile: VBoxContainer = content_margin.get_node("HBoxContainer/Profile")
	profile.offset_transform_enabled = false
	profile.offset_transform_position = Vector2.ZERO
	profile.custom_minimum_size.x = 58
	profile.size_flags_horizontal = Control.SIZE_FILL
	for child in profile.get_children():
		if child is Label:
			child.add_theme_font_size_override("font_size", 7)
			child.autowrap_mode = TextServer.AUTOWRAP_OFF
			child.clip_text = true
	var defense_column: VBoxContainer = dock_content.get_node("DefenseAndResource")
	for defense in defense_column.get_node("HBoxContainer").get_children():
		for child in defense.get_children():
			if child is Label:
				child.add_theme_font_size_override("font_size", 7)
	combat_status_bar.get_node("Status").add_theme_stylebox_override("normal", UITheme.style(UITheme.BUTTON_BACKGROUND, UITheme.CARD_BORDER, 2))
	var minor_column: VBoxContainer = combat_bar.get_node("Action_bar_Minor")
	minor_column.add_theme_constant_override("separation", 0)
	minor_column.custom_minimum_size = Vector2.ZERO
	minor_column.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	minor_column.offset_right = minf(ACTION_DOCK_WIDTH, maxf(60.0, minor_action_list.columns * 30.0 + 6.0))
	minor_column.offset_top = -60
	minor_column.offset_bottom = -6
	minor_column.get_node("VSeparator").hide()
	minor_column.get_node("NinePatchRect").custom_minimum_size = Vector2(0, 36)
	minor_action_title.add_theme_font_size_override("font_size", 4)
	minor_column.get_node("MenuHeader/Close").add_theme_font_size_override("font_size", 4)
	var turn_panel: Control = combat_ui.get_node("Endturn")
	turn_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	turn_panel.offset_left = -edge - log_inset - 86
	turn_panel.offset_top = -edge - 50
	turn_panel.offset_right = -edge - log_inset
	turn_panel.offset_bottom = -edge
	var major_action_grid: GridContainer = $UILayer/Control/CombatUI/Combat_bar/Combat_bar_Container/VBoxContainer/Combat_bar/MarginContainer/HBoxContainer/Action_Bar_Major
	major_action_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.get_node("HBoxContainer/DefenseAndResource").size_flags_horizontal = Control.SIZE_FILL
	major_action_grid.add_theme_constant_override("h_separation", 2 if small_screen else 4)
	major_action_grid.add_theme_constant_override("v_separation", 2 if small_screen else 4)
	for action_card in major_action_grid.get_children():
		if action_card is Control:
			action_card.custom_minimum_size = Vector2(40.0, 24.0)
			var action_button := action_card.get_node_or_null("Button") as Button
			if action_button != null:
				action_button.add_theme_font_size_override("font_size", 7)
		if action_card is NinePatchRect:
			action_card.patch_margin_left = 6
			action_card.patch_margin_right = 6
	var profile_portrait: TextureRect = $UILayer/Control/CombatUI/Combat_bar/Combat_bar_Container/VBoxContainer/Combat_bar/MarginContainer/HBoxContainer/Profile/TextureRect
	profile_portrait.custom_minimum_size = Vector2(24.0, 24.0)
	var header: Control = $UILayer/Control/Header
	header.custom_minimum_size = Vector2(0.0, header_height)
	header.set_anchors_preset(Control.PRESET_TOP_LEFT)
	header.offset_left = edge
	header.offset_top = edge
	header.offset_right = -edge
	header.offset_bottom = edge + header_height
	var log_button: Button = $UILayer/Control/CombatLogButton
	var log_button_width := 90.0 if small_screen else 112.0
	log_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	log_button.offset_left = edge
	log_button.offset_top = edge + 3.0
	log_button.offset_right = edge + log_button_width
	log_button.offset_bottom = edge + header_height - 3.0
	log_button.add_theme_font_size_override("font_size", 9 if small_screen else 12)
	var initiative_timeline: HBoxContainer = $UILayer/Control/Header/InitiativeTimeline
	initiative_timeline.set_anchors_preset(Control.PRESET_FULL_RECT)
	initiative_timeline.offset_left = log_button_width + 6.0
	initiative_timeline.offset_top = 2.0
	initiative_timeline.offset_right = -6.0
	initiative_timeline.offset_bottom = -2.0
	initiative_timeline.add_theme_constant_override("separation", 4 if small_screen else 6)
	initiative_timeline.alignment = BoxContainer.ALIGNMENT_BEGIN
	combat_round_label.custom_minimum_size = Vector2(130.0, 0.0)
	combat_round_label.size_flags_horizontal = Control.SIZE_FILL
	combat_round_label.add_theme_font_size_override("font_size", 9 if small_screen else 12)
	$UILayer/Control/Header/InitiativeTimeline/Separator.custom_minimum_size.y = 24.0 if small_screen else 30.0
	initiative_row.add_theme_constant_override("separation", 3 if small_screen else 4)
	for child in initiative_row.get_children():
		if child is Button:
			child.custom_minimum_size = Vector2(24.0, 24.0)
	header.offset_right = edge + minf(viewport_size.x - edge * 2.0, log_button_width + initiative_timeline.get_combined_minimum_size().x + 18.0)
	var side_width := minf(180.0 if small_screen else (300.0 if compact else 340.0), viewport_size.x - edge * 2.0)
	var target_height := 80.0 if small_screen else 100.0
	var enemy_panel: Control = $UILayer/Control/Enemy_panel
	enemy_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	enemy_panel.offset_left = -edge - log_inset - side_width
	enemy_panel.offset_top = edge + header_height + (6.0 if small_screen else 10.0)
	enemy_panel.offset_right = -edge - log_inset
	enemy_panel.offset_bottom = enemy_panel.offset_top + target_height
	var target_title: Label = $UILayer/Control/Enemy_panel/VBoxContainer/PanelTitle
	var target_name: Label = $UILayer/Control/Enemy_panel/VBoxContainer/Name
	var target_hp: Label = $UILayer/Control/Enemy_panel/VBoxContainer/Hp
	var target_effects: Label = $UILayer/Control/Enemy_panel/VBoxContainer/Effects
	target_title.label_settings.font_size = 10 if small_screen else 13
	target_title.label_settings.font_color = UITheme.GOLD
	for target_label in [target_name, target_hp, target_effects]:
		target_label.label_settings.font_size = 9 if small_screen else 13
	target_name.clip_text = small_screen
	target_effects.max_lines_visible = 1 if small_screen else -1
	target_effects.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	log_panel.custom_minimum_size = Vector2.ZERO
	log_panel.anchor_left = 1.0
	log_panel.anchor_top = 0.0
	log_panel.anchor_right = 1.0
	log_panel.anchor_bottom = 1.0
	log_panel.offset_left = -log_width
	log_panel.offset_top = 0.0
	log_panel.offset_right = 0.0
	log_panel.offset_bottom = 0.0
	var log_margin: MarginContainer = $UILayer/Control/CombatLogPanel/Margin
	log_margin.add_theme_constant_override("margin_left", 7)
	log_margin.add_theme_constant_override("margin_top", 8)
	log_margin.add_theme_constant_override("margin_right", 7)
	log_margin.add_theme_constant_override("margin_bottom", 8)
	var log_column: VBoxContainer = $UILayer/Control/CombatLogPanel/Margin/VBoxContainer
	log_column.add_theme_constant_override("separation", 4)
	var log_title: Label = $UILayer/Control/CombatLogPanel/Margin/VBoxContainer/Header/Title
	log_title.add_theme_font_size_override("font_size", 9)
	log_title.clip_text = true
	var log_close: Button = $UILayer/Control/CombatLogPanel/Margin/VBoxContainer/Header/Close
	log_close.custom_minimum_size = Vector2(24.0, 24.0)
	log_close.add_theme_font_size_override("font_size", 8)
	$UILayer/Control/CombatLogPanel/Margin/VBoxContainer/Turn.add_theme_font_size_override("font_size", 7)
	$UILayer/Control/CombatLogPanel/Margin/VBoxContainer/ModeHint.add_theme_font_size_override("font_size", 7)
	$UILayer/Control/CombatLogPanel/Margin/VBoxContainer/Scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var log_entries: VBoxContainer = $UILayer/Control/CombatLogPanel/Margin/VBoxContainer/Scroll/Entries
	log_entries.add_theme_constant_override("separation", 5)
	for card in log_entries.get_children():
		if card.has_method("apply_compact_layout"):
			card.apply_compact_layout(true)
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
	var reaction_width := minf(248.0, (viewport_size.x - edge * 2.0 - 8.0) * 0.5)
	var reaction_top := edge + header_height + 6.0
	var reaction_height := minf(240.0, viewport_size.y - dock_height - edge * 2.0 - reaction_top)
	for index in range(2):
		var reaction_panel: Control = combat_ui.get_node("Reaction" if index == 0 else "ReactionDescription")
		reaction_panel.custom_minimum_size = Vector2.ZERO
		reaction_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		reaction_panel.position = Vector2(viewport_size.x * 0.5 - reaction_width - 4.0 if index == 0 else viewport_size.x * 0.5 + 4.0, reaction_top)
		reaction_panel.size = Vector2(reaction_width, reaction_height)


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
	focus_camera_on_current_actor()
	for child in initiative_row.get_children():
		initiative_row.remove_child(child)
		child.queue_free()
	for index in range(state.turn_order.size()):
		var actor_id: String = state.turn_order[index]
		var actor: CombatantState = state.get_combatant(actor_id)
		if actor == null:
			continue
		var chip := Button.new()
		chip.custom_minimum_size = Vector2(24, 24)
		chip.text = actor.display_name.left(1).to_upper()
		if actor.token_texture != null:
			chip.text = ""
			chip.icon = actor.token_texture
			chip.expand_icon = true
		chip.tooltip_text = "%d. %s%s" % [index + 1, actor.display_name, " - Current Turn" if actor_id == state.current_actor_id else ""]
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		style_initiative_chip(chip, actor_id == state.current_actor_id, actor.team != state.get_combatant("player").team)
		chip.pressed.connect(_select_character_from_initiative.bind(actor_id))
		initiative_row.add_child(chip)
		if index < state.turn_order.size() - 1:
			var arrow := Label.new()
			arrow.text = ">"
			arrow.add_theme_color_override("font_color", UITheme.MUTED)
			initiative_row.add_child(arrow)
	if minor_action_list != null:
		_apply_responsive_layout.call_deferred()


func _select_character_from_initiative(actor_id: String) -> void:
	if combat_system == null or combat_system.get_combat_state() == null:
		return
	var selected: CombatantState = combat_system.get_combat_state().get_combatant(actor_id)
	if selected == null or selected.is_dying():
		return
	selected_character_id = actor_id
	var primary: CombatantState = combat_system.get_combat_state().get_combatant("player")
	if primary != null and selected.team != primary.team:
		selected_target_id = actor_id
	update_target_selection()
	$UILayer/Control.add_log_message("Turn Manager selected: %s." % selected.display_name)


func style_initiative_chip(button: Button, current: bool, enemy: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.BUTTON_BACKGROUND
	style.border_color = UITheme.GOLD if current else (UITheme.ENEMY if enemy else UITheme.ALLY)
	style.set_border_width_all(2 if current else 1)
	style.set_corner_radius_all(19)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override("font_color", UITheme.GOLD if current else UITheme.TEXT)


func _apply_combat_typography() -> void:
	$UILayer/Control/Enemy_panel/VBoxContainer/PanelTitle.add_theme_color_override("font_color", UITheme.GOLD)
	$UILayer/Control/ReactionPrompt/VBoxContainer/Title.add_theme_color_override("font_color", UITheme.GOLD)


func _apply_combat_theme() -> void:
	UITheme.apply_combat_theme($UILayer/Control)
	CombatTheme.apply($UILayer/Control)
	refresh_initiative_bar(true)
	for panel_path in ["Header", "Enemy_panel", "CombatLogPanel", "ReactionPrompt", "ActionMenu"]:
		var panel := $UILayer/Control.get_node_or_null(panel_path) as Control
		if panel != null:
			style_panel(panel, UITheme.CARD_BACKGROUND, UITheme.GOLD if panel_path in ["Enemy_panel", "ReactionPrompt"] else UITheme.CARD_BORDER, 4)
	var status_strip := $UILayer/Control.get_node_or_null("CombatUI/Combat_bar/Combat_bar_Container/VBoxContainer/StatusBar/Status") as Label
	if status_strip != null:
		status_strip.add_theme_stylebox_override("normal", UITheme.style(UITheme.BUTTON_BACKGROUND, UITheme.CARD_BORDER, 4))
		status_strip.add_theme_color_override("font_color", UITheme.MUTED)


func _style_combat_log_strip() -> void:
	var log_style := UITheme.style(UITheme.CARD_BACKGROUND, Color("d4463f"), 0)
	log_style.set_border_width_all(0)
	log_style.border_width_left = 2
	log_style.set_corner_radius_all(0)
	$UILayer/Control/CombatLogPanel.add_theme_stylebox_override("panel", log_style)


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
	_apply_responsive_layout()


func _build_gm_console() -> void:
	if gm_console_controller == null:
		gm_console_controller = GMConsoleControllerScript.new(self)
	gm_console_controller.build()


func _input(event: InputEvent) -> void:
	if gm_console_controller != null:
		gm_console_controller.handle_input(event)


func _build_essential_hud() -> void:
	_build_reference_player_panel()
	_build_reference_turn_panel()


func _build_reference_player_panel() -> void:
	reference_player_panel = $UILayer/Control/CombatUI/Combat_bar
	reference_player_portrait = $UILayer/Control/CombatUI/Combat_bar/Combat_bar_Container/VBoxContainer/Combat_bar/MarginContainer/HBoxContainer/Profile/TextureRect
	reference_player_portrait.tooltip_text = "Click to open Character"
	reference_player_portrait.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	reference_player_portrait.mouse_filter = Control.MOUSE_FILTER_STOP
	reference_player_portrait.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			reference_player_portrait.accept_event()
			open_character_from_portrait()
	)


func _build_reference_turn_panel() -> void:
	reference_turn_panel = $UILayer/Control/CombatUI/Endturn
	essential_turn_status = $UILayer/Control/CombatUI/Endturn/VBoxContainer/Label2
	@warning_ignore("shadowed_variable_base_class")
	reference_end_turn_button = $UILayer/Control/CombatUI/Endturn/Button
	reference_end_turn_button.pressed.connect(func():
		refresh_end_turn_lock()
		if not reference_end_turn_button.disabled:
			$"UILayer/Control/ActionSources/End Turn".pressed.emit()
	)


func _build_action_dock() -> void:
	var action_grid: GridContainer = $UILayer/Control/CombatUI/Combat_bar/Combat_bar_Container/VBoxContainer/Combat_bar/MarginContainer/HBoxContainer/Action_Bar_Major
	var background := $UILayer/Control/CombatUI/Combat_bar/Combat_bar_Container/VBoxContainer/Combat_bar.get_node_or_null("BG") as Control
	if background != null:
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_category_buttons.clear()
	for category in ["attack", "move", "skill", "ability", "basic", "item"]:
		var card: Control = action_grid.get_node(category.capitalize())
		var button: Button = card.get_node("Button")
		var label: Label = card.get_node("Label")
		label.text = "BASIC" if category == "basic" else category.to_upper()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var decoration := card.get_node_or_null("TextureRect") as Control
		if decoration != null:
			decoration.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.tooltip_text = "Choose %s" % category.capitalize()
		var callback := _on_action_category_pressed.bind(category)
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)
		action_category_buttons[category] = button
	$UILayer/Control/CombatUI/Reaction.visible = false
	$UILayer/Control/CombatUI/ReactionDescription.visible = false
	_build_action_menu()
func _build_action_menu() -> void:
	action_menu_panel = $UILayer/Control/ActionMenu
	style_panel(action_menu_panel, UITheme.CARD_BACKGROUND, UITheme.GOLD, 4)
	action_menu_title = $UILayer/Control/ActionMenu/Margin/Column/Header/Title
	var close: Button = $UILayer/Control/ActionMenu/Margin/Column/Header/Close
	close.pressed.connect(func(): action_menu_panel.visible = false)
	action_menu_panel.visible = false
	_build_minor_action_list()
	action_menu_controller = ActionMenuScript.new(self)


func _build_minor_action_list() -> void:
	var minor_action_panel: VBoxContainer = $UILayer/Control/CombatUI/Combat_bar/Action_bar_Minor
	var frame: NinePatchRect = minor_action_panel.get_node("NinePatchRect")
	minor_action_panel.visible = false
	var menu_header := HBoxContainer.new()
	menu_header.name = "MenuHeader"
	minor_action_panel.add_child(menu_header)
	minor_action_panel.move_child(menu_header, 0)
	minor_action_title = UITheme.label("ACTIONS", CombatTheme.BODY, UITheme.GOLD)
	minor_action_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_header.add_child(minor_action_title)
	var close := Button.new()
	close.name = "Close"
	close.text = "CLOSE"
	close.pressed.connect(minor_action_panel.hide)
	menu_header.add_child(close)
	minor_action_scroll = ScrollContainer.new()
	minor_action_scroll.name = "ActionScroll"
	minor_action_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	minor_action_scroll.offset_left = 2.0
	minor_action_scroll.offset_top = 2.0
	minor_action_scroll.offset_right = -2.0
	minor_action_scroll.offset_bottom = -2.0
	minor_action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	minor_action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	minor_action_scroll.scroll_horizontal_custom_step = 48.0
	minor_action_scroll.follow_focus = true
	minor_action_scroll.visible = false
	frame.add_child(minor_action_scroll)
	minor_action_list = GridContainer.new()
	minor_action_list.name = "ActionList"
	minor_action_list.columns = 2
	minor_action_list.add_theme_constant_override("h_separation", 2)
	minor_action_list.add_theme_constant_override("v_separation", 2)
	minor_action_scroll.add_child(minor_action_list)
	action_menu_list = minor_action_list


func _on_action_category_pressed(category: String) -> void:
	var minor: Control = $UILayer/Control/CombatUI/Combat_bar/Action_bar_Minor
	if minor.visible and minor.get_meta("category", "") == category:
		minor.hide()
		return
	if category == "move":
		if is_inactive_friendly_selected():
			show_action_menu("move")
			return
		action_menu_panel.visible = false
		$UILayer/Control/ActionSources/Move.pressed.emit()
		minor.hide()
		return
	show_action_menu(category)


func show_action_menu(category: String) -> void:
	action_menu_controller.show_action_menu(category)


func add_action_menu_button(text: String, tooltip: String, action: Callable, menu_navigation: bool = false) -> void:
	action_menu_controller.add_action_menu_button(text, tooltip, action, menu_navigation)


func add_action_menu_note(text: String) -> void:
	action_menu_controller.add_action_menu_note(text)


func style_minor_action_button(button: Button, icon_texture: Texture2D) -> void:
	action_menu_controller.style_minor_action_button(button, icon_texture)


func use_equipment_attack(attack: AttackData) -> void:
	begin_attack_targeting(attack)


func begin_attack_targeting(attack: AttackData) -> void:
	if attack == null:
		return
	pending_target_attack = attack
	pending_search_targeting = false
	ground_targeting_kind = ""
	ground_targeting_id = ""
	move_mode = false
	selected_target_id = ""
	update_target_selection()
	$UILayer/Control.set_mode_hint("%s: choose a highlighted target within %.1f ft. Right-click or Esc cancels." % [attack.display_name, attack.range_feet])
	$UILayer/Control.add_log_message("Attack Targeting active: %s." % attack.display_name)
	queue_redraw()


func begin_basic_maneuver_targeting(maneuver: ActionTypes.Maneuver) -> void:
	pending_basic_maneuver = maneuver
	pending_search_targeting = false
	pending_target_attack = null
	pending_single_target_kind = ""
	pending_single_target_source = null
	ground_targeting_kind = ""
	ground_targeting_id = ""
	move_mode = false
	selected_target_id = ""
	update_target_selection()
	var actor := get_player_controlled_actor()
	var range_feet: float = actor.unarmed_attack.range_feet if actor != null and actor.unarmed_attack != null else 5.0
	$UILayer/Control.set_mode_hint("%s: choose an enemy within %.1f ft. Right-click or Esc cancels." % [ActionTypes.Maneuver.keys()[maneuver].capitalize(), range_feet])
	queue_redraw()


func draw_attack_targeting() -> void:
	var state = combat_system.get_combat_state()
	var player: CombatantState = get_displayed_party_member()
	if player == null:
		return
	var range_feet: float = pending_target_attack.range_feet if pending_target_attack != null else (player.unarmed_attack.range_feet if player.unarmed_attack != null else 5.0)
	if not pending_search_targeting:
		var range_world: float = combat_system.map_rules.get_targeting_preview_radius_world_units(player, range_feet)
		draw_circle(player.position, range_world, Color(0.34, 0.59, 0.67, 0.10))
		draw_arc(player.position, range_world, 0.0, TAU, 96, Color("78bed0"), 2.0)
	for target in state.combatants.values():
		if target == null or target.team == player.team or target.is_dying():
			continue
		if not combat_system.map_rules.has_line_of_sight_between(player, target):
			continue
		var in_range: bool = pending_search_targeting or combat_system.map_rules.is_target_in_range(player, target, range_feet)
		var color := Color("d5a84c") if in_range else Color(0.55, 0.58, 0.60, 0.45)
		var radius: float = combat_system.map_rules.get_combatant_radius_world_units(target) + 7.0
		draw_arc(target.position, radius, 0.0, TAU, 40, color, 4.0 if in_range else 2.0)


func confirm_attack_target(mouse_position: Vector2) -> bool:
	var player: CombatantState = get_player_controlled_actor()
	for combatant_node in get_enemy_nodes():
		if not combatant_node.is_spatially_selectable():
			continue
		if combatant_node.state == null or combatant_node.state.is_dying():
			continue
		var target: CombatantState = combatant_node.state
		var radius: float = target.collision_radius_feet * combat_system.map_rules.world_units_per_foot
		if mouse_position.distance_to(target.position) > radius + 8.0:
			continue
		if pending_search_targeting:
			pending_search_targeting = false
			selected_target_id = target.id
			selected_character_id = target.id
			update_target_selection()
			handle_menu_action_result(combat_system.use_search(player.id, target.id))
			queue_redraw()
			return true
		var range_feet: float = pending_target_attack.range_feet if pending_target_attack != null else (player.unarmed_attack.range_feet if player.unarmed_attack != null else 5.0)
		if not combat_system.map_rules.is_target_in_range(player, target, range_feet):
			$UILayer/Control.set_mode_hint("%s is outside this action's %.1f ft range." % [target.display_name, range_feet])
			return true
		if pending_basic_maneuver >= 0:
			var maneuver: ActionTypes.Maneuver = pending_basic_maneuver
			pending_basic_maneuver = -1
			selected_target_id = target.id
			selected_character_id = target.id
			update_target_selection()
			handle_menu_action_result(combat_system.use_basic_maneuver(player.id, target.id, maneuver))
			queue_redraw()
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
	if pending_target_attack == null and pending_basic_maneuver < 0 and not pending_search_targeting:
		return
	var attack_name: String = "Search" if pending_search_targeting else (pending_target_attack.display_name if pending_target_attack != null else ActionTypes.Maneuver.keys()[pending_basic_maneuver].capitalize())
	pending_target_attack = null
	pending_basic_maneuver = -1
	pending_search_targeting = false
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
	if skill.target_mode == SkillData.TargetMode.SELF:
		var actor_id := get_player_controlled_actor_id()
		var request := ActionRequest.new(actor_id, ActionTypes.Type.SKILL)
		request.target_id = actor_id
		request.skill_data = skill
		handle_menu_action_result(combat_system.execute_action(request))
		return
	begin_single_targeting("skill", skill)


func use_hide_from_menu() -> void:
	handle_menu_action_result(combat_system.use_hide(get_player_controlled_actor_id()))


func begin_search_targeting() -> void:
	pending_target_attack = null
	pending_basic_maneuver = -1
	pending_single_target_kind = ""
	pending_single_target_source = null
	ground_targeting_kind = ""
	ground_targeting_id = ""
	move_mode = false
	pending_search_targeting = true
	selected_target_id = ""
	update_target_selection()
	$UILayer/Control.set_mode_hint("Search: choose any highlighted enemy, even if not visible. Right-click or Esc cancels.")
	$UILayer/Control.add_log_message("Search targeting active.")
	queue_redraw()


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


func use_item_from_menu(item: ConsumableData) -> void:
	if item.target_mode == ConsumableData.TargetMode.SELF:
		var actor_id := get_player_controlled_actor_id()
		handle_menu_action_result(combat_system.use_consumable_item(actor_id, item.id, actor_id))
		return
	if item.target_mode == ConsumableData.TargetMode.SINGLE_COMBATANT:
		begin_single_targeting("item", item)
		return
	begin_ground_targeting("item", item.id)


func begin_single_targeting(kind: String, source) -> void:
	pending_single_target_kind = kind
	pending_single_target_source = source
	pending_target_attack = null
	pending_search_targeting = false
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
	if kind == "item":
		return source.range_feet
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
		if target == null or not is_valid_single_target(player, target):
			continue
		if target.team != player.team and not combat_system.map_rules.has_line_of_sight_between(player, target):
			continue
		var in_range: bool = combat_system.map_rules.is_target_in_range(player, target, range_feet)
		var color := Color("d5a84c") if in_range else Color(0.55, 0.58, 0.60, 0.45)
		draw_arc(target.position, combat_system.map_rules.get_combatant_radius_world_units(target) + 7.0, 0.0, TAU, 40, color, 4.0 if in_range else 2.0)


func is_valid_single_target(player: CombatantState, target: CombatantState) -> bool:
	if target.is_dying() and (pending_single_target_kind != "item" or pending_single_target_source.cannot_target_dying):
		return false
	if pending_single_target_kind == "skill":
		match pending_single_target_source.target_filter:
			SkillData.TargetFilter.ENEMIES: return target.team != player.team
			SkillData.TargetFilter.ALLIES: return target.team == player.team
			_: return true
	if pending_single_target_kind == "item":
		return combat_system.consumable_item_executor.target_filter_matches(player, target, pending_single_target_source)
	match pending_single_target_source.target_filter:
		AbilityData.TargetFilter.ENEMIES: return target.team != player.team
		AbilityData.TargetFilter.ALLIES: return target.team == player.team
		_: return true


func confirm_single_target(mouse_position: Vector2) -> bool:
	var state = combat_system.get_combat_state()
	var player: CombatantState = get_player_controlled_actor()
	var range_feet: float = get_single_target_range(pending_single_target_kind, pending_single_target_source)
	for combatant_node in get_all_combatant_nodes():
		if not combatant_node.is_spatially_selectable():
			continue
		var target: CombatantState = combatant_node.state
		if target == null or not is_valid_single_target(player, target):
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
		elif kind == "ability":
			handle_menu_action_result(combat_system.use_active_ability(player.id, target.id, source.id))
		else:
			handle_menu_action_result(combat_system.use_consumable_item(player.id, source.id, target.id))
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
	refresh_essential_hud()


func refresh_action_dock() -> void:
	if combat_system != null and combat_system.get_combat_state() != null:
		var state = combat_system.get_combat_state()
		var locked: bool = state.is_finished() or not is_player_party_turn() or combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement()
		for category in action_category_buttons:
			action_category_buttons[category].disabled = locked
		var current_actor: CombatantState = state.get_current_actor()
		if action_category_buttons.has("move") and current_actor != null and is_player_party_turn():
			action_category_buttons["move"].disabled = locked or not combat_system.movement_system.can_begin_or_continue_move(current_actor, 1)
		for category in action_category_buttons:
			var category_button: Button = action_category_buttons[category]
			category_button.get_parent().modulate = Color(0.48, 0.5, 0.55, 1.0) if category_button.disabled else Color.WHITE
		if locked and action_menu_panel != null:
			action_menu_panel.visible = false
			$UILayer/Control/CombatUI/Combat_bar/Action_bar_Minor.hide()


func use_escape_from_menu(status_id: String) -> void:
	action_menu_panel.visible = false
	var actor: CombatantState = get_player_controlled_actor()
	if actor == null:
		return
	var result: ActionResult = combat_system.execute_escape(actor.id, status_id)
	$UILayer/Control.record_action_result(result)
	if not result.success:
		$UILayer/Control.set_mode_hint("Escape failed: %s" % result.failure_reason)
	else:
		$UILayer/Control.set_mode_hint("Escape resolved. Choose an action.")
	refresh_combatant_nodes()
	refresh_essential_hud()


func use_stand_from_menu() -> void:
	action_menu_panel.visible = false
	var actor := get_player_controlled_actor()
	if actor != null:
		handle_menu_action_result(combat_system.use_basic_maneuver(actor.id, "", ActionTypes.Maneuver.STAND))


func refresh_essential_hud() -> void:
	if reference_player_panel == null or combat_system == null:
		return
	var state = combat_system.get_combat_state()
	if state == null:
		return
	var player: CombatantState = get_displayed_party_member()
	if player == null:
		return
	var bar := "UILayer/Control/CombatUI/Combat_bar/Combat_bar_Container/VBoxContainer/Combat_bar/MarginContainer/HBoxContainer"
	if reference_player_portrait != null:
		reference_player_portrait.texture = player.token_texture if player.token_texture != null else DevoteeFallbackPortrait
	get_node(bar + "/Profile/Name").text = "%s · Lv %d" % [player.display_name, player.level]
	get_node(bar + "/Profile/Speed").text = "Speed: %.1f ft" % player.get_effective_speed()
	var equipped_names := PackedStringArray()
	for slot in [player.active_weapon_slot, 3 if player.active_weapon_slot == 0 else 0]:
		var equipped_item = player.equipped_items.get(slot)
		if equipped_item != null and not equipped_names.has(equipped_item.display_name):
			equipped_names.append(equipped_item.display_name)
	var weapon_text := " + ".join(equipped_names) if not equipped_names.is_empty() else "Unarmed"
	var weapon_label: Label = get_node(bar + "/Profile/Weapon")
	weapon_label.text = "Weapon: %s" % weapon_text
	weapon_label.tooltip_text = "Equipped hands: %s" % weapon_text
	var resistance_names := PackedStringArray()
	for damage_type in player.damage_resistances:
		var amount: int = player.get_damage_resistance(String(damage_type))
		if amount > 0:
			resistance_names.append("%s %d" % [String(damage_type).capitalize(), amount])
	var resistance_label: Label = get_node(bar + "/Profile/Resistance")
	var resistance_text := ", ".join(resistance_names) if not resistance_names.is_empty() else "None"
	resistance_label.text = "RES %d" % resistance_names.size()
	resistance_label.tooltip_text = "Resistance: %s" % resistance_text
	var immunity_names := PackedStringArray()
	for immunity in player.damage_immunities + player.status_immunities:
		immunity_names.append(String(immunity).capitalize())
	var immunity_label: Label = get_node(bar + "/Profile/Imunity")
	var immunity_text := ", ".join(immunity_names) if not immunity_names.is_empty() else "None"
	immunity_label.text = "IMM %d" % immunity_names.size()
	immunity_label.tooltip_text = "Immunity: %s" % immunity_text
	var status_names := PackedStringArray()
	for effect in player.effects:
		var stack_text := " x%d" % effect.stack_count if effect.stack_count > 1 else ""
		status_names.append("%s%s" % [effect.get_display_name(), stack_text])
	var visible_statuses := status_names.slice(0, mini(3, status_names.size()))
	var status_text := " | ".join(visible_statuses) if not visible_statuses.is_empty() else "None"
	if status_names.size() > visible_statuses.size():
		status_text += " | +%d" % (status_names.size() - visible_statuses.size())
	var status_label: Label = $UILayer/Control/CombatUI/Combat_bar/Combat_bar_Container/VBoxContainer/StatusBar/Status
	status_label.text = "STATUS: %s" % status_text
	status_label.tooltip_text = "Active status: %s" % $UILayer/Control.get_effect_names(player)
	get_node(bar + "/DefenseAndResource/HBoxContainer/Fortitude/Value").text = str(combat_system.defense_system.get_defense(player, DefenseTypes.Type.FORTITUDE))
	get_node(bar + "/DefenseAndResource/HBoxContainer/Reflex/Value").text = str(combat_system.defense_system.get_defense(player, DefenseTypes.Type.REFLEX))
	get_node(bar + "/DefenseAndResource/HBoxContainer/Will/Value").text = str(combat_system.defense_system.get_defense(player, DefenseTypes.Type.WILL))
	_set_combat_resource_bar(bar + "/DefenseAndResource/VBoxContainer/Hp", player.hp, player.max_hp, "HP")
	var temp_hp_panel: Control = get_node(bar + "/DefenseAndResource/VBoxContainer/TempHp")
	temp_hp_panel.visible = false
	var mana_panel: Control = get_node(bar + "/DefenseAndResource/VBoxContainer/Mana")
	mana_panel.visible = player.max_mana > 0
	_set_combat_resource_bar(mana_panel.get_path(), player.mana, player.max_mana, "Mana")
	var faith_panel: Control = get_node(bar + "/DefenseAndResource/VBoxContainer/Faith")
	faith_panel.visible = player.max_faith > 0
	_set_combat_resource_bar(faith_panel.get_path(), player.faith + player.temporary_faith, player.max_faith + player.temporary_faith, "Faith")
	var gauge_panel: Control = get_node(bar + "/DefenseAndResource/VBoxContainer/Heat")
	gauge_panel.visible = player.max_finishing_gauge > 0
	_set_combat_resource_bar(gauge_panel.get_path(), player.finishing_gauge, player.max_finishing_gauge, "Gauge")
	reference_player_portrait.tooltip_text = "%s · Lv %d\nSpeed: %.1f ft\nWeapon: %s\nResistance: %s\nImmunity: %s\nClick to open Character" % [player.display_name, player.level, player.get_effective_speed(), weapon_text, resistance_text, immunity_text]
	essential_turn_status.text = "AP  %d / %d" % [player.ap, player.effective_max_ap]


func _set_combat_resource_bar(panel_path: NodePath, current: int, maximum: int, caption: String) -> void:
	var panel := get_node_or_null(panel_path)
	if panel == null:
		return
	var progress := panel.get_node("ProgressBar") as ProgressBar
	progress.max_value = maxi(1, maximum)
	progress.value = clampi(current, 0, maxi(1, maximum))
	(panel.get_node("ProgressBar/Value") as Label).text = "%s %d/%d" % [caption, current, maximum]


func get_combat_resource_text(player: CombatantState) -> String:
	if player.max_faith > 0:
		return "Faith %d / %d   |   Temporary +%d" % [player.faith, player.max_faith, player.temporary_faith]
	var resource_text := "Mana %d / %d" % [player.mana, player.max_mana]
	if player.max_finishing_gauge > 0:
		resource_text += "   |   Finishing Gauge %d / %d" % [player.finishing_gauge, player.max_finishing_gauge]
	return resource_text


func _build_inventory_drawer() -> void:
	if character_panel_controller == null:
		character_panel_controller = CharacterPanelControllerScript.new(self)
	character_panel_controller.build()


func toggle_inventory() -> void:
	character_panel_controller.toggle_inventory()


func open_character_from_portrait() -> void:
	character_panel_controller.open_character_from_portrait()


func set_character_tab(tab_id: String) -> void:
	character_panel_controller.set_character_tab(tab_id)


func refresh_inventory() -> void:
	character_panel_controller.refresh_inventory()


func refresh_character_panel_interaction_lock(state: CombatState, reaction_locked: bool) -> void:
	if character_panel_controller != null:
		character_panel_controller.refresh_interaction_lock(state, reaction_locked)


func change_inventory_item(item, slot: int) -> void:
	character_panel_controller.change_inventory_item(item, slot)


func is_two_handed_item(item) -> bool:
	return character_panel_controller.is_two_handed_item(item)


func style_panel(panel: Control, background: Color, border: Color, radius: int) -> void:
	# Combat panels already contain their own margins. Leaving style padding at
	# zero keeps the responsive panel bounds independent of the visual theme.
	var style := UITheme.style(background, border, 0, 1)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style)


func style_action_button(button: Button) -> void:
	UITheme.apply_button_style(button)
