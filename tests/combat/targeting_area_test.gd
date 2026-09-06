extends SceneTree

const PlayerData = preload("res://data/character/player.tres")
const EnemyData = preload("res://data/character/enemy.tres")
const BurstData = preload("res://data/skill/arcane_burst.tres")

var failures: Array[String] = []

func _init() -> void:
	var player: CombatantState = PlayerData.create_combatant_state()
	var enemy_a: CombatantState = EnemyData.create_combatant_state()
	var enemy_b: CombatantState = EnemyData.create_combatant_state()
	var enemy_out: CombatantState = EnemyData.create_combatant_state()
	enemy_b.id = "enemy_b"
	enemy_out.id = "enemy_out"
	player.position = Vector2(100, 100)
	enemy_a.position = Vector2(225, 100)
	enemy_b.position = Vector2(285, 100)
	enemy_out.position = Vector2(500, 100)
	enemy_a.active_reactions.clear()
	enemy_b.active_reactions.clear()
	enemy_out.active_reactions.clear()
	var system := CombatSystem.new()
	system.start_combat([player, enemy_a, enemy_b, enemy_out])
	# start_combat reapplies the current class loadout; add this standalone test
	# Skill afterwards so the fixture does not depend on the player's class.
	if not player.available_skills.any(func(skill): return skill != null and skill.id == BurstData.id):
		player.available_skills.append(BurstData)
	system.combat_state.current_actor_id = player.id
	player.ap = player.max_ap
	player.mana = maxi(player.max_mana, BurstData.mana_cost)
	check(system.validate_ground_skill_start(player.id, BurstData.id).success, "Available Area Skill should enter targeting mode")
	player.ap = 0
	check(system.validate_ground_skill_start(player.id, BurstData.id).failure_reason.contains("AP"), "Targeting should explain insufficient AP")
	player.ap = player.max_ap
	var mana_skill = BurstData.duplicate(true)
	mana_skill.id = "mana_area_validation"
	mana_skill.mana_cost = 1
	player.available_skills.append(mana_skill)
	player.mana = 0
	check(system.validate_ground_skill_start(player.id, mana_skill.id).failure_reason.contains("Mana"), "Targeting should explain insufficient Mana")
	player.mana = maxi(player.max_mana, BurstData.mana_cost)
	player.skill_cooldowns[BurstData.id] = 2
	check(system.validate_ground_skill_start(player.id, BurstData.id).failure_reason.contains("cooldown"), "Targeting should explain active Cooldown")
	player.skill_cooldowns.erase(BurstData.id)
	var ap_before := player.ap
	var area_result := system.execute_ground_skill(player.id, BurstData.id, Vector2(250, 100))
	check(area_result.success, "Valid ground target should resolve the Area Skill")
	check(player.ap == ap_before - BurstData.ap_cost, "Area Skill should spend AP once")
	var attacked_ids: Array[String] = []
	for event in area_result.events:
		if event.type == EventTypes.Type.ATTACK_HIT or event.type == EventTypes.Type.ATTACK_MISS:
			attacked_ids.append(event.target_id)
	check(attacked_ids.has(enemy_a.id) and attacked_ids.has(enemy_b.id), "Circle should resolve a separate Attack against every enemy inside")
	check(not attacked_ids.has(enemy_out.id), "Circle should not affect enemies outside its radius")

	var too_far: ActionResult = system.targeting_system.validate_target_point(player, Vector2(1000, 100), BurstData, system.map_rules)
	check(not too_far.success, "Ground target beyond targeting range should fail")
	var line_skill = BurstData.duplicate(true)
	line_skill.area_shape = SkillData.AreaShape.LINE
	line_skill.line_length_feet = 20.0
	line_skill.line_width_feet = 5.0
	var line_targets: Array[CombatantState] = system.targeting_system.collect_targets(player, Vector2(500, 100), line_skill, system.combat_state, system.map_rules)
	check(line_targets.has(enemy_a) and line_targets.has(enemy_b), "Line targeting should include enemies along the line")
	var cone_skill = BurstData.duplicate(true)
	cone_skill.area_shape = SkillData.AreaShape.CONE
	cone_skill.cone_angle_degrees = 60.0
	var cone_targets: Array[CombatantState] = system.targeting_system.collect_targets(player, Vector2(500, 100), cone_skill, system.combat_state, system.map_rules)
	check(cone_targets.has(enemy_a) and cone_targets.has(enemy_b), "Cone targeting should include enemies inside its angle and range")

	var preview: Dictionary = system.targeting_system.get_targeting_preview(player, Vector2(250, 100), BurstData, system.combat_state, system.map_rules)
	check(preview.valid and preview.targets.has(enemy_a) and preview.targets.has(enemy_b), "Preview should use the same validation and targets as resolution")
	var ally: CombatantState = PlayerData.create_combatant_state()
	ally.id = "ally"
	ally.position = Vector2(250, 115)
	system.combat_state.add_combatant(ally)
	var enemy_only_targets: Array[CombatantState] = system.targeting_system.collect_targets(player, Vector2(250, 100), BurstData, system.combat_state, system.map_rules)
	check(not enemy_only_targets.has(ally) and not enemy_only_targets.has(player), "Enemy-only Area should exclude allies and its caster")

	var blocked_skill = BurstData.duplicate(true)
	blocked_skill.requires_line_of_sight = false
	blocked_skill.area_blocked_by_obstacles = true
	system.map_rules.add_circular_obstacle(Vector2(267, 100), 12.0, "Test Cover")
	var blocked_targets: Array[CombatantState] = system.targeting_system.collect_targets(player, Vector2(250, 100), blocked_skill, system.combat_state, system.map_rules)
	check(blocked_targets.has(enemy_a) and not blocked_targets.has(enemy_b), "Obstacle should block Area propagation to targets behind it")
	var los_skill = BurstData.duplicate(true)
	system.map_rules.clear_obstacles()
	system.map_rules.add_circular_obstacle(Vector2(175, 100), 20.0, "Wall")
	check(not system.targeting_system.validate_target_point(player, Vector2(250, 100), los_skill, system.map_rules).success, "Ground targeting should reject a point without line of sight")

	if failures.is_empty():
		print("TARGETING_AREA_TEST: PASS")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		print("TARGETING_AREA_TEST: FAIL (%d)" % failures.size())
		quit(1)

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
