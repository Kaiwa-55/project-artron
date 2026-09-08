extends SceneTree

const PlayerData := preload("res://data/character/player.tres")

const EXPECTED_SKILL_IDS: Array[String] = [
	"arcane_bolt",
	"arcane_burst",
	"arcane_cone",
	"ember_bolt",
	"flame_wave",
	"frost_shard",
	"frozen_ground",
]


func _init() -> void:
	var player: CombatantState = PlayerData.create_combatant_state()
	CharacterClassSystem.new().apply_class(player)
	StatSystem.new().initialize_combatant(player)
	var skill_ids: Array[String] = []
	for skill in player.available_skills:
		if skill != null:
			skill_ids.append(skill.id)
	var passed := EXPECTED_SKILL_IDS.all(func(skill_id: String): return skill_ids.has(skill_id)) \
		and skill_ids.size() == EXPECTED_SKILL_IDS.size() \
		and player.max_mana == 10
	if not passed:
		push_error("Player must receive every Skill and enough Mana to use the test loadout.")
	print("PLAYER_ALL_SKILLS_TEST: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
