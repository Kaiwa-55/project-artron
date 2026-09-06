extends SceneTree

const PassiveAbilities = [
	preload("res://data/ability/killer_instinct.tres"),
	preload("res://data/ability/build_up_body.tres"),
	preload("res://data/ability/human_adapt.tres"),
	preload("res://data/ability/long_reach.tres"),
	preload("res://data/ability/martial_training.tres"),
]


func _init() -> void:
	var ability_system := AbilitySystem.new()
	var passed := true
	for ability in PassiveAbilities:
		passed = passed and ability.is_passive and ability_system.ability_has_trait(ability, "passive")
	print("PASSIVE_TRAIT_TEST: PASS" if passed else "PASSIVE_TRAIT_TEST: FAIL")
	quit(0 if passed else 1)
