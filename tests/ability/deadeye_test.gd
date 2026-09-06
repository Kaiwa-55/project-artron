extends SceneTree

const PlayerTemplate = preload("res://data/character/player.tres")
const EnemyTemplate = preload("res://data/character/enemy.tres")
const AssassinData = preload("res://data/class/assassin.tres")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _init() -> void:
	var character = PlayerTemplate.duplicate(true)
	character.character_class = AssassinData
	character.set_meta("selected_class_attribute_choices", [AttributeTypes.Type.INTELLIGENCE])
	character.available_abilities.append(load("res://data/ability/deadeye.tres"))
	character.selected_ability_ids.append("deadeye")
	character.equipped_abilities.append("deadeye")
	var player: CombatantState = character.create_combatant_state()
	var enemy: CombatantState = EnemyTemplate.create_combatant_state()
	var system := CombatSystem.new()
	system.start_combat([player, enemy])
	system.combat_state.current_actor_id = player.id
	var ranged: AttackData = load("res://data/attack/shortbow.tres")
	var melee: AttackData = player.equipped_weapon_attack
	check(player.equipped_abilities.has("deadeye"), "Learned Deadeye is equipped")
	check(system.ability_system.get_to_hit_bonus(player, ranged, 19.99) == 0, "Target below 20 ft is ineligible")
	check(int(player.ability_uses_this_turn.get("deadeye", 0)) == 0, "Ineligible attack does not spend use")
	check(system.ability_system.get_to_hit_bonus(player, melee, 20.0) == 0, "Melee attack is ineligible")
	check(int(player.ability_uses_this_turn.get("deadeye", 0)) == 0, "Melee attack does not spend use")
	check(system.ability_system.get_to_hit_bonus(player, ranged, 20.0) == 1, "Exactly 20 ft gains +1 To Hit")
	check(int(player.ability_uses_this_turn.get("deadeye", 0)) == 1, "Eligible declaration spends the use")
	check(system.ability_system.get_to_hit_bonus(player, ranged, 25.0) == 0, "Further ranged attacks this Turn gain no bonus")
	system.turn_system.start_turn(system.combat_state)
	check(system.ability_system.get_to_hit_bonus(player, ranged, 30.0) == 1, "New Turn restores Deadeye")
	# Runtime distance is measured edge-to-edge like targeting.
	system.turn_system.start_turn(system.combat_state)
	player.position = Vector2.ZERO
	enemy.position = Vector2((player.collision_radius_feet + enemy.collision_radius_feet + 20.0) * 12.0, 0)
	ranged.to_hit_bonus = -1000
	player.ap = player.max_ap
	var result := system.attack_system.resolve_attack(player, enemy, ranged)
	var base_modifier: int = player.get_attribute_modifier(ranged.attack_attribute) + ranged.to_hit_bonus + system.effect_system.get_attack_bonus(player)
	check(result.attack_modifier == base_modifier + 1, "Attack resolution applies Deadeye at edge distance")
	check(not result.hit and int(player.ability_uses_this_turn.get("deadeye", 0)) == 1, "Miss still consumes the first Attack use")
	for failure in failures:
		push_error(failure)
	print("DEADEYE_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
