extends Button

const Card = preload("res://scenes/combat/ui/ActionDetailCard.tscn")

var detail_source: Resource
var detail_actor: CombatantState
var detail_system


func _make_custom_tooltip(for_text: String) -> Object:
	var card := Card.instantiate()
	card.setup(detail_source, detail_actor, detail_system, for_text)
	return card
