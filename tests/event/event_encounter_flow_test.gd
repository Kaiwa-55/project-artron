extends SceneTree

const EncounterObjectiveScript := preload("res://data/encounter/encounter_objective.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	test_global_continue_without_actor()
	var authored_event := load("res://data/event/Strange Caravan/strange_caravan.tres") as EventData
	check(authored_event != null and authored_event.choices.size() == 3, "Authored .tres Event chain should load with three Choices.")
	check(authored_event.choices[1].encounter != null and authored_event.choices[1].encounter.enemies.size() == 1, "Authored Event should link to a playable EncounterData resource.")
	check(authored_event.choices[1].encounter.objectives.size() == 1 and authored_event.choices[1].encounter.objectives[0].type == EncounterObjectiveScript.Type.DEFEAT_ALL, "Authored Encounter should demonstrate a DefeatAll Objective.")
	check(authored_event.choices[2].actor_mode == EventChoice.ActorMode.SELECT_ONE, "Authored tracking Choice should demonstrate character selection.")

	var world := GameState.new()
	world.set_flag("caravan_available", true)
	var hero := CombatantState.new()
	hero.id = "hero"
	hero.strength = 8
	hero.level = 2
	hero.max_hp = 30
	hero.hp = 5
	var context := EventContext.new(world, [hero])
	context.actor_id = "hero"

	var strength_condition := EventCondition.new()
	strength_condition.type = EventCondition.Type.ATTRIBUTE
	strength_condition.key = "strength"
	strength_condition.required_number = 8
	strength_condition.failure_reason = "Requires Strength 8."
	var start_condition := EventCondition.new()
	start_condition.type = EventCondition.Type.FLAG
	start_condition.key = "caravan_available"
	start_condition.comparison = EventCondition.Comparison.EQUAL

	var level_condition := EventCondition.new()
	level_condition.type = EventCondition.Type.LEVEL
	level_condition.required_number = 3
	level_condition.failure_reason = "Requires Level 3."

	var heal := EventEffect.new()
	heal.type = EventEffect.Type.HEAL
	heal.amount = 20
	var remember_choice := EventEffect.new()
	remember_choice.type = EventEffect.Type.MODIFY_FLAG
	remember_choice.key = "discovered_ambush"
	var remember_completion := EventEffect.new()
	remember_completion.type = EventEffect.Type.MODIFY_FLAG
	remember_completion.key = "left_caravan_event"

	var result_started := EventEffect.new()
	result_started.type = EventEffect.Type.MODIFY_FLAG
	result_started.key = "won_bandit_ambush"
	var result_event := EventData.new()
	result_event.id = "bandit_victory"
	result_event.title = "The Road Is Clear"
	result_event.on_start_effects = [result_started]
	var leave_choice := EventChoice.new()
	leave_choice.text = "Continue"
	result_event.choices = [leave_choice]

	var gold_reward := EventEffect.new()
	gold_reward.type = EventEffect.Type.MODIFY_RESOURCE
	gold_reward.key = "gold"
	gold_reward.amount = 12
	var encounter := EncounterData.new()
	encounter.id = "bandit_ambush"
	encounter.type = EncounterData.Type.AMBUSH
	encounter.victory_event = result_event
	encounter.rewards = [gold_reward]

	var fight_choice := EventChoice.new()
	fight_choice.text = "Spring the counter-ambush"
	fight_choice.conditions = [strength_condition]
	fight_choice.effects = [heal, remember_choice]
	fight_choice.encounter = encounter
	var locked_choice := EventChoice.new()
	locked_choice.text = "Challenge the leader"
	locked_choice.conditions = [level_condition]
	var hidden_choice := EventChoice.new()
	hidden_choice.text = "Secret route"
	hidden_choice.conditions = [level_condition]
	hidden_choice.failed_condition_presentation = EventChoice.FailedConditionPresentation.HIDDEN

	var opening := EventData.new()
	opening.id = "strange_caravan"
	opening.title = "Strange Caravan"
	opening.start_conditions = [start_condition]
	opening.on_end_effects = [remember_completion]
	opening.choices = [fight_choice, locked_choice, hidden_choice]

	var encounter_manager := EncounterManager.new()
	var event_manager := EventManager.new()
	root.add_child(encounter_manager)
	root.add_child(event_manager)
	event_manager.configure(world, encounter_manager)
	check(event_manager.start_event(opening, context), "Opening Event should start when its conditions pass.")
	var states := event_manager.get_choice_states()
	check(states.size() == 3, "EventManager should expose all choice presentation states.")
	check(states[0].enabled and states[0].visible, "Passing Choice should be visible and enabled.")
	check(not states[1].enabled and states[1].visible, "Failed Choice should be disabled by default.")
	check(not states[2].enabled and not states[2].visible, "Hidden failed Choice should not be shown.")
	check(not event_manager.choose(1), "A disabled Choice must not resolve.")
	check(event_manager.choose(0), "A valid Choice should apply effects and start its Encounter.")
	check(hero.hp == 25 and world.get_flag("discovered_ambush") and world.get_flag("left_caravan_event"), "Choice and Event-end Effects should update the actor and GameState.")
	check(encounter_manager.active_encounter == encounter, "EncounterManager should own the active Encounter.")

	var combat := CombatSystem.new()
	encounter_manager.bind_combat_system(combat)
	combat.event_system.emit(CombatEvent.new(EventTypes.Type.COMBAT_VICTORY, "", "", {"winner_team": 1}))
	check(encounter_manager.active_encounter == null, "Combat result should finish the Encounter through its signal bridge.")
	check(event_manager.active_event == result_event, "Victory should route back to the configured result Event.")
	check(world.get_flag("won_bandit_ambush") and int(world.resources.get("gold", 0)) == 12, "Victory Event and rewards should update shared GameState.")
	check(event_manager.choose(0), "Result Event should be completable.")
	check(not event_manager.start_event(opening, context), "A non-repeatable completed Event must not start twice.")

	var ally := CombatantState.new()
	ally.id = "ally_1"
	ally.display_name = "Strong Ally"
	ally.strength = 10
	ally.max_hp = 30
	ally.hp = 1
	context.party.append(ally)
	var strong_condition := EventCondition.new()
	strong_condition.type = EventCondition.Type.ATTRIBUTE
	strong_condition.key = "strength"
	strong_condition.required_number = 9
	var selected_heal := EventEffect.new()
	selected_heal.type = EventEffect.Type.HEAL
	selected_heal.amount = 5
	var shared_gold := EventEffect.new()
	shared_gold.type = EventEffect.Type.MODIFY_RESOURCE
	shared_gold.key = "gold"
	shared_gold.amount = 2
	var select_choice := EventChoice.new()
	select_choice.text = "Lift the gate"
	select_choice.actor_mode = EventChoice.ActorMode.SELECT_ONE
	select_choice.conditions = [strong_condition]
	select_choice.effects = [selected_heal, shared_gold]
	var selection_event := EventData.new()
	selection_event.id = "select_actor_test"
	selection_event.choices = [select_choice]
	var selection_request := {}
	event_manager.character_selection_requested.connect(func(index, actor_ids): selection_request.assign({"index": index, "actor_ids": actor_ids}))
	check(event_manager.start_event(selection_event, context), "Actor-selection Event should start.")
	check(event_manager.choose(0), "SELECT_ONE Choice should open character selection.")
	check(event_manager.active_event == selection_event and selection_request.get("actor_ids", []) == ["ally_1"], "Only party members who pass actor Conditions should be selectable.")
	check(not event_manager.choose_for_actor(0, "hero"), "An ineligible actor must not resolve the Choice.")
	check(event_manager.choose_for_actor(0, "ally_1"), "An eligible selected actor should resolve the Choice.")
	check(ally.hp == 6 and hero.hp == 25 and int(world.resources.get("gold", 0)) == 14, "Actor Effect should apply only to the selected member and global Effect only once.")

	var party_heal := EventEffect.new()
	party_heal.type = EventEffect.Type.HEAL
	party_heal.amount = 3
	var all_choice := EventChoice.new()
	all_choice.text = "Rest together"
	all_choice.actor_mode = EventChoice.ActorMode.ALL_PARTY
	all_choice.effects = [party_heal, shared_gold]
	var all_event := EventData.new()
	all_event.id = "all_party_test"
	all_event.choices = [all_choice]
	check(event_manager.start_event(all_event, context) and event_manager.choose(0), "ALL_PARTY Choice should resolve for the full party.")
	check(hero.hp == 28 and ally.hp == 9 and int(world.resources.get("gold", 0)) == 16, "Actor Effects should reach every member while global Effects still apply once.")
	var invalid_target_heal := EventEffect.new()
	invalid_target_heal.type = EventEffect.Type.HEAL
	invalid_target_heal.target_id = "missing_member"
	invalid_target_heal.amount = 20
	invalid_target_heal.apply(context)
	check(hero.hp == 28 and ally.hp == 9, "An invalid explicit target id must not fall back to another party member.")

	event_manager.queue_free()
	encounter_manager.queue_free()
	if failures.is_empty():
		print("EVENT_ENCOUNTER_FLOW_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("EVENT_ENCOUNTER_FLOW_TEST: FAIL (%d)" % failures.size())
		quit(1)


func test_global_continue_without_actor() -> void:
	var choice := EventChoice.new()
	choice.text = "Continue the journey"
	var event := EventData.new()
	event.id = "global_continue_without_actor"
	event.choices = [choice]
	var manager := EventManager.new()
	manager.configure(GameState.new())
	check(manager.start_event(event, EventContext.new(manager.game_state)), "A global terminal Event should start without a party actor.")
	var states := manager.get_choice_states()
	check(states.size() == 1 and bool(states[0].get("enabled", false)), "A global Choice should remain enabled without a context actor.")
	check(manager.choose(0) and manager.active_event == null, "A global Continue Choice should finish without a context actor.")
	manager.queue_free()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
