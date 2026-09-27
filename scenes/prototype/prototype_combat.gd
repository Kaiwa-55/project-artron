extends "res://scenes/prototype/prototype_ui_controller.gd"

const REWARD_SCENE := "res://scenes/run/RewardSelection.tscn"
const COMBAT_SCENE := "res://scenes/prototype/PrototypeCombat.tscn"
const CUTSCENE_SCENE := "res://scenes/prototype/EncounterCutscene.tscn"
const RUN_MAP_SCENE := "res://scenes/run/RunMap.tscn"
const PreCombatStatusSystemScript := preload("res://encounter/pre_combat_status_system.gd")
const DefaultBuildingMap: BuildingMapData = preload("res://data/world/artron_keep/artron_keep_map.tres")
const DungeonWorldScene := preload("res://scenes/world3d/DungeonWorld3D.tscn")
const AreaVisual := preload("res://scenes/world3d/area_visual_3d.gd")
const DesertStorm3D := preload("res://scenes/world3d/desert_storm_3d.gd")
const EnemyGroupDataScript := preload("res://data/encounter/enemy_group_data.gd")
const ENEMY_ACTION_PAUSE_SECONDS := 1.0

var post_combat_transition_started: bool = false
var objective_panel: PanelContainer
var objective_list: VBoxContainer
var objective_toggle_button: Button
var objective_panel_open := true
var resolved_encounter: Resource
var dungeon_world: DungeonWorld3D
var battlefield_camera_3d: Camera3D
var area_target_pick: Dictionary = {}
var area_preview_3d
var smoke_visuals_3d: Dictionary = {}
var area_preview_geometry_key: Array = []
var spatial_combatants: Array[Node3D] = []
var followed_surface_id: StringName = &"ground"
var visibility_debug_enabled := false
var visibility_debug_key_down := false
var prefer_floor_on_stair_overlap := false
var movement_pick_options: Dictionary = {}
var encounter_spawn_rng := RandomNumberGenerator.new()
var enemy_action_pause_pending := false


func reset_combat() -> void:
	get_tree().reload_current_scene()

func start_test_combat() -> void:
	encounter_spawn_rng.randomize()
	combat_system = CombatSystem.new()
	var active_encounter: Resource = get_active_encounter_data()
	var active_map: BuildingMapData = active_encounter.building_map if active_encounter != null and active_encounter.building_map != null else _create_flat_encounter_map(active_encounter)
	combat_system.map_rules.configure_building_map(active_map)
	if active_encounter != null:
		combat_system.map_rules.set_light_level(active_encounter.initial_light_level)
	var map_size_feet: Vector2 = active_map.source_size / active_map.pixels_per_foot
	var map_size_world: Vector2 = map_size_feet * combat_system.map_rules.world_units_per_foot
	_setup_3d_world(active_map)
	_configure_desert_storm(active_encounter)
	$BattlefieldCamera.configure(combat_system.map_rules.playable_bounds, Vector2.ZERO)
	for object_data in _get_encounter_objects(active_encounter):
		if String(object_data.get("kind", "")) != "obstacle":
			continue
		var blocks_movement := bool(object_data.get("blocks_movement", true))
		var blocks_line_of_sight := bool(object_data.get("blocks_line_of_sight", blocks_movement))
		if not blocks_movement and not blocks_line_of_sight:
			continue
		if object_data.has("rect_feet"):
			var rect_feet: Rect2 = Rect2(object_data.get("rect_feet", Rect2()))
			var rect_world := Rect2(
				rect_feet.position * combat_system.map_rules.world_units_per_foot,
				rect_feet.size * combat_system.map_rules.world_units_per_foot
			)
			combat_system.map_rules.add_rectangular_obstacle(rect_world, String(object_data.get("label", "Wall")), blocks_movement, blocks_line_of_sight)
			continue
		var center: Vector2 = Vector2(object_data.get("position_feet", Vector2.ZERO)) * combat_system.map_rules.world_units_per_foot
		var radius: float = float(object_data.get("radius_feet", 0.0)) * combat_system.map_rules.world_units_per_foot
		combat_system.map_rules.add_circular_obstacle(center, radius, String(object_data.get("label", "Obstacle")), blocks_movement, blocks_line_of_sight)
	dungeon_world.add_encounter_obstacles(combat_system.map_rules.obstacles)
	move_mode = false
	prefer_floor_on_stair_overlap = false
	movement_pick_options.clear()
	selected_target_id = ""
	var party: Array[CombatantState] = create_encounter_player_party(active_encounter)
	setup_party_nodes(party)
	var enemies: Array[CombatantState] = create_encounter_enemies(active_encounter)
	_separate_spawn_positions(party, enemies)
	setup_enemy_nodes(enemies)
	var combatants: Array[CombatantState] = party.duplicate()
	combatants.append_array(enemies)
	get_viewport().canvas_cull_mask = 1
	visibility_layer = 0xFFFFFFFF
	$BattlefieldWorld.visibility_layer = 0xFFFFFFFF
	for proxy in get_all_combatant_nodes():
		if proxy.state != null:
			proxy.global_position = proxy.state.position
			proxy.movement_target = proxy.state.position
			proxy.set_meta("capture_index", spatial_combatants.size())
			var visual := preload("res://scenes/world3d/combatant_3d.gd").new()
			add_child(visual)
			visual.setup(proxy, active_map)
			spatial_combatants.append(visual)
	PreCombatStatusSystemScript.new().apply(active_encounter, combatants, combat_system.effect_system)
	combat_system.start_combat(combatants)
	combat_system.configure_encounter_objectives(active_encounter)
	_show_reach_objectives(active_encounter)
	$UILayer/Control.reset_for_combat()
	$UILayer/Control.setup(combat_system)
	if not $UILayer/Control.reaction_choice_selected.is_connected(resolve_reaction_choice):
		$UILayer/Control.reaction_choice_selected.connect(resolve_reaction_choice)
	update_target_selection()
	_start_spatial_combat_ai()


func _show_reach_objectives(encounter: EncounterData) -> void:
	if encounter == null or dungeon_world == null:
		return
	for objective in encounter.objectives:
		if objective == null or objective.type != EncounterObjective.Type.REACH_AREA:
			continue
		var surface: BuildingSurfaceData = dungeon_world.map_data.get_surface(encounter.starting_surface_id)
		var elevation := surface.elevation_feet if surface != null else 0.0
		var center := Vector3(objective.area_center_feet.x, elevation, objective.area_center_feet.y)
		var marker := AreaVisual.new()
		marker.name = "ReachObjective_%s" % String(objective.id)
		dungeon_world.add_child(marker)
		marker.configure(SkillData.AreaShape.CIRCLE, center, center, objective.area_radius_feet, 0.0, 0.0, 0.0, Color(0.12, 0.8, 0.75, 0.16), Color(0.2, 1.0, 0.85, 0.9))

func _start_spatial_combat_ai() -> void:
	# Newly created static bodies are synchronized on the first physics tick.
	await get_tree().physics_frame
	await get_tree().physics_frame
	run_enemy_ai_if_needed()


func _separate_spawn_positions(party: Array[CombatantState], enemies: Array[CombatantState]) -> void:
	var occupied: Dictionary = {}
	var all_combatants: Array[CombatantState] = party.duplicate()
	all_combatants.append_array(enemies)
	for combatant in all_combatants:
		if combatant == null:
			continue
		if _is_spawn_position_free(combatant, combatant.position, occupied):
			occupied[combatant.id] = combatant
			continue
		var authored_area: Rect2 = combatant.get_meta("spawn_area_feet", Rect2())
		if authored_area.has_area():
			for attempt in range(64):
				var candidate_feet := Vector2(
					encounter_spawn_rng.randf_range(authored_area.position.x, authored_area.end.x),
					encounter_spawn_rng.randf_range(authored_area.position.y, authored_area.end.y))
				var candidate: Vector2 = candidate_feet * combat_system.map_rules.world_units_per_foot
				if _is_spawn_position_free(combatant, candidate, occupied):
					combatant.position = candidate
					break
		if _is_spawn_position_free(combatant, combatant.position, occupied):
			occupied[combatant.id] = combatant
			continue
		var origin := combatant.position
		var placed := false
		for ring in range(1, 13):
			var radius: float = float(ring) * 5.5 * combat_system.map_rules.world_units_per_foot
			for step in range(16):
				var candidate: Vector2 = origin + Vector2.from_angle(TAU * float(step) / 16.0) * radius
				if _is_spawn_position_free(combatant, candidate, occupied):
					combatant.position = candidate
					placed = true
					break
			if placed:
				break
		occupied[combatant.id] = combatant


func _is_spawn_position_free(combatant: CombatantState, candidate: Vector2, occupied: Dictionary) -> bool:
	# Spawn placement has no travel segment. Checking a path from an overlapping
	# authored origin rejects every candidate, including otherwise empty spots.
	var probe := CombatantState.new()
	probe.id = combatant.id
	probe.spatial_units_per_foot = combatant.spatial_units_per_foot
	probe.surface_id = combatant.surface_id
	probe.elevation_feet = combatant.elevation_feet
	probe.collision_radius_feet = combatant.collision_radius_feet
	probe.position = candidate
	var rules: MapRules = combat_system.map_rules
	if not rules.validate_movement_path(probe, candidate, occupied).success:
		return false
	if rules.spatial_navigation != null:
		return rules.spatial_navigation.supported(probe.world_position, probe.surface_id, probe.collision_radius_feet)
	return true


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


func _setup_3d_world(active_map: BuildingMapData) -> void:
	if dungeon_world == null:
		dungeon_world = DungeonWorldScene.instantiate()
		dungeon_world.name = "DungeonWorld3D"
		add_child(dungeon_world)
		move_child(dungeon_world, 0)
	if battlefield_camera_3d == null:
		battlefield_camera_3d = Camera3D.new()
		battlefield_camera_3d.name = "BattlefieldCamera3D"
		battlefield_camera_3d.projection = Camera3D.PROJECTION_ORTHOGONAL
		battlefield_camera_3d.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		battlefield_camera_3d.current = true
		add_child(battlefield_camera_3d)
	dungeon_world.visual_light_level = combat_system.map_rules.light_level
	dungeon_world.build(active_map)
	combat_system.map_rules.spatial_world = dungeon_world
	dungeon_world.set_focus_surface(&"ground", false)
	$BattlefieldWorld/BattlefieldBackground.visible = false
	_sync_3d_camera()


func _configure_desert_storm(encounter: Resource) -> void:
	var existing := battlefield_camera_3d.get_node_or_null("DesertStorm3D")
	if existing != null:
		existing.queue_free()
	if encounter == null or not encounter.desert_storm_enabled or encounter.desert_storm_intensity <= 0.0:
		return
	var storm := DesertStorm3D.new()
	storm.name = "DesertStorm3D"
	battlefield_camera_3d.add_child(storm)
	storm.configure(encounter)


func _set_view_surface(surface_id: StringName) -> void:
	if dungeon_world == null or dungeon_world.map_data == null:
		return
	var surface := dungeon_world.map_data.get_surface(surface_id)
	if surface == null:
		return
	dungeon_world.set_focus_surface(surface_id, surface.elevation_feet > 0.0)


func _sync_3d_camera() -> void:
	if battlefield_camera_3d == null:
		return
	var camera_2d: Camera2D = $BattlefieldCamera
	var units_per_foot: float = combat_system.map_rules.world_units_per_foot if combat_system != null else 12.0
	battlefield_camera_3d.position = Vector3(camera_2d.position.x / units_per_foot, 100.0, camera_2d.position.y / units_per_foot)
	var viewport_height := get_viewport_rect().size.y
	battlefield_camera_3d.size = viewport_height / maxf(0.01, camera_2d.zoom.y) / units_per_foot


func get_combat_pointer_position(screen_position: Vector2) -> Vector2:
	var actor := get_player_controlled_actor()
	if not ground_targeting_id.is_empty() and dungeon_world != null:
		area_target_pick = dungeon_world.pick_world(battlefield_camera_3d, screen_position)
		return Vector2(area_target_pick.logic_position) if area_target_pick.has("logic_position") else Vector2.INF
	if actor != null and move_mode and dungeon_world != null:
		movement_pick_options = _movement_pick_options(screen_position, actor)
		if not movement_pick_options.get("ambiguous", false):
			prefer_floor_on_stair_overlap = false
		var selected: Dictionary = movement_pick_options.get("selected", {})
		if movement_pick_options.get("ambiguous", false) and prefer_floor_on_stair_overlap:
			selected = movement_pick_options.floor
			movement_pick_options.selected = selected
		if selected.has("logic_position"):
			actor.requested_surface_id = selected.surface_id
			return Vector2(selected.logic_position)
	else:
		movement_pick_options.clear()
	var picked := dungeon_world.pick_world(battlefield_camera_3d, screen_position) if dungeon_world != null else {}
	if picked.has("logic_position"):
		return Vector2(picked.logic_position)
	return super.get_combat_pointer_position(screen_position)

func get_ground_target_world_position(_target_point: Vector2) -> Vector3:
	return Vector3(area_target_pick.world_position) if area_target_pick.has("world_position") and Vector2(area_target_pick.logic_position).is_equal_approx(_target_point) else Vector3.INF

func _update_area_preview_3d() -> void:
	if dungeon_world == null or combat_system == null or ground_targeting_id.is_empty():
		if is_instance_valid(area_preview_3d):
			area_preview_3d.hide()
		return
	var actor := get_player_controlled_actor()
	var source = get_ground_targeting_data()
	if actor == null or source == null:
		return
	var picked := dungeon_world.pick_world(battlefield_camera_3d, get_viewport().get_mouse_position())
	if not picked.has("world_position"):
		if is_instance_valid(area_preview_3d):
			area_preview_3d.hide()
		return
	var point: Vector2 = picked.logic_position
	var world_point: Vector3 = picked.world_position
	var effective_range: float = combat_system.skill_system.get_effective_range_feet(actor, source) if ground_targeting_kind == "skill" else source.targeting_range_feet
	var preview: Dictionary = combat_system.targeting_system.get_targeting_preview(actor, point, source, combat_system.get_combat_state(), combat_system.map_rules, effective_range, world_point)
	if not is_instance_valid(area_preview_3d):
		area_preview_3d = AreaVisual.new()
		area_preview_3d.name = "AreaPreview3D"
		dungeon_world.add_child(area_preview_3d)
	var fill := Color(0.45, 0.2, 0.9, 0.18) if preview.valid else Color(0.9, 0.15, 0.2, 0.12)
	var edge := Color("c084fc") if preview.valid else Color("fb7185")
	var geometry_key := [source.area_shape, actor.world_position, world_point, source.area_radius_feet, effective_range, source.line_width_feet, source.cone_angle_degrees, preview.valid]
	if area_preview_geometry_key != geometry_key:
		area_preview_3d.configure(source.area_shape, actor.world_position, world_point, source.area_radius_feet, effective_range, source.line_width_feet, source.cone_angle_degrees, fill, edge)
		area_preview_geometry_key = geometry_key
	area_preview_3d.show()
	$UILayer/Control.set_mode_hint("%s | %s | %d target(s) | Left-click confirm, right-click/Esc cancel" % [source.display_name, preview.failure_reason if not preview.valid else "Valid target point", preview.targets.size()])

func show_area_animation_3d(event: CombatEvent, attacker: Combatant) -> void:
	if dungeon_world == null or attacker == null or attacker.state == null:
		return
	var template: AttackAnimationData = event.data.get("animation_template")
	if template == null:
		return
	var target_world: Vector3 = event.data.get("animation_world_target", Vector3.INF)
	if target_world == Vector3.INF:
		var point: Vector2 = event.data.get("animation_target", attacker.state.position)
		target_world = Vector3(point.x / combat_system.map_rules.world_units_per_foot, attacker.state.elevation_feet, point.y / combat_system.map_rules.world_units_per_foot)
	var shape: int = int(event.data.get("area_shape", SkillData.AreaShape.CIRCLE))
	var origin: Vector3 = event.data.get("animation_world_origin", attacker.state.world_position)
	var effect = AreaVisual.new()
	effect.name = "AreaEffect3D"
	dungeon_world.add_child(effect)
	var fill: Color = template.cone_fill_color if shape == SkillData.AreaShape.CONE else template.circle_fill_color
	var edge: Color = template.cone_edge_color if shape == SkillData.AreaShape.CONE else template.circle_edge_color
	effect.configure(shape, origin, target_world, float(event.data.get("area_radius_feet", 0.0)), float(event.data.get("area_length_feet", event.data.get("line_length_feet", 0.0))), float(event.data.get("line_width_feet", 5.0)), float(event.data.get("cone_angle_degrees", 90.0)), fill, edge)
	effect.set_animation(template, shape, origin, target_world, float(event.data.get("area_radius_feet", 0.0)), float(event.data.get("area_length_feet", event.data.get("line_length_feet", 0.0))), float(event.data.get("line_width_feet", 5.0)), combat_system.map_rules.world_units_per_foot, float(event.data.get("cone_angle_degrees", 90.0)))
	var frame_duration := float(template.last_frame - template.first_frame + 1) / maxf(1.0, template.frames_per_second)
	var duration: float = frame_duration if template.sprite_sheet != null else (template.cone_duration_seconds if shape == SkillData.AreaShape.CONE else template.circle_duration_seconds)
	effect.play(duration)

func _movement_pick_options(screen_position: Vector2, actor: CombatantState) -> Dictionary:
	if dungeon_world == null or dungeon_world.map_data == null or battlefield_camera_3d == null:
		return {}
	var visible_pick: Dictionary = dungeon_world.pick_world(battlefield_camera_3d, screen_position)
	var floor_pick: Dictionary = dungeon_world.pick_surface_position(battlefield_camera_3d, screen_position, actor.surface_id)
	var navigation = combat_system.map_rules.spatial_navigation
	if not floor_pick.is_empty() and navigation != null and not navigation.supported(Vector3(floor_pick.world_position), actor.surface_id, actor.collision_radius_feet):
		floor_pick = {}
	var stair_pick: Dictionary = dungeon_world.resolve_transition_pick(visible_pick, actor) if not visible_pick.is_empty() else {}
	if not stair_pick.is_empty() and dungeon_world.map_data.get_surface(StringName(stair_pick.surface_id)) != null:
		stair_pick = {}
	if not stair_pick.is_empty() and navigation != null and not navigation.supported(Vector3(stair_pick.world_position), StringName(stair_pick.surface_id), actor.collision_radius_feet):
		stair_pick = {}
	var ambiguous := not stair_pick.is_empty() and not floor_pick.is_empty()
	var selected: Dictionary = stair_pick if not stair_pick.is_empty() else floor_pick
	if selected.is_empty():
		selected = visible_pick
	return {"selected": selected, "stairs": stair_pick, "floor": floor_pick, "ambiguous": ambiguous}

func get_movement_preview_context() -> Dictionary:
	return movement_pick_options

func cycle_movement_pick(screen_position: Vector2) -> bool:
	var actor := get_player_controlled_actor()
	if not move_mode or actor == null or not _movement_pick_options(screen_position, actor).get("ambiguous", false):
		return false
	prefer_floor_on_stair_overlap = not prefer_floor_on_stair_overlap
	get_combat_pointer_position(screen_position)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed \
			and dungeon_world != null and battlefield_camera_3d != null and not is_movement_animating() \
			and pending_single_target_kind.is_empty() and pending_target_attack == null \
			and pending_basic_maneuver < 0 and not pending_search_targeting and ground_targeting_id.is_empty():
		var picked_door := dungeon_world.pick_door(battlefield_camera_3d, event.position)
		if not picked_door.is_empty():
			var actor := get_player_controlled_actor()
			var result := combat_system.interact_door(actor.id if actor != null else "", picked_door.surface_id, picked_door.door_id)
			$UILayer/Control.set_mode_hint("Door %s." % ("opened" if combat_system.map_rules.door_is_open(picked_door.surface_id, picked_door.door_id) else "closed") if result.success else result.failure_reason)
			$UILayer/Control.record_action_result(result)
			$UILayer/Control.update_ui()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE \
			and not is_movement_animating():
		if cycle_movement_pick(get_viewport().get_mouse_position()):
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)


func get_active_encounter_data() -> Resource:
	if resolved_encounter != null:
		return resolved_encounter
	var source: Resource = encounter_data if encounter_data != null else DefaultEncounter
	if get_tree().has_meta("active_encounter_data"):
		var run_encounter = get_tree().get_meta("active_encounter_data")
		if run_encounter is EncounterDataScript:
			source = run_encounter
	resolved_encounter = source.duplicate(true) if source is EncounterDataScript else source
	if resolved_encounter is EncounterDataScript and resolved_encounter.building_map == null:
		if get_tree().get_meta("use_dungeondraft_combat", false) or get_tree().has_meta("dungeon_combat_return"):
			resolved_encounter.building_map = DefaultBuildingMap
		else:
			resolved_encounter.building_map = _create_flat_encounter_map(resolved_encounter)
	return resolved_encounter


func _create_flat_encounter_map(data: EncounterData) -> BuildingMapData:
	var result := BuildingMapData.new()
	result.map_id = StringName("legacy_%s" % (data.id if data != null and not data.id.is_empty() else "encounter"))
	result.display_name = data.get_encounter_name() if data != null else "Encounter"
	result.pixels_per_foot = 12.0
	var size_feet: Vector2 = data.map_size_feet if data != null else MAP_SIZE_FEET
	result.source_size = size_feet * result.pixels_per_foot
	var surface := BuildingSurfaceData.new()
	surface.surface_id = &"ground"
	surface.display_name = "Ground"
	surface.elevation_feet = 0.0
	surface.texture = data.battlefield_texture if data != null else null
	surface.walkable_rects = [Rect2(Vector2.ZERO, result.source_size)]
	result.surfaces = [surface]
	return result


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
		state.spatial_units_per_foot = combat_system.map_rules.world_units_per_foot
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
		state.surface_id = data.starting_surface_id if data != null else &"ground"
		var spawn_surface: BuildingSurfaceData = combat_system.map_rules.building_map.get_surface(state.surface_id) if combat_system.map_rules.building_map != null else null
		state.elevation_feet = spawn_surface.elevation_feet if spawn_surface != null else 0.0
		apply_active_run_bonuses(state)
		var spawn_position_feet: Vector2 = data.get_player_spawn_position_feet(index, entry, encounter_spawn_rng) if data != null else Vector2(entry.get("position_feet", Vector2.ZERO))
		state.position = spawn_position_feet * combat_system.map_rules.world_units_per_foot
		if data != null and index < data.player_spawn_areas_feet.size():
			state.set_meta("spawn_area_feet", data.player_spawn_areas_feet[index])
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
	if progression_state != null:
		restore_run_resources(state, progression_state)


func restore_run_resources(target: CombatantState, source: CombatantState) -> void:
	if target == null or source == null:
		return
	target.hp = clampi(source.hp, 0, target.max_hp)
	target.mana = clampi(source.mana, 0, target.max_mana)
	target.set_meta("preserve_resources_on_combat_start", true)


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
	target.status_immunities = source.status_immunities.duplicate()
	target.granted_ability_ids = source.granted_ability_ids.duplicate()
	target.available_abilities = source.available_abilities.duplicate()
	target.equipped_abilities = source.equipped_abilities.duplicate()
	target.available_skills = source.available_skills.duplicate()
	target.learned_spell_ids = source.learned_spell_ids.duplicate()
	target.spell_choices_by_grantor = source.spell_choices_by_grantor.duplicate(true)
	target.item_inventory = duplicate_item_inventory(source.item_inventory)
	# Run equipment is the current loadout, including items removed or moved on the map.
	target.starting_equipment = []
	target.starting_equipment_slots = source.starting_equipment_slots.duplicate()
	target.equipment_inventory = source.equipment_inventory.duplicate()
	target.equipped_items = source.equipped_items.duplicate()
	target.active_weapon_slot = source.active_weapon_slot
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


func sync_run_party_state() -> void:
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
			sync_combatant_to_run_state(combatant, progression_state)


func sync_combatant_to_run_state(source: CombatantState, target: CombatantState) -> void:
	if source == null or target == null:
		return
	target.strength = source.strength
	target.dexterity = source.dexterity
	target.constitution = source.constitution
	target.intelligence = source.intelligence
	target.wisdom = source.wisdom
	target.charisma = source.charisma
	target.available_skills = source.available_skills.duplicate()
	target.item_inventory = duplicate_item_inventory(source.item_inventory)
	target.equipment_inventory = source.equipment_inventory.duplicate()
	target.equipped_items = source.equipped_items.duplicate()
	target.active_weapon_slot = source.active_weapon_slot
	EquipmentSystem.new().refresh_equipment(target)
	target.effects.clear()
	target.life_state = source.life_state
	# The active combatant already includes the Run-wide Max HP reward. Keep that
	# derived input on the Run copy so HP above the character's original maximum
	# is not accidentally discarded by a later progression refresh.
	target.max_hp_bonus = source.max_hp_bonus
	StatSystem.new().refresh_combatant(target)
	target.hp = clampi(source.hp, 0, target.max_hp)
	target.mana = clampi(source.mana, 0, target.max_mana)


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
	var entries: Array[Dictionary] = []
	for enemy_data in data.enemies:
		entries.append({"character": enemy_data, "position_feet": null, "group_id": "legacy"})
	var party_level := _get_encounter_party_level()
	var run_flags := _get_active_run_flags()
	for group in data.enemy_groups:
		if not group is EnemyGroupDataScript or not group.is_active(party_level, run_flags):
			continue
		for index in range(group.count):
			entries.append({"character": group.enemy, "position_feet": group.get_spawn_position(index, encounter_spawn_rng), "group_id": group.id, "spawn_area_feet": group.spawn_area_feet})
	for entry in entries:
		var enemy_data: CharacterData = entry.get("character")
		if enemy_data == null:
			continue
		var state: CombatantState = enemy_data.create_combatant_state()
		state.spatial_units_per_foot = combat_system.map_rules.world_units_per_foot
		# CharacterData positions predate centered encounter coordinates and are
		# authored from the map's top-left corner. Convert them at the boundary.
		var authored_position = entry.get("position_feet")
		if authored_position is Vector2:
			state.position = authored_position * combat_system.map_rules.world_units_per_foot
		elif state.position != Vector2.ZERO:
			state.position += combat_system.map_rules.playable_bounds.position
		var group_id := String(entry.get("group_id", "legacy"))
		var base_id: String = state.id if not state.id.is_empty() else "enemy"
		if group_id != "legacy":
			base_id = "%s_%s" % [group_id, base_id]
		var unique_id := base_id
		var suffix := 2
		while used_ids.has(unique_id):
			unique_id = "%s_%d" % [base_id, suffix]
			suffix += 1
		state.id = unique_id
		if entry.has("spawn_area_feet"):
			state.set_meta("spawn_area_feet", entry.spawn_area_feet)
		state.surface_id = data.starting_surface_id
		var enemy_surface: BuildingSurfaceData = combat_system.map_rules.building_map.get_surface(state.surface_id) if combat_system.map_rules.building_map != null else null
		state.elevation_feet = enemy_surface.elevation_feet if enemy_surface != null else 0.0
		used_ids[unique_id] = true
		states.append(state)
	return states

func _get_encounter_party_level() -> int:
	var highest := 1
	for node in party_nodes.values():
		if node != null and node.state != null:
			highest = maxi(highest, node.state.level)
	if get_tree().has_meta("active_run_state"):
		var run_state = get_tree().get_meta("active_run_state")
		if run_state != null and "party_character_data" in run_state:
			for character in run_state.party_character_data:
				if character != null:
					highest = maxi(highest, int(character.level))
	return highest

func _get_active_run_flags() -> Dictionary:
	if not get_tree().has_meta("active_run_state"):
		return {}
	var run_state = get_tree().get_meta("active_run_state")
	if run_state is RunState and run_state.game_state != null:
		return run_state.game_state.flags
	return {}


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
	var observer: CombatantState = get_displayed_party_member()
	for node in get_all_combatant_nodes():
		if is_instance_valid(node) and node.state != null:
			node.refresh_from_state()
			node.set_concealment_against(observer, combat_system.map_rules)


func run_enemy_ai_if_needed() -> void:
	if enemy_action_pause_pending:
		return
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
	enemy_action_pause_pending = true
	$UILayer/Control.set_mode_hint("%s is preparing an action..." % enemy.display_name)
	await get_tree().create_timer(ENEMY_ACTION_PAUSE_SECONDS).timeout
	enemy_action_pause_pending = false
	if not is_inside_tree() or combat_system == null:
		return
	state = combat_system.get_combat_state()
	if state == null or state.is_finished() or state.get_current_actor() != enemy \
			or combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() \
			or combat_system.has_pending_ability_movement():
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
	refresh_essential_hud()
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
		$UILayer/Control.set_mode_hint("Choose a Reaction after the attack.")
		$UILayer/Control.update_ui()
		return
	if combat_system.has_pending_step_back_move():
		move_mode = true
		$UILayer/Control.set_mode_hint("%s: click a destination up to %.1f ft away." % [combat_system.pending_reaction_move_name, combat_system.step_back_move_distance_feet])
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
	# A selected party member changes whose Concealment is displayed at each
	# enemy Token; refresh immediately rather than waiting for the next frame.
	refresh_combatant_nodes()


func get_displayed_party_member() -> CombatantState:
	if combat_system == null or combat_system.get_combat_state() == null:
		return null
	var state = combat_system.get_combat_state()
	var selected_character: CombatantState = state.get_combatant(selected_character_id)
	var primary: CombatantState = state.get_combatant("player")
	if selected_character != null and primary != null and selected_character.team == primary.team and selected_character.is_alive():
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
	_build_objective_panel()
	_build_inventory_drawer()
	_build_floor_selector()
	$UILayer/Control/DefeatOverlay/Panel/Margin/Column/RestartButton.pressed.connect(restart_run_after_defeat)
	$UILayer/Control/DefeatOverlay.hide()
	$UILayer/Control.update_ui()


func _build_floor_selector() -> void:
	var selector := OptionButton.new()
	selector.position = Vector2(10, 58)
	selector.z_index = 20
	var surfaces: Array[BuildingSurfaceData] = dungeon_world.map_data.surfaces.filter(func(surface): return not surface.walkable_rects.is_empty())
	for surface in surfaces:
		selector.add_item(surface.display_name)
	selector.visible = surfaces.size() > 1
	selector.tooltip_text = "View floor. In Move mode, click any stair tread to stop there; click farther up or down to continue."
	selector.item_selected.connect(func(index: int):
		_set_view_surface(surfaces[index].surface_id))
	$UILayer/Control.add_child(selector)


func _build_objective_panel() -> void:
	objective_panel = PanelContainer.new()
	objective_panel.name = "ObjectivePanel"
	objective_panel.position = Vector2(8, 52)
	objective_panel.custom_minimum_size = Vector2(210, 0)
	objective_panel.z_index = 12
	var panel_style := UITheme.style(UITheme.CARD_BACKGROUND, UITheme.CARD_BORDER, 0)
	objective_panel.add_theme_stylebox_override("panel", panel_style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	objective_panel.add_child(margin)
	objective_list = VBoxContainer.new()
	objective_list.add_theme_constant_override("separation", 3)
	margin.add_child(objective_list)
	$UILayer/Control.add_child(objective_panel)
	objective_toggle_button = Button.new()
	objective_toggle_button.name = "ObjectiveToggleButton"
	objective_toggle_button.text = "OBJECTIVES"
	objective_toggle_button.tooltip_text = "Show objectives"
	objective_toggle_button.position = objective_panel.position + Vector2(0, 32)
	objective_toggle_button.custom_minimum_size = Vector2(76, 20)
	objective_toggle_button.z_index = objective_panel.z_index
	objective_toggle_button.add_theme_font_size_override("font_size", 8)
	UITheme.apply_button_style(objective_toggle_button)
	objective_toggle_button.custom_minimum_size.y = 20
	objective_toggle_button.pressed.connect(func(): _set_objective_panel_open(true))
	$UILayer/Control.add_child(objective_toggle_button)
	if not combat_system.encounter_objective_system.objective_updated.is_connected(_on_objective_updated):
		combat_system.encounter_objective_system.objective_updated.connect(_on_objective_updated)
	_refresh_objective_panel()


func _on_objective_updated(_objective: EncounterObjective, _completed: bool) -> void:
	_refresh_objective_panel()


func _refresh_objective_panel() -> void:
	if objective_panel == null or objective_list == null:
		return
	for child in objective_list.get_children():
		objective_list.remove_child(child)
		child.queue_free()
	var states := combat_system.get_objective_states()
	_update_objective_visibility(not states.is_empty())
	if states.is_empty():
		return
	var header := HBoxContainer.new()
	objective_list.add_child(header)
	var title := Label.new()
	title.text = "OBJECTIVES"
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", UITheme.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.name = "Close"
	close_button.text = "×"
	close_button.tooltip_text = "Hide objectives"
	close_button.custom_minimum_size = Vector2(16, 16)
	close_button.add_theme_font_size_override("font_size", 9)
	close_button.pressed.connect(func(): _set_objective_panel_open(false))
	header.add_child(close_button)
	for state in states:
		var label := Label.new()
		var completed := bool(state.get("completed", false))
		label.text = "%s %s%s" % ["✓" if completed else "□", String(state.get("text", "Objective")), "" if bool(state.get("required", true)) else " (Optional)"]
		label.add_theme_font_size_override("font_size", CombatTheme.BODY)
		label.add_theme_color_override("font_color", UITheme.HEALTH_FILL if completed else UITheme.TEXT)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		objective_list.add_child(label)


func _set_objective_panel_open(open: bool) -> void:
	objective_panel_open = open
	_update_objective_visibility(not combat_system.get_objective_states().is_empty())


func _update_objective_visibility(has_objectives: bool) -> void:
	objective_panel.visible = has_objectives and objective_panel_open
	objective_toggle_button.visible = has_objectives and not objective_panel_open


func _build_obstacle_visuals() -> void:
	var active_encounter: Resource = get_active_encounter_data()
	for object_data in _get_encounter_objects(active_encounter):
		if String(object_data.get("kind", "")) != "obstacle":
			continue
		if object_data.has("rect_feet"):
			continue # The wall is baked into the Dungeondraft texture.
		var obstacle := {
			"center": Vector2(object_data.get("position_feet", Vector2.ZERO)) * combat_system.map_rules.world_units_per_foot,
			"radius": float(object_data.get("radius_feet", 0.0)) * combat_system.map_rules.world_units_per_foot,
			"label": String(object_data.get("label", "Obstacle")),
		}
		var visual := ObstacleVisualScript.new()
		visual.name = String(object_data.get("id", obstacle.label)).replace(" ", "")
		$BattlefieldWorld.add_child(visual)
		visual.setup(float(obstacle.radius), String(obstacle.label))
		# ObstacleVisual draws its circle around local (radius, radius), so its
		# Control origin must be one radius above/left of the rules-space center.
		visual.position = Vector2(obstacle.center) - Vector2.ONE * float(obstacle.radius)


func _process(_delta: float) -> void:
	_sync_3d_camera()
	var movement_actor := get_player_controlled_actor()
	if movement_actor != null and dungeon_world != null:
		var hover_pick := dungeon_world.pick_world(battlefield_camera_3d, get_viewport().get_mouse_position())
		var hover_logic := Vector2(hover_pick.get("logic_position", Vector2.INF))
		dungeon_world.update_transition_hover(movement_actor.surface_id, hover_logic, move_mode and hover_logic != Vector2.INF)
	var debug_pressed := Input.is_physical_key_pressed(KEY_F8)
	if debug_pressed and not visibility_debug_key_down:
		visibility_debug_enabled = not visibility_debug_enabled
	visibility_debug_key_down = debug_pressed
	if combat_system == null or combat_system.get_combat_state() == null:
		return
	var visibility_observer := get_displayed_party_member()
	if visibility_observer != null and visibility_observer.surface_id != followed_surface_id:
		followed_surface_id = visibility_observer.surface_id
		if dungeon_world.map_data.get_surface(followed_surface_id) != null:
			_set_view_surface(followed_surface_id)
	for visual in spatial_combatants:
		visual.sync_state()
		var target_state: CombatantState = visual.proxy.state
		var focused := dungeon_world.map_data.get_surface(dungeon_world.focus_surface_id)
		var on_ramp := dungeon_world.map_data.get_surface(target_state.surface_id) == null
		var is_controlled_actor := target_state == movement_actor
		var observer_can_see: bool = visibility_observer == null or target_state.team == visibility_observer.team or not combat_system.map_rules.get_visibility(visibility_observer, target_state).not_visible
		var visible_enemy_across_floors := visibility_observer != null and target_state.team != visibility_observer.team and observer_can_see
		visual.observer_visible = observer_can_see
		visual.visible = (visible_enemy_across_floors or is_controlled_actor or on_ramp or focused == null or visual.position.y <= focused.elevation_feet + 0.1) and observer_can_see and not dungeon_world.is_covered_by_visible_floor(visual.position)
	# A previously selected enemy must not remain exposed in the HUD after it
	# moves behind real 3D cover. Search targeting is the deliberate exception.
	var inspected: CombatantState = combat_system.get_combat_state().get_combatant(selected_character_id)
	if visibility_debug_enabled and visibility_observer != null and inspected != null:
		dungeon_world.show_visibility_debug(combat_system.map_rules.visibility_query.query(dungeon_world, visibility_observer, inspected))
	else:
		dungeon_world.hide_visibility_debug()
	if not pending_search_targeting and visibility_observer != null and inspected != null \
			and inspected.team != visibility_observer.team \
			and combat_system.map_rules.get_visibility(visibility_observer, inspected).not_visible:
		selected_character_id = ""
		selected_target_id = ""
		update_target_selection()
	var state = combat_system.get_combat_state()
	if state.is_finished() and get_tree().has_meta("dungeon_combat_return") and not post_combat_transition_started:
		post_combat_transition_started = true
		sync_run_party_state()
		return_to_dungeon_exploration(state.combat_result)
		return
	if state.is_finished() and get_tree().has_meta("active_event_encounter") and not post_combat_transition_started:
		post_combat_transition_started = true
		var active_encounter := get_active_encounter_data() as EncounterDataScript
		if state.combat_result == CombatEnums.CombatResult.DEFEAT and active_encounter != null:
			if active_encounter.event_defeat_outcome == EncounterDataScript.EventDefeatOutcome.END_RUN:
				restart_run_after_defeat()
				return
			revive_party_after_event_defeat()
		sync_run_party_state()
		return_to_event_flow_after_combat(state.combat_result)
		return
	if state.is_finished() and state.combat_result == CombatEnums.CombatResult.VICTORY and get_tree().has_meta("active_run_state") and not post_combat_transition_started:
		post_combat_transition_started = true
		sync_run_party_state()
		var completed_encounter := get_active_encounter_data() as EncounterDataScript
		if completed_encounter != null and completed_encounter.next_encounter != null:
			open_next_encounter(completed_encounter.next_encounter)
		else:
			open_reward_after_victory()
	$UILayer/Control/DefeatOverlay.visible = state.is_finished() and state.combat_result == CombatEnums.CombatResult.DEFEAT
	var reaction_locked: bool = combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement()
	refresh_character_panel_interaction_lock(state, reaction_locked)
	$UILayer/Controllers/CombatHUD.refresh()
	refresh_shadow_step_button()
	refresh_area_skill_button()
	$UILayer/Controllers/ActionBar.refresh()
	_update_area_preview_3d()
	_sync_smoke_visuals_3d()
	queue_redraw()


func _sync_smoke_visuals_3d() -> void:
	if dungeon_world == null or combat_system == null:
		return
	var active_ids: Dictionary = {}
	var units_per_foot: float = combat_system.map_rules.world_units_per_foot
	for area in combat_system.map_rules.temporary_light_areas:
		var area_id: int = int(area.get("id", 0))
		active_ids[area_id] = true
		if smoke_visuals_3d.has(area_id):
			continue
		var surface_id: StringName = area.get("surface_id", &"ground")
		var surface: BuildingSurfaceData = dungeon_world.map_data.get_surface(surface_id) if dungeon_world.map_data != null else null
		var elevation: float = surface.elevation_feet if surface != null else 0.0
		var center: Vector2 = area.get("center", Vector2.ZERO)
		var world_center := Vector3(center.x / units_per_foot, elevation, center.y / units_per_foot)
		var visual = AreaVisual.new()
		visual.name = "SmokeArea_%d" % area_id
		dungeon_world.add_child(visual)
		visual.configure(SkillData.AreaShape.CIRCLE, world_center, world_center, float(area.get("radius", 0.0)) / units_per_foot, 0.0, 0.0, 0.0, Color(0.12, 0.15, 0.20, 0.38), Color(0.65, 0.72, 0.79, 0.88))
		smoke_visuals_3d[area_id] = visual
	for area_id in smoke_visuals_3d.keys():
		if active_ids.has(area_id):
			continue
		var visual = smoke_visuals_3d[area_id]
		if is_instance_valid(visual):
			visual.queue_free()
		smoke_visuals_3d.erase(area_id)


func revive_party_after_event_defeat() -> void:
	if combat_system == null or combat_system.get_combat_state() == null:
		return
	for combatant in combat_system.get_combat_state().combatants.values():
		if combatant != null and combat_system.is_player_controlled(combatant) and combatant.hp <= 0:
			combatant.hp = 1
			combatant.life_state = CombatEnums.LifeState.ALIVE


func open_next_encounter(next_encounter: EncounterData) -> void:
	await get_tree().create_timer(0.75).timeout
	var previous_encounter = get_tree().get_meta("active_encounter_data")
	get_tree().set_meta("active_encounter_data", next_encounter)
	var destination := CUTSCENE_SCENE if next_encounter.cutscene_image != null else COMBAT_SCENE
	var change_error := get_tree().change_scene_to_file(destination)
	if change_error != OK:
		get_tree().set_meta("active_encounter_data", previous_encounter)
		post_combat_transition_started = false
		$UILayer/Control.add_log_message("Could not open next Encounter: %s" % error_string(change_error))


func open_reward_after_victory() -> void:
	await get_tree().create_timer(0.75).timeout
	var active_run := get_tree().get_meta("active_run_state", null) as RunState
	if active_run != null:
		get_node("/root/SaveGame").save_run(active_run, "reward")
	var change_error := get_tree().change_scene_to_file(REWARD_SCENE)
	if change_error != OK:
		post_combat_transition_started = false
		$UILayer/Control.add_log_message("Could not open Reward Selection: %s" % error_string(change_error))


func return_to_event_flow_after_combat(combat_result: CombatEnums.CombatResult) -> void:
	await get_tree().create_timer(0.75).timeout
	var result_type := EncounterResult.Type.VICTORY if combat_result == CombatEnums.CombatResult.VICTORY else EncounterResult.Type.DEFEAT
	get_tree().set_meta("pending_event_encounter_result", result_type)
	var change_error := get_tree().change_scene_to_file(RUN_MAP_SCENE)
	if change_error != OK:
		post_combat_transition_started = false
		$UILayer/Control.add_log_message("Could not return to Event: %s" % error_string(change_error))


func return_to_dungeon_exploration(combat_result: CombatEnums.CombatResult) -> void:
	await get_tree().create_timer(0.75).timeout
	var payload: Dictionary = get_tree().get_meta("dungeon_combat_return", {})
	if combat_result == CombatEnums.CombatResult.VICTORY and get_tree().has_meta("active_run_state"):
		var active_run = get_tree().get_meta("active_run_state") as RunState
		if active_run != null:
			var defeated: Dictionary = active_run.get_meta("dungeon_defeated_encounters", {})
			defeated[String(payload.get("encounter_id", ""))] = true
			active_run.set_meta("dungeon_defeated_encounters", defeated)
			get_node("/root/SaveGame").save_run(active_run, "exploration")
	get_tree().remove_meta("active_encounter_data")
	get_tree().remove_meta("dungeon_combat_return")
	var change_error := get_tree().change_scene_to_file("res://scenes/exploration/DungeonExploration.tscn")
	if change_error != OK:
		post_combat_transition_started = false
		$UILayer/Control.add_log_message("Could not return to the building: %s" % error_string(change_error))


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
		or pending_basic_maneuver >= 0 \
		or pending_search_targeting \
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
	if dungeon_world == null:
		draw_smoke_areas_2d()
	if pending_target_attack != null or pending_basic_maneuver >= 0 or pending_search_targeting:
		draw_attack_targeting()
	if not pending_single_target_kind.is_empty():
		draw_single_targeting()
	if dungeon_world != null:
		return
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


func draw_smoke_areas_2d() -> void:
	for area in combat_system.map_rules.temporary_light_areas:
		var center: Vector2 = area.get("center", Vector2.ZERO)
		var radius: float = float(area.get("radius", 0.0))
		draw_circle(center, radius, Color(0.12, 0.15, 0.20, 0.38))
		draw_arc(center, radius, 0.0, TAU, 64, Color(0.65, 0.72, 0.79, 0.88), 2.0)


func draw_active_auras() -> void:
	var state = combat_system.get_combat_state()
	if state == null:
		return
	for source in state.combatants.values():
		if source == null or source.is_dying():
			continue
		for instance in source.effects:
			if instance == null or instance.data == null or instance.data.aura_radius_feet <= 0.0:
				continue
			var radius: float = get_aura_visual_radius_world_units(source, instance.data)
			var fill: Color = instance.data.aura_color
			var outline := Color(fill.r, fill.g, fill.b, minf(fill.a + 0.55, 1.0))
			draw_circle(source.position, radius, fill)
			draw_arc(source.position, radius, 0.0, TAU, 64, outline, 2.0)


func get_aura_visual_radius_world_units(source: CombatantState, effect) -> float:
	if combat_system == null or source == null or effect == null:
		return 0.0
	return combat_system.map_rules.get_targeting_preview_radius_world_units(source, effect.aura_radius_feet)
