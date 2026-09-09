extends SceneTree

const PlayerTemplate := preload("res://data/character/player.tres")
const MartialArtist := preload("res://data/class/martial_artist.tres")
const FinishingMove := preload("res://data/ability/finishing_move.tres")
const Catalog := preload("res://data/creation/default_creation_catalog.tres")


func _init() -> void:
	var failures: Array[String] = []
	var character = PlayerTemplate.duplicate(true)
	character.character_class = MartialArtist
	character.level = 3
	character.class_attribute_choices.assign([AttributeTypes.Type.STRENGTH])
	character.starting_equipment = []
	character.starting_equipment_slots = {}
	var actor: CombatantState = character.create_combatant_state()
	var target := CombatantState.new()
	target.id = "target"
	target.display_name = "Target"
	target.team = 2
	target.base_max_hp = 500
	target.base_max_ap = 1
	actor.position = Vector2.ZERO
	target.position = Vector2(100, 0)
	var system := CombatSystem.new()
	system.start_combat([actor, target])
	system.combat_state.current_actor_id = actor.id

	var ability: AbilityData = FinishingMove.duplicate(true)
	ability.attack_data = FinishingMove.attack_data.duplicate(true)
	replace_ability(actor, ability)
	actor.finishing_gauge = 10
	actor.ap = actor.max_ap
	ability.attack_data.requires_to_hit = false
	ability.attack_data.can_critical = false
	var hp_before := target.hp
	var hit := system.use_active_ability(actor.id, target.id, ability.id)
	var hit_event = hit.events.filter(func(event): return event.type == EventTypes.Type.ATTACK_HIT).front()
	check(hit.success, "Finishing Move resolves when AP and Gauge are available", failures)
	check(hp_before - target.hp == 10 * actor.level and hit_event.data.get("damage_type") == "blunt", "Finishing Move deals exactly 10 x Level Blunt Damage", failures)
	check(actor.ap == actor.max_ap - 3, "Finishing Move costs 3 AP", failures)
	check(actor.finishing_gauge == 1, "A Finishing Move Hit spends 10 Gauge then gains 1 for the successful Martial Artist Attack", failures)

	actor.finishing_gauge = 10
	actor.ap = actor.max_ap
	ability.attack_data.requires_to_hit = true
	ability.attack_data.to_hit_bonus = -1000
	hp_before = target.hp
	var miss := system.use_active_ability(actor.id, target.id, ability.id)
	check(miss.success and miss.events.any(func(event): return event.type == EventTypes.Type.ATTACK_MISS), "Finishing Move can miss normally", failures)
	check(target.hp == hp_before and actor.finishing_gauge == 0, "A missed Finishing Move still spends all 10 Gauge", failures)
	check(actor.ap == actor.max_ap - 3, "A missed Finishing Move still spends 3 AP", failures)

	actor.finishing_gauge = 9
	actor.ap = actor.max_ap
	var blocked := system.use_active_ability(actor.id, target.id, ability.id)
	check(not blocked.success and actor.ap == actor.max_ap and actor.finishing_gauge == 9, "Finishing Move requires 10 Gauge before spending any resource", failures)
	check(FinishingMove.required_level == 0 and FinishingMove.ap_cost == 3 and FinishingMove.finishing_gauge_cost == 10, "Finishing Move has the requested Level and costs", failures)
	check(FinishingMove.required_trait_ids.has("martial_artist") and FinishingMove.required_attack_trait_ids.has("unarmed"), "Finishing Move requires Martial Artist and Unarmed", failures)
	check(Catalog.abilities.has(FinishingMove), "Finishing Move appears in Character Creation", failures)
	check(MartialArtist.granted_abilities.has(FinishingMove) and actor.granted_ability_ids.has("finishing_move"), "Martial Artist receives Finishing Move automatically", failures)

	for failure in failures:
		push_error(failure)
	print("FINISHING_MOVE_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func replace_ability(actor: CombatantState, replacement: AbilityData) -> void:
	for index in range(actor.available_abilities.size()):
		if actor.available_abilities[index] != null and actor.available_abilities[index].id == replacement.id:
			actor.available_abilities[index] = replacement
			return
	actor.available_abilities.append(replacement)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
