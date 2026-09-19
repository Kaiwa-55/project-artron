extends SceneTree

const PlayerData = preload("res://data/character/player.tres")
const EnemyData = preload("res://data/character/enemy.tres")


func _init() -> void:
	var actor: CombatantState = PlayerData.create_combatant_state()
	var seen_enemy: CombatantState = EnemyData.create_combatant_state()
	var hidden_enemy: CombatantState = EnemyData.create_combatant_state()
	seen_enemy.id = "seen_enemy"
	hidden_enemy.id = "hidden_enemy"
	actor.position = Vector2(0, 0)
	seen_enemy.position = Vector2(100, 0)
	hidden_enemy.position = Vector2(100, 100)
	actor.skill_ranks["stealth"] = 7
	seen_enemy.skill_ranks["perception"] = 100
	var system := CombatSystem.new()
	system.start_combat([actor, seen_enemy, hidden_enemy])
	system.combat_state.current_actor_id = actor.id
	actor.ap = actor.max_ap
	system.map_rules.add_circular_obstacle(Vector2(50, 50), 20, "Wall")
	var result: ActionResult = system.use_hide(actor.id)
	var hide_event: CombatEvent = result.events[0]
	var checks: Array = hide_event.data.checks
	var seen_check: Dictionary = checks.filter(func(entry): return entry.enemy_id == seen_enemy.id)[0]
	var hidden_check: Dictionary = checks.filter(func(entry): return entry.enemy_id == hidden_enemy.id)[0]
	var passed: bool = result.success and hide_event.data.succeeded \
		and actor.ap == actor.max_ap - 1 \
		and seen_check.dc == 114 and hidden_check.dc == 10 \
		and actor.get_concealment_bonus_against(seen_enemy.id) == 0 \
		and actor.get_concealment_bonus_against(hidden_enemy.id) == 1
	print("HIDE_ACTION_TEST: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
