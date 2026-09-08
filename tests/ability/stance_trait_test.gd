extends SceneTree

const StanceTrait := preload("res://data/trait/stance.tres")


func _init() -> void:
	var failures: Array[String] = []
	var actor := CombatantState.new()
	actor.id = "stance_tester"
	actor.level = 5
	actor.ap = 4

	var first_stance := make_stance("first_stance", "First Stance")
	var second_stance := make_stance("second_stance", "Second Stance")
	actor.available_abilities.assign([first_stance, second_stance])
	actor.equipped_abilities.assign([first_stance.id, second_stance.id])

	var ability_system := AbilitySystem.new()
	var effect_system := EffectSystem.new()
	var stance_effect := EffectData.new()
	stance_effect.id = "first_stance_effect"
	stance_effect.display_name = "First Stance"
	stance_effect.duration_turns = 1
	stance_effect.expire_at_start_of_turn = true
	effect_system.apply_effect(actor, stance_effect, first_stance.id, first_stance.display_name, true)

	check(ability_system.validate_active_use(actor, first_stance, actor).success, "The currently active Stance may be refreshed", failures)
	var blocked := ability_system.validate_active_use(actor, second_stance, actor)
	check(not blocked.success and blocked.failure_reason.contains("First Stance"), "A second Stance is blocked while another Stance is active", failures)
	effect_system.expire_start_turn_effects(actor)
	check(ability_system.validate_active_use(actor, second_stance, actor).success, "A new Stance may be used after the previous Stance expires", failures)
	check(StanceTrait.id == "stance" and not StanceTrait.description.is_empty(), "Stance is available as a documented shared Trait", failures)

	if failures.is_empty():
		print("STANCE_TRAIT_TEST: PASS")
		quit(0)
	for failure in failures:
		push_error(failure)
	quit(1)


func make_stance(id: String, display_name: String) -> AbilityData:
	var ability := AbilityData.new()
	ability.id = id
	ability.display_name = display_name
	ability.target_mode = AbilityData.TargetMode.SELF
	ability.traits = [StanceTrait]
	return ability


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
