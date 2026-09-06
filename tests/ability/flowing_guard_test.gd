extends SceneTree

const PlayerTemplate = preload("res://data/character/player.tres")
const EnemyTemplate = preload("res://data/character/enemy.tres")
const MartialArtist = preload("res://data/class/martial_artist.tres")
const FlowingGuard = preload("res://data/ability/flowing_guard.tres")
const Catalog = preload("res://data/creation/default_creation_catalog.tres")

var failures: Array[String] = []


func _init() -> void:
	var character = PlayerTemplate.duplicate(true)
	character.character_class = MartialArtist
	character.level = 2
	character.class_attribute_choices.assign([AttributeTypes.Type.STRENGTH])
	character.available_abilities.append(FlowingGuard)
	character.selected_ability_ids.append("flowing_guard")
	character.equipped_abilities.append("flowing_guard")
	var martial_artist: CombatantState = character.create_combatant_state()
	var enemy: CombatantState = EnemyTemplate.create_combatant_state()
	martial_artist.position = Vector2.ZERO
	enemy.position = Vector2(1000, 0)
	var system := CombatSystem.new()
	system.start_combat([martial_artist, enemy])
	system.combat_state.current_actor_id = martial_artist.id
	system.start_current_turn()
	var movement := MovementData.new()
	movement.ap_cost = 1
	movement.world_units_per_foot = system.map_rules.world_units_per_foot
	var base_reflex_bonus: int = system.effect_system.get_reflex_bonus(martial_artist)

	check(execute_move(system, martial_artist, Vector2(36, 0), movement).success, "First 3 ft Move succeeds")
	check(not martial_artist.has_status("flowing_guard_reflex"), "Flowing Guard waits until at least 5 ft has been moved")
	var trigger_result := execute_move(system, martial_artist, Vector2(60, 0), movement)
	check(trigger_result.success and martial_artist.has_status("flowing_guard_reflex"), "Split Move triggers Flowing Guard when cumulative distance reaches 5 ft")
	check(system.effect_system.get_reflex_bonus(martial_artist) == base_reflex_bonus + 1, "Flowing Guard grants +1 Reflex")
	check(trigger_result.events.any(func(event): return event.type == EventTypes.Type.EFFECT_APPLIED and event.data.get("ability_name", "") == "Flowing Guard"), "Flowing Guard reports its activation")

	check(execute_move(system, martial_artist, Vector2(120, 0), movement).success, "Further movement succeeds")
	check(martial_artist.effects.filter(func(effect): return effect.data.id == "flowing_guard_reflex").size() == 1, "Repeated movement does not stack Flowing Guard")
	system.start_current_turn()
	check(not martial_artist.has_status("flowing_guard_reflex"), "Flowing Guard expires at the start of the next Turn")
	check(Catalog.abilities.any(func(ability): return ability != null and ability.id == "flowing_guard"), "Flowing Guard is available in Character Creation")
	check(MartialArtist.get_progression_entry(2).granted_abilities.any(func(ability): return ability != null and ability.id == "flowing_guard"), "Martial Artist receives Flowing Guard at Level 2")

	for failure in failures:
		push_error(failure)
	print("FLOWING_GUARD_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func execute_move(system: CombatSystem, actor: CombatantState, destination: Vector2, movement: MovementData) -> ActionResult:
	var request := ActionRequest.new(actor.id, ActionTypes.Type.MOVE)
	request.target_position = destination
	request.movement_data = movement
	return system.execute_action(request)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
