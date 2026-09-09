extends SceneTree

const KeyStrike := preload("res://data/ability/key_strike.tres")
const Catalog := preload("res://data/creation/default_creation_catalog.tres")


func _init() -> void:
	var failures: Array[String] = []
	var system := CombatSystem.new()
	var actor := make_actor("martial", 1)
	var target := make_actor("target", 2)
	actor.strength = 16
	var key_strike = KeyStrike.duplicate(true)
	key_strike.attack_data = KeyStrike.attack_data.duplicate(true)
	key_strike.attack_data.requires_to_hit = false
	actor.available_abilities.append(key_strike)
	actor.selected_ability_ids.append(key_strike.id)
	actor.equipped_abilities.append(key_strike.id)
	system.start_combat([actor, target])
	system.combat_state.current_actor_id = actor.id
	actor.ap = 4
	var result := system.use_active_ability(actor.id, target.id, key_strike.id)
	check(result.success, "Key Strike resolves", failures)
	var slowed := target.effects.filter(func(instance): return instance.data.id == "slowed")
	check(slowed.size() == 1 and slowed[0].stack_count == 3, "Key Strike applies Slowed equal to STR modifier", failures)
	check(actor.ap == 3, "Key Strike costs 1 AP", failures)
	check(system.ability_system.get_remaining_cooldown(actor, key_strike.id) == 2, "Key Strike starts a two-Turn cooldown", failures)
	check(Catalog.abilities.any(func(ability): return ability != null and ability.id == "key_strike"), "Key Strike is available in Character Creation", failures)
	if failures.is_empty():
		print("KEY_STRIKE_TEST: PASS")
		quit(0)
	for failure in failures:
		push_error(failure)
	quit(1)


func make_actor(id: String, team: int) -> CombatantState:
	var actor := CombatantState.new()
	actor.id = id
	actor.display_name = id.capitalize()
	actor.team = team
	actor.level = 2
	actor.base_max_hp = 20
	actor.base_max_ap = 4
	actor.base_speed = 30
	actor.unarmed_attack = load("res://data/attack/unarmed_attack.tres")
	actor.active_traits = [load("res://data/trait/martial_artist.tres")]
	return actor


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
