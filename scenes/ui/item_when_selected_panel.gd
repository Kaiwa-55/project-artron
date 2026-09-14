class_name ItemWhenSelectedPanel
extends PanelContainer

@onready var name_label: Label = $NinePatchRect/VBox/Name
@onready var trait_label: Label = $NinePatchRect/VBox/Trait
@onready var item_image: TextureRect = $NinePatchRect/Item_image
@onready var value_label: Label = $NinePatchRect/HBoxContainer/VBox2/Ability
@onready var description_label: Label = $NinePatchRect/Description

var entry


func _ready() -> void:
	_set_mouse_passthrough(self)
	$ExitButton.visible = false


func setup(value) -> void:
	entry = value
	var data = _unwrap(value)
	if data == null:
		clear()
		return
	name_label.text = data.display_name if "display_name" in data else "Item"
	description_label.text = data.description if "description" in data else ""
	item_image.texture = data.icon_texture if "icon_texture" in data else null
	var attack = data.weapon_attack if "weapon_attack" in data else null
	trait_label.text = _trait_text(data, attack)
	value_label.text = _value_text(data, attack)


func clear() -> void:
	entry = null
	name_label.text = "Item"
	trait_label.text = ""
	item_image.texture = null
	value_label.text = "-\n-\n-\n-\n-\n-"
	description_label.text = ""


func _unwrap(value):
	if value != null and "item" in value and "quantity" in value:
		return value.item
	return value


func _trait_text(data, attack) -> String:
	var names: Array[String] = []
	var traits: Array = attack.traits if attack != null else (data.traits if "traits" in data else [])
	for trait_data in traits:
		if trait_data == null:
			continue
		var display: String = trait_data.display_name if "display_name" in trait_data and not trait_data.display_name.is_empty() else trait_data.id
		names.append(display)
	return ", ".join(names) if not names.is_empty() else "Item"


func _value_text(data, attack) -> String:
	if attack != null:
		return "%s\n%s\n%+d\n%s\n%d %s\n%s ft" % [
			_enum_name(AttributeTypes.Type, attack.attack_attribute),
			_enum_name(DefenseTypes.Type, attack.defense_type),
			attack.to_hit_bonus,
			"Attribute" if attack.uses_attribute_damage_modifier else "+0",
			attack.base_damage,
			attack.damage_type.capitalize(),
			_number(attack.range_feet),
		]
	if "reflex_bonus" in data:
		var defense := "R%+d F%+d W%+d" % [data.reflex_bonus, data.fortitude_bonus, data.will_bonus]
		return "-\n%s\n-\n-\n-\n-" % defense
	var range_text := _number(data.range_feet) if "range_feet" in data else "-"
	return "-\n-\n-\n-\n-\n%s%s" % [range_text, " ft" if range_text != "-" else ""]


func _enum_name(enum_values: Dictionary, value: int) -> String:
	for key in enum_values:
		if int(enum_values[key]) == value:
			return String(key).capitalize()
	return "-"


func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


func _set_mouse_passthrough(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_passthrough(child)
