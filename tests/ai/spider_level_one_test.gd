extends SceneTree

const SpiderData = preload("res://data/character/spider.tres")

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func has_trait(actor: CombatantState, trait_id: String) -> bool:
	return actor.active_traits.any(func(trait_data): return trait_data != null and trait_data.id == trait_id)

func _init() -> void:
	var spider: CombatantState = SpiderData.create_combatant_state()
	check(spider.id == "spider" and spider.display_name == "Spider", "Spider resource creates the correct monster")
	check(spider.level == 1 and spider.max_hp == 8 and spider.max_ap == 3, "Spider has Level 1 combat stats")
	check(spider.get_effective_speed() == 25.0 and spider.collision_radius_feet == 2.5, "Spider uses a small fast movement profile")
	check(spider.equipped_weapon_attack != null and spider.equipped_weapon_attack.id == "spider_bite", "Spider Bite is equipped")
	check(spider.equipped_weapon_attack.base_damage == 3 and spider.equipped_weapon_attack.ap_cost == 1, "Spider Bite has Level 1 damage and cost")
	check(spider.equipped_weapon_attack.effects_on_hit.any(func(effect): return effect.id == "poisoned"), "Spider Bite can apply Poisoned")
	check(has_trait(spider, "beast") and has_trait(spider, "poison"), "Spider creature traits are present")
	for failure in failures:
		push_error(failure)
	print("SPIDER_LEVEL_ONE_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
