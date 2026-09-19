extends SceneTree

const PlayerData = preload("res://data/character/player.tres")
const EnemyData = preload("res://data/character/enemy.tres")


func _init() -> void:
	var attacker: CombatantState = PlayerData.create_combatant_state()
	var target: CombatantState = EnemyData.create_combatant_state()
	attacker.position = Vector2(100, 100)
	target.position = Vector2(160, 100)
	attacker.vision = 2
	target.base_concealment = 2
	var system := CombatSystem.new()
	system.start_combat([attacker, target])
	system.combat_state.current_actor_id = attacker.id
	system.map_rules.set_light_level(3)
	var blocked := system.attack_system.validate_attack(attacker, target, attacker.equipped_weapon_attack)
	target.base_concealment = 1
	var partial := system.attack_system.validate_attack(attacker, target, attacker.equipped_weapon_attack)
	var result := system.attack_system.resolve_attack(attacker, target, attacker.equipped_weapon_attack)
	var blind := EffectData.new()
	blind.id = "blind"
	attacker.add_effect(blind)
	var blinded := system.attack_system.validate_attack(attacker, target, attacker.equipped_weapon_attack)
	var passed: bool = not blocked.success and blocked.failure_reason.contains("not visible") \
		and partial.success \
		and result.attack_modifier <= -4 \
		and not blinded.success
	print("VISION_COMBAT_INTEGRATION_TEST: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
