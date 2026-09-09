extends SceneTree

const PlayerTemplate := preload("res://data/character/player.tres")
const Devotee := preload("res://data/class/devotee.tres")
const Sacrificial := preload("res://data/ability/sacrificial.tres")
const Catalog := preload("res://data/creation/default_creation_catalog.tres")


func _init() -> void:
	var failures: Array[String] = []
	var character = PlayerTemplate.duplicate(true)
	character.character_class = Devotee
	character.level = 1
	character.class_attribute_choices.assign([AttributeTypes.Type.CONSTITUTION])
	var devotee: CombatantState = character.create_combatant_state()
	devotee.id = "player"; devotee.team = 0
	var ally := CombatantState.new()
	ally.id = "ally"; ally.team = 0; ally.base_max_hp = 30
	var enemy := CombatantState.new()
	enemy.id = "enemy"; enemy.team = 1; enemy.base_max_hp = 30; enemy.strength = 10

	var attack := AttackData.new()
	attack.id = "sacrificial_test_attack"
	attack.display_name = "Certain Damage"
	attack.requires_to_hit = false
	attack.can_critical = false
	attack.base_damage = 10
	attack.ap_cost = 1
	attack.range_feet = 20.0

	var system := CombatSystem.new()
	system.start_combat([enemy, devotee, ally])
	devotee.position = Vector2.ZERO
	ally.position = Vector2(120, 0)
	enemy.position = Vector2(180, 0)
	system.combat_state.current_actor_id = enemy.id
	enemy.ap = 4
	devotee.ap = 3
	devotee.faith = 10
	check(devotee.active_reactions.any(func(reaction): return reaction != null and reaction.id == "sacrificial_reaction"), "Level 1 Devotee has the Sacrificial reaction active", failures)
	var ally_hp_before: int = ally.hp
	var devotee_hp_before: int = devotee.hp

	var request := ActionRequest.new(enemy.id, ActionTypes.Type.ATTACK)
	request.target_id = ally.id
	request.attack_data = attack
	var pending := system.execute_action(request)
	check(pending.requires_reaction_choice and pending.reaction_prompt.get("damage_intervention", false), "An ally about to take damage offers Sacrificial", failures)
	var resolved := system.resolve_pending_reaction(0)
	check(resolved.success and ally.hp == ally_hp_before, "Sacrificial prevents all incoming damage to the ally", failures)
	check(devotee.hp == devotee_hp_before - 10, "The Devotee takes the ally's 10 damage instead", failures)
	check(devotee.ap == 2 and devotee.faith == 9, "Sacrificial costs 1 AP and 1 Faith", failures)
	check(resolved.events.any(func(event): return event.type == EventTypes.Type.DAMAGE_APPLIED and event.target_id == devotee.id and int(event.data.get("amount", 0)) == 10), "The damage event identifies the Devotee as its recipient", failures)

	ally.hp = ally.max_hp
	devotee.hp = devotee.max_hp
	devotee.position = Vector2.ZERO
	ally.position = Vector2(300, 0)
	enemy.ap = 4
	request = ActionRequest.new(enemy.id, ActionTypes.Type.ATTACK)
	request.target_id = ally.id
	request.attack_data = attack
	var outside := system.execute_action(request)
	check(not outside.requires_reaction_choice, "Sacrificial is unavailable when the ally is beyond 15 feet", failures)

	check(Sacrificial.required_level == 1 and Sacrificial.reaction_only and Sacrificial.ap_cost == 1 and Sacrificial.faith_cost == 1, "Sacrificial has the specified level, type, and costs", failures)
	check(Catalog.abilities.has(Sacrificial) and Devotee.get_progression_entry(1).granted_abilities.has(Sacrificial), "Sacrificial is registered in Character Creation and Level 1 progression", failures)

	for failure in failures:
		push_error(failure)
	print("SACRIFICIAL_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
