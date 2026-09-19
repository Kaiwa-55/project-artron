class_name ShopOfferData
extends Resource

@export var product: Resource
@export var icon_texture: Texture2D
@export_range(1, 99) var quantity: int = 1
@export_range(0, 9999) var price: int = 0
