extends SceneTree

const Bleeding := preload("res://data/status/bleeding.tres")
const Burning := preload("res://data/status/burning.tres")
const Slowed := preload("res://data/status/slowed.tres")
const BloodClaw := preload("res://data/attack/blood_claw_attack.tres")
const FlameWave := preload("res://data/attack/flame_wave.tres")
const FrostShard := preload("res://data/attack/frost_shard.tres")
const GoblinStone := preload("res://data/attack/goblin_crippling_stone.tres")
const CoilingSweep := preload("res://data/attack/coiling_sweep_attack.tres")


func _init() -> void:
	var failures: Array[String] = []
	var effects := EffectSystem.new()
	var target := CombatantState.new()
	target.max_hp = 20
	target.hp = 20
	effects.apply_effect(target, BloodClaw.get_effects_on_hit()[0])
	check(target.effects.size() == 1 and target.effects[0].data.id == "bleeding" and target.effects[0].stack_count == 5, "Blood Claw applies one Bleeding status with five stacks", failures)
	check(Bleeding.stacks_on_apply == 1, "Blood Claw does not change the shared Bleeding resource", failures)
	target.effects.clear()
	effects.apply_effect(target, FlameWave.get_effects_on_hit()[0])
	check(target.effects.size() == 1 and target.effects[0].data.id == "burning" and target.effects[0].stack_count == 2, "Flame Wave applies Burning with two stacks", failures)
	var hp_before := target.hp
	effects.resolve_effects(target, EffectData.Trigger.START_OF_TURN)
	check(target.hp == hp_before - 2 and Burning.stacks_on_apply == 1, "Burning two stacks deal two damage without changing the shared resource", failures)
	target.effects.clear()
	for entry in [[FrostShard, 1, 6], [GoblinStone, 1, 1], [CoilingSweep, 5, 1]]:
		var attack: AttackData = entry[0]
		effects.apply_effect(target, attack.get_effects_on_hit()[0])
		check(target.effects.size() == 1 and target.effects[0].data.id == "slowed" and target.effects[0].stack_count == entry[1] and target.effects[0].remaining_turns == entry[2], "%s uses shared Slowed with its configured stacks and duration" % attack.display_name, failures)
		target.effects.clear()
	check(Slowed.stacks_on_apply == 5 and Slowed.duration_turns == 6, "Attack settings do not change the shared Slowed resource", failures)
	for failure in failures:
		push_error(failure)
	print("STATUS_VARIANT_CONSOLIDATION_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
