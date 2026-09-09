extends SceneTree

const PotionStack := preload("res://data/item/minor_healing_potion_stack.tres")


func _init() -> void:
	var failures: Array[String] = []
	var system := CombatSystem.new()
	var actor := make_actor("player", 1)
	var enemy := make_actor("enemy", 2)
	actor.item_inventory.append(PotionStack.create_runtime_stack())
	system.start_combat([actor, enemy])
	system.combat_state.current_actor_id = actor.id
	actor.max_hp = 20
	actor.hp = 10
	actor.movement_in_progress = true
	actor.movement_remaining_feet = 10.0
	var before_ap := actor.ap
	var result := system.use_consumable_item(actor.id, "minor_healing_potion", actor.id)
	check(result.success, "Minor Healing Potion can be used", failures)
	check(actor.hp == 16, "Minor Healing Potion restores 6 HP", failures)
	check(actor.ap == before_ap - 1, "Minor Healing Potion costs 1 AP", failures)
	check(not actor.movement_in_progress, "Using an Item forfeits remaining Move", failures)
	check(actor.item_inventory.is_empty(), "Potion is consumed after use", failures)
	check(result.events.size() == 2 and result.events[0].type == EventTypes.Type.ITEM_USED, "Item use emits a public Item event and its effect event", failures)

	actor.item_inventory.append(PotionStack.create_runtime_stack())
	actor.hp = actor.max_hp
	before_ap = actor.ap
	var blocked := system.use_consumable_item(actor.id, "minor_healing_potion", actor.id)
	check(not blocked.success, "Potion cannot be wasted at full HP", failures)
	check(actor.ap == before_ap and actor.item_inventory[0].quantity == 1, "Failed use spends no AP or Item", failures)

	if failures.is_empty():
		print("CONSUMABLE_ITEM_TEST: PASS")
		quit(0)
	for failure in failures:
		push_error(failure)
	quit(1)


func make_actor(id: String, team: int) -> CombatantState:
	var actor := CombatantState.new()
	actor.id = id
	actor.display_name = id.capitalize()
	actor.team = team
	actor.max_hp = 20
	actor.hp = 20
	actor.base_max_ap = 4
	actor.max_ap = 4
	actor.ap = 4
	return actor


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
