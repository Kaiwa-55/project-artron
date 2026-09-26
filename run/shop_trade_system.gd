class_name ShopTradeSystem
extends RefCounted


static func sell_unit_price(entry) -> int:
	if entry is ItemStack and entry.item != null and entry.item.category != ItemData.Category.QUEST:
		return maxi(0, entry.item.sell_price)
	if entry is EquipmentData:
		return maxi(0, floori(entry.purchase_price / 2.0))
	return 0


static func sell(member: CombatantState, entry, quantity: int) -> int:
	if member == null or quantity <= 0:
		return 0
	var unit_price := sell_unit_price(entry)
	if unit_price <= 0:
		return 0
	if entry is ItemStack:
		if not member.item_inventory.has(entry) or entry.quantity < quantity:
			return 0
		entry.quantity -= quantity
		if entry.quantity == 0:
			member.item_inventory.erase(entry)
		return unit_price * quantity
	if entry is EquipmentData:
		if quantity != 1 or not member.equipment_inventory.has(entry) or member.equipped_items.values().has(entry):
			return 0
		member.equipment_inventory.erase(entry)
		return unit_price
	return 0
