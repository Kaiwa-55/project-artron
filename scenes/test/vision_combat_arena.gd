extends "res://scenes/prototype/prototype_combat.gd"


func start_test_combat() -> void:
	super.start_test_combat()
	# These zones are world-space and therefore affect the real CombatSystem.
	combat_system.map_rules.set_light_level(1)
	combat_system.map_rules.add_light_area(Rect2(-480, -240, 320, 480), 0, "Bright Light")
	combat_system.map_rules.add_light_area(Rect2(-160, -240, 320, 480), 2, "Dim Light")
	combat_system.map_rules.add_light_area(Rect2(160, -240, 320, 480), 3, "Darkness")
	# EnemyData uses legacy map coordinates. Place this scenario's target well
	# inside Darkness and outside the Central Stone's collision radius.
	var enemy: CombatantState = combat_system.get_combat_state().get_combatant("enemy")
	if enemy != null:
		enemy.position = Vector2(300, -90)
		enemy.base_concealment = 1
		var enemy_node = get_enemy_node(enemy.id)
		if enemy_node != null:
			enemy_node.refresh_from_state()
	var dark_vision_enemy: CombatantState = combat_system.get_combat_state().get_combatant("enemy_2")
	if dark_vision_enemy != null:
		dark_vision_enemy.display_name = "Dark Vision Enemy"
		dark_vision_enemy.position = Vector2(300, 90)
		dark_vision_enemy.base_concealment = 1
		dark_vision_enemy.dark_vision = 1
		var dark_vision_node = get_enemy_node(dark_vision_enemy.id)
		if dark_vision_node != null:
			dark_vision_node.refresh_from_state()
	$BattlefieldWorld/LightZones.queue_redraw()
	$UILayer/Control.update_ui()
