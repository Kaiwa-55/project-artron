class_name ShopData
extends Resource

const WeaponEnhancements = preload("res://data/equipment/weapon_enhancement_catalog.gd")

@export var id: String = ""
@export_group("Shop Appearance")
@export var display_name: String = "Shop"
@export_multiline var description: String = ""
@export var banner_texture: Texture2D
@export_group("Stock")
@export var offers: Array[Resource] = []
@export var stock_enhanced_weapons: bool = false

var _enhanced_offers: Array[Resource] = []


func get_offers() -> Array[Resource]:
	if not stock_enhanced_weapons:
		return offers
	if _enhanced_offers.is_empty():
		_enhanced_offers = WeaponEnhancements.create_offers()
	return offers + _enhanced_offers
