extends SceneTree

const EmberBolt := preload("res://data/skill/ember_bolt.tres")
const FlameWave := preload("res://data/skill/flame_wave.tres")
const FrostShard := preload("res://data/skill/frost_shard.tres")
const FrozenGround := preload("res://data/skill/frozen_ground.tres")


func _init() -> void:
	var failures: Array[String] = []
	var skills: Array = [EmberBolt, FlameWave, FrostShard, FrozenGround]
	for skill in skills:
		check(skill.mana_cost == skill.spell_level, "%s Mana Cost must equal Spell Level" % skill.display_name, failures)
		check(has_trait(skill, "elemental"), "%s must have the Elemental Trait" % skill.display_name, failures)

	check(EmberBolt.attack_data.base_damage == 4 and has_trait(EmberBolt, "fire") and has_trait(EmberBolt, "ranged"), "Ember Bolt data matches its Fire ranged design", failures)
	check(FlameWave.area_shape == SkillData.AreaShape.CONE and FlameWave.targeting_range_feet == 15.0 and FlameWave.cone_angle_degrees == 90.0, "Flame Wave uses the expected cone", failures)
	check(FrostShard.attack_data.base_damage == 3 and FrostShard.attack_data.effects_on_hit[0].id == "slowed" and FrostShard.attack_data.effects_on_hit[0].stacks_on_apply == 1, "Frost Shard applies one 5-foot Slowed Stack on Hit", failures)
	check(FrozenGround.area_shape == SkillData.AreaShape.CIRCLE and FrozenGround.area_radius_feet == 10.0, "Frozen Ground uses the expected circle", failures)
	check(FrozenGround.attack_data.effects_on_hit[0].id == "rooted" and FrozenGround.attack_data.effects_on_miss[0].id == "slowed", "Frozen Ground applies Rooted on Hit and Slowed on Miss", failures)

	var catalog = load("res://data/creation/default_creation_catalog.tres")
	for training_id in ["spell_training_ember_bolt", "spell_training_flame_wave", "spell_training_frost_shard", "spell_training_frozen_ground"]:
		check(catalog.find_ability(training_id) != null, "%s is available in the Spell catalog" % training_id, failures)

	if failures.is_empty():
		print("ELEMENTAL_SPELL_TEST: PASS")
		quit(0)
	for failure in failures:
		push_error(failure)
	quit(1)


func has_trait(skill, trait_id: String) -> bool:
	return skill.traits.any(func(trait_data): return trait_data != null and trait_data.id == trait_id)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
