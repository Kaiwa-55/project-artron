extends SceneTree

const PlayerTemplate = preload("res://data/character/player.tres")
const EnemyTemplate = preload("res://data/character/enemy.tres")
const ArcanistData = preload("res://data/class/arcanist.tres")
const ArcaneAim = preload("res://data/ability/arcane_aim.tres")
const ArcaneBolt = preload("res://data/attack/arcane_bolt.tres")
const Shortbow = preload("res://data/attack/shortbow.tres")

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _init() -> void:
	var character = PlayerTemplate.duplicate(true)
	character.level = 2
	character.character_class = ArcanistData
	character.available_abilities.append(ArcaneAim)
	character.selected_ability_ids.append("arcane_aim")
	character.equipped_abilities.append("arcane_aim")
	var player: CombatantState = character.create_combatant_state()
	var enemy: CombatantState = EnemyTemplate.create_combatant_state()
	var system := CombatSystem.new()
	system.start_combat([player, enemy])
	check(ArcaneAim.required_level == 2 and ArcaneAim.required_trait_ids.has("arcanist"), "Arcane Aim is a Level 2 Arcanist Ability")
	check(system.ability_system.get_to_hit_bonus(player, ArcaneBolt, 10.0) == 1, "Arcane Aim grants +1 To Hit to Arcane Bolt")
	check(system.ability_system.get_to_hit_bonus(player, Shortbow, 10.0) == 0, "Arcane Aim does not affect non-Arcane attacks")
	for failure in failures:
		push_error(failure)
	print("ARCANE_AIM_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
