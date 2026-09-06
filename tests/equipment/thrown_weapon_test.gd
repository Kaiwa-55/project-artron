extends SceneTree

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _init() -> void:
	for returning in [false, true]:
		for hit in [false, true]:
			var player = load("res://data/character/player.tres").create_combatant_state()
			var enemy = load("res://data/character/enemy.tres").create_combatant_state()
			var item = load("res://data/equipment/hand_axe.tres").duplicate(true)
			if returning:
				item.weapon_attack.traits.append(load("res://data/trait/returning.tres"))
			player.equipment_inventory.append(item)
			var system := CombatSystem.new()
			system.start_combat([player, enemy])
			system.combat_state.current_actor_id = player.id
			enemy.active_reactions.clear()
			enemy.base_max_hp = 1000
			enemy.hp = 1000
			system.equipment_system.equip_hand_item_without_cost(player, item, 0)
			system.equipment_system.refresh_equipment(player)
			var attack: AttackData = system.equipment_system.create_throw_attack(item)
			check(attack.range_feet == 15.0 and not system.trait_system.attack_has_trait(attack, "melee"), "Throw is ranged at 15 ft")
			check(item.weapon_attack.range_feet == 5.0 and system.trait_system.attack_has_trait(item.weapon_attack, "melee"), "Source remains melee")
			attack.to_hit_bonus = 1000 if hit else -1000
			var request := ActionRequest.new(player.id, ActionTypes.Type.ATTACK)
			request.attack_data = attack
			request.target_id = enemy.id
			player.ap = player.max_ap
			var ap: int = player.ap
			enemy.position = player.position + Vector2(1000, 0)
			check(not system.execute_action(request).success and player.equipment_inventory.has(item) and player.ap == ap, "Invalid throw is free")
			enemy.position = player.position + Vector2(150, 0)
			var result := system.execute_action(request)
			check(result.success and player.ap == ap - 1, "Throw spends one AP")
			check(player.equipment_inventory.has(item) == returning, "Returning controls consumption, independent of hit")
			check((system.equipment_system.find_hand_slot(player, item) >= 0) == returning, "Consumed item removed from hand")
			if not returning:
				var after: int = player.ap
				check(not system.execute_action(request).success and player.ap == after, "Stale throw cannot reuse consumed item")
	for failure in failures:
		push_error(failure)
	print("THROWN_WEAPON_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
