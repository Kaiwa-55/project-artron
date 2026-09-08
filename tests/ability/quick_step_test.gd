extends SceneTree

const PlayerTemplate = preload("res://data/character/player.tres")
const EnemyTemplate = preload("res://data/character/enemy.tres")
const AssassinData = preload("res://data/class/assassin.tres")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _init() -> void:
	var character = PlayerTemplate.duplicate(true)
	character.character_class = AssassinData
	character.level = 3
	character.set_meta("selected_class_attribute_choices", [AttributeTypes.Type.INTELLIGENCE])
	character.available_abilities.append(load("res://data/ability/quick_step.tres"))
	character.selected_ability_ids.append("quick_step")
	character.equipped_abilities.append("quick_step")
	var player: CombatantState = character.create_combatant_state()
	var enemy: CombatantState = EnemyTemplate.create_combatant_state()
	var system := CombatSystem.new()
	system.start_combat([player, enemy])
	system.combat_state.current_actor_id = player.id
	player.position = Vector2.ZERO
	enemy.position = Vector2(2000, 2000)
	player.ap = player.max_ap
	var movement := MovementData.new()
	movement.ap_cost = 1
	movement.world_units_per_foot = system.map_rules.world_units_per_foot
	var speed := player.get_effective_speed()
	check(player.equipped_abilities.has("quick_step"), "Learned Quick Step is equipped")
	check(system.movement_system.get_available_distance_feet(player) == speed + 5.0, "First Move preview gains 5 ft")
	var too_far := Vector2((speed + 5.1) * movement.world_units_per_foot, 0)
	check(not system.movement_system.validate_move(player, too_far, movement, system.combat_state).success, "Move cannot exceed boosted distance")
	check(int(player.ability_uses_this_turn.get("quick_step", 0)) == 0, "Invalid Move does not consume Quick Step")
	var destination := Vector2(5.0 * movement.world_units_per_foot, 0)
	check(system.movement_system.execute_move(player, destination, movement, system.combat_state).success, "First Move succeeds")
	check(player.movement_remaining_feet == speed, "Partial first Move leaves base Speed after using bonus")
	check(int(player.ability_uses_this_turn.get("quick_step", 0)) == 1, "First valid Move consumes Quick Step")
	check(system.movement_system.get_available_distance_feet(player) == speed, "Continuation uses remaining boosted movement")
	player.movement_in_progress = false
	player.movement_remaining_feet = 0.0
	check(system.movement_system.get_available_distance_feet(player) == 0.0, "A completed or forfeited Move cannot start again this Turn")
	check(not system.movement_system.validate_move(player, player.position + Vector2.ONE, movement, system.combat_state).success, "Move is rejected when no Speed remains")
	system.turn_system.start_turn(system.combat_state)
	check(system.movement_system.get_available_distance_feet(player) == speed + 5.0, "New Turn restores Quick Step")
	# Special movement does not consume the passive.
	system.ability_system.commit_first_move_distance_bonuses(null)
	check(int(player.ability_uses_this_turn.get("quick_step", 0)) == 0, "Non-Move effects do not consume Quick Step")
	for failure in failures:
		push_error(failure)
	print("QUICK_STEP_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
