extends SceneTree

var failures: Array[String] = []


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _init() -> void:
	var player: CombatantState = load("res://data/character/player.tres").create_combatant_state()
	var enemy: CombatantState = load("res://data/character/enemy.tres").create_combatant_state()
	var system := CombatSystem.new()
	system.start_combat([player, enemy])
	system.combat_state.current_actor_id = player.id
	enemy.active_reactions.clear()
	enemy.position = player.position + Vector2(150, 0)
	var bow: AttackData = load("res://data/attack/shortbow.tres")
	var standard: ItemData = load("res://data/item/standard_arrow.tres")
	var heavy: ItemData = load("res://data/item/heavy_arrow.tres")
	var ordinary_attack: AttackData = system.equipment_system.create_ammunition_attack(bow, standard)
	var heavy_attack: AttackData = system.equipment_system.create_ammunition_attack(bow, heavy)
	check(ordinary_attack != null and heavy_attack != null, "Both arrows create bow attacks")
	check(ordinary_attack.base_damage == 4 and heavy_attack.base_damage == 6 and heavy_attack.to_hit_bonus == bow.to_hit_bonus - 1, "Arrow modifiers differ without changing the bow")
	var request := ActionRequest.new(player.id, ActionTypes.Type.ATTACK)
	request.target_id = enemy.id
	request.attack_data = bow
	var ap_before: int = player.ap
	check(not system.execute_action(request).success and player.ap == ap_before, "Bow requires an arrow choice")
	request.attack_data = ordinary_attack
	var ordinary_stack: ItemStack = system.equipment_system.find_ammunition_stack(player, standard.id)
	var heavy_stack: ItemStack = system.equipment_system.find_ammunition_stack(player, heavy.id)
	check(ordinary_stack != null and heavy_stack != null, "Both arrow stacks exist")
	if ordinary_stack != null and heavy_stack != null:
		var ordinary_before: int = ordinary_stack.quantity
		var heavy_before: int = heavy_stack.quantity
		check(system.execute_action(request).success, "Selected standard arrow fires")
		check(ordinary_stack.quantity == ordinary_before - 1 and heavy_stack.quantity == heavy_before, "Only selected arrow is consumed")
		player.ap = player.max_ap
		request.attack_data = heavy_attack
		check(system.execute_action(request).success, "Selected heavy arrow fires")
		check(heavy_stack.quantity == heavy_before - 1, "Heavy arrow is consumed")
		player.ap = player.max_ap
		heavy_stack.quantity = 0
		var ap_after: int = player.ap
		check(not system.execute_action(request).success and player.ap == ap_after, "Empty arrow stack blocks attack without AP cost")
	for failure in failures:
		push_error(failure)
	print("BOW_AMMUNITION_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
