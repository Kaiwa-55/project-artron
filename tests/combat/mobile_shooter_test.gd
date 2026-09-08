extends SceneTree

const PlayerTemplate = preload("res://data/character/player.tres")
const EnemyTemplate = preload("res://data/character/enemy.tres")
const AssassinData = preload("res://data/class/assassin.tres")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func make_request(attack: AttackData) -> ActionRequest:
	var request := ActionRequest.new("player", ActionTypes.Type.ATTACK)
	request.target_id = "enemy"
	request.attack_data = attack
	return request

func _init() -> void:
	var character = PlayerTemplate.duplicate(true)
	character.character_class = AssassinData
	character.level = 3
	character.set_meta("selected_class_attribute_choices", [AttributeTypes.Type.INTELLIGENCE])
	character.available_abilities.append(load("res://data/ability/mobile_shooter.tres"))
	character.selected_ability_ids.append("mobile_shooter")
	character.equipped_abilities.append("mobile_shooter")
	var player: CombatantState = character.create_combatant_state()
	var enemy: CombatantState = EnemyTemplate.create_combatant_state()
	var system := CombatSystem.new()
	system.start_combat([player, enemy])
	system.combat_state.current_actor_id = player.id
	enemy.active_reactions.clear()
	player.position = Vector2.ZERO
	enemy.position = Vector2(180, 0)
	var ranged: AttackData = load("res://data/attack/shortbow.tres").duplicate(true)
	var mobile_ability = load("res://data/ability/mobile_shooter.tres")
	var mobile = player.active_reactions.filter(func(reaction): return reaction != null and reaction.id == "mobile_shooter")
	check(mobile.size() == 1 and mobile[0].ap_cost == 0, "Assassin gains free Mobile Shooter Reaction")
	check(mobile_ability.reaction_only, "Mobile Shooter is marked Reaction-only")
	check(not mobile_ability.granted_reactions.is_empty(), "Mobile Shooter still grants its Reaction data")
	check(not system.ability_system.validate_active_use(player, mobile_ability).success, "Mobile Shooter cannot be activated from the Action Bar")
	var effect = system.reaction_system.get_effect(mobile[0], ReactionEffectData.Type.MOVEMENT)
	check(effect.distance_feet == 5.0 and not effect.movement_triggers_reactions, "Movement is 5 ft and does not trigger Reactions")
	# Miss does not trigger or consume it.
	ranged.to_hit_bonus = -1000
	player.ap = player.max_ap
	var miss := system.execute_action(make_request(ranged))
	check(miss.success and not miss.requires_reaction_choice, "Ranged Miss does not offer Mobile Shooter")
	check(int(player.ability_uses_this_turn.get("mobile_shooter", 0)) == 0, "Miss does not consume limit")
	# First final Hit offers the choice and consumes this turn's trigger.
	ranged.to_hit_bonus = 1000
	player.ap = player.max_ap
	var before_ap := player.ap
	var hit := system.execute_action(make_request(ranged))
	check(hit.requires_reaction_choice and hit.reaction_prompt.reaction.id == "mobile_shooter", "First Ranged Hit offers Mobile Shooter")
	check(int(player.ability_uses_this_turn.get("mobile_shooter", 0)) == 1, "First Hit consumes trigger limit")
	var accepted := system.resolve_pending_reaction(0)
	check(accepted.success and system.has_pending_step_back_move(), "Accepting asks for movement destination")
	check(player.ap == before_ap - ranged.ap_cost, "Mobile Shooter costs no additional AP")
	var origin := player.position
	var moved := system.execute_step_back_move(origin + Vector2(0, 9999))
	check(moved.success and is_equal_approx(origin.distance_to(player.position) / 12.0, 5.0), "Movement clamps to 5 ft")
	player.ap = player.max_ap
	var second := system.execute_action(make_request(ranged))
	check(second.success and not second.requires_reaction_choice, "Second Ranged Hit this Turn does not trigger")
	system.turn_system.start_turn(system.combat_state)
	player.ap = player.max_ap
	var next_turn := system.execute_action(make_request(ranged))
	check(next_turn.requires_reaction_choice, "New Turn restores Mobile Shooter")
	for failure in failures:
		push_error(failure)
	print("MOBILE_SHOOTER_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
