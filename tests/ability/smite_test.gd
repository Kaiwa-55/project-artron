extends SceneTree

const PlayerTemplate = preload("res://data/character/player.tres")
const EnemyTemplate = preload("res://data/character/enemy.tres")
const DevoteeData = preload("res://data/class/devotee.tres")
const Smite = preload("res://data/ability/smite.tres")
const SwordAttack = preload("res://data/attack/sword.tres")
const ShortbowAttack = preload("res://data/attack/shortbow.tres")
const Catalog = preload("res://data/creation/default_creation_catalog.tres")

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _init() -> void:
	var character = PlayerTemplate.duplicate(true)
	character.character_class = DevoteeData
	character.level = 2
	character.class_attribute_choices.assign([AttributeTypes.Type.CONSTITUTION])
	character.available_abilities.append(Smite)
	character.selected_ability_ids.append("smite")
	character.equipped_abilities.append("smite")
	var devotee: CombatantState = character.create_combatant_state()
	var enemy: CombatantState = EnemyTemplate.create_combatant_state()
	devotee.position = Vector2.ZERO
	enemy.position = Vector2(5, 0)
	var system := CombatSystem.new()
	system.start_combat([devotee, enemy])
	system.combat_state.current_actor_id = devotee.id
	devotee.ap = devotee.max_ap

	var certain_sword: AttackData = SwordAttack.duplicate(true)
	certain_sword.requires_to_hit = false
	devotee.equipped_weapon_attack = certain_sword
	var hp_before := enemy.hp
	var faith_before := devotee.get_total_faith()
	var hit := system.use_active_ability(devotee.id, enemy.id, "smite")
	check(hit.success, "Smite can attack with an equipped Melee weapon")
	check(enemy.hp < hp_before and get_smite_damage(hit.events) == faith_before, "Smite adds Light Damage equal to Faith on Hit")
	check(devotee.get_total_faith() == faith_before - Smite.faith_cost and devotee.ap == devotee.max_ap - Smite.ap_cost, "Smite pays its configured AP and Faith costs")
	check(hit.events.any(func(event): return event.type == EventTypes.Type.FAITH_CHANGED and event.data.get("faith_spent", 0) == Smite.faith_cost), "Smite reports its Faith cost to the Combat Log")

	var missing_sword: AttackData = SwordAttack.duplicate(true)
	missing_sword.requires_to_hit = true
	missing_sword.to_hit_bonus = -1000
	devotee.equipped_weapon_attack = missing_sword
	devotee.ap = devotee.max_ap
	devotee.faith = devotee.max_faith
	hp_before = enemy.hp
	var miss := system.use_active_ability(devotee.id, enemy.id, "smite")
	check(miss.success and enemy.hp == hp_before, "Smite deals neither weapon nor bonus Light Damage on Miss")

	devotee.equipped_weapon_attack = ShortbowAttack
	devotee.ap = devotee.max_ap
	var ranged := system.use_active_ability(devotee.id, enemy.id, "smite")
	check(not ranged.success and devotee.ap == devotee.max_ap, "Smite rejects a Ranged weapon before spending AP")
	check(Smite.required_level == 2 and Smite.use_effects[0].faith_divisor == 1, "Smite is a Level 2 Ability that scales at full Faith")
	check(Catalog.abilities.any(func(ability): return ability != null and ability.id == "smite"), "Smite is available in Character Creation")

	for failure in failures:
		push_error(failure)
	print("SMITE_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func get_smite_damage(events: Array[CombatEvent]) -> int:
	for event in events:
		if event.type == EventTypes.Type.DAMAGE_APPLIED and event.data.get("ability_name", "") == "Smite":
			return int(event.data.get("damage", -1))
	return -1
