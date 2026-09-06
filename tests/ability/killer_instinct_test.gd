extends SceneTree

const PlayerTemplate = preload("res://data/character/player.tres")
const EnemyData = preload("res://data/character/enemy.tres")
const AssassinData = preload("res://data/class/assassin.tres")

var failures: Array[String] = []


func _init() -> void:
	var character = PlayerTemplate.duplicate(true)
	character.character_class = AssassinData
	character.set_meta("selected_class_attribute_choices", [AttributeTypes.Type.INTELLIGENCE])
	var player: CombatantState = character.create_combatant_state()
	var enemy: CombatantState = EnemyData.create_combatant_state()
	var system := CombatSystem.new()
	system.start_combat([player, enemy])
	system.combat_state.current_actor_id = player.id
	player.ap = player.max_ap

	var ancestry_dex_bonus := 1 if character.ancestry_attribute_choices.has(AttributeTypes.Type.DEXTERITY) else 0
	var class_dex_bonus := int(AssassinData.fixed_attribute_bonuses.get(AttributeTypes.Type.DEXTERITY, 0))
	check(player.dexterity == character.dexterity + ancestry_dex_bonus + class_dex_bonus, "Assassin should grant its configured DEX bonus")
	check(player.intelligence == character.intelligence + AssassinData.attribute_bonus_per_choice, "Assassin should grant the selected INT bonus")
	check(player.available_abilities.any(func(ability): return ability != null and ability.id == "killer_instinct"), "Killer Instinct should be granted")
	check(player.equipped_abilities.has("killer_instinct"), "Killer Instinct should auto-equip")
	check(not system.toggle_ability(player.id, "killer_instinct").success, "Killer Instinct should not be manually unequipped")
	# Isolate this Ability from other Assassin damage Passives.
	player.equipped_abilities.erase("brutal_strike")

	var round_number := system.combat_state.current_round
	check(total_bonus(system.ability_system.get_conditional_damage_bonuses(player, enemy, player.equipped_weapon_attack, round_number)) == player.level, "first declared attack this round should gain Level bonus")
	var request := ActionRequest.new(player.id, ActionTypes.Type.ATTACK)
	request.target_id = enemy.id
	request.attack_data = player.equipped_weapon_attack
	var attack_result := system.execute_action(request)
	check(attack_result.success, "valid attack declaration should execute")
	check(enemy.last_attack_declared_round == round_number, "target should be marked when Attack is declared")
	check(total_bonus(system.ability_system.get_conditional_damage_bonuses(player, enemy, player.equipped_weapon_attack, round_number)) == 0, "another attack at 50% HP or higher in the same round should not gain the bonus")

	enemy.hp = maxi(0, (enemy.max_hp - 1) / 2)
	check(enemy.hp * 2 < enemy.max_hp, "test target should be below 50% HP")
	check(total_bonus(system.ability_system.get_conditional_damage_bonuses(player, enemy, player.equipped_weapon_attack, round_number)) == player.level, "below-50% target should always grant Level bonus")
	var similar_ability := AbilityData.new()
	similar_ability.id = "finisher_test"
	similar_ability.display_name = "Finisher Test"
	var similar_effect := AbilityEffectData.new()
	similar_effect.effect_type = AbilityEffectData.Type.CONDITIONAL_DAMAGE_BONUS
	similar_effect.target_hp_below_percent = 50
	similar_effect.flat_damage_bonus = 2
	similar_ability.effects = [similar_effect]
	player.available_abilities.append(similar_ability)
	player.equipped_abilities.append(similar_ability.id)
	var combined: Array[Dictionary] = system.ability_system.get_conditional_damage_bonuses(player, enemy, player.equipped_weapon_attack, round_number)
	check(total_bonus(combined) == player.level + 2 and combined.size() == 2, "similar conditional damage Abilities should stack without hard-coded Ability ids")
	enemy.hp = enemy.max_hp
	check(total_bonus(system.ability_system.get_conditional_damage_bonuses(player, enemy, player.equipped_weapon_attack, round_number + 1)) == player.level, "a new round should make the target eligible again")

	if failures.is_empty():
		print("KILLER_INSTINCT_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("KILLER_INSTINCT_TEST: FAIL (%d)" % failures.size())
		quit(1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func total_bonus(bonuses: Array[Dictionary]) -> int:
	var total := 0
	for bonus in bonuses:
		total += int(bonus.get("amount", 0))
	return total
