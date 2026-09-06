extends SceneTree

func _init() -> void:
	var rules := MapRules.new()
	var player := CombatantState.new()
	var spider := CombatantState.new()
	player.collision_radius_feet = 2.5
	spider.collision_radius_feet = 5.0
	player.position = Vector2.ZERO
	var success := true
	for reach in [5.0, 30.0]:
		var radius := rules.get_targeting_preview_radius_world_units(player, reach)
		for offset in [-1.0, 0.0, 1.0]:
			spider.position = Vector2(radius + rules.get_combatant_radius_world_units(spider) + offset, 0)
			var touches_preview := player.position.distance_to(spider.position) <= radius + rules.get_combatant_radius_world_units(spider)
			success = success and touches_preview == rules.is_target_in_range(player, spider, reach)
			success = success and rules.is_target_in_range(player, spider, reach) == rules.is_target_in_range(spider, player, reach)
	print("TARGETING_PREVIEW_RANGE_TEST: " + ("PASS" if success else "FAIL"))
	quit(0 if success else 1)
