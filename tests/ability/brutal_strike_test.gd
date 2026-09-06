extends SceneTree

const PlayerTemplate = preload("res://data/character/player.tres")
const EnemyTemplate = preload("res://data/character/enemy.tres")
const AssassinData = preload("res://data/class/assassin.tres")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func brutal_amount(bonuses: Array[Dictionary]) -> int:
	for bonus in bonuses:
		if bonus.get("ability_id") == "brutal_strike":
			return int(bonus.get("amount", 0))
	return 0

func _init() -> void:
	var character = PlayerTemplate.duplicate(true)
	character.character_class = AssassinData
	character.set_meta("selected_class_attribute_choices", [AttributeTypes.Type.INTELLIGENCE])
	character.available_abilities.append(load("res://data/ability/brutal_strike.tres"))
	character.selected_ability_ids.append("brutal_strike")
	character.equipped_abilities.append("brutal_strike")
	var player: CombatantState = character.create_combatant_state()
	var enemy: CombatantState = EnemyTemplate.create_combatant_state()
	var system := CombatSystem.new()
	system.start_combat([player, enemy])
	system.combat_state.current_actor_id = player.id
	enemy.active_reactions.clear()
	var melee: AttackData = player.equipped_weapon_attack.duplicate(true)
	var ranged: AttackData = load("res://data/attack/shortbow.tres")
	check(player.equipped_abilities.has("brutal_strike"), "Learned Brutal Strike is equipped")
	check(brutal_amount(system.ability_system.get_conditional_damage_bonuses(player, enemy, melee, 1)) == 2, "First eligible Melee Hit offers +2")
	check(brutal_amount(system.ability_system.get_conditional_damage_bonuses(player, enemy, ranged, 1)) == 0, "Ranged attacks are ineligible")
	enemy.hp = enemy.max_hp / 2
	check(brutal_amount(system.ability_system.get_conditional_damage_bonuses(player, enemy, melee, 1)) == 3, "Exactly 50 percent HP offers +3 instead")
	# A miss must not consume the once-per-turn benefit.
	melee.to_hit_bonus = -1000
	player.ap = player.max_ap
	var request := ActionRequest.new(player.id, ActionTypes.Type.ATTACK)
	request.target_id = enemy.id
	request.attack_data = melee
	check(system.execute_action(request).success, "Miss resolves normally")
	check(int(player.ability_uses_this_turn.get("brutal_strike", 0)) == 0, "Miss does not consume Brutal Strike")
	melee.to_hit_bonus = 1000
	player.ap = player.max_ap
	check(system.execute_action(request).success, "Hit resolves normally")
	check(int(player.ability_uses_this_turn.get("brutal_strike", 0)) == 1, "First Hit consumes Brutal Strike")
	check(brutal_amount(system.ability_system.get_conditional_damage_bonuses(player, enemy, melee, 1)) == 0, "Further Hits this Turn gain no bonus")
	system.turn_system.start_turn(system.combat_state)
	check(brutal_amount(system.ability_system.get_conditional_damage_bonuses(player, enemy, melee, 1)) == 3, "New Turn restores Brutal Strike")
	for failure in failures:
		push_error(failure)
	print("BRUTAL_STRIKE_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
