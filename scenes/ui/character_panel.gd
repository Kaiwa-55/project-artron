class_name CharacterPanel
extends Control

signal equipment_change_requested(item, slot: int)
signal closed

var combat_system
var combatant_id := "player"
var active_tab := "abilities"
var changes_locked := false
var summary: VBoxContainer
var content_list: VBoxContainer
var page_title: Label
var status_label: Label
var tab_buttons: Dictionary = {}
var standalone_character: CombatantState


func setup(system, target_id: String = "player") -> void:
	combat_system = system
	standalone_character = null
	combatant_id = target_id
	set_tab(active_tab)


func setup_standalone(player: CombatantState, initial_tab: String = "inventory", allow_equipment_changes: bool = false) -> void:
	combat_system = null
	standalone_character = player
	changes_locked = not allow_equipment_changes
	set_tab(initial_tab)


func set_changes_locked(value: bool) -> void:
	# Preserve live buttons between mouse-down and mouse-up during arena polling.
	if changes_locked == value:
		return
	changes_locked = value
	if visible:
		refresh()


func set_tab(tab_id: String) -> void:
	if tab_id in ["abilities", "equipment", "inventory"]:
		active_tab = tab_id
		refresh()


func refresh() -> void:
	pass


func _get_character() -> CombatantState:
	if standalone_character != null:
		return standalone_character
	if combat_system != null and combat_system.get_combat_state() != null:
		return combat_system.get_combat_state().get_combatant(combatant_id)
	return null


func _is_two_handed(item) -> bool:
	if item == null or item.weapon_attack == null:
		return false
	for trait_data in item.weapon_attack.traits:
		if trait_data != null and trait_data.id == "two_handed":
			return true
	return false


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func close() -> void:
	hide()
	closed.emit()
