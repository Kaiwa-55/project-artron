class_name RewardOptionData
extends Resource

enum RewardType { GOLD, MAX_HP, ABILITY_POINT, EXPERIENCE, ITEM, EQUIPMENT }

@export var id: String = ""
@export var reward_type: RewardType = RewardType.GOLD
@export var display_name: String = ""
@export var description: String = ""
@export var amount: int = 0
@export var product: Resource


func get_value_text() -> String:
	match reward_type:
		RewardType.GOLD:
			return "+%d Gold" % amount
		RewardType.MAX_HP:
			return "+%d Max HP" % amount
		RewardType.ABILITY_POINT:
			return "+%d Ability Point" % amount
		RewardType.EXPERIENCE:
			return "+%d XP to every hero" % amount
		RewardType.ITEM, RewardType.EQUIPMENT:
			return "%s x%d" % [product.display_name, amount] if product != null else ""
	return ""
