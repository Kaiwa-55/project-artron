extends SceneTree

const PlayerTemplate := preload("res://data/character/player.tres")
const Devotee := preload("res://data/class/devotee.tres")
const JudgmentWave := preload("res://data/ability/judgment_wave.tres")
const Catalog := preload("res://data/creation/default_creation_catalog.tres")


func _init() -> void:
	var failures: Array[String] = []
	var character = PlayerTemplate.duplicate(true)
	character.character_class = Devotee
	character.level = 2
	character.class_attribute_choices.assign([AttributeTypes.Type.CONSTITUTION])
	var devotee: CombatantState = character.create_combatant_state()
	devotee.id = "player"; devotee.team = 0
	var ally := make_target("ally", 0, Vector2(120, 20))
	var enemy := make_target("enemy", 1, Vector2(180, -20))
	var immune := make_target("immune", 1, Vector2(200, 35))
	immune.damage_immunities = ["light"]
	var behind := make_target("behind", 1, Vector2(-120, 0))

	var system := CombatSystem.new()
	system.start_combat([devotee, ally, enemy, immune, behind])
	system.combat_state.current_actor_id = devotee.id
	devotee.position = Vector2.ZERO
	devotee.ap = 5
	devotee.faith = 11
	var devotee_hp_before: int = devotee.hp
	var ally_hp_before: int = ally.hp
	var enemy_hp_before: int = enemy.hp
	var immune_hp_before: int = immune.hp
	var behind_hp_before: int = behind.hp

	var result := system.execute_ground_ability(devotee.id, JudgmentWave.id, Vector2(240, 0))
	check(result.success, "Judgment Wave resolves in a 20-foot cone", failures)
	check(ally.hp == ally_hp_before - 13 and enemy.hp == enemy_hp_before - 13, "Faith 11 plus Level 2 deals 13 Light Damage to allies and enemies in the cone", failures)
	check(ally.has_status("prone") and enemy.has_status("prone"), "Targets that take Judgment Wave damage become Prone", failures)
	check(immune.hp == immune_hp_before and not immune.has_status("prone"), "A target immune to Light takes no damage and does not become Prone", failures)
	check(behind.hp == behind_hp_before and not behind.has_status("prone"), "Targets outside the cone are unaffected", failures)
	check(devotee.hp == devotee_hp_before and not devotee.has_status("prone"), "Judgment Wave does not include its caster", failures)
	check(devotee.ap == 2 and devotee.faith == 8, "Judgment Wave costs 3 AP and 3 Faith after snapshotting damage", failures)

	check(JudgmentWave.required_level == 2 and JudgmentWave.area_shape == AbilityData.AreaShape.CONE and JudgmentWave.targeting_range_feet == 20.0, "Judgment Wave is a Level 2 Cone with 20-foot range", failures)
	check(JudgmentWave.ap_cost == 3 and JudgmentWave.faith_cost == 3 and JudgmentWave.target_filter == AbilityData.TargetFilter.ALL_COMBATANTS, "Judgment Wave has the specified costs and affects every combatant", failures)
	check(Catalog.abilities.has(JudgmentWave) and Devotee.get_progression_entry(2).granted_abilities.has(JudgmentWave), "Judgment Wave is registered in Character Creation and Level 2 progression", failures)

	for failure in failures:
		push_error(failure)
	print("JUDGMENT_WAVE_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func make_target(id: String, team: int, position: Vector2) -> CombatantState:
	var target := CombatantState.new()
	target.id = id
	target.display_name = id.capitalize()
	target.team = team
	target.position = position
	target.base_max_hp = 40
	return target


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
