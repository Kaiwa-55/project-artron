extends SceneTree

const AbilityUseEffectDataScript = preload("res://data/ability/ability_use_effect_data.gd")

func _init() -> void:
	var failures: Array[String] = []
	var actor: CombatantState = load("res://data/character/player.tres").create_combatant_state()
	var enemy_a: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	var enemy_b: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	actor.position = Vector2(100, 100)
	enemy_a.position = Vector2(220, 100)
	enemy_b.id = "enemy_b"; enemy_b.position = Vector2(260, 100)
	enemy_a.active_reactions.clear(); enemy_b.active_reactions.clear()
	var ability := AbilityData.new()
	ability.id = "ground_ability_test"; ability.display_name = "Ground Ability Test"
	ability.ap_cost = 2; ability.cooldown_turns = 1
	ability.target_mode = AbilityData.TargetMode.GROUND
	ability.target_filter = AbilityData.TargetFilter.ENEMIES
	ability.area_shape = AbilityData.AreaShape.CIRCLE
	ability.targeting_range_feet = 20.0; ability.area_radius_feet = 8.0
	ability.attack_source = AbilityData.AttackSource.CONFIGURED_ATTACK
	ability.animation_template = load("res://animation/lunge_return.tres")
	var attack := AttackData.new(); attack.id = "ground_ability_attack"; attack.display_name = "Ground Ability Attack"; attack.requires_to_hit = false; attack.base_damage = 0
	ability.attack_data = attack
	var mark := EffectData.new(); mark.id = "ground_ability_mark"; mark.display_name = "Ground Ability Mark"
	var entry = AbilityUseEffectDataScript.new(); entry.timing = AbilityUseEffectDataScript.Timing.ON_HIT; entry.recipient = AbilityUseEffectDataScript.Recipient.TARGET; entry.effect = mark
	ability.use_effects = [entry]
	actor.available_abilities.append(ability); actor.equipped_abilities.append(ability.id)
	var system := CombatSystem.new(); system.start_combat([actor, enemy_a, enemy_b]); system.combat_state.current_actor_id = actor.id; actor.ap = 10
	check(system.validate_ground_ability_start(actor.id, ability.id).success, "Available Area Ability should enter shared targeting mode", failures)
	var ap_before := actor.ap
	var result := system.execute_ground_ability(actor.id, ability.id, Vector2(235, 100))
	check(result.success, "Ground Ability should resolve through the shared Area executor", failures)
	check(actor.ap == ap_before - ability.ap_cost, "Ground Ability should spend AP once", failures)
	check(system.ability_system.get_remaining_cooldown(actor, ability.id) == 1, "Ground Ability should start Ability cooldown once", failures)
	check(enemy_a.has_status(mark.id) and enemy_b.has_status(mark.id), "On Hit Effect should resolve separately for every Area target", failures)
	var ability_events := result.events.filter(func(event): return event.type == EventTypes.Type.ABILITY_TRIGGERED)
	check(ability_events.size() == 1 and ability_events[0].data.get("area_target_count", 0) == 2, "Area Ability should produce one summary event", failures)
	var attack_events := result.events.filter(func(event): return event.type in [EventTypes.Type.ATTACK_HIT, EventTypes.Type.ATTACK_MISS])
	check(attack_events.size() == 2 and attack_events.all(func(event): return event.data.get("animation_template") == ability.animation_template), "Area Ability animation should be attached to every resolved target", failures)
	check(not system.execute_ground_ability(actor.id, ability.id, Vector2(235, 100)).success, "Ground Ability should respect shared cooldown", failures)
	check(system.validate_ground_ability_start(actor.id, ability.id).failure_reason.contains("cooldown"), "Ability targeting should explain active Cooldown", failures)

	if failures.is_empty(): print("GROUND_ABILITY_TEST: PASS"); quit(0)
	for failure in failures: push_error(failure)
	quit(1)

func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition: failures.append(message)
