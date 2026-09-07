extends Node2D

signal settled
var arena
var busy: bool = false
var blocker: Control
var tooltip: Label
var preview: Dictionary = {}
var observed_event_system
var event_cursor: int = 0
var attack_queue: Array[CombatEvent] = []


func is_no_damage_result(event: CombatEvent) -> bool:
	if event.type == EventTypes.Type.ATTACK_MISS:
		return true
	if not event.data.get("is_damaging_attack", false):
		return false
	return event.type == EventTypes.Type.ATTACK_HIT and float(event.data.get("final_damage", 0)) <= 0.0


func collect_attack_animations() -> void:
	if arena.combat_system == null:
		return
	var events = arena.combat_system.event_system
	if observed_event_system != events:
		observed_event_system = events
		event_cursor = 0
		attack_queue.clear()
	if event_cursor > events.event_history.size():
		event_cursor = 0
		attack_queue.clear()
	while event_cursor < events.event_history.size():
		var event: CombatEvent = events.event_history[event_cursor]
		event_cursor += 1
		if event.type in [EventTypes.Type.ATTACK_HIT, EventTypes.Type.ATTACK_MISS] and (event.data.get("animation_template") != null or is_no_damage_result(event)):
			attack_queue.append(event)


func find_token(actor_id: String) -> Combatant:
	var candidates: Array = arena.get_all_combatant_nodes() if arena.has_method("get_all_combatant_nodes") else arena.get_children()
	for child in candidates:
		if child is Combatant and child.state != null and child.state.id == actor_id:
			return child
	return null


func _ready() -> void:
	arena = get_parent()
	z_index = 10
	var canvas := CanvasLayer.new()
	canvas.layer = 50
	add_child(canvas)
	blocker = Control.new()
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.hide()
	canvas.add_child(blocker)
	tooltip = Label.new()
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.add_theme_color_override("font_shadow_color", Color.BLACK)
	tooltip.add_theme_constant_override("shadow_offset_x", 2)
	tooltip.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(tooltip)


func sync_movement() -> bool:
	collect_attack_animations()
	var moving := false
	var candidates: Array = arena.get_all_combatant_nodes() if arena.has_method("get_all_combatant_nodes") else arena.get_children()
	for child in candidates:
		if child is Combatant:
			child.refresh_from_state()
			moving = moving or child.is_movement_animating() or child.is_attack_animating()
	if not moving and not attack_queue.is_empty():
		var event: CombatEvent = attack_queue.pop_front()
		var attacker := find_token(event.source_id)
		var target := find_token(event.target_id)
		if attacker != null and target != null and event.data.get("animation_template") != null:
			attacker.play_attack_animation(event.data.animation_template, event.data.animation_origin, event.data.animation_target, target.state.collision_radius_feet, arena.combat_system.map_rules.world_units_per_foot)
			if is_no_damage_result(event):
				if attacker.is_attack_animating():
					attacker.attack_tween.finished.connect(target.show_no_damage_feedback, CONNECT_ONE_SHOT)
				else:
					target.show_no_damage_feedback()
			moving = true
		elif target != null and is_no_damage_result(event):
			target.show_no_damage_feedback()
	moving = moving or not attack_queue.is_empty()
	return moving


func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventKey) and sync_movement():
		get_viewport().set_input_as_handled()


func defer_until_settled(callback: Callable) -> bool:
	if not sync_movement():
		return false
	busy = true
	if not settled.is_connected(callback):
		settled.connect(callback, CONNECT_ONE_SHOT | CONNECT_DEFERRED)
	return true


func _process(_delta: float) -> void:
	var moving := sync_movement()
	blocker.visible = moving
	if busy and not moving:
		settled.emit()
	busy = moving
	preview = {}
	var system = arena.combat_system
	if system != null and not moving and not system.has_pending_reaction() and arena.move_mode:
		var hovered := get_viewport().gui_get_hovered_control()
		if hovered == null or hovered == arena.get_node("UILayer/Control"):
			preview = build_preview(get_global_mouse_position())
	tooltip.visible = not preview.is_empty()
	if tooltip.visible:
		tooltip.text = preview.text
		tooltip.modulate = preview.color
		var mouse := get_viewport().get_mouse_position() + Vector2(20, 22)
		tooltip.position = mouse.clamp(Vector2.ZERO, (get_viewport_rect().size - tooltip.size - Vector2(12, 12)).max(Vector2.ZERO))
	queue_redraw()


func build_preview(destination: Vector2) -> Dictionary:
	var system = arena.combat_system
	var state: CombatState = system.get_combat_state()
	var actor: CombatantState = arena.get_player_controlled_actor()
	if actor == null or state.is_finished():
		return {}
	var special: bool = system.has_pending_step_back_move() or system.has_pending_ability_movement()
	if not special and state.current_actor_id != actor.id:
		return {}
	var movement := MovementData.new()
	movement.ap_cost = 1
	movement.world_units_per_foot = system.map_rules.world_units_per_foot
	var budget: float = system.movement_system.get_available_distance_feet(actor)
	if system.has_pending_step_back_move():
		actor = state.get_combatant(system.step_back_move_actor_id)
		budget = system.step_back_move_distance_feet
	elif system.has_pending_ability_movement():
		actor = state.get_combatant(system.ability_move_actor_id)
		var ability = system.ability_system.get_available_ability(actor, system.ability_move_id)
		if ability == null:
			return {}
		budget = system.ability_system.get_movement_effect(ability).movement_distance_feet
	var endpoint: Vector2 = actor.position + (destination - actor.position).limit_length(maxf(0.0, budget) * movement.world_units_per_foot)
	var validation: ActionResult = system.map_rules.validate_movement_path(actor, endpoint, state.combatants) if special else system.movement_system.validate_move(actor, endpoint, movement, state)
	var distance := actor.position.distance_to(endpoint) / movement.world_units_per_foot
	var caption := "%.1f / %.1f ft" % [distance, budget]
	if not endpoint.is_equal_approx(destination):
		caption += "  • Speed limit"
	if not validation.success:
		caption += "\n" + validation.failure_reason
	return {"origin": actor.position, "endpoint": endpoint, "requested": destination, "text": caption, "color": Color("79E5C1") if validation.success else Color("F47777")}


func _draw() -> void:
	if preview.is_empty():
		return
	var origin := to_local(preview.origin)
	var endpoint := to_local(preview.endpoint)
	var color: Color = preview.color
	draw_line(origin, endpoint, color, 3.0, true)
	draw_circle(endpoint, 9.0, Color(color, 0.2))
	draw_arc(endpoint, 10.0, 0.0, TAU, 40, color, 2.0, true)
	if not preview.endpoint.is_equal_approx(preview.requested):
		draw_dashed_line(endpoint, to_local(preview.requested), Color(color, 0.35), 1.0, 8.0)
