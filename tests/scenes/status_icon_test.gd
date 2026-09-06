extends SceneTree

const CombatantNode = preload("res://entities/combatant.gd")
const Bleeding = preload("res://data/status/bleeding.tres")
const Haste = preload("res://data/status/haste.tres")
const SacredWard = preload("res://data/ability/effect/sacred_ward_defenses.tres")
const TestIcon = preload("res://assets/icon/skill_icons22.png")

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _init() -> void:
	var state := CombatantState.new()
	state.id = "status_test"
	state.collision_radius_feet = 2.5
	state.add_effect(Bleeding)
	state.add_effect(Bleeding)
	state.add_effect(Bleeding)
	var haste_with_icon: EffectData = Haste.duplicate(true)
	haste_with_icon.icon_texture = TestIcon
	state.add_effect(haste_with_icon)
	state.add_effect(SacredWard)
	var token := CombatantNode.new()
	root.add_child(token)
	token.setup(state)
	var layer: Control = token.get_node("StatusIcons")
	check(layer.get_child_count() == 2, "Only status Effects create icons; ordinary buffs do not")
	var bleeding_icon: Control = layer.get_node("Status_bleeding")
	check(bleeding_icon.tooltip_text.contains("3 stacks"), "Status tooltip displays stack count")
	check(layer.get_node("Status_haste") != null, "Each active status receives its own icon")
	check(layer.get_node("Status_haste").get_node("Content/Texture") != null, "A Status can display its configured texture")
	check(not bleeding_icon.position.is_equal_approx(layer.get_node("Status_haste").position), "Multiple icons occupy separate positions around the token")
	state.remove_status("haste")
	token.refresh_from_state()
	check(layer.get_child_count() == 1 and layer.has_node("Status_bleeding"), "Icons update when a status expires")

	for failure in failures:
		push_error(failure)
	print("STATUS_ICON_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
