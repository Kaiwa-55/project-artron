extends SceneTree

const Meditate := preload("res://data/ability/meditate.tres")
const Catalog := preload("res://data/creation/default_creation_catalog.tres")


func _init() -> void:
	var failures: Array[String] = []
	var actor := CombatantState.new()
	actor.id = "martial"
	actor.display_name = "Martial Artist"
	actor.team = 1
	actor.level = 3
	actor.base_max_hp = 100
	actor.base_max_ap = 4
	actor.active_traits = [load("res://data/trait/martial_artist.tres")]
	actor.available_abilities = [Meditate]
	actor.selected_ability_ids = [Meditate.id]
	actor.equipped_abilities = [Meditate.id]
	var enemy := CombatantState.new()
	enemy.id = "enemy"
	enemy.team = 2
	enemy.base_max_hp = 10
	enemy.base_max_ap = 1
	var system := CombatSystem.new()
	system.start_combat([actor, enemy])
	system.combat_state.current_actor_id = actor.id
	actor.ap = 4
	actor.hp = 40
	var result := system.use_active_ability(actor.id, actor.id, Meditate.id)
	check(result.success, "Meditate resolves", failures)
	check(actor.hp == 70, "Level 3 Meditate restores 30 HP", failures)
	check(actor.ap == 2, "Meditate costs 2 AP", failures)
	check(system.ability_system.get_remaining_cooldown(actor, Meditate.id) == 3, "Meditate starts a three-Turn cooldown", failures)
	check(result.events.any(func(event): return event.type == EventTypes.Type.EFFECT_HEAL_APPLIED and event.data.get("amount", 0) == 30), "Meditate reports healing to UI and Combat Log", failures)
	check(Catalog.abilities.any(func(ability): return ability != null and ability.id == "meditate"), "Meditate is available in Character Creation", failures)
	if failures.is_empty():
		print("MEDITATE_TEST: PASS")
		quit(0)
	for failure in failures:
		push_error(failure)
	quit(1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
