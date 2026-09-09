class_name ItemStack
extends RefCounted

var item: ItemData
var quantity: int = 0


func _init(p_item: ItemData = null, p_quantity: int = 0) -> void:
	item = p_item
	quantity = maxi(0, p_quantity)


func consume(amount: int = 1) -> bool:
	if amount <= 0 or quantity < amount:
		return false
	quantity -= amount
	return true
