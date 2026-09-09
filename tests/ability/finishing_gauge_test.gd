extends SceneTree

const MartialArtist := preload("res://data/class/martial_artist.tres")
const MartialArtistTrait := preload("res://data/trait/martial_artist.tres")


func _init() -> void:
	var failures: Array[String] = []
	var actor := make_actor("martial", 1, true)
	var target := make_actor("target", 2, false)
	var system := CombatSystem.new()
	system.start_combat([actor, target])
	check(actor.max_finishing_gauge == 10 and actor.finishing_gauge == 0, "Martial Artist starts Combat with an empty 0/10 Finishing Gauge", failures)

	var attack := AttackData.new()
	attack.id = "gauge_test_attack"
	attack.display_name = "Gauge Test Attack"
	attack.ap_cost = 0
	attack.base_damage = 0
	attack.to_hit_bonus = -1000
	var miss := system.attack_system.resolve_attack(actor, target, attack)
	check(not miss.hit and actor.finishing_gauge == 0, "A missed Attack does not gain Finishing Gauge", failures)

	attack.to_hit_bonus = 1000
	var hit := system.attack_system.resolve_attack(actor, target, attack)
	check(hit.hit and hit.finishing_gauge_gained == 1 and actor.finishing_gauge == 1, "A hit gains exactly 1 Finishing Gauge", failures)
	actor.finishing_gauge = 0
	system.combat_state.current_actor_id = actor.id
	var request := ActionRequest.new(actor.id, ActionTypes.Type.ATTACK)
	request.target_id = target.id
	request.attack_data = attack
	var action_hit := system.execute_action(request)
	var hit_event = action_hit.events.filter(func(event): return event.type == EventTypes.Type.ATTACK_HIT).front()
	check(action_hit.success and actor.finishing_gauge == 1, "The real Combat action pipeline gains the Gauge once per hit", failures)
	check(hit_event.data.get("finishing_gauge_gained", 0) == 1 and hit_event.data.get("finishing_gauge", 0) == 1, "The hit event exposes the updated Finishing Gauge to the UI", failures)

	actor.finishing_gauge = 9
	system.attack_system.resolve_attack(actor, target, attack)
	var capped_hit := system.attack_system.resolve_attack(actor, target, attack)
	check(actor.finishing_gauge == 10 and capped_hit.finishing_gauge_gained == 0, "Finishing Gauge cannot exceed 10", failures)

	var non_martial := make_actor("other", 1, false)
	non_martial.max_finishing_gauge = 10
	system.attack_system.resolve_attack(non_martial, target, attack)
	check(non_martial.finishing_gauge == 0, "A non-Martial Artist does not gain Finishing Gauge", failures)

	for failure in failures:
		push_error(failure)
	print("FINISHING_GAUGE_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func make_actor(actor_id: String, team: int, martial_artist: bool) -> CombatantState:
	var actor := CombatantState.new()
	actor.id = actor_id
	actor.display_name = actor_id.capitalize()
	actor.team = team
	actor.base_max_hp = 100
	actor.base_max_ap = 4
	actor.position = Vector2.ZERO
	if martial_artist:
		actor.active_traits = [MartialArtistTrait]
		actor.set_meta("class_data", MartialArtist)
	return actor


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
