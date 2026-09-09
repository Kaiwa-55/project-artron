extends SceneTree

const BeatDown := preload("res://data/ability/beat_down.tres")
const Catalog := preload("res://data/creation/default_creation_catalog.tres")


func _init() -> void:
	var failures: Array[String] = []
	var system := CombatSystem.new()
	var actor := make_actor("martial", 1)
	var target := make_actor("target", 2)
	var beat_down = BeatDown.duplicate(true)
	beat_down.attack_data = BeatDown.attack_data.duplicate(true)
	beat_down.attack_data.requires_to_hit = true
	actor.available_abilities.append(beat_down)
	actor.selected_ability_ids.append(beat_down.id)
	actor.equipped_abilities.append(beat_down.id)
	system.start_combat([actor, target])
	system.combat_state.current_actor_id = actor.id
	actor.ap = 4
	var result := system.use_active_ability(actor.id, target.id, beat_down.id)
	check(result.success, "Beat Down resolves", failures)
	var attacks := result.events.filter(func(event): return event.type == EventTypes.Type.ATTACK_HIT or event.type == EventTypes.Type.ATTACK_MISS)
	check(attacks.size() == 5, "Beat Down resolves five separate Attacks", failures)
	var penalties: Array[int] = []
	for event in attacks:
		penalties.append(int(event.data.get("repeated_attack_penalty", 0)))
	check(penalties == [0, -2, -4, -4, -4], "Every Beat Down Attack receives sequential RAP", failures)
	check(actor.attacks_declared_this_turn == 5, "Every Beat Down Attack counts as declared", failures)
	check(actor.ap == 1, "Beat Down costs 3 AP once", failures)
	check(system.ability_system.get_remaining_cooldown(actor, beat_down.id) == 2, "Beat Down starts a two-Turn cooldown", failures)
	check(Catalog.abilities.any(func(ability): return ability != null and ability.id == "beat_down"), "Beat Down is available in Character Creation", failures)
	var blocked_actor := make_actor("blocked", 1)
	blocked_actor.starting_equipment = [load("res://data/equipment/dagger.tres"), load("res://data/equipment/dagger_offhand.tres")]
	blocked_actor.starting_equipment_slots = {"dagger": EquipmentSystem.WEAPON_SLOT_1, "dagger_offhand": EquipmentSystem.WEAPON_SLOT_2}
	blocked_actor.available_abilities.append(beat_down)
	blocked_actor.selected_ability_ids.append(beat_down.id)
	blocked_actor.equipped_abilities.append(beat_down.id)
	var blocked_system := CombatSystem.new()
	var blocked_target := make_actor("blocked_target", 2)
	blocked_system.start_combat([blocked_actor, blocked_target])
	blocked_system.combat_state.current_actor_id = blocked_actor.id
	blocked_actor.ap = 4
	var blocked := blocked_system.use_active_ability(blocked_actor.id, blocked_target.id, beat_down.id)
	check(not blocked.success and blocked_actor.ap == 4, "Beat Down requires a free hand before spending AP", failures)
	if failures.is_empty():
		print("BEAT_DOWN_TEST: PASS")
		quit(0)
	for failure in failures:
		push_error(failure)
	quit(1)


func make_actor(id: String, team: int) -> CombatantState:
	var actor := CombatantState.new()
	actor.id = id
	actor.display_name = id.capitalize()
	actor.team = team
	actor.level = 3
	actor.base_max_hp = 200
	actor.base_max_ap = 4
	actor.base_speed = 30
	actor.position = Vector2.ZERO if team == 1 else Vector2(120, 0)
	actor.unarmed_attack = load("res://data/attack/unarmed_attack.tres")
	actor.active_traits = [load("res://data/trait/martial_artist.tres")]
	return actor


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
