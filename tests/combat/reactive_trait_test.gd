extends SceneTree

const Parry = preload("res://data/reaction/parry.tres")
const MartialSense = preload("res://data/reaction/martial_sense.tres")
const OpportunityAttack = preload("res://data/reaction/opportunity_attack.tres")
const StepBack = preload("res://data/ability/step_back.tres")
const ReactionEffectDataScript = preload("res://data/reaction/reaction_effect_data.gd")


func _init() -> void:
	var reaction_system = ReactionSystem.new(null, null, null)
	var ability_system = AbilitySystem.new()
	var passed: bool = reaction_system.reaction_has_trait(Parry, "reactive") \
		and reaction_system.reaction_has_trait(MartialSense, "reactive") \
		and reaction_system.reaction_has_trait(OpportunityAttack, "reactive") \
		and ability_system.ability_has_trait(StepBack, "reactive") \
		and ability_system.ability_has_trait(StepBack, "basic") \
		and ability_system.ability_has_trait(StepBack, "move") \
		and reaction_system.get_effect(Parry, ReactionEffectDataScript.Type.DEFENSE_BONUS) != null \
		and reaction_system.get_effect(MartialSense, ReactionEffectDataScript.Type.TURN_HIT_TO_MISS) != null \
		and reaction_system.get_effect(OpportunityAttack, ReactionEffectDataScript.Type.ATTACK) != null \
		and not StepBack.granted_reactions.is_empty() \
		and reaction_system.get_effect(StepBack.granted_reactions[0], ReactionEffectDataScript.Type.MOVEMENT) != null
	print("REACTIVE_TRAIT_TEST: PASS" if passed else "REACTIVE_TRAIT_TEST: FAIL")
	quit(0 if passed else 1)
