extends SceneTree

const PlayerData = preload("res://data/character/player.tres")
const EnemyData = preload("res://data/character/enemy.tres")


func _init() -> void:
	var actor: CombatantState = PlayerData.create_combatant_state()
	var target: CombatantState = EnemyData.create_combatant_state()
	actor.position = Vector2(0, 0)
	target.position = Vector2(100, 0)
	actor.vision = 0
	actor.vision_penalty = 4
	actor.skill_ranks["perception"] = 7
	target.skill_ranks["stealth"] = 0
	target.base_concealment = 3
	target.grant_concealment_against(actor.id, 1)
	var visibility_before: VisionSystem.Visibility = VisionSystem.get_visibility(actor, target, 1, true)
	var system := CombatSystem.new()
	system.start_combat([actor, target])
	system.combat_state.current_actor_id = actor.id
	actor.ap = actor.max_ap
	system.map_rules.add_circular_obstacle(Vector2(50, 0), 20, "Blocked Sight")
	var result: ActionResult = system.use_search(actor.id, target.id)
	var search_event: CombatEvent = result.events[0]
	var passed: bool = result.success \
		and search_event.data.maneuver == "Search" \
		and search_event.data.succeeded \
		and actor.ap == actor.max_ap - 1 \
		and target.get_concealment_reduction_against(actor.id) == 1 \
		and visibility_before == VisionSystem.Visibility.PARTIALLY_VISIBLE \
		and VisionSystem.get_visibility(actor, target, 1, true) == VisionSystem.Visibility.VISIBLE \
		and not system.map_rules.has_line_of_sight(actor.position, target.position)
	print("SEARCH_ACTION_TEST: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
