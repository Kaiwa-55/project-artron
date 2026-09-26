extends SceneTree

const ManaVial = preload("res://data/item/mana_vial.tres")
const SmokeFlask = preload("res://data/item/smoke_flask.tres")
const WardingCharm = preload("res://data/item/warding_charm.tres")

var failures: Array[String] = []


func _init() -> void:
	var actor := make_actor("player", 1, Vector2.ZERO)
	var ally := make_actor("ally", 1, Vector2(120, 0))
	var enemy := make_actor("enemy", 2, Vector2(360, 0))
	actor.base_max_mana = 10
	actor.item_inventory.append(ItemStack.new(ManaVial, 1))
	actor.item_inventory.append(ItemStack.new(SmokeFlask, 1))
	actor.item_inventory.append(ItemStack.new(WardingCharm, 1))
	var combat := CombatSystem.new()
	combat.start_combat([actor, ally, enemy])
	combat.combat_state.current_actor_id = actor.id
	actor.max_mana = 10
	actor.mana = 2
	check(combat.use_consumable_item(actor.id, ManaVial.id).success and actor.mana == 4, "Mana Vial restores 2 Mana")
	check(not combat.use_consumable_item(actor.id, ManaVial.id).success, "Mana Vial is consumed")
	var ap_before := actor.ap
	check(not combat.use_consumable_item(actor.id, SmokeFlask.id, "", Vector2(500, 0)).success, "Smoke Flask rejects an out-of-range point")
	check(actor.ap == ap_before, "Invalid throw spends no AP")
	check(combat.use_consumable_item(actor.id, SmokeFlask.id, "", Vector2(60, 0)).success, "Smoke Flask can be thrown at a point")
	check(combat.map_rules.get_light_level_at(Vector2(60, 0)) == 2 and combat.map_rules.get_light_level_at(enemy.position) == 1, "Smoke dims only its 10 ft area by one level")
	check(not actor.effects.any(func(effect): return effect.data.id == "smoke_concealment"), "Smoke changes the area instead of following creatures")
	check(not combat.use_consumable_item(actor.id, WardingCharm.id).success, "Warding Charm waits for a hit instead of spending a turn")
	var attack := AttackData.new()
	attack.id = "ward_test"
	attack.requires_to_hit = false
	attack.can_critical = false
	attack.ap_cost = 0
	attack.base_damage = 10
	attack.range_feet = 40.0
	combat.combat_state.current_actor_id = enemy.id
	var request := ActionRequest.new(enemy.id, ActionTypes.Type.ATTACK)
	request.target_id = actor.id
	request.attack_data = attack
	var first := combat.execute_action(request)
	check(first.requires_reaction_choice, "Warding Charm appears as a Reaction after a hit")
	var ward_index := -1
	if first.requires_reaction_choice:
		for index in range(first.reaction_prompt.reactions.size()):
			if first.reaction_prompt.reactions[index].id == "warding_charm_reaction":
				ward_index = index
	check(ward_index >= 0, "Warding Charm is selectable in the Reaction prompt")
	if ward_index >= 0:
		combat.resolve_pending_reaction(ward_index)
	check(actor.hp == actor.max_hp - 6 and combat.consumable_item_executor.find_stack(actor, WardingCharm.id) == null, "Ward reduces one damaging hit by 4 and is consumed")
	combat.execute_action(request)
	check(actor.hp == actor.max_hp - 16, "Ward does not reduce a second hit")
	while combat.combat_state.current_round < 4 and not combat.combat_state.is_finished():
		combat.advance_turn()
	check(combat.map_rules.get_light_level_at(Vector2(60, 0)) == 1 and combat.map_rules.temporary_light_areas.is_empty(), "Smoke expires after 3 rounds")
	var healer = load("res://data/shop/healer_shop.tres")
	var outfitter = load("res://data/shop/outfitter_shop.tres")
	check(healer.offers.any(func(offer): return offer.product == ManaVial), "Mana Vial is sold at the apothecary")
	check(outfitter.offers.any(func(offer): return offer.product == SmokeFlask) and outfitter.offers.any(func(offer): return offer.product == WardingCharm), "Smoke Flask and Warding Charm are sold at the outfitter")
	for failure in failures:
		push_error(failure)
	print("NEW_CONSUMABLES_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func make_actor(id: String, team: int, at: Vector2) -> CombatantState:
	var actor := CombatantState.new()
	actor.id = id
	actor.display_name = id
	actor.team = team
	actor.position = at
	actor.base_max_hp = 30
	actor.base_max_ap = 4
	return actor


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
