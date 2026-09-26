extends RefCounted

const CharacterPanelScript := preload("res://scenes/ui/inventory_and_more.gd")

var host
var combat_system
var inventory_drawer: Control


func _init(p_host) -> void:
	host = p_host
	combat_system = host.combat_system


func build() -> void:
	inventory_drawer = host.get_node("UILayer/Control/CharacterPanel")
	host.inventory_drawer = inventory_drawer
	inventory_drawer.equipment_change_requested.connect(host.change_inventory_item)
	if inventory_drawer.has_signal("item_use_requested"):
		inventory_drawer.item_use_requested.connect(host.use_item_from_menu)
	inventory_drawer.setup(combat_system, "player")
	host.inventory_list = inventory_drawer.content_list
	host.inventory_status = inventory_drawer.status_label
	host.character_summary = inventory_drawer.summary
	host.character_page_title = inventory_drawer.page_title
	host.character_tab_buttons = inventory_drawer.tab_buttons


func toggle_inventory() -> void:
	inventory_drawer.visible = not inventory_drawer.visible
	if inventory_drawer.visible:
		refresh_inventory()


func open_character_from_portrait() -> void:
	if inventory_drawer == null or host.is_movement_animating():
		return
	if combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement():
		return
	if host.action_menu_panel != null:
		host.action_menu_panel.hide()
	inventory_drawer.show()
	refresh_inventory()


func set_character_tab(tab_id: String) -> void:
	host.character_active_tab = tab_id
	if inventory_drawer != null and inventory_drawer.get_script() == CharacterPanelScript:
		inventory_drawer.set_tab(tab_id)
		return
	refresh_inventory()


func refresh_inventory() -> void:
	if inventory_drawer != null and inventory_drawer.get_script() == CharacterPanelScript:
		var displayed_actor: CombatantState = host.get_displayed_party_member()
		if displayed_actor != null and inventory_drawer.combatant_id != displayed_actor.id:
			inventory_drawer.setup(combat_system, displayed_actor.id)
		inventory_drawer.refresh()
		host.character_active_tab = inventory_drawer.active_tab
		return


func refresh_interaction_lock(state: CombatState, reaction_locked: bool) -> void:
	if inventory_drawer == null:
		return
	if inventory_drawer.get_script() == CharacterPanelScript:
		var displayed_actor: CombatantState = host.get_displayed_party_member()
		if displayed_actor != null and inventory_drawer.combatant_id != displayed_actor.id:
			inventory_drawer.setup(combat_system, displayed_actor.id)
		var current_actor: CombatantState = state.get_current_actor()
		var viewing_out_of_turn: bool = displayed_actor != null and (current_actor == null or displayed_actor.id != current_actor.id)
		inventory_drawer.set_changes_locked(reaction_locked or state.is_finished() or not host.is_player_party_turn() or viewing_out_of_turn)
	if reaction_locked and inventory_drawer.visible:
		inventory_drawer.visible = false


func change_inventory_item(item, slot: int) -> void:
	var result: ActionResult = combat_system.toggle_equipment(host.get_player_controlled_actor_id(), item, slot)
	host.sync_move_mode_from_state()
	if result.success:
		host.get_node("UILayer/Control").add_log_message("Inventory updated: %s." % item.display_name)
	else:
		host.get_node("UILayer/Control").add_log_message("Inventory failed: %s" % result.failure_reason)
	host.get_node("UILayer/Control").update_ui()
	refresh_inventory()


func is_two_handed_item(item) -> bool:
	if item == null or item.weapon_attack == null:
		return false
	for trait_data in item.weapon_attack.traits:
		if trait_data != null and trait_data.id == "two_handed":
			return true
	return false
