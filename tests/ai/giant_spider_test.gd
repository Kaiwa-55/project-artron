extends SceneTree

const GiantSpiderData = preload("res://data/character/giant_spider.tres")

var failures: Array[String] = []


func _init() -> void:
	var spider: CombatantState = GiantSpiderData.create_combatant_state()
	check(spider.id == "giant_spider", "resource creates the Giant Spider")
	check(spider.level == 2 and spider.max_hp == 24 and spider.max_ap == 3, "core combat stats are initialized")
	check(spider.get_effective_speed() == 30.0 and spider.collision_radius_feet == 5.0, "large movement profile is initialized")
	check(spider.equipped_weapon_attack != null and spider.equipped_weapon_attack.id == "venomous_bite", "Venomous Bite is equipped")
	check(spider.equipped_weapon_attack.effects_on_hit.any(func(effect): return effect.id == "poisoned"), "Venomous Bite applies Poisoned")
	check(spider.equipped_weapon_attack.granted_abilities.any(func(ability): return ability.id == "webbed_prey"), "Venomous Bite gains its webbed-target damage passive")
	check(has_ability(spider, "web_shot") and spider.equipped_abilities.has("web_shot"), "Web Shot is active")
	check(has_ability(spider, "skitter") and spider.equipped_abilities.has("skitter"), "Skitter is active")
	check(has_trait(spider, "beast") and has_trait(spider, "poison") and has_trait(spider, "web_walker"), "creature traits are present")
	finish()


func has_ability(spider: CombatantState, ability_id: String) -> bool:
	return spider.available_abilities.any(func(ability): return ability != null and ability.id == ability_id)


func has_trait(spider: CombatantState, trait_id: String) -> bool:
	return spider.active_traits.any(func(trait_data): return trait_data != null and trait_data.id == trait_id)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func finish() -> void:
	if failures.is_empty():
		print("GIANT_SPIDER_TEST: PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("GIANT_SPIDER_TEST: FAIL")
	quit(1)
