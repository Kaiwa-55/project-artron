extends SceneTree

const PlayerTemplate = preload("res://data/character/player.tres")
const EnemyTemplate = preload("res://data/character/enemy.tres")
const DevoteeData = preload("res://data/class/devotee.tres")
const HealOrHarm = preload("res://data/ability/heal_or_harm.tres")
const Catalog = preload("res://data/creation/default_creation_catalog.tres")
const Draft = preload("res://scenes/character_creation/creation_draft.gd")

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _init() -> void:
	var character = PlayerTemplate.duplicate(true)
	character.character_class = DevoteeData
	character.level = 1
	character.class_attribute_choices.assign([AttributeTypes.Type.CONSTITUTION])
	var devotee: CombatantState = character.create_combatant_state()
	# Devotee resource rules are tested without the prototype Player's starting Status.
	devotee.effects.clear()
	var ally := CombatantState.new()
	ally.id = "ally"
	ally.display_name = "Ally"
	ally.team = devotee.team
	ally.base_max_hp = 30
	ally.hp = 10
	ally.position = Vector2(120, 0)
	var enemy: CombatantState = EnemyTemplate.create_combatant_state()
	devotee.position = Vector2.ZERO
	enemy.position = Vector2(240, 0)
	var system := CombatSystem.new()
	system.start_combat([devotee, ally, enemy])
	system.combat_state.current_actor_id = devotee.id
	system.turn_system.start_turn(system.combat_state)
	system.turn_system.activate_turn(system.combat_state, devotee.max_ap)
	ally.hp = 10
	var expected_speed: float = character.ancestry.speed_feet + DevoteeData.base_speed_feet
	check(devotee.class_id == "devotee" and devotee.get_effective_speed() == expected_speed, "Devotee class Speed combines with Human Speed")
	check(devotee.max_mana == 0 and devotee.faith == 10 and devotee.max_faith == 10, "Devotee starts combat with 10 Faith and no Mana")
	check(devotee.equipped_abilities.has("belief") and devotee.equipped_abilities.has("pray") and devotee.equipped_abilities.has("heal_or_harm"), "Belief, Pray, and Heal or Harm are granted at Level 1")
	check(devotee.wisdom == 12 and devotee.constitution == 12, "Belief and the current Human ancestry choices grant Wisdom and Constitution")
	var animated_heal = system.ability_system.get_available_ability(devotee, "heal_or_harm")
	animated_heal.animation_template = load("res://animation/lunge_return.tres")

	var heal := system.use_active_ability(devotee.id, ally.id, "heal_or_harm")
	check(heal.success and ally.hp == 20, "Heal or Harm heals an ally by current Faith")
	var heal_trigger = heal.events.filter(func(event): return event.type == EventTypes.Type.ABILITY_TRIGGERED).front()
	check(heal_trigger.data.get("animation_template") == animated_heal.animation_template and heal_trigger.data.get("animation_target") == ally.position, "Effect-only Ability emits its animation template and target")
	check(devotee.faith == 10 and devotee.temporary_faith == 0, "Heal or Harm does not consume Faith")
	devotee.ap = devotee.max_ap
	var enemy_hp := enemy.hp
	var harm := system.use_active_ability(devotee.id, enemy.id, "heal_or_harm")
	check(harm.success and enemy.hp == enemy_hp - 5, "Heal or Harm deals Light Damage equal to floor(current Faith / 2)")
	check(devotee.faith == 10, "Harm does not consume Faith")
	devotee.faith = 9
	devotee.ap = devotee.max_ap
	enemy_hp = enemy.hp
	var odd_faith_harm := system.use_active_ability(devotee.id, enemy.id, "heal_or_harm")
	check(odd_faith_harm.success and enemy.hp == enemy_hp - 4, "Heal or Harm rounds odd Faith damage down")

	devotee.wisdom = 14
	devotee.faith = 8
	devotee.ap = devotee.max_ap
	check(system.use_active_ability(devotee.id, devotee.id, "pray").success and devotee.faith == 10, "Pray restores normal Faith using Wisdom modifier")
	devotee.ap = devotee.max_ap
	check(system.use_active_ability(devotee.id, devotee.id, "pray").success and devotee.temporary_faith == 2, "Pray creates Temporary Faith above 10")
	system.combat_state.current_actor_id = devotee.id
	system.advance_turn()
	check(devotee.temporary_faith == 0, "Temporary Faith decreases by 2 at end of turn without becoming negative")
	devotee.temporary_faith = 5
	system.combat_state.current_actor_id = devotee.id
	system.advance_turn()
	check(devotee.temporary_faith == 3, "Temporary Faith loses exactly 2 when more than 2 remains")

	# Verify the real Character Creation handoff, not only a manually prepared character.
	var draft = Draft.new()
	draft.setup(Catalog)
	draft.select_class(DevoteeData)
	draft.set_level(1)
	draft.ancestry_choices.assign([0, 1, 2])
	draft.class_choices.assign([AttributeTypes.Type.CONSTITUTION])
	draft.rebuild()
	var created: CharacterData = draft.finish()
	check(created != null, "Character Creation finishes a Level 1 Devotee without selecting Heal or Harm")
	var created_devotee: CombatantState = created.create_combatant_state()
	var created_enemy: CombatantState = EnemyTemplate.create_combatant_state()
	created_devotee.position = Vector2.ZERO
	created_enemy.position = Vector2(120, 0)
	var handoff_system := CombatSystem.new()
	handoff_system.start_combat([created_devotee, created_enemy])
	check(created_devotee.granted_ability_ids.has("heal_or_harm") and created_devotee.equipped_abilities.has("heal_or_harm"), "Character Creation grants and equips Heal or Harm automatically at Level 1")
	handoff_system.combat_state.current_actor_id = created_devotee.id
	created_devotee.ap = created_devotee.max_ap
	var handoff_hp := created_enemy.hp
	var handoff_harm := handoff_system.use_active_ability(created_devotee.id, created_enemy.id, "heal_or_harm")
	check(handoff_harm.success and created_enemy.hp == handoff_hp - 5, "Character Creation Devotee deals floor(Faith / 2) Light Damage in Combat")

	for failure in failures:
		push_error(failure)
	print("DEVOTEE_FAITH_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
