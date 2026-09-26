extends SceneTree

const TABLE: EventTable = preload("res://data/event/default_event_table.tres")

var failures: Array[String] = []


func _init() -> void:
	var expected_ids := [
		"goblin_crossfire", "webbed_passage", "hunt_the_slinger", "hold_the_line",
		"thornscale_pincer", "stalker_in_the_dim", "escape_the_ravager", "velkarias_brood",
	]
	var entries := {}
	for entry in TABLE.entries:
		if entry != null:
			entries[String(entry.id)] = entry
	for event_id in expected_ids:
		check(entries.has(event_id), "%s is missing from the default Event table." % event_id)
		if not entries.has(event_id):
			continue
		var entry: EventTableEntry = entries[event_id]
		check(entry.event != null, "%s has no Event." % event_id)
		if entry.event == null:
			continue
		var encounter: EncounterData = null
		var has_exit := false
		for choice in entry.event.choices:
			if choice.encounter != null:
				encounter = choice.encounter
			else:
				has_exit = true
		check(encounter != null and has_exit, "%s needs a combat choice and an exit choice." % event_id)
		if encounter == null:
			continue
		check(not encounter.enemy_groups.is_empty(), "%s has no enemy group." % event_id)
		check(not encounter.objectives.is_empty(), "%s has no objective." % event_id)
		check(not encounter.player_spawn_positions_feet.is_empty(), "%s has no party spawn." % event_id)
		for objective in encounter.objectives:
			if objective.type == EncounterObjective.Type.DEFEAT_TARGET:
				var target_exists := false
				for group in encounter.enemy_groups:
					if objective.target_id == "%s_%s" % [group.id, group.enemy.id]:
						target_exists = true
				check(target_exists, "%s has an unknown defeat target." % event_id)
			if objective.type == EncounterObjective.Type.REACH_AREA:
				check(objective.area_center_feet.distance_to(encounter.player_spawn_positions_feet[0]) > objective.area_radius_feet, "%s starts inside the escape area." % event_id)
	check((entries["stalker_in_the_dim"] as EventTableEntry).event.choices[0].encounter.initial_light_level == 2, "Stalker event should start in dim light.")
	var player := CombatantState.new()
	player.id = "player"
	var party: Array[CombatantState] = [player]
	var context := EventContext.new(GameState.new(), party)
	context.actor_id = "player"
	for level_value in [1, 3, 6]:
		player.level = level_value
		for event_id in expected_ids:
			var entry: EventTableEntry = entries[event_id]
			var required_level := 6 if event_id == "velkarias_brood" else 3 if event_id in ["thornscale_pincer", "stalker_in_the_dim", "escape_the_ravager"] else 1
			check(entry.is_available(context) == (level_value >= required_level), "%s availability is wrong at level %d." % [event_id, level_value])
	player.level = 1
	player.experience = 0
	var ally := CombatantState.new()
	ally.id = "ally"
	context.party.append(ally)
	var encounter_manager := EncounterManager.new()
	var event_manager := EventManager.new()
	root.add_child(encounter_manager)
	root.add_child(event_manager)
	event_manager.configure(context.game_state, encounter_manager)
	for event_id in expected_ids:
		var encounter: EncounterData = (entries[event_id] as EventTableEntry).event.choices[0].encounter
		check(encounter.victory_event is EventData, "%s has no visible victory result." % event_id)
		check(not encounter.rewards.is_empty(), "%s has no reward." % event_id)
		if encounter.rewards.is_empty():
			continue
		var before := {}
		var xp_reward: EventEffect
		var player_xp_before := player.experience
		var ally_xp_before := ally.experience
		for effect in encounter.rewards:
			if effect is EventEffect and effect.type == EventEffect.Type.GAIN_EXPERIENCE:
				xp_reward = effect
			elif effect is EventEffect and effect.type == EventEffect.Type.GAIN_ITEM and effect.item != null:
				before[effect.item.id] = item_quantity(player, effect.item.id)
		check(not before.is_empty(), "%s has no item reward." % event_id)
		check(xp_reward != null and xp_reward.amount > 0, "%s has no XP reward." % event_id)
		check(encounter_manager.resume_encounter(encounter, context), "%s could not resume." % event_id)
		check(encounter_manager.finish_encounter(EncounterResult.new(EncounterResult.Type.VICTORY)), "%s victory could not finish." % event_id)
		check(event_manager.active_event == encounter.victory_event, "%s did not show its victory result." % event_id)
		for effect in encounter.rewards:
			if effect is EventEffect and effect.type == EventEffect.Type.GAIN_ITEM and effect.item != null:
				check(item_quantity(player, effect.item.id) == int(before[effect.item.id]) + effect.amount, "%s did not grant its item." % event_id)
		if xp_reward != null:
			check(player.experience == player_xp_before + xp_reward.amount, "%s did not grant player XP." % event_id)
			check(ally.experience == ally_xp_before + xp_reward.amount, "%s did not grant party XP." % event_id)
		check(not encounter_manager.finish_encounter(EncounterResult.new(EncounterResult.Type.VICTORY)), "%s granted rewards twice." % event_id)
	var defeat_encounter: EncounterData = (entries["goblin_crossfire"] as EventTableEntry).event.choices[0].encounter
	var potion_count := item_quantity(player, "minor_healing_potion")
	var xp_count := player.experience
	check(encounter_manager.resume_encounter(defeat_encounter, context), "Defeat case could not resume.")
	check(encounter_manager.finish_encounter(EncounterResult.new(EncounterResult.Type.DEFEAT)), "Defeat case could not finish.")
	check(item_quantity(player, "minor_healing_potion") == potion_count, "Defeat should not grant rewards.")
	check(player.experience == xp_count, "Defeat should not grant XP.")
	for failure in failures:
		push_error(failure)
	print("VARIED_ENCOUNTER_EVENTS_TEST: PASS" if failures.is_empty() else "VARIED_ENCOUNTER_EVENTS_TEST: FAIL")
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func item_quantity(member: CombatantState, item_id: String) -> int:
	var total := 0
	for stack in member.item_inventory:
		if stack != null and stack.item != null and stack.item.id == item_id:
			total += stack.quantity
	return total
