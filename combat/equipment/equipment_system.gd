class_name EquipmentSystem
extends RefCounted

const EquipmentDataScript = preload("res://data/equipment/equipment_data.gd")
const WEAPON_SLOT_1 := 0
const WEAPON_SLOT_2 := 3
const ACCESSORY_SLOTS := [8, 9, 10]
const LOADOUT_SLOTS := [0, 3, 1, 4, 5, 6, 7, 8, 9, 10]
const SLOT_NAMES := {0: "Hand 1", 3: "Hand 2", 1: "Body", 4: "Head", 5: "Legs", 6: "Boots", 7: "Gloves", 8: "Accessory 1", 9: "Accessory 2", 10: "Accessory 3"}
const SLOT_TYPE_NAMES := {0: "Weapon", 1: "Armor", 2: "Shield", 4: "Head", 5: "Legs", 6: "Boots", 7: "Gloves", 8: "Accessory"}


func has_free_hand(combatant: CombatantState) -> bool:
	return combatant != null and (combatant.equipped_items.get(WEAPON_SLOT_1) == null or combatant.equipped_items.get(WEAPON_SLOT_2) == null)


func validate_unarmed_attack(combatant: CombatantState, attack: AttackData) -> ActionResult:
	if attack == null or not TraitSystem.new().attack_has_trait(attack, "unarmed"):
		return ActionResult.success_result()
	if not has_free_hand(combatant):
		return ActionResult.failure("Unarmed Attack requires at least one free hand.")
	return ActionResult.success_result()


func validate_dual_weapon_setup(combatant: CombatantState) -> ActionResult:
	if combatant == null:
		return ActionResult.failure("Character does not exist.")
	var main_item = combatant.equipped_items.get(WEAPON_SLOT_1)
	var off_item = combatant.equipped_items.get(WEAPON_SLOT_2)
	if main_item == null or off_item == null or main_item == off_item:
		return ActionResult.failure("Dual Strike requires two one-handed weapons.")
	if main_item.slot != EquipmentDataScript.Slot.WEAPON or off_item.slot != EquipmentDataScript.Slot.WEAPON:
		return ActionResult.failure("A Shield cannot be used for Dual Strike.")
	if main_item.weapon_attack == null or off_item.weapon_attack == null or is_two_handed(main_item) or is_two_handed(off_item):
		return ActionResult.failure("Dual Strike requires two one-handed weapons.")
	var traits := TraitSystem.new()
	if not traits.attack_has_trait(main_item.weapon_attack, "dual_weapon") or not traits.attack_has_trait(off_item.weapon_attack, "dual_weapon"):
		return ActionResult.failure("Both weapons require the Dual Weapon trait.")
	return ActionResult.success_result()


func create_throw_attack(item) -> AttackData:
	if item == null or item.weapon_attack == null:
		return null
	var source: AttackData = item.weapon_attack
	var traits := TraitSystem.new()
	if not traits.attack_has_trait(source, "thrown") or source.thrown_range_feet <= 0.0:
		return null
	var attack: AttackData = source.duplicate()
	attack.traits = source.traits.duplicate()
	attack.traits = attack.traits.filter(func(trait_data): return trait_data != null and trait_data.id != "melee")
	if not traits.attack_has_trait(attack, "ranged"):
		attack.traits.append(preload("res://data/trait/ranged.tres"))
	attack.range_feet = source.thrown_range_feet
	attack.display_name = "Throw %s" % item.display_name
	attack.thrown_item = item
	# A melee lunge would incorrectly move the token toward a ranged target.
	attack.animation_template = null
	return attack


func validate_throw(combatant: CombatantState, attack: AttackData) -> ActionResult:
	var item = attack.thrown_item
	if combatant == null or item == null or not combatant.equipment_inventory.has(item) or find_hand_slot(combatant, item) < 0:
		return ActionResult.failure("The thrown weapon must still be held and in inventory.")
	if create_throw_attack(item) == null:
		return ActionResult.failure("This weapon cannot be thrown.")
	return ActionResult.success_result()


func consume_thrown_weapon(combatant: CombatantState, attack: AttackData) -> bool:
	var item = attack.thrown_item
	if item == null or TraitSystem.new().attack_has_trait(attack, "returning"):
		return false
	remove_hand_item_from_all_slots(combatant, item)
	combatant.equipment_inventory.erase(item)
	combatant.starting_equipment.erase(item)
	combatant.starting_equipment_slots.erase(item.id)
	select_fallback_active_weapon(combatant)
	refresh_equipment(combatant)
	return true


func initialize_combatant(combatant: CombatantState) -> void:
	if combatant == null:
		return
	for item in combatant.starting_equipment:
		if item != null and not combatant.equipment_inventory.has(item):
			combatant.equipment_inventory.append(item)
	for item in combatant.starting_equipment:
		if item == null:
			continue
		if item.slot == EquipmentDataScript.Slot.WEAPON or item.slot == EquipmentDataScript.Slot.SHIELD:
			var starting_slot := WEAPON_SLOT_1 if combatant.equipped_items.get(WEAPON_SLOT_1) == null else WEAPON_SLOT_2
			var requested_slot: int = int(combatant.starting_equipment_slots.get(item.id, starting_slot))
			if requested_slot == WEAPON_SLOT_1 or requested_slot == WEAPON_SLOT_2:
				starting_slot = requested_slot
			equip_hand_item_without_cost(combatant, item, starting_slot)
		else:
			var requested_slot: int = int(combatant.starting_equipment_slots.get(item.id, -1))
			var target_slot: int = get_non_hand_slot(combatant, item, requested_slot)
			if target_slot >= 0:
				combatant.equipped_items[target_slot] = item
	initialize_ammunition(combatant)


func uses_ammunition(attack: AttackData) -> bool:
	return attack != null and attack.ammunition_capacity > 0 and TraitSystem.new().attack_has_trait(attack, "reload")


func initialize_ammunition(combatant: CombatantState) -> void:
	if combatant == null:
		return
	for item in combatant.equipment_inventory:
		if item == null or item.weapon_attack == null or not uses_ammunition(item.weapon_attack):
			continue
		if not combatant.ammunition.has(item.weapon_attack.id):
			combatant.ammunition[item.weapon_attack.id] = item.weapon_attack.ammunition_capacity


func get_ammunition(combatant: CombatantState, attack: AttackData) -> int:
	if not uses_ammunition(attack):
		return -1
	initialize_ammunition(combatant)
	return int(combatant.ammunition.get(attack.id, attack.ammunition_capacity))


func validate_ammunition(combatant: CombatantState, attack: AttackData) -> ActionResult:
	if attack != null and not attack.ammunition_item_ids.is_empty():
		if combatant == null or attack.ammunition_item_id.is_empty() or not attack.ammunition_item_ids.has(attack.ammunition_item_id):
			return ActionResult.failure("เลือกชนิดลูกธนูก่อนยิง")
		if find_ammunition_stack(combatant, attack.ammunition_item_id) == null:
			return ActionResult.failure("ลูกธนูชนิดนี้หมดแล้ว")
	if not uses_ammunition(attack):
		return ActionResult.success_result()
	if get_ammunition(combatant, attack) <= 0:
		return ActionResult.failure("ไม่มี ammunition เหลือ ต้อง Reload ก่อน")
	return ActionResult.success_result()


func consume_ammunition(combatant: CombatantState, attack: AttackData) -> void:
	if attack != null and not attack.ammunition_item_id.is_empty():
		var stack: ItemStack = find_ammunition_stack(combatant, attack.ammunition_item_id)
		if stack != null and stack.consume():
			if stack.quantity == 0:
				combatant.item_inventory.erase(stack)
	if uses_ammunition(attack):
		combatant.ammunition[attack.id] = maxi(0, get_ammunition(combatant, attack) - 1)


func find_ammunition_stack(combatant: CombatantState, item_id: String) -> ItemStack:
	if combatant == null:
		return null
	for stack in combatant.item_inventory:
		if stack != null and stack.item != null and stack.item.id == item_id and stack.quantity > 0:
			return stack
	return null


func create_ammunition_attack(source: AttackData, arrow: ItemData) -> AttackData:
	if source == null or arrow == null or not source.ammunition_item_ids.has(arrow.id):
		return null
	var attack: AttackData = source.duplicate()
	attack.ammunition_item_id = arrow.id
	attack.display_name = "%s · %s" % [source.display_name, arrow.display_name]
	attack.to_hit_bonus_sources = source.to_hit_bonus_sources.duplicate(true)
	attack.base_damage_bonus_sources = source.base_damage_bonus_sources.duplicate(true)
	attack.base_damage += arrow.ammunition_damage_bonus
	attack.to_hit_bonus += arrow.ammunition_to_hit_bonus
	if arrow.ammunition_damage_bonus != 0:
		attack.base_damage_bonus_sources.append({"source": arrow.display_name, "amount": arrow.ammunition_damage_bonus})
	if arrow.ammunition_to_hit_bonus != 0:
		attack.to_hit_bonus_sources.append({"source": arrow.display_name, "amount": arrow.ammunition_to_hit_bonus})
	return attack


func reload_weapon(combatant: CombatantState) -> ActionResult:
	if combatant == null:
		return ActionResult.failure("Character does not exist.")
	var attack: AttackData = combatant.equipped_weapon_attack
	if not uses_ammunition(attack):
		return ActionResult.failure("อาวุธที่ถืออยู่ไม่ต้อง Reload")
	if combatant.ap < attack.reload_ap_cost:
		return ActionResult.failure("Not enough AP to Reload.")
	if get_ammunition(combatant, attack) >= attack.ammunition_capacity:
		return ActionResult.failure("กระสุนเต็มอยู่แล้ว")
	combatant.spend_ap(attack.reload_ap_cost)
	combatant.ammunition[attack.id] = attack.ammunition_capacity
	return ActionResult.success_result()


func toggle_equipment(combatant: CombatantState, item, target_slot: int = -1) -> ActionResult:
	if combatant == null or item == null:
		return ActionResult.failure("Equipment does not exist.")
	if not combatant.equipment_inventory.has(item):
		return ActionResult.failure("Item is not in this character's inventory.")
	if item.slot == EquipmentDataScript.Slot.ARMOR:
		return ActionResult.failure("Armor cannot be equipped or removed during combat.")
	if item.slot == EquipmentDataScript.Slot.WEAPON or item.slot == EquipmentDataScript.Slot.SHIELD:
		return toggle_hand_item(combatant, item, target_slot)
	return ActionResult.failure("This equipment cannot be changed during combat.")


func toggle_hand_item(combatant: CombatantState, item, target_slot: int) -> ActionResult:
	return _toggle_hand_item(combatant, item, target_slot, true)


func toggle_equipment_without_cost(combatant: CombatantState, item, target_slot: int = -1) -> ActionResult:
	if combatant == null or item == null:
		return ActionResult.failure("Equipment does not exist.")
	if not combatant.equipment_inventory.has(item):
		return ActionResult.failure("Item is not in this character's inventory.")
	var result: ActionResult
	if item.slot == EquipmentDataScript.Slot.WEAPON or item.slot == EquipmentDataScript.Slot.SHIELD:
		result = _toggle_hand_item(combatant, item, target_slot, false)
	else:
		var equipped_slot: int = find_equipped_slot(combatant, item)
		var chosen_slot: int = get_non_hand_slot(combatant, item, target_slot)
		if chosen_slot < 0:
			return ActionResult.failure("Unsupported equipment slot.")
		if equipped_slot >= 0:
			combatant.equipped_items.erase(equipped_slot)
		if equipped_slot != chosen_slot:
			combatant.equipped_items[chosen_slot] = item
		result = ActionResult.success_result()
	if result.success:
		refresh_equipment(combatant)
	return result


func get_valid_slots(item) -> Array:
	if item == null:
		return []
	if item.slot == EquipmentDataScript.Slot.WEAPON or item.slot == EquipmentDataScript.Slot.SHIELD:
		return [WEAPON_SLOT_1, WEAPON_SLOT_2]
	if item.slot == EquipmentDataScript.Slot.ACCESSORY:
		return ACCESSORY_SLOTS.duplicate()
	return [item.slot] if SLOT_NAMES.has(item.slot) else []


func get_non_hand_slot(combatant: CombatantState, item, requested_slot: int = -1) -> int:
	var valid_slots: Array = get_valid_slots(item)
	if valid_slots.is_empty() or valid_slots.has(WEAPON_SLOT_1):
		return -1
	if requested_slot >= 0:
		return requested_slot if valid_slots.has(requested_slot) else -1
	var equipped_slot: int = find_equipped_slot(combatant, item)
	if equipped_slot >= 0:
		return equipped_slot
	for slot in valid_slots:
		if combatant.equipped_items.get(slot) == null:
			return slot
	return valid_slots[0]


func find_equipped_slot(combatant: CombatantState, item) -> int:
	for slot in combatant.equipped_items:
		if combatant.equipped_items[slot] == item:
			return int(slot)
	return -1


func _toggle_hand_item(combatant: CombatantState, item, target_slot: int, spend_action_point: bool) -> ActionResult:
	if target_slot != WEAPON_SLOT_1 and target_slot != WEAPON_SLOT_2:
		target_slot = find_hand_slot(combatant, item)
		if target_slot < 0:
			target_slot = WEAPON_SLOT_1 if combatant.equipped_items.get(WEAPON_SLOT_1) == null else WEAPON_SLOT_2
	if spend_action_point and combatant.ap < 1:
		return ActionResult.failure("Not enough AP to change equipment.")
	if spend_action_point:
		combatant.spend_ap(1)
	var current_slot := find_hand_slot(combatant, item)
	if current_slot >= 0:
		remove_hand_item_from_all_slots(combatant, item)
		if not is_two_handed(item) and current_slot != target_slot:
			equip_hand_item_without_cost(combatant, item, target_slot)
		else:
			select_fallback_active_weapon(combatant)
		return ActionResult.success_result()
	equip_hand_item_without_cost(combatant, item, target_slot)
	return ActionResult.success_result()


func set_active_weapon_slot(combatant: CombatantState, target_slot: int) -> ActionResult:
	if combatant == null or (target_slot != WEAPON_SLOT_1 and target_slot != WEAPON_SLOT_2):
		return ActionResult.failure("Weapon slot does not exist.")
	var target_item = combatant.equipped_items.get(target_slot)
	if target_item == null or target_item.weapon_attack == null:
		return ActionResult.failure("There is no Weapon in that slot.")
	if combatant.active_weapon_slot == target_slot:
		return ActionResult.success_result()
	if combatant.ap < 1:
		return ActionResult.failure("Not enough AP to change Weapon.")
	combatant.spend_ap(1)
	combatant.active_weapon_slot = target_slot
	return ActionResult.success_result()


func refresh_equipment(combatant: CombatantState) -> void:
	combatant.equipment_reflex_bonus = 0
	combatant.equipment_fortitude_bonus = 0
	combatant.equipment_will_bonus = 0
	combatant.equipment_stealth_bonus = 0
	combatant.equipment_max_mana_bonus = 0
	combatant.equipment_damage_resistances.clear()
	combatant.equipped_weapon_attack = combatant.natural_attack
	var processed_items: Array = []
	for item in combatant.equipped_items.values():
		if item == null:
			continue
		if processed_items.has(item):
			continue
		processed_items.append(item)
		combatant.equipment_reflex_bonus += item.reflex_bonus
		combatant.equipment_fortitude_bonus += item.fortitude_bonus
		combatant.equipment_will_bonus += item.will_bonus
		combatant.equipment_stealth_bonus += item.stealth_bonus
		combatant.equipment_max_mana_bonus += item.max_mana_bonus
		for damage_type in item.damage_resistances:
			var key := String(damage_type).strip_edges().to_lower()
			combatant.equipment_damage_resistances[key] = int(combatant.equipment_damage_resistances.get(key, 0)) + int(item.damage_resistances[damage_type])
	var active_weapon = combatant.equipped_items.get(combatant.active_weapon_slot)
	if active_weapon == null or active_weapon.weapon_attack == null:
		select_fallback_active_weapon(combatant)
		active_weapon = combatant.equipped_items.get(combatant.active_weapon_slot)
	if active_weapon != null and active_weapon.weapon_attack != null:
		combatant.equipped_weapon_attack = active_weapon.weapon_attack
	StatSystem.new().refresh_combatant(combatant)


func equip_hand_item_without_cost(combatant: CombatantState, item, target_slot: int) -> void:
	var occupying_item = combatant.equipped_items.get(target_slot)
	if occupying_item != null and is_two_handed(occupying_item):
		remove_hand_item_from_all_slots(combatant, occupying_item)
	if is_two_handed(item):
		combatant.equipped_items[WEAPON_SLOT_1] = item
		combatant.equipped_items[WEAPON_SLOT_2] = item
		combatant.active_weapon_slot = WEAPON_SLOT_1
		return
	combatant.equipped_items[target_slot] = item
	if item.weapon_attack != null:
		combatant.active_weapon_slot = target_slot
	elif combatant.active_weapon_slot == target_slot:
		select_fallback_active_weapon(combatant)


func is_two_handed(item) -> bool:
	if item == null or item.weapon_attack == null:
		return false
	for trait_data in item.weapon_attack.traits:
		if trait_data != null and trait_data.id == "two_handed":
			return true
	return false


func find_hand_slot(combatant: CombatantState, item) -> int:
	if combatant.equipped_items.get(WEAPON_SLOT_1) == item:
		return WEAPON_SLOT_1
	if combatant.equipped_items.get(WEAPON_SLOT_2) == item:
		return WEAPON_SLOT_2
	return -1


func remove_hand_item_from_all_slots(combatant: CombatantState, item) -> void:
	if combatant.equipped_items.get(WEAPON_SLOT_1) == item:
		combatant.equipped_items.erase(WEAPON_SLOT_1)
	if combatant.equipped_items.get(WEAPON_SLOT_2) == item:
		combatant.equipped_items.erase(WEAPON_SLOT_2)


func select_fallback_active_weapon(combatant: CombatantState) -> void:
	var hand_1 = combatant.equipped_items.get(WEAPON_SLOT_1)
	var hand_2 = combatant.equipped_items.get(WEAPON_SLOT_2)
	if hand_1 != null and hand_1.weapon_attack != null:
		combatant.active_weapon_slot = WEAPON_SLOT_1
	elif hand_2 != null and hand_2.weapon_attack != null:
		combatant.active_weapon_slot = WEAPON_SLOT_2
	else:
		combatant.active_weapon_slot = WEAPON_SLOT_1


func get_equipment_name(combatant: CombatantState, slot: int) -> String:
	var item = combatant.equipped_items.get(slot)
	return item.display_name if item != null else "None"
