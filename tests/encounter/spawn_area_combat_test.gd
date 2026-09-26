extends SceneTree

const CombatScene = preload("res://scenes/prototype/PrototypeCombat.tscn")
const Player = preload("res://data/character/player.tres")
const Goblin = preload("res://data/character/goblin_shiv.tres")
const Group = preload("res://data/encounter/enemy_group_data.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var encounter := EncounterData.new()
	encounter.id = "spawn_area_test"
	encounter.player_party = [{"character": Player, "id": "player"}]
	encounter.player_spawn_areas_feet = [Rect2(-80, -80, 20, 20)]
	var group := Group.new()
	group.id = "patrol"
	group.enemy = Goblin
	group.count = 2
	group.spawn_area_feet = Rect2(50, 50, 30, 30)
	encounter.enemy_groups = [group]
	set_meta("active_encounter_data", encounter)
	var combat = CombatScene.instantiate()
	root.add_child(combat)
	var states: Array = combat.combat_system.combat_state.combatants.values()
	var player_count := 0
	var enemy_count := 0
	for state: CombatantState in states:
		var feet: Vector2 = state.position / combat.combat_system.map_rules.world_units_per_foot
		if state.team == 1:
			player_count += 1
			check(encounter.player_spawn_areas_feet[0].has_point(feet), "Player uses random spawn area")
		else:
			enemy_count += 1
			check(group.spawn_area_feet.has_point(feet), "Enemy group uses its own spawn area")
	check(player_count == 1 and enemy_count == 2, "Combat creates the party and all group members")
	combat.queue_free()
	remove_meta("active_encounter_data")
	print("SPAWN_AREA_COMBAT_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
