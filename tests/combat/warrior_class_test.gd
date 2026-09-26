extends SceneTree

const Warrior = preload("res://data/class/warrior.tres")
const Sword = preload("res://data/attack/sword.tres")
const Shortbow = preload("res://data/attack/shortbow.tres")
const Unarmed = preload("res://data/attack/unarmed_attack.tres")

var failures: Array[String] = []


func _init() -> void:
	var catalog = load("res://data/creation/default_creation_catalog.tres")
	check(catalog.classes.has(Warrior) and Warrior.has_valid_progression(10), "Warrior is selectable with complete progression")
	var warrior_visual = catalog.visual_for("warrior")
	check(warrior_visual != null and warrior_visual.artwork != null and warrior_visual.artwork.get_size() == Vector2(1254, 1254), "Character Creation loads Warrior artwork")
	check(Warrior.main_attribute == AttributeTypes.Type.STRENGTH and Warrior.fixed_attribute_bonuses.get(0) == 1 and Warrior.attribute_choice_options == [2, 1], "Warrior favors Strength and chooses Constitution or Dexterity")
	check(Warrior.get_progression_entry(1).max_hp_gain == 8 and Warrior.get_progression_entry(2).max_hp_gain == 6, "Warrior HP progression")
	var draft = load("res://scenes/character_creation/creation_draft.gd").new()
	draft.setup(catalog)
	draft.select_class(Warrior)
	check(draft.preview.class_id == "warrior" and draft.preview.granted_ability_ids.has("counterattack"), "Character Creation previews Warrior and its reaction")
	var data: CharacterData = load("res://data/character/player.tres").duplicate()
	data.character_class = Warrior
	data.level = 1
	var warrior: CombatantState = data.create_combatant_state()
	var enemy: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	enemy.position = warrior.position + Vector2(50, 0)
	var system := CombatSystem.new()
	system.start_combat([warrior, enemy])
	for id in ["simple_weapon_training", "advanced_weapon_training", "steady_assault", "stand_firm", "counterattack"]:
		check(warrior.granted_ability_ids.has(id) and warrior.equipped_abilities.has(id), "Warrior starts with " + id)
	check(warrior.active_reactions.any(func(reaction): return reaction != null and reaction.id == "counterattack"), "Counterattack is active")
	var bonuses: Array[Dictionary] = system.ability_system.get_conditional_damage_bonuses(warrior, enemy, Sword, system.combat_state.current_round)
	check(bonuses.size() == 1 and bonuses[0].amount == 2, "First weapon hit gets +2 damage")
	check(system.ability_system.get_conditional_damage_bonuses(warrior, enemy, Unarmed, system.combat_state.current_round).is_empty(), "Unarmed attacks get no Steady Assault bonus")
	system.ability_system.commit_conditional_damage_bonuses(warrior, bonuses)
	check(system.ability_system.get_conditional_damage_bonuses(warrior, enemy, Shortbow, system.combat_state.current_round).is_empty(), "Later weapon hits do not repeat bonus")
	var base_defense: int = warrior.reflex + warrior.defense_bonus + warrior.reflex_bonus + system.effect_system.get_reflex_bonus(warrior)
	check(system.defense_system.get_defense(warrior, DefenseTypes.Type.REFLEX) == base_defense + 1, "Stand Firm adds one Defense while stationary")
	warrior.movement_distance_this_turn = 3.0
	check(system.defense_system.get_defense(warrior, DefenseTypes.Type.REFLEX) == base_defense, "Moving removes Stand Firm")
	warrior.movement_distance_this_turn = 0.0
	var miss := AttackResult.new()
	miss.hit = false
	check(system.reaction_system.get_miss_counter_reactions(enemy, warrior, Shortbow, miss, system.combat_state.current_round).is_empty(), "Ranged misses cannot trigger Counterattack")
	system.combat_state.current_actor_id = enemy.id
	var attack: AttackData = enemy.equipped_weapon_attack.duplicate()
	attack.to_hit_bonus = -1000
	var request := ActionRequest.new(enemy.id, ActionTypes.Type.ATTACK)
	request.target_id = warrior.id
	request.attack_data = attack
	var attack_result: ActionResult = system.execute_action(request)
	check(attack_result.requires_reaction_choice and attack_result.reaction_prompt.get("counterattack_choice", false), "Missed melee attack offers Counterattack")
	if attack_result.requires_reaction_choice:
		var ap_before: int = warrior.ap
		var counter_result: ActionResult = system.resolve_pending_reaction(0)
		check(counter_result.events.any(func(event): return event.type == EventTypes.Type.REACTION_TRIGGERED and event.data.get("reaction_name") == "Counterattack"), "Accepted Counterattack resolves")
		check(warrior.ap == ap_before - 1, "Counterattack costs exactly one AP")
		enemy.ap = enemy.max_ap
		var second_attack: ActionResult = system.execute_action(request)
		check(second_attack.requires_reaction_choice, "Another missed melee attack can offer Counterattack")
		if second_attack.requires_reaction_choice:
			var ap_before_decline: int = warrior.ap
			system.resolve_pending_reaction(-1)
			check(warrior.ap == ap_before_decline, "Declining Counterattack costs no AP")
	for failure in failures:
		push_error(failure)
	print("WARRIOR_CLASS_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
