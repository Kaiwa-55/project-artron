extends SceneTree

const LightFootwork := preload("res://data/ability/light_footwork.tres")
const SlowedFive := preload("res://data/status/elemental_slowed_5.tres")


func _init() -> void:
	var failures: Array[String] = []
	var actor := CombatantState.new()
	actor.speed = 20.0
	actor.level = 1
	actor.available_abilities = [LightFootwork]
	actor.equipped_abilities = [LightFootwork.id]

	check(LightFootwork.is_passive and LightFootwork.required_trait_ids.has("martial_artist"), "Light-footwork is a Level 1 Martial Artist Passive", failures)
	check(is_equal_approx(actor.get_effective_speed(), 25.0), "Light-footwork increases effective Speed by 5 ft", failures)
	actor.add_effect(SlowedFive)
	check(is_equal_approx(actor.get_effective_speed(), 20.0), "Light-footwork combines correctly with Slowed 5 ft", failures)
	actor.equipped_abilities.clear()
	check(is_equal_approx(actor.get_effective_speed(), 15.0), "The Speed bonus is removed when the Passive is not active", failures)

	if failures.is_empty():
		print("LIGHT_FOOTWORK_TEST: PASS")
		quit(0)
	for failure in failures:
		push_error(failure)
	quit(1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
