extends SceneTree

const Warrior = preload("res://data/class/warrior.tres")
const Pursuit = preload("res://data/ability/relentless_pursuit.tres")
const Sword = preload("res://data/attack/sword.tres")

var failures: Array[String] = []


func _init() -> void:
	var data: CharacterData = load("res://data/character/player.tres").duplicate()
	data.character_class = Warrior
	data.level = 2
	var actor: CombatantState = data.create_combatant_state()
	actor.position = Vector2.ZERO
	actor.available_abilities.append(Pursuit)
	actor.equipped_abilities.append(Pursuit.id)
	var enemy: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	enemy.position = Vector2(60, 0)
	enemy.hp = 1
	var second: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	second.id = "second_enemy"
	second.position = Vector2(240, 0)
	var system := CombatSystem.new()
	system.start_combat([actor, enemy, second])
	system.combat_state.current_actor_id = actor.id
	actor.ap = 10
	check(system.use_active_ability(actor.id, actor.id, "assault_stance").success, "Assault Stance activates")
	var attack: AttackData = Sword.duplicate()
	attack.to_hit_bonus = 1000
	attack.base_damage = 100
	attack.ap_cost = 1
	var request := ActionRequest.new(actor.id, ActionTypes.Type.ATTACK)
	request.target_id = enemy.id
	request.attack_data = attack
	var result: ActionResult = system.execute_action(request)
	check(result.success and enemy.is_dying(), "Attack defeats the target")
	check(system.has_pending_step_back_move() and system.reaction_resolver.move_distance_feet == 5.0, "Defeating a target offers the 5 ft pursuit move")
	check(actor.ability_uses_this_turn.get(Pursuit.id, 0) == 1, "Pursuit is consumed once this turn")
	if system.has_pending_step_back_move():
		var start: Vector2 = actor.position
		var move_result: ActionResult = system.execute_step_back_move(start + Vector2(-60, 0))
		check(move_result.success and is_equal_approx(start.distance_to(actor.position) / system.map_rules.world_units_per_foot, 5.0), "Pursuit movement resolves at 5 ft")
	second.life_state = CombatEnums.LifeState.DYING
	actor.ability_uses_this_turn.erase(Pursuit.id)
	system.offer_on_kill_movement(actor, enemy, ActionResult.success_result())
	check(not system.has_pending_step_back_move(), "Pursuit does not leave a pending move after the last enemy falls")
	for failure in failures:
		push_error(failure)
	print("WARRIOR_ASSAULT_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
