class_name EventChoice
extends Resource

enum FailedConditionPresentation {
	DISABLED,
	HIDDEN,
}

enum ActorMode {
	CONTEXT_ACTOR,
	SELECT_ONE,
	ALL_PARTY,
}

@export var text: String = ""
@export var actor_mode: ActorMode = ActorMode.CONTEXT_ACTOR
@export var conditions: Array[EventCondition] = []
@export var effects: Array[EventEffect] = []
@export var next_event: Resource
@export var encounter: EncounterData
@export var failed_condition_presentation: FailedConditionPresentation = FailedConditionPresentation.DISABLED


func requires_choice_actor() -> bool:
	return conditions.any(func(condition): return condition != null and condition.uses_choice_actor()) \
		or effects.any(func(effect): return effect != null and effect.uses_choice_actor())


func conditions_met(context: EventContext) -> bool:
	return conditions.all(func(condition): return condition != null and condition.is_met(context))


func get_failure_reasons(context: EventContext) -> Array[String]:
	var reasons: Array[String] = []
	for condition in conditions:
		if condition != null and not condition.is_met(context):
			reasons.append(condition.failure_reason)
	return reasons


func global_conditions_met(context: EventContext) -> bool:
	return conditions.all(func(condition): return condition != null and (condition.uses_choice_actor() or condition.is_met(context)))


func actor_conditions_met(context: EventContext, actor_id: String) -> bool:
	var previous_actor_id := context.actor_id
	context.actor_id = actor_id
	var passed := conditions.all(func(condition): return condition != null and (not condition.uses_choice_actor() or condition.is_met(context)))
	context.actor_id = previous_actor_id
	return passed


func get_actor_failure_reasons(context: EventContext, actor_id: String) -> Array[String]:
	var previous_actor_id := context.actor_id
	context.actor_id = actor_id
	var reasons: Array[String] = []
	for condition in conditions:
		if condition != null and condition.uses_choice_actor() and not condition.is_met(context) and not reasons.has(condition.failure_reason):
			reasons.append(condition.failure_reason)
	context.actor_id = previous_actor_id
	return reasons
