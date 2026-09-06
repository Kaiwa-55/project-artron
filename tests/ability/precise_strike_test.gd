extends SceneTree

const PlayerTemplate = preload("res://data/character/player.tres")
const EnemyTemplate = preload("res://data/character/enemy.tres")
const AssassinData = preload("res://data/class/assassin.tres")
const PreciseStrike = preload("res://data/ability/precise_strike.tres")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _init() -> void:
	var character = PlayerTemplate.duplicate(true)
	character.character_class = AssassinData
	character.set_meta("selected_class_attribute_choices", [AttributeTypes.Type.INTELLIGENCE])
	character.available_abilities.append(PreciseStrike)
	character.selected_ability_ids.append("precise_strike")
	character.equipped_abilities.append("precise_strike")
	var player: CombatantState = character.create_combatant_state()
	var enemy: CombatantState = EnemyTemplate.create_combatant_state()
	var system := CombatSystem.new()
	system.start_combat([player, enemy])
	check(player.available_abilities.any(func(ability): return ability != null and ability.id == "precise_strike"), "Assassin receives Precise Strike")
	check(player.equipped_abilities.has("precise_strike"), "Learned Precise Strike is equipped")
	check(PreciseStrike.is_passive and system.ability_system.ability_has_trait(PreciseStrike, "passive"), "Precise Strike is Passive")
	var attack: AttackData = player.equipped_weapon_attack.duplicate(true)
	check(system.ability_system.get_critical_chance_bonus(player, attack) == 5, "Critical Chance gains 5 percent")
	check(system.ability_system.get_critical_damage_bonus(player, attack) == 2, "Critical gains 2 Damage")
	# Duplicate effects inside this skill cannot stack its bonus.
	PreciseStrike.effects.append(PreciseStrike.effects[0])
	PreciseStrike.effects.append(PreciseStrike.effects[1])
	check(system.ability_system.get_critical_chance_bonus(player, attack) == 5, "Critical Chance does not self-stack")
	check(system.ability_system.get_critical_damage_bonus(player, attack) == 2, "Critical Damage does not self-stack")
	PreciseStrike.effects.resize(2)
	attack.critical_chance = 100
	attack.to_hit_bonus = 1000
	enemy.active_reactions.clear()
	player.ap = player.max_ap
	var expected: int = system.damage_system.calculate_critical_damage(player, attack) + 2
	var result: AttackResult = system.attack_system.resolve_attack(player, enemy, attack)
	check(result.hit and result.critical, "100 percent test attack critically hits")
	check(result.damage == expected, "Critical Damage adds 2 after the critical multiplier")
	player.equipped_abilities.erase("precise_strike")
	check(system.ability_system.get_critical_chance_bonus(player, attack) == 0 and system.ability_system.get_critical_damage_bonus(player, attack) == 0, "Inactive ability grants no bonus")
	for failure in failures:
		push_error(failure)
	print("PRECISE_STRIKE_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
