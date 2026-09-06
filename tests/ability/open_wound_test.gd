extends SceneTree

const PlayerTemplate = preload("res://data/character/player.tres")
const EnemyTemplate = preload("res://data/character/enemy.tres")
const AssassinData = preload("res://data/class/assassin.tres")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func bleeding_stacks(target: CombatantState) -> int:
	for instance in target.effects:
		if instance.data != null and instance.data.id == "bleeding":
			return instance.stack_count
	return 0

func execute_attack(system: CombatSystem, player: CombatantState, enemy: CombatantState, attack: AttackData) -> ActionResult:
	player.ap = player.max_ap
	var request := ActionRequest.new(player.id, ActionTypes.Type.ATTACK)
	request.target_id = enemy.id
	request.attack_data = attack
	return system.execute_action(request)

func _init() -> void:
	var character = PlayerTemplate.duplicate(true)
	character.character_class = AssassinData
	character.set_meta("selected_class_attribute_choices", [AttributeTypes.Type.INTELLIGENCE])
	character.available_abilities.append(load("res://data/ability/open_wound.tres"))
	character.selected_ability_ids.append("open_wound")
	character.equipped_abilities.append("open_wound")
	var player: CombatantState = character.create_combatant_state()
	var enemy: CombatantState = EnemyTemplate.create_combatant_state()
	enemy.max_hp = 999
	enemy.hp = enemy.max_hp
	var system := CombatSystem.new()
	system.start_combat([player, enemy])
	system.combat_state.current_actor_id = player.id
	enemy.active_reactions.clear()
	player.active_reactions = player.active_reactions.filter(func(reaction): return reaction == null or reaction.id != "mobile_shooter")
	check(player.equipped_abilities.has("open_wound"), "Learned Open Wound is equipped")

	var melee: AttackData = player.equipped_weapon_attack.duplicate(true)
	melee.to_hit_bonus = -1000
	check(execute_attack(system, player, enemy, melee).success, "Melee miss resolves")
	check(bleeding_stacks(enemy) == 0, "Miss does not apply Bleeding")
	check(int(player.ability_uses_this_turn.get("open_wound", 0)) == 0, "Miss does not consume Open Wound")
	# Defensive Reactions resolve before passive on-Hit statuses.
	melee.to_hit_bonus = 1000
	player.ap = player.max_ap
	var parried := system.attack_system.resolve_attack(player, enemy, melee, true)
	parried.hit = false
	system.attack_system.finalize_attack(player, enemy, melee, parried)
	check(bleeding_stacks(enemy) == 0, "A final Miss after a defensive Reaction does not apply Bleeding")
	check(int(player.ability_uses_this_turn.get("open_wound", 0)) == 0, "A defensive Reaction does not consume Open Wound")

	var ranged: AttackData = load("res://data/attack/shortbow.tres").duplicate(true)
	ranged.to_hit_bonus = 1000
	check(execute_attack(system, player, enemy, ranged).success, "Ranged hit resolves")
	check(bleeding_stacks(enemy) == 0, "Ranged Hit does not apply Open Wound")
	check(int(player.ability_uses_this_turn.get("open_wound", 0)) == 0, "Ranged Hit does not consume Open Wound")

	melee.to_hit_bonus = 1000
	check(execute_attack(system, player, enemy, melee).success, "Melee hit resolves")
	check(bleeding_stacks(enemy) == 1, "First Melee Hit applies Bleeding 1")
	check(int(player.ability_uses_this_turn.get("open_wound", 0)) == 1, "First Melee Hit consumes Open Wound")
	check(execute_attack(system, player, enemy, melee).success, "Second Melee hit resolves")
	check(bleeding_stacks(enemy) == 1, "Second Melee Hit in the same Turn does not add Bleeding")

	system.turn_system.start_turn(system.combat_state)
	system.combat_state.current_actor_id = player.id
	check(execute_attack(system, player, enemy, melee).success, "New-Turn Melee hit resolves")
	check(bleeding_stacks(enemy) == 2, "New Turn restores Open Wound")

	for failure in failures:
		push_error(failure)
	print("OPEN_WOUND_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
