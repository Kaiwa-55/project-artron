class_name EventManager
extends Node

signal event_started(data: EventData)
signal choices_changed(choice_states: Array[Dictionary])
signal effects_applied(results: Array[Dictionary])
signal event_finished(data: EventData)
signal encounter_requested(data: EncounterData)
signal character_selection_requested(choice_index: int, eligible_actor_ids: Array[String])

var game_state: GameState
var context: EventContext
var encounter_manager: EncounterManager
var active_event: EventData
var _choice_states: Array[Dictionary] = []


func configure(p_game_state: GameState, p_encounter_manager: EncounterManager = null) -> void:
	game_state = p_game_state if p_game_state != null else GameState.new()
	if encounter_manager != null and encounter_manager.event_requested.is_connected(_on_result_event_requested):
		encounter_manager.event_requested.disconnect(_on_result_event_requested)
	encounter_manager = p_encounter_manager
	if encounter_manager != null and not encounter_manager.event_requested.is_connected(_on_result_event_requested):
		encounter_manager.event_requested.connect(_on_result_event_requested)


func start_event(data: EventData, event_context: EventContext = null, start_conditions_checked: bool = false) -> bool:
	if data == null:
		return false
	var next_context := event_context if event_context != null else EventContext.new(game_state)
	if game_state == null:
		game_state = next_context.game_state
	next_context.game_state = game_state
	if not start_conditions_checked and not data.can_start(next_context):
		return false
	context = next_context
	active_event = data
	event_started.emit(data)
	_apply_effects(data.on_start_effects)
	refresh_choices()
	return true


func get_choice_states() -> Array[Dictionary]:
	return _choice_states.duplicate(true)


func refresh_choices() -> void:
	var states: Array[Dictionary] = []
	if active_event == null:
		_choice_states = states
		choices_changed.emit(get_choice_states())
		return
	for index in range(active_event.choices.size()):
		var choice := active_event.choices[index]
		if choice == null:
			continue
		var reasons: Array[String] = []
		var global_enabled := true
		for condition in choice.conditions:
			if condition == null:
				global_enabled = false
			elif not condition.uses_choice_actor() and not condition.is_met(context):
				global_enabled = false
				if not reasons.has(condition.failure_reason):
					reasons.append(condition.failure_reason)
		var eligible_actor_ids := _get_eligible_actor_ids(choice)
		var enabled := global_enabled
		match choice.actor_mode:
			EventChoice.ActorMode.CONTEXT_ACTOR:
				if choice.requires_choice_actor():
					enabled = enabled and not eligible_actor_ids.is_empty()
			EventChoice.ActorMode.SELECT_ONE:
				enabled = enabled and not eligible_actor_ids.is_empty()
			EventChoice.ActorMode.ALL_PARTY:
				enabled = enabled and not context.party.is_empty() and eligible_actor_ids.size() == context.party.size()
		if global_enabled and not enabled:
			for member in context.party:
				if member != null and not eligible_actor_ids.has(member.id):
					for reason in choice.get_actor_failure_reasons(context, member.id):
						if not reasons.has(reason):
							reasons.append(reason)
		var visible := enabled or choice.failed_condition_presentation == EventChoice.FailedConditionPresentation.DISABLED
		states.append({
			"index": index,
			"choice": choice,
			"text": choice.text,
			"visible": visible,
			"enabled": enabled,
			"failure_reasons": reasons,
			"actor_mode": choice.actor_mode,
			"eligible_actor_ids": eligible_actor_ids,
		})
	_choice_states = states
	choices_changed.emit(get_choice_states())


func choose(choice_index: int) -> bool:
	if active_event == null or choice_index < 0 or choice_index >= active_event.choices.size():
		return false
	var choice := active_event.choices[choice_index]
	var state_index := _choice_states.find_custom(func(state): return int(state.get("index", -1)) == choice_index)
	if choice == null or state_index < 0 or not bool(_choice_states[state_index].get("enabled", false)):
		return false
	var eligible_actor_ids: Array[String] = []
	eligible_actor_ids.assign(_choice_states[state_index].get("eligible_actor_ids", []))
	if choice.actor_mode == EventChoice.ActorMode.SELECT_ONE:
		character_selection_requested.emit(choice_index, eligible_actor_ids)
		return true
	var actor_ids: Array[String] = eligible_actor_ids.duplicate()
	if choice.actor_mode == EventChoice.ActorMode.CONTEXT_ACTOR:
		actor_ids.clear()
		var context_actor := context.get_actor()
		if context_actor != null:
			actor_ids.append(context_actor.id)
	return _resolve_choice(choice_index, actor_ids)


func choose_for_actor(choice_index: int, actor_id: String) -> bool:
	if active_event == null or choice_index < 0 or choice_index >= active_event.choices.size():
		return false
	var choice := active_event.choices[choice_index]
	if choice == null or choice.actor_mode != EventChoice.ActorMode.SELECT_ONE:
		return false
	var state_index := _choice_states.find_custom(func(state): return int(state.get("index", -1)) == choice_index)
	if state_index < 0 or not Array(_choice_states[state_index].get("eligible_actor_ids", [])).has(actor_id):
		return false
	return _resolve_choice(choice_index, [actor_id])


func _resolve_choice(choice_index: int, actor_ids: Array[String]) -> bool:
	var choice := active_event.choices[choice_index]
	var previous_actor_id := context.actor_id
	if choice.actor_mode == EventChoice.ActorMode.SELECT_ONE and not actor_ids.is_empty():
		context.actor_id = actor_ids[0]
	var encounter_from_effect: EncounterData
	for result in _apply_choice_effects(choice.effects, actor_ids):
		if result.get("start_encounter") is EncounterData:
			encounter_from_effect = result["start_encounter"]
	var next_event := choice.next_event as EventData
	var next_encounter := choice.encounter if choice.encounter != null else encounter_from_effect
	_finish_active_event()
	if next_encounter != null:
		encounter_requested.emit(next_encounter)
		return encounter_manager == null or encounter_manager.start_encounter(next_encounter, context)
	if next_event != null:
		return start_event(next_event, context)
	if choice.actor_mode == EventChoice.ActorMode.ALL_PARTY:
		context.actor_id = previous_actor_id
	return true


func _get_eligible_actor_ids(choice: EventChoice) -> Array[String]:
	var candidates: Array[CombatantState] = []
	if choice.actor_mode == EventChoice.ActorMode.CONTEXT_ACTOR:
		var actor := context.get_actor()
		if actor != null:
			candidates.append(actor)
	else:
		candidates = context.party
	var ids: Array[String] = []
	for candidate in candidates:
		if candidate != null and choice.actor_conditions_met(context, candidate.id):
			ids.append(candidate.id)
	return ids


func _apply_choice_effects(effects: Array[EventEffect], actor_ids: Array[String]) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var previous_actor_id := context.actor_id
	for effect in effects:
		if effect == null:
			continue
		if effect.uses_choice_actor():
			for actor_id in actor_ids:
				context.actor_id = actor_id
				results.append(effect.apply(context))
		else:
			results.append(effect.apply(context))
	context.actor_id = previous_actor_id
	if not results.is_empty():
		effects_applied.emit(results)
	return results


func _finish_active_event() -> void:
	if active_event == null:
		return
	var completed := active_event
	_apply_effects(completed.on_end_effects)
	game_state.mark_event_completed(completed.id)
	active_event = null
	_choice_states.clear()
	event_finished.emit(completed)


func _apply_effects(effects: Array[EventEffect]) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for effect in effects:
		if effect != null:
			results.append(effect.apply(context))
	if not results.is_empty():
		effects_applied.emit(results)
	return results


func _on_result_event_requested(data: EventData) -> void:
	start_event(data, context)
