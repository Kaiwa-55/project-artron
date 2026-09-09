extends SceneTree

const PlayerData := preload("res://data/character/player.tres")
const EnemyData := preload("res://data/character/enemy.tres")


func _init() -> void:
	var failures: Array[String] = []
	var generic := CombatantState.new()
	check(generic.class_dc == 13, "Every new combatant starts with Class DC 13 at Level 1", failures)

	for current_level in [1, 2, 5, 10]:
		generic.level = current_level
		check(generic.class_dc == 12 + current_level, "Class DC follows 12 + Level at Level %d" % current_level, failures)
		check(generic.get_class_dc() == generic.class_dc, "Class DC property and public getter agree", failures)

	var player: CombatantState = PlayerData.create_combatant_state()
	var enemy: CombatantState = EnemyData.create_combatant_state()
	check(player.class_dc == 12 + player.level, "Player receives Class DC", failures)
	check(enemy.class_dc == 12 + enemy.level, "Enemy receives Class DC", failures)

	if failures.is_empty():
		print("CLASS_DC_TEST: PASS")
		quit(0)
	for failure in failures:
		push_error(failure)
	quit(1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
