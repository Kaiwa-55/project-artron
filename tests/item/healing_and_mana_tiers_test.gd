extends SceneTree

const GreaterHealing = preload("res://data/item/greater_healing_potion.tres")
const Bandage = preload("res://data/item/emergency_bandage.tres")
const GreaterMana = preload("res://data/item/greater_mana_vial.tres")
const ManaVial = preload("res://data/item/mana_vial.tres")

var failures: Array[String] = []


func _init() -> void:
	var actor := make_actor("player", 1, Vector2.ZERO)
	var ally := make_actor("ally", 1, Vector2(600, 0))
	var enemy := make_actor("enemy", 2, Vector2(60, 0))
	actor.item_inventory = [
		ItemStack.new(GreaterHealing, 1),
		ItemStack.new(Bandage, 2),
		ItemStack.new(GreaterMana, 1),
		ItemStack.new(ManaVial, 1),
	]
	var combat := CombatSystem.new()
	combat.start_combat([actor, ally, enemy])
	combat.combat_state.current_actor_id = actor.id
	actor.hp = 10
	ally.hp = 12
	actor.mana = 0
	var ap_before := actor.ap
	check(combat.use_consumable_item(actor.id, GreaterHealing.id).success and actor.hp == 22 and actor.ap == ap_before - 1, "Greater Healing Potion restores 12 HP for 1 AP")
	check(combat.consumable_item_executor.find_stack(actor, GreaterHealing.id) == null, "Greater Healing Potion is consumed")
	ap_before = actor.ap
	check(not combat.use_consumable_item(actor.id, Bandage.id, ally.id).success and actor.ap == ap_before, "Emergency Bandage cannot reach a distant ally")
	check(not combat.use_consumable_item(actor.id, Bandage.id, enemy.id).success and actor.ap == ap_before, "Emergency Bandage cannot heal an enemy")
	ally.position = Vector2(60, 0)
	check(combat.use_consumable_item(actor.id, Bandage.id, ally.id).success and ally.hp == 16 and actor.ap == ap_before - 1, "Emergency Bandage heals a nearby ally by 4 HP")
	check(combat.use_consumable_item(actor.id, Bandage.id, actor.id).success and actor.hp == 26 and actor.ap == ap_before - 2, "Emergency Bandage heals self by 4 HP")
	check(combat.consumable_item_executor.find_stack(actor, Bandage.id) == null, "Both bandages are consumed")
	ap_before = actor.ap
	check(combat.use_consumable_item(actor.id, ManaVial.id).success and actor.mana == 2 and actor.ap == ap_before - 1, "Mana Vial restores 2 Mana for 1 AP")
	check(combat.use_consumable_item(actor.id, GreaterMana.id).success and actor.mana == 6 and actor.ap == ap_before - 2, "Greater Mana Vial restores 4 Mana for 1 AP")
	var healer: ShopData = load("res://data/shop/healer_shop.tres")
	for item in [GreaterHealing, Bandage, GreaterMana]:
		check(healer.offers.any(func(offer): return offer.product == item), "%s is sold at the apothecary" % item.display_name)
	for failure in failures:
		push_error(failure)
	print("HEALING_AND_MANA_TIERS_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func make_actor(id: String, team: int, at: Vector2) -> CombatantState:
	var actor := CombatantState.new()
	actor.id = id
	actor.display_name = id
	actor.team = team
	actor.position = at
	actor.base_max_hp = 30
	actor.base_max_mana = 10
	actor.base_max_ap = 6
	return actor


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
