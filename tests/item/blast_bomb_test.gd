extends SceneTree

const BlastBomb = preload("res://data/item/blast_bomb.tres")

var failures: Array[String] = []


func _init() -> void:
	var actor := make_actor("player", 1, Vector2.ZERO)
	var ally := make_actor("ally", 1, Vector2(300, 0))
	var enemy := make_actor("enemy", 2, Vector2(360, 0))
	var distant_enemy := make_actor("distant_enemy", 2, Vector2(600, 0))
	actor.item_inventory.append(ItemStack.new(BlastBomb, 1))
	var combat := CombatSystem.new()
	combat.start_combat([actor, ally, enemy, distant_enemy])
	combat.combat_state.current_actor_id = actor.id
	var ap_before := actor.ap
	check(not combat.use_consumable_item(actor.id, BlastBomb.id, "", Vector2(500, 0)).success, "Bomb rejects a point beyond 30 ft")
	check(actor.ap == ap_before and combat.consumable_item_executor.find_stack(actor, BlastBomb.id) != null, "Invalid throw does not spend AP or bomb")
	var result := combat.use_consumable_item(actor.id, BlastBomb.id, "", Vector2(300, 0))
	check(result.success, "Bomb can be thrown at a point")
	check(ally.hp == ally.max_hp - 6 and enemy.hp == enemy.max_hp - 6, "Blast damages allies and enemies in its radius")
	check(actor.hp == actor.max_hp and distant_enemy.hp == distant_enemy.max_hp, "Blast leaves combatants outside its radius unharmed")
	check(actor.ap == ap_before - 2 and combat.consumable_item_executor.find_stack(actor, BlastBomb.id) == null, "Bomb costs 2 AP and is consumed")
	check(not combat.use_consumable_item(actor.id, BlastBomb.id, "", Vector2(300, 0)).success, "Consumed bomb cannot be used again")
	var outfitter = load("res://data/shop/outfitter_shop.tres")
	check(outfitter.offers.any(func(offer): return offer.product == BlastBomb and offer.price == 50), "Outfitter sells Blast Bomb")
	for failure in failures:
		push_error(failure)
	print("BLAST_BOMB_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
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
