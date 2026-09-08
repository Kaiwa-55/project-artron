extends SceneTree

const Bleeding = preload("res://data/status/bleeding.tres")
const Burning = preload("res://data/status/burning.tres")
const Poisoned = preload("res://data/status/poisoned.tres")
const Slowed = preload("res://data/status/slowed.tres")
const Rooted = preload("res://data/status/rooted.tres")
const Dazed = preload("res://data/status/dazed.tres")
const Stunned = preload("res://data/status/stunned.tres")
const Silenced = preload("res://data/status/silenced.tres")
const Frightened = preload("res://data/status/frightened.tres")
const Weakened = preload("res://data/status/weakened.tres")
const Surprise = preload("res://data/status/surprise.tres")
const Parry = preload("res://data/reaction/parry.tres")

var failures: Array[String] = []


func _init() -> void:
	var effects := EffectSystem.new()
	var actor := make_actor()
	var bleeding = Bleeding.duplicate()
	bleeding.duration_turns = 3
	for index in range(3): effects.apply_effect(actor, bleeding)
	check(actor.effects[0].stack_count == 3, "Bleeding should stack")
	var hp_before := actor.hp
	effects.resolve_effects(actor, EffectData.Trigger.END_OF_TURN)
	check(actor.hp == hp_before - 3, "Bleeding should deal damage equal to Stack")
	effects.decay_end_turn_stacks(actor)
	check(actor.effects[0].stack_count == 1, "Bleeding should lose positive CON modifier stacks")
	actor.effects.clear()
	actor.constitution = 10
	for index in range(2): effects.apply_effect(actor, bleeding)
	effects.decay_end_turn_stacks(actor)
	check(actor.effects[0].stack_count == 1, "Bleeding should lose at least 1 Stack when CON modifier is zero")
	actor.constitution = 14

	actor.effects.clear()
	var slowed = Slowed.duplicate()
	slowed.duration_turns = 3
	slowed.stacks_on_apply = 1
	for index in range(3): effects.apply_effect(actor, slowed)
	check(is_equal_approx(actor.get_effective_speed(), 15.0), "Slowed should reduce Speed by 5 ft per Stack")
	var zero_speed_actor := make_actor()
	zero_speed_actor.movement_in_progress = true
	zero_speed_actor.movement_remaining_feet = 10.0
	var zero_speed_slow := Slowed.duplicate(true)
	zero_speed_slow.stacks_on_apply = 10
	effects.apply_effect(zero_speed_actor, zero_speed_slow)
	check(is_zero_approx(zero_speed_actor.get_effective_speed()), "Slowed can reduce Speed to zero")
	var zero_speed_movement_system := MovementSystem.new()
	check(is_zero_approx(zero_speed_movement_system.get_available_distance_feet(zero_speed_actor)), "No movement remains while Slowed reduces Speed to zero")
	check(not zero_speed_movement_system.validate_move(zero_speed_actor, zero_speed_actor.position + Vector2.ONE, MovementData.new()).success, "Move validation rejects a character whose current Speed is zero")
	effects.decay_end_turn_stacks(actor)
	check(is_equal_approx(actor.get_effective_speed(), 25.0), "Slowed should decay by CON modifier")
	actor.effects.clear()
	actor.constitution = 10
	for index in range(2): effects.apply_effect(actor, slowed)
	effects.decay_end_turn_stacks(actor)
	check(actor.effects[0].stack_count == 1, "Slowed should lose at least 1 Stack when CON modifier is zero")
	actor.constitution = 14

	actor.effects.clear()
	var weak_burn = Burning.duplicate()
	weak_burn.potency = 2
	weak_burn.amount = 2
	var strong_burn = Burning.duplicate()
	strong_burn.potency = 4
	strong_burn.amount = 4
	effects.apply_effect(actor, weak_burn)
	effects.apply_effect(actor, strong_burn)
	effects.apply_effect(actor, weak_burn)
	check(actor.effects[0].data.potency == 4, "Burning should retain the stronger Potency")
	hp_before = actor.hp
	effects.resolve_effects(actor, EffectData.Trigger.START_OF_TURN)
	check(actor.hp == hp_before - 4, "Burning should deal its configured Fire damage")

	actor.effects.clear()
	effects.apply_effect(actor, Poisoned)
	effects.apply_effect(actor, Dazed)
	check(effects.get_max_ap_penalty(actor) == 2, "Poisoned and Dazed should each reduce next-turn Maximum AP by 1")
	check(effects.get_fortitude_bonus(actor) == -2 and effects.get_reflex_bonus(actor) == -2, "Poisoned and Dazed should reduce their defenses")

	actor.effects.clear()
	var strong_stun = Stunned.duplicate()
	strong_stun.potency = 3
	strong_stun.ap_penalty_per_stack = 3
	effects.apply_effect(actor, strong_stun)
	effects.apply_effect(actor, Stunned)
	check(effects.get_max_ap_penalty(actor) == 3, "Stunned should retain the stronger AP penalty")

	actor.effects.clear()
	for index in range(3): effects.apply_effect(actor, Frightened)
	check(effects.get_attack_bonus(actor) == -3 and effects.get_will_bonus(actor) == -3, "Frightened penalties should equal Stack")
	effects.decay_end_turn_stacks(actor)
	check(actor.effects[0].stack_count == 2, "Frightened should lose 1 Stack at End Turn")

	actor.effects.clear()
	var strong_weakened = Weakened.duplicate()
	strong_weakened.potency = 3
	strong_weakened.reflex_bonus = -3
	strong_weakened.fortitude_bonus = -3
	strong_weakened.will_bonus = -3
	effects.apply_effect(actor, strong_weakened)
	effects.apply_effect(actor, Weakened)
	check(effects.get_reflex_bonus(actor) == -3 and effects.get_fortitude_bonus(actor) == -3 and effects.get_will_bonus(actor) == -3, "Weakened should retain the stronger all-Defense penalty")

	actor.effects.clear()
	effects.apply_effect(actor, Rooted)
	var movement_system := MovementSystem.new()
	var movement := MovementData.new()
	movement.ap_cost = 1
	check(not movement_system.validate_move(actor, actor.position + Vector2(10, 0), movement).success, "Rooted should prevent Move")

	actor.effects.clear()
	effects.apply_effect(actor, Silenced)
	var mana_skill := SkillData.new()
	mana_skill.mana_cost = 1
	check(not SkillSystem.new().validate_skill(actor, actor, mana_skill, null).success, "Silenced should prevent Mana Skills")

	actor.effects.clear()
	effects.apply_effect(actor, Surprise)
	actor.id = "player"
	actor.team = 1
	actor.active_reactions = [Parry]
	var enemy := make_actor()
	enemy.id = "enemy"
	enemy.team = 2
	var reaction_system := ReactionSystem.new(null, null, null)
	var prepared := AttackResult.new()
	prepared.hit = true
	check(reaction_system.get_post_hit_prompt(enemy, actor, AttackData.new(), prepared).is_empty(), "Surprise should prevent Reactive Reactions")

	if failures.is_empty():
		print("STATUS_SYSTEM_TEST: PASS")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		print("STATUS_SYSTEM_TEST: FAIL (%d)" % failures.size())
		quit(1)


func make_actor() -> CombatantState:
	var actor := CombatantState.new()
	actor.constitution = 14
	actor.speed = 30.0
	actor.max_hp = 100
	actor.hp = 100
	actor.max_ap = 4
	actor.ap = 4
	return actor


func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
