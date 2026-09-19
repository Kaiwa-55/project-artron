extends Button

const Card = preload("res://scenes/combat/ui/ActionDetailCard.tscn")

var detail_source: Resource
var detail_actor: CombatantState
var detail_system
var _tooltip_card: WeakRef


func _make_custom_tooltip(for_text: String) -> Object:
	var card := Card.instantiate()
	card.setup(detail_source, detail_actor, detail_system, for_text)
	_tooltip_card = weakref(card)
	return card


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_WHEEL_UP and event.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return
	var card = _tooltip_card.get_ref() if _tooltip_card != null else null
	if card == null or not card.is_inside_tree():
		return
	var description: RichTextLabel = card.get_node("Column/DescriptionViewport/Description")
	var direction := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
	description.get_v_scroll_bar().value += direction * 24.0
	accept_event()
