class_name WeaponEnhancementCatalog
extends RefCounted

const WEAPON_PATHS: Array[String] = [
	"res://data/equipment/sword.tres",
	"res://data/equipment/dagger.tres",
	"res://data/equipment/club.tres",
	"res://data/equipment/hand_axe.tres",
	"res://data/equipment/short_spear.tres",
	"res://data/equipment/long_spear.tres",
	"res://data/equipment/shortbow.tres",
	"res://data/equipment/greatsword.tres",
	"res://data/equipment/warhammer.tres",
	"res://data/equipment/crossbow.tres",
	"res://data/equipment/apprentice_staff.tres",
	"res://data/equipment/focus_staff.tres",
	"res://data/equipment/ember_staff.tres",
	"res://data/equipment/frost_staff.tres",
]


static func create_offers() -> Array[Resource]:
	var result: Array[Resource] = []
	for path in WEAPON_PATHS:
		var weapon: EquipmentData = load(path)
		if weapon == null or weapon.weapon_attack == null:
			continue
		for level in [1, 2]:
			var enhanced := weapon.create_enhanced(level)
			var offer := ShopOfferData.new()
			offer.product = enhanced
			offer.price = enhanced.purchase_price
			result.append(offer)
	return result
