extends SceneTree

const Warrior = preload("res://data/class/warrior.tres")
const Sweep = preload("res://data/ability/sweeping_assault.tres")
const Pursuit = preload("res://data/ability/relentless_pursuit.tres")

var failures: Array[String] = []


func _init() -> void:
	var data: CharacterData = load("res://data/character/player.tres").duplicate()
	data.character_class = Warrior
	data.level = 3
	var actor: CombatantState = data.create_combatant_state()
	actor.position = Vector2.ZERO
	actor.available_abilities.append(Sweep)
	actor.equipped_abilities.append(Sweep.id)
	actor.available_abilities.append(Pursuit)
	actor.equipped_abilities.append(Pursuit.id)
	var enemies: Array[CombatantState] = []
	for index in range(3):
		var enemy: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
		enemy.id = "enemy_%d" % index
		enemy.position = [Vector2(60, 0), Vector2(-60, 0), Vector2(0, 60)][index]
		enemy.active_reactions.clear()
		enemies.append(enemy)
	enemies[0].hp = 1
	var system := CombatSystem.new()
	system.start_combat([actor, enemies[0], enemies[1], enemies[2]])
	actor.equipped_weapon_attack = actor.equipped_weapon_attack.duplicate()
	actor.equipped_weapon_attack.to_hit_bonus = 1000
	actor.equipped_weapon_attack.base_damage = 100
	system.combat_state.current_actor_id = actor.id
	actor.ap = 10
	check(system.use_active_ability(actor.id, actor.id, "assault_stance").success, "Assault Stance activates")
	var ap_before: int = actor.ap
	var result: ActionResult = system.use_active_ability(actor.id, actor.id, Sweep.id)
	check(result.success and actor.ap == ap_before - 2, "Sweeping Assault costs 2 AP")
	check(result.events.any(func(event): return event.type == EventTypes.Type.ABILITY_TRIGGERED and event.data.get("ability_name") == "Sweeping Assault" and event.data.get("area_resolved_count") == 2), "Sweeping Assault resolves against at most two targets")
	check(system.ability_system.get_remaining_cooldown(actor, Sweep.id) == 2, "Sweeping Assault starts a two turn cooldown")
	check(system.has_pending_step_back_move() and system.reaction_resolver.move_distance_feet == 5.0, "A Sweeping Assault kill can trigger Relentless Pursuit")
	for failure in failures:
		push_error(failure)
	print("WARRIOR_SWEEP_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
