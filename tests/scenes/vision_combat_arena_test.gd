extends SceneTree

const TestScene = preload("res://scenes/test/VisionCombatArena.tscn")
const DaggerAttack = preload("res://data/attack/dagger.tres")


func _init() -> void:
	var scene = TestScene.instantiate()
	root.add_child(scene)
	await process_frame
	var rules = scene.combat_system.map_rules
	var player: CombatantState = scene.combat_system.get_combat_state().get_combatant("player")
	var enemy: CombatantState = scene.combat_system.get_combat_state().get_combatant("enemy")
	var dark_vision_enemy: CombatantState = scene.combat_system.get_combat_state().get_combatant("enemy_2")
	var enemy_node = scene.get_enemy_node(enemy.id)
	var stone = scene.get_node("BattlefieldWorld/central_stone")
	var stone_radius: float = float(rules.obstacles[0].radius)
	var visual_center: Vector2 = stone.position + Vector2.ONE * stone_radius
	player.position = Vector2(-300, 150)
	enemy.position = Vector2(300, 150)
	player.ap = player.max_ap
	player.base_concealment = 3
	enemy_node.set_concealment_against(player, rules)
	var dagger_result: AttackResult = scene.combat_system.attack_system.resolve_attack(player, enemy, DaggerAttack)
	var passed: bool = rules.light_areas.size() == 3 \
		and not rules.obstacles.is_empty() \
		and rules.get_light_level_at(Vector2(300, 0)) == 3 \
		and enemy != null and enemy.base_concealment == 1 \
		and dark_vision_enemy != null and dark_vision_enemy.dark_vision == 1 \
		and dark_vision_enemy.position == Vector2(300, 90) \
		and visual_center == Vector2(rules.obstacles[0].center) \
		and enemy_node.get_node("ConcealmentBadge").visible \
		and enemy_node.get_node("ConcealmentBadge").text.begins_with("C ") \
		and dagger_result.visibility_penalty == -4
	print("VISION_COMBAT_ARENA_TEST: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
