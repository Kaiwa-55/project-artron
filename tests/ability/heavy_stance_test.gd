extends SceneTree

const PlayerTemplate := preload("res://data/character/player.tres")
const EnemyTemplate := preload("res://data/character/enemy.tres")
const HeavyStance := preload("res://data/ability/heavy_stance.tres")
const DefensiveStance := preload("res://data/ability/defensive_stance.tres")
const UnarmedAttack := preload("res://data/attack/unarmed_attack.tres")
const SwordAttack := preload("res://data/attack/sword.tres")
const Catalog := preload("res://data/creation/default_creation_catalog.tres")


func _init() -> void:
	var failures: Array[String] = []
	var character = PlayerTemplate.duplicate(true)
	character.level = 1
	character.available_abilities.append(HeavyStance)
	character.available_abilities.append(DefensiveStance)
	character.equipped_abilities.append(HeavyStance.id)
	character.equipped_abilities.append(DefensiveStance.id)
	var actor: CombatantState = character.create_combatant_state()
	var enemy: CombatantState = EnemyTemplate.create_combatant_state()
	actor.position = Vector2.ZERO
	enemy.position = Vector2(5.0, 0.0)
	var system := CombatSystem.new()
	system.start_combat([actor, enemy])
	system.combat_state.current_actor_id = actor.id
	actor.ap = actor.max_ap
	var base_speed := actor.get_effective_speed()
	var unarmed_before := system.damage_system.calculate_damage(actor, enemy, UnarmedAttack)
	var sword_before := system.damage_system.calculate_damage(actor, enemy, SwordAttack)
	var result := system.use_active_ability(actor.id, actor.id, HeavyStance.id)
	check(result.success and actor.ap == actor.max_ap - 1, "Heavy Stance activates on Self for 1 AP", failures)
	check(actor.has_status("heavy_stance") and is_equal_approx(actor.get_effective_speed(), maxf(0.0, base_speed - 5.0)), "Heavy Stance reduces Speed by 5 ft", failures)
	check(system.damage_system.calculate_damage(actor, enemy, UnarmedAttack) == unarmed_before + 2, "Heavy Stance adds 2 Damage to Unarmed Attacks", failures)
	check(system.damage_system.calculate_damage(actor, enemy, SwordAttack) == sword_before, "Heavy Stance does not add Damage to weapon Attacks", failures)
	system.effect_system.expire_turn_end_effects(actor)
	system.effect_system.expire_start_turn_effects(actor)
	check(actor.has_status("heavy_stance"), "Heavy Stance persists across turns until Combat ends", failures)
	var blocked: ActionResult = system.ability_system.validate_active_use(actor, DefensiveStance, enemy)
	check(not blocked.success and blocked.failure_reason.contains("Heavy Stance"), "Another Stance is blocked while Heavy Stance is active", failures)
	check(Catalog.abilities.has(HeavyStance), "Heavy Stance is available in Character Creation", failures)
	for failure in failures:
		push_error(failure)
	print("HEAVY_STANCE_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
