extends SceneTree

const PlayerTemplate := preload("res://data/character/player.tres")
const EnemyTemplate := preload("res://data/character/enemy.tres")
const Devotee := preload("res://data/class/devotee.tres")
const Bless := preload("res://data/ability/bless.tres")
const Catalog := preload("res://data/creation/default_creation_catalog.tres")


func _init() -> void:
	var failures: Array[String] = []
	var character = PlayerTemplate.duplicate(true)
	character.character_class = Devotee
	character.level = 1
	character.class_attribute_choices.assign([AttributeTypes.Type.CONSTITUTION])
	var devotee: CombatantState = character.create_combatant_state()
	var ally: CombatantState = PlayerTemplate.create_combatant_state()
	var far_ally: CombatantState = PlayerTemplate.create_combatant_state()
	var enemy: CombatantState = EnemyTemplate.create_combatant_state()
	devotee.id = "devotee"; devotee.team = 0
	ally.id = "ally"; ally.team = 0
	far_ally.id = "far_ally"; far_ally.team = 0
	enemy.id = "enemy"; enemy.team = 1

	var system := CombatSystem.new()
	system.start_combat([devotee, ally, far_ally, enemy])
	system.combat_state.current_actor_id = devotee.id
	devotee.position = Vector2.ZERO
	ally.position = Vector2(60, 0)
	far_ally.position = Vector2(300, 0)
	enemy.position = Vector2(60, 0)
	devotee.ap = 3

	check(devotee.granted_ability_ids.has("bless") and devotee.equipped_abilities.has("bless"), "Level 1 Devotee receives and equips Bless", failures)
	var result := system.use_active_ability(devotee.id, ally.id, Bless.id)
	check(result.success, "Bless can target an ally within 10 feet", failures)
	check(devotee.ap == 2, "Bless costs 1 AP", failures)
	var aura = devotee.effects.filter(func(instance): return instance != null and instance.data != null and instance.data.id == "bless_aura").front()
	check(aura != null and aura.remaining_turns == 5, "Bless creates a five-turn Aura stance on the Devotee", failures)
	check(system.ability_system.get_aura_attack_bonus(devotee) == 1, "Bless includes its source", failures)
	check(system.ability_system.get_aura_attack_bonus(ally) == 1, "An ally inside the Aura gains +1 To Hit", failures)
	check(system.ability_system.get_aura_attack_bonus(far_ally) == 0, "An ally outside the Aura gains no bonus", failures)
	check(system.ability_system.get_aura_attack_bonus(enemy) == 0, "Enemies gain no bonus from Bless", failures)
	var ap_before_reuse: int = devotee.ap
	var duration_before_reuse: int = aura.remaining_turns
	var reused := system.use_active_ability(devotee.id, ally.id, Bless.id)
	check(not reused.success, "Bless cannot be declared again while its Aura is active", failures)
	check(devotee.ap == ap_before_reuse and aura.remaining_turns == duration_before_reuse, "Rejected Bless reuse does not spend AP or refresh duration", failures)

	ally.position = Vector2(300, 0)
	check(system.ability_system.get_aura_attack_bonus(ally) == 0, "The bonus is removed immediately after leaving the Aura", failures)
	ally.position = Vector2(60, 0)
	check(system.ability_system.get_aura_attack_bonus(ally) == 1, "The bonus returns immediately after entering the Aura", failures)

	for turn in range(4):
		system.effect_system.expire_turn_end_effects(devotee)
	check(devotee.has_status("bless_aura"), "Bless remains active through four turn endings", failures)
	system.effect_system.expire_turn_end_effects(devotee)
	check(not devotee.has_status("bless_aura") and system.ability_system.get_aura_attack_bonus(ally) == 0, "Bless expires after the fifth turn ending", failures)

	check(Bless.required_level == 1 and Bless.ap_cost == 1 and Bless.targeting_range_feet == 10.0, "Bless has the specified level, AP cost, and range", failures)
	check(Bless.traits.all(func(trait_data): return trait_data != null) and ["devotee", "divine", "stance", "aura"].all(func(id): return Bless.traits.any(func(trait_data): return trait_data.id == id)), "Bless has Devotee, Divine, Stance, and Aura traits", failures)
	check(Catalog.abilities.has(Bless) and Devotee.get_progression_entry(1).granted_abilities.has(Bless), "Bless is registered in Character Creation and Level 1 progression", failures)

	for failure in failures:
		push_error(failure)
	print("BLESS_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
