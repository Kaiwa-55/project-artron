extends SceneTree

const PlayerTemplate = preload("res://data/character/player.tres")
const DevoteeData = preload("res://data/class/devotee.tres")
const DivineIntervention = preload("res://data/ability/divine_intervention.tres")

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _init() -> void:
	var character = PlayerTemplate.duplicate(true)
	character.character_class = DevoteeData
	character.level = 3
	character.class_attribute_choices.assign([AttributeTypes.Type.CONSTITUTION])
	if not character.available_abilities.any(func(ability): return ability != null and ability.id == "divine_intervention"):
		character.available_abilities.append(DivineIntervention)
	if not character.selected_ability_ids.has("divine_intervention"):
		character.selected_ability_ids.append("divine_intervention")
	if not character.equipped_abilities.has("divine_intervention"):
		character.equipped_abilities.append("divine_intervention")
	var devotee: CombatantState = character.create_combatant_state()
	devotee.position = Vector2.ZERO

	var ally := CombatantState.new()
	ally.id = "ally"
	ally.display_name = "Ally"
	ally.team = devotee.team
	ally.base_max_hp = 30
	ally.hp = 30
	ally.position = Vector2(120, 0)
	var enemy := CombatantState.new()
	enemy.id = "enemy"
	enemy.display_name = "Enemy"
	enemy.team = devotee.team + 1
	enemy.base_max_hp = 30
	enemy.hp = 30
	enemy.strength = 10
	enemy.position = Vector2(180, 0)

	var attack := AttackData.new()
	attack.id = "certain_damage"
	attack.display_name = "Certain Damage"
	attack.requires_to_hit = false
	attack.can_critical = false
	attack.base_damage = 10
	attack.ap_cost = 1
	attack.range_feet = 10.0

	var system := CombatSystem.new()
	system.start_combat([enemy, devotee, ally])
	system.combat_state.current_actor_id = devotee.id
	devotee.ap = 4
	var manual_use := system.use_active_ability(devotee.id, enemy.id, "divine_intervention")
	check(not manual_use.success and devotee.ap == 4 and devotee.faith == 10, "Divine Intervention cannot be activated manually or target an Enemy")
	system.combat_state.current_actor_id = enemy.id
	enemy.ap = 4
	devotee.ap = 4
	var request := ActionRequest.new(enemy.id, ActionTypes.Type.ATTACK)
	request.target_id = ally.id
	request.attack_data = attack
	var pending := system.execute_action(request)
	check(pending.requires_reaction_choice and pending.reaction_prompt.get("damage_intervention", false), "An ally taking Attack damage offers Divine Intervention")
	var resolved := system.resolve_pending_reaction(0)
	check(resolved.success and ally.hp == 25, "Faith 10 reduces 10 Attack damage by floor(Faith / 2) = 5")
	check(devotee.ap == 3 and devotee.faith == 8, "Divine Intervention costs 1 AP and 2 Faith")

	# It cannot protect the Devotee who owns the Reaction.
	devotee.hp = devotee.max_hp
	enemy.ap = 4
	system.combat_state.current_actor_id = enemy.id
	request.target_id = devotee.id
	var self_result := system.execute_action(request)
	check(not self_result.reaction_prompt.get("damage_intervention", false), "Divine Intervention cannot target its own reactor")

	for failure in failures:
		push_error(failure)
	print("DIVINE_INTERVENTION_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
