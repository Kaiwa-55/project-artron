extends Node2D

const Layout = preload("res://scenes/exploration/dungeon_layout.gd")
const Pawn = preload("res://scenes/exploration/dungeon_pawn.gd")
const Overlay = preload("res://scenes/exploration/dungeon_overlay.gd")
const Visibility = preload("res://scenes/exploration/dungeon_visibility.gd")
const Hostiles = preload("res://scenes/exploration/dungeon_hostiles.gd")
const TokenBuilder = preload("res://scenes/character_creation/token_image_builder.gd")
const RUN_MAP := "res://scenes/run/RunMap.tscn"
const SAVE_KEY := "dungeondraft_exploration"
@onready var save_game = get_node("/root/SaveGame")
var player: CharacterBody2D
var camera: Camera2D
var upper: Sprite2D
var roof: Sprite2D
var overlay: Node2D
var sight: Node2D
var hostiles: Node2D
var floor_id := 0
var overview := false
var inspect_roof := false
var zoom_level := 0.72
var return_started := false
var floor_label: Label
var hint: Label
var stairs_button: Button
var roof_button: Button
var overview_button: Button
var engage_button: Button
var active_run: RunState
var hero_name := "Explorer"

func _ready() -> void:
	if get_tree().has_meta("active_run_state"):
		active_run = get_tree().get_meta("active_run_state") as RunState
	var backdrop_layer := CanvasLayer.new()
	backdrop_layer.layer = -10
	add_child(backdrop_layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color("10191f")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop_layer.add_child(backdrop)
	make_image("Ground", "res://assets/maps/dungeondraft/Ground.png", 0)
	upper = make_image("Level1", "res://assets/maps/dungeondraft/Level1.png", 1)
	upper.visible = false
	roof = make_image("Roof", "res://assets/maps/dungeondraft/roof.png", 10)
	for level in range(2):
		var body := StaticBody2D.new()
		body.name = "Floor%dWalls" % level
		body.collision_layer = 2 if level == 0 else 4
		body.collision_mask = 0
		add_child(body)
		for rect in Layout.walls(level):
			var collider := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = rect.size
			collider.shape = shape
			collider.position = rect.get_center()
			body.add_child(collider)
	player = Pawn.new()
	player.name = "PartyLeader"
	player.position = Layout.START
	add_child(player)
	configure_hero()
	overlay = Overlay.new()
	overlay.z_index = 6
	add_child(overlay)
	sight = Visibility.new()
	sight.name = "WallVisibility"
	sight.z_index = 8 # Conceals map and markers; roof inspection stays above it.
	add_child(sight)
	hostiles = Hostiles.new()
	hostiles.name = "GroundHallGuards"
	hostiles.z_index = 5
	add_child(hostiles)
	camera = Camera2D.new()
	camera.position = player.position
	add_child(camera)
	make_hud()
	restore_location()
	update_view(1.0)

func make_image(node_name: String, path: String, depth: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = load(path)
	sprite.centered = false
	sprite.scale = Layout.SIZE / sprite.texture.get_size()
	sprite.z_index = depth
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
	return sprite

func configure_hero() -> void:
	var character: CharacterData
	if active_run != null and not active_run.party_character_data.is_empty():
		character = active_run.party_character_data[0]
	elif get_tree().has_meta("created_character_data"):
		character = get_tree().get_meta("created_character_data") as CharacterData
	if character == null:
		character = load("res://data/character/player.tres")
	hero_name = character.display_name
	player.token = TokenBuilder.build(character.token_texture, character.token_scale, character.token_offset)

func make_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ExplorationHUD"
	add_child(canvas)
	var shell := Control.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(shell)
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 8
	top.offset_top = 8
	top.offset_right = -8
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035,0.05,0.06,0.96)
	style.border_color = Color("8b754d")
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	style.set_corner_radius_all(5)
	top.add_theme_stylebox_override("panel", style)
	shell.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	top.add_child(row)
	floor_label = Label.new()
	floor_label.add_theme_color_override("font_color",Color("edd7a8"))
	floor_label.add_theme_font_size_override("font_size",12)
	floor_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(floor_label)
	overview_button = add_button(row, "Overview [Tab]", toggle_overview)
	roof_button = add_button(row, "Roof [R]", toggle_roof)
	add_button(row, "Save & Menu", save_and_menu)
	add_button(row, "Return [Esc]", return_to_run)
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 8
	bottom.offset_right = -8
	bottom.offset_top = -57
	bottom.offset_bottom = -8
	bottom.add_theme_stylebox_override("panel",style)
	shell.add_child(bottom)
	var column := VBoxContainer.new()
	bottom.add_child(column)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	hint = Label.new()
	hint.add_theme_font_size_override("font_size",10)
	hint.add_theme_color_override("font_color",Color("a9dbcf"))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)
	stairs_button = add_button(footer,"Use stairs [E]",use_stairs)
	engage_button = add_button(footer,"Engage hostiles [F]",start_hostile_combat)
	var controls := Label.new()
	controls.text = "WASD / Arrows: walk   •   Wheel: zoom   •   F2: walls   •   Home: entrance"
	controls.add_theme_font_size_override("font_size",9)
	column.add_child(controls)

func add_button(parent: Node, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.add_theme_font_size_override("font_size",10)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _process(delta: float) -> void:
	update_view(delta)

func roof_should_show() -> bool:
	return inspect_roof or (floor_id == 0 and not Layout.INTERIOR.has_point(player.position))

func update_view(delta: float) -> void:
	sight.update_observer(player.position,floor_id)
	roof.modulate.a = move_toward(roof.modulate.a,1.0 if roof_should_show() else 0.0,delta * 5.0)
	var viewport_size := get_viewport_rect().size
	var view_zoom := minf(viewport_size.x / 1640.0, (viewport_size.y - 115.0) / 1640.0) if overview else zoom_level
	camera.zoom = Vector2.ONE * maxf(view_zoom,0.05)
	var half_view := viewport_size * 0.5 / camera.zoom
	camera.position = Vector2(800,800) if overview else Vector2(
		clampf(player.position.x, minf(half_view.x,800),maxf(1600-half_view.x,800)),
		clampf(player.position.y, minf(half_view.y,800),maxf(1600-half_view.y,800)))
	player.input_enabled = not inspect_roof and not return_started
	floor_label.text = "ARTRON  /  " + ("GROUND" if floor_id == 0 else "LEVEL 1")
	var at_stairs := Layout.STAIRS.has_point(player.position)
	var hostiles_nearby := floor_id == 0 and Layout.HOSTILE_AREA.has_point(player.position) and not encounter_defeated(Layout.HOSTILE_ID)
	stairs_button.disabled = not at_stairs or inspect_roof
	engage_button.visible = hostiles_nearby
	hostiles.visible_hostiles = not encounter_defeated(Layout.HOSTILE_ID)
	hostiles.queue_redraw()
	stairs_button.text = ("Go up [E]" if floor_id == 0 else "Go down [E]")
	hint.text = hero_name + (" • Stairs ready" if at_stairs else " • Staircase: west side")
	if inspect_roof:
		hint.text = "Roof inspection • Press R to resume walking"
	roof_button.text = "Resume [R]" if inspect_roof else "Roof [R]"
	overview_button.text = "Follow [Tab]" if overview else "Overview [Tab]"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E: use_stairs()
			KEY_F: start_hostile_combat()
			KEY_TAB: toggle_overview()
			KEY_R: toggle_roof()
			KEY_F2:
				overlay.debug_walls = not overlay.debug_walls
				overlay.queue_redraw()
			KEY_ESCAPE: return_to_run()
			KEY_HOME:
				set_floor(0, Layout.START)
				inspect_roof = false
	if event is InputEventMouseButton and event.pressed and not overview:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_level = clampf(zoom_level + 0.08,0.3,1.8)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_level = clampf(zoom_level - 0.08,0.3,1.8)

func toggle_overview() -> void:
	overview = not overview

func toggle_roof() -> void:
	inspect_roof = not inspect_roof

func use_stairs() -> void:
	if return_started or inspect_roof or not Layout.STAIRS.has_point(player.position):
		return
	if set_floor(1-floor_id, Layout.STAIR_LANDING):
		save_location()


func encounter_defeated(encounter_id: String) -> bool:
	if active_run == null:
		return false
	var defeated: Dictionary = active_run.get_meta("dungeon_defeated_encounters", {})
	return bool(defeated.get(encounter_id, false))


func start_hostile_combat() -> void:
	if return_started or inspect_roof or floor_id != 0 or encounter_defeated(Layout.HOSTILE_ID) or not Layout.HOSTILE_AREA.has_point(player.position):
		return
	var encounter := EncounterData.new()
	encounter.id = Layout.HOSTILE_ID
	encounter.display_name = "Hall Guards"
	encounter.encounter_name = "Hall Guards"
	encounter.encounter_description = "Two guards defend the central hall."
	encounter.battlefield_texture = load("res://assets/maps/dungeondraft/Ground.png")
	encounter.map_size_feet = Layout.SIZE / 12.0
	encounter.player_spawn_positions_feet = [Layout.world_to_combat_feet(player.position)]
	for offset in [Vector2(-24,18), Vector2(24,18)]:
		encounter.player_spawn_positions_feet.append(Layout.world_to_combat_feet(player.position + offset))
	encounter.building_map = preload("res://data/world/artron_keep/artron_keep_map.tres")
	encounter.starting_surface_id = &"ground" if floor_id == 0 else &"level_1"
	var guard_source: CharacterData = load("res://data/character/enemy.tres")
	for index in range(Layout.HOSTILE_POSITIONS.size()):
		var guard: CharacterData = guard_source.duplicate()
		guard.id = "hall_guard_%d" % (index + 1)
		guard.display_name = "Hall Guard %d" % (index + 1)
		guard.position = Layout.HOSTILE_POSITIONS[index]
		encounter.enemies.append(guard)
	save_location()
	get_tree().set_meta("active_encounter_data", encounter)
	get_tree().set_meta("dungeon_combat_return", {"encounter_id": Layout.HOSTILE_ID})
	return_started = true
	var change_error := get_tree().change_scene_to_file("res://scenes/prototype/PrototypeCombat.tscn")
	if change_error != OK:
		return_started = false
		get_tree().remove_meta("active_encounter_data")
		get_tree().remove_meta("dungeon_combat_return")
		push_error("Could not begin hall combat: %s" % error_string(change_error))

func set_floor(destination: int, landing: Vector2) -> bool:
	if not Layout.can_stand(landing,destination):
		return false
	floor_id = destination
	player.collision_mask = 2 if floor_id == 0 else 4
	player.velocity = Vector2.ZERO
	player.position = landing
	upper.visible = floor_id == 1
	overlay.floor_id = floor_id
	overlay.queue_redraw()
	sight.update_observer(player.position,floor_id)
	return true

func save_location() -> void:
	if active_run != null:
		active_run.set_meta(SAVE_KEY, {"floor": floor_id, "position": player.position})
		save_game.save_run(active_run, "exploration")


func save_and_menu() -> void:
	save_location()
	if save_game.last_error.is_empty():
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")

func restore_location() -> void:
	if active_run == null:
		return
	var saved: Dictionary = active_run.get_meta(SAVE_KEY, {})
	if not saved.is_empty():
		set_floor(int(saved.get("floor",0)), saved.get("position",Layout.START))

func return_to_run() -> void:
	if return_started:
		return
	return_started = true
	save_location()
	var error := get_tree().change_scene_to_file(RUN_MAP)
	if error != OK:
		return_started = false
		push_error("Could not return to Run Map: %s" % error)
