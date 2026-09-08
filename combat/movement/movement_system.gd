class_name MovementSystem
extends RefCounted

var map_rules
var ability_system


func get_available_distance_feet(actor: CombatantState) -> float:
	if actor == null:
		return 0.0
	# Status effects such as Slowed can reduce current Speed to zero while a
	# split Move is still in progress. Current Speed always takes priority over
	# the distance that was reserved when the Move began.
	if actor.get_effective_speed() <= 0.001:
		return 0.0
	if actor.movement_in_progress:
		return actor.movement_remaining_feet
	# Each new Move action grants a fresh Speed allowance. Continuing an
	# unfinished Move reuses the remaining allowance without spending AP again.
	return actor.get_effective_speed() + (ability_system.get_first_move_distance_bonus(actor) if ability_system != null else 0.0)


func can_begin_or_continue_move(actor: CombatantState, ap_cost: int = 1) -> bool:
	if actor == null or get_available_distance_feet(actor) <= 0.001:
		return false
	return actor.movement_in_progress or actor.ap >= ap_cost


func clamp_destination_to_remaining_speed(
	actor: CombatantState,
	destination: Vector2,
	movement: MovementData
) -> Vector2:
	if actor == null or movement == null:
		return destination
	var available_distance_feet: float = get_available_distance_feet(actor)
	var maximum_distance: float = maxf(0.0, available_distance_feet) \
		* movement.world_units_per_foot
	var requested_distance: float = actor.position.distance_to(destination)
	if requested_distance <= maximum_distance or requested_distance <= 0.001:
		return destination
	return actor.position + actor.position.direction_to(destination) * maximum_distance

func validate_move(
	actor: CombatantState,
	destination: Vector2,
	movement: MovementData,
	combat_state: CombatState = null
) -> ActionResult:

	if actor == null:
		return ActionResult.failure(
			"Actor does not exist."
		)

	if movement == null:
		return ActionResult.failure(
			"Movement data does not exist."
		)

	if actor.is_dying():
		return ActionResult.failure(
			"Actor is Dying."
		)
	if actor.has_status("rooted"):
		return ActionResult.failure("Rooted characters cannot Move.")

	if not actor.movement_in_progress and actor.ap < movement.ap_cost:
		return ActionResult.failure(
			"Not enough AP."
		)

	var distance := actor.position.distance_to(
		destination
	)

	var available_distance_feet: float = get_available_distance_feet(actor)
	if available_distance_feet <= 0.001:
		return ActionResult.failure("No Speed remaining this Turn.")
	if distance > available_distance_feet * movement.world_units_per_foot + 0.01:
		return ActionResult.failure(
			"Destination exceeds remaining Speed."
		)

	if map_rules != null and combat_state != null:
		var path_validation: ActionResult = map_rules.validate_movement_path(actor, destination, combat_state.combatants)
		if not path_validation.success:
			return path_validation

	return ActionResult.success_result()

func execute_move(
	actor: CombatantState,
	destination: Vector2,
	movement: MovementData,
	combat_state: CombatState = null
) -> ActionResult:

	var validation := validate_move(
		actor,
		destination,
		movement,
		combat_state
	)

	if not validation.success:
		return validation

	if not actor.movement_in_progress:
		var first_move_distance: float = get_available_distance_feet(actor)
		if not actor.spend_ap(movement.ap_cost):
			return ActionResult.failure(
				"Unable to spend AP."
			)
		actor.movement_in_progress = true
		actor.movement_remaining_feet = first_move_distance
		if ability_system != null:
			ability_system.commit_first_move_distance_bonuses(actor)

	var distance_feet: float = actor.position.distance_to(destination) \
		/ movement.world_units_per_foot
	actor.position = destination
	actor.movement_distance_this_turn += distance_feet
	actor.movement_remaining_feet = maxf(
		0.0,
		actor.movement_remaining_feet - distance_feet
	)
	if actor.movement_remaining_feet <= 0.001:
		actor.movement_remaining_feet = 0.0
		actor.movement_in_progress = false

	return ActionResult.success_result()
