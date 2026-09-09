class_name ItemStackData
extends Resource

@export var item: ItemData
@export_range(1, 999) var quantity: int = 1


func create_runtime_stack() -> ItemStack:
	return ItemStack.new(item, quantity)
