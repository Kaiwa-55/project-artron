extends SceneTree

const Skullmaul = preload("res://data/character/goblin_skullmaul.tres")
const Encounter = preload("res://data/encounter/run_elite_goblin_skullmaul.tres")
const Catalog = preload("res://data/run/prototype_encounter_catalog.tres")

var failures: Array[String] = []


func _init() -> void:
	var brute: CombatantState = Skullmaul.create_combatant_state()
	check(brute.id == "goblin_skullmaul" and brute.team == 2 and brute.level == 2, "Skullmaul loads as a level 2 enemy")
	check(brute.max_hp == 30 and brute.max_ap == 3 and brute.base_speed == 10.0, "Skullmaul has durable, slow melee stats")
	check(brute.equipped_weapon_attack.id == "goblin_skullmaul_club" and brute.equipped_weapon_attack.ap_cost == 2, "Skullmaul carries its heavy club")
	check(brute.ai_profile != null and brute.token_texture != null, "Skullmaul has AI and artwork")
	check(Encounter.enemies.has(Skullmaul) and Catalog.elite_encounters.has(Encounter), "Skullmaul is available in Elite encounters")
	for failure in failures:
		push_error(failure)
	print("GOBLIN_SKULLMAUL_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
