extends SceneTree

const PlayerTemplate = preload("res://data/character/player.tres")
const EnemyTemplate = preload("res://data/character/enemy.tres")
const MartialArtist = preload("res://data/class/martial_artist.tres")
const CrushingPalm = preload("res://data/ability/crushing_palm.tres")
const Catalog = preload("res://data/creation/default_creation_catalog.tres")

var failures: Array[String] = []


func _init() -> void:
	var character = PlayerTemplate.duplicate(true)
	character.character_class = MartialArtist
	character.level = 2
	character.class_attribute_choices.assign([AttributeTypes.Type.STRENGTH])
	var crushing_palm = CrushingPalm.duplicate(true)
	crushing_palm.attack_data = CrushingPalm.attack_data.duplicate(true)
	crushing_palm.attack_data.requires_to_hit = false
	character.available_abilities.append(crushing_palm)
	character.selected_ability_ids.append("crushing_palm")
	character.equipped_abilities.append("crushing_palm")
	var martial_artist: CombatantState = character.create_combatant_state()
	var enemy: CombatantState = EnemyTemplate.create_combatant_state()
	martial_artist.position = Vector2.ZERO
	enemy.position = Vector2(100, 0)
	enemy.active_reactions.clear()
	var system := CombatSystem.new()
	system.start_combat([martial_artist, enemy])
	system.combat_state.current_actor_id = martial_artist.id
	martial_artist.ap = martial_artist.max_ap

	var hp_before := enemy.hp
	var result: ActionResult = system.use_active_ability(martial_artist.id, enemy.id, "crushing_palm")
	var hit_event = result.events.filter(func(event): return event.type == EventTypes.Type.ATTACK_HIT).front()
	check(result.success, "Crushing Palm executes with a free hand")
	check(int(hit_event.data.get("conditional_damage_bonus", 0)) == martial_artist.level, "Crushing Palm adds Damage equal to Level after Critical calculation")
	check(enemy.hp < hp_before and enemy.has_status("weakened"), "Crushing Palm damages and applies Weakened 1 on Hit")
	check(system.ability_system.get_remaining_cooldown(martial_artist, "crushing_palm") == 1, "Crushing Palm starts its one-Turn cooldown")

	martial_artist.ap = martial_artist.max_ap
	system.ability_system.set_remaining_cooldown(martial_artist, "crushing_palm", 0)
	martial_artist.equipped_items[0] = RefCounted.new()
	martial_artist.equipped_items[3] = RefCounted.new()
	var blocked: ActionResult = system.use_active_ability(martial_artist.id, enemy.id, "crushing_palm")
	check(not blocked.success and blocked.failure_reason.contains("free hand"), "Crushing Palm cannot bypass the Unarmed free-hand rule")
	check(CrushingPalm.required_level == 2 and CrushingPalm.ap_cost == 1 and CrushingPalm.cooldown_turns == 1, "Crushing Palm has the requested Level, AP, and Cooldown")
	check(Catalog.abilities.any(func(ability): return ability != null and ability.id == "crushing_palm"), "Crushing Palm is available in Character Creation")
	check(MartialArtist.get_progression_entry(2).granted_abilities.any(func(ability): return ability != null and ability.id == "crushing_palm"), "Martial Artist receives Crushing Palm at Level 2")

	for failure in failures:
		push_error(failure)
	print("CRUSHING_PALM_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
