extends SceneTree

const AbilityUseEffectDataScript = preload("res://data/ability/ability_use_effect_data.gd")

func _init() -> void:
	var failures: Array[String] = []
	var actor: CombatantState = load("res://data/character/player.tres").create_combatant_state()
	var ally: CombatantState = load("res://data/character/player.tres").create_combatant_state()
	var enemy: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	actor.id = "actor"; actor.team = 0; actor.position = Vector2.ZERO
	ally.id = "ally"; ally.team = 0; ally.position = Vector2(4, 0)
	enemy.id = "enemy"; enemy.team = 1; enemy.position = Vector2(5, 0)
	var system := CombatSystem.new()
	system.start_combat([actor, ally, enemy])
	system.combat_state.current_actor_id = actor.id
	actor.ap = 20

	var self_effect := make_effect("self_guard", 1)
	var self_ability := make_ability("self_guard_ability", AbilityData.TargetMode.SELF, AbilityData.TargetFilter.ALLIES)
	self_ability.use_effects = [make_use_effect(self_effect, AbilityUseEffectDataScript.Timing.ALWAYS, AbilityUseEffectDataScript.Recipient.CASTER)]
	grant(actor, self_ability)
	check(system.use_active_ability(actor.id, "", self_ability.id).success and actor.has_status(self_effect.id), "Self Ability should apply an ordered self Effect", failures)

	var ally_effect := make_effect("ally_guard", 2)
	var ally_ability := make_ability("ally_guard_ability", AbilityData.TargetMode.SINGLE_COMBATANT, AbilityData.TargetFilter.ALLIES)
	ally_ability.use_effects = [make_use_effect(ally_effect, AbilityUseEffectDataScript.Timing.ALWAYS, AbilityUseEffectDataScript.Recipient.TARGET)]
	grant(actor, ally_ability)
	check(system.use_active_ability(actor.id, ally.id, ally_ability.id).success and ally.has_status(ally_effect.id), "Ally Ability should apply its Effect to an ally", failures)
	check(not system.use_active_ability(actor.id, enemy.id, ally_ability.id).success, "Ally Ability must reject enemies", failures)

	var hit_effect := make_effect("hit_mark", -1)
	var attack := AttackData.new(); attack.id = "certain_attack"; attack.display_name = "Certain Attack"; attack.requires_to_hit = false; attack.base_damage = 0; attack.range_feet = 10
	var attack_ability := make_ability("attack_effect_ability", AbilityData.TargetMode.SINGLE_COMBATANT, AbilityData.TargetFilter.ENEMIES)
	attack_ability.attack_source = AbilityData.AttackSource.CONFIGURED_ATTACK; attack_ability.attack_data = attack
	attack_ability.use_effects = [make_use_effect(hit_effect, AbilityUseEffectDataScript.Timing.ON_HIT, AbilityUseEffectDataScript.Recipient.TARGET)]
	grant(actor, attack_ability)
	check(system.use_active_ability(actor.id, enemy.id, attack_ability.id).success and enemy.has_status(hit_effect.id), "Attack Ability should apply On Hit target Effects", failures)

	if failures.is_empty(): print("ACTIVE_ABILITY_EXECUTOR_TEST: PASS"); quit(0)
	for failure in failures: push_error(failure)
	quit(1)


func make_ability(id: String, mode: int, filter: int) -> AbilityData:
	var ability := AbilityData.new(); ability.id = id; ability.display_name = id; ability.ap_cost = 1; ability.target_mode = mode; ability.target_filter = filter
	return ability


func make_effect(id: String, reflex: int) -> EffectData:
	var effect := EffectData.new(); effect.id = id; effect.display_name = id; effect.reflex_bonus = reflex
	return effect


func make_use_effect(effect: EffectData, timing: int, recipient: int):
	var entry = AbilityUseEffectDataScript.new(); entry.effect = effect; entry.timing = timing; entry.recipient = recipient
	return entry


func grant(actor: CombatantState, ability: AbilityData) -> void:
	actor.available_abilities.append(ability); actor.equipped_abilities.append(ability.id)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition: failures.append(message)
