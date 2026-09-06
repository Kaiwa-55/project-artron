extends SceneTree

const IronSword = preload("res://data/attack/iron_sword.tres")
const LongSpear = preload("res://data/attack/long_spear.tres")
const EnemySword = preload("res://data/attack/enemy_sword.tres")

func _init() -> void:
	var passed := has_trait(IronSword, "simple") and not has_trait(IronSword, "advanced") \
		and has_trait(EnemySword, "simple") and has_trait(LongSpear, "advanced") \
		and not has_trait(LongSpear, "simple") and has_trait(LongSpear, "two_handed") \
		and has_trait(IronSword, "slash") and has_trait(IronSword, "shield_compatible") \
		and has_trait(LongSpear, "reach") and has_trait(LongSpear, "pierce")
	print("WEAPON_CATEGORY_TRAIT_TEST: PASS" if passed else "WEAPON_CATEGORY_TRAIT_TEST: FAIL")
	quit(0 if passed else 1)

func has_trait(attack, trait_id: String) -> bool:
	for trait_data in attack.traits:
		if trait_data != null and trait_data.id == trait_id:
			return true
	return false
