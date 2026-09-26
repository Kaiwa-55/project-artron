extends RefCounted

const GMConsoleScript := preload("res://scenes/prototype/gm_console.gd")
const CreationCatalog := preload("res://data/creation/default_creation_catalog.tres")

var host
var combat_system
var gm_console


func _init(p_host) -> void:
	host = p_host
	combat_system = host.combat_system


func build() -> void:
	if gm_console != null:
		return
	gm_console = GMConsoleScript.new()
	gm_console.name = "GMConsole"
	gm_console.z_index = 40
	# Debug controls must remain above the presentation input blocker (layer 50).
	var console_layer := CanvasLayer.new()
	console_layer.name = "GMConsoleLayer"
	console_layer.layer = 60
	host.get_node("UILayer/Control").add_child(console_layer)
	console_layer.add_child(gm_console)
	host.gm_console = gm_console
	gm_console.configure(CreationCatalog.classes, CreationCatalog.get_abilities(), CreationCatalog.get_skills())
	gm_console.class_requested.connect(_gm_change_class)
	gm_console.ability_requested.connect(_gm_grant_ability)
	gm_console.skill_requested.connect(_gm_grant_skill)
	gm_console.attribute_requested.connect(_gm_change_attribute)
	gm_console.command_requested.connect(_gm_command)


func handle_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.keycode != KEY_F1 or gm_console == null:
		return
	# Handle the global shortcut before focused controls can consume it.
	host.get_viewport().set_input_as_handled()
	if not event.pressed or event.echo:
		return
	gm_console.toggle_console()
	if gm_console.visible:
		var character := _gm_character()
		gm_console.set_status("Character: %s" % character.display_name if character != null else "No character available.")


func _gm_character() -> CombatantState:
	var character: CombatantState = host.get_displayed_party_member()
	return character if character != null else host.get_player_controlled_actor()


func _gm_target(character: CombatantState, command: String) -> CombatantState:
	var state = combat_system.get_combat_state()
	var selected: CombatantState = state.get_combatant(host.selected_character_id)
	if selected != null and selected.is_alive():
		return selected
	if command == "heal_target":
		return character
	var target: CombatantState = state.get_combatant(host.selected_target_id)
	if target != null and target.is_alive():
		return target
	for candidate in state.combatants.values():
		if candidate != null and candidate.team != character.team and candidate.is_alive():
			return candidate
	return null


func _gm_change_class(class_data) -> void:
	var character := _gm_character()
	if character == null or class_data == null:
		gm_console.set_status("Class change failed: no character.")
		return
	var previous = character.get_meta("class_data", null)
	if previous != null:
		var reversed_bonuses: Dictionary = {}
		for attribute in previous.fixed_attribute_bonuses:
			reversed_bonuses[attribute] = -int(previous.fixed_attribute_bonuses[attribute])
		CharacterClassSystem.new().apply_fixed_attribute_bonuses(character, reversed_bonuses)
		if previous.base_speed_feet >= 0.0: character.base_speed -= previous.base_speed_feet
		if previous.base_mana >= 0: character.base_max_mana = 0
		if previous.base_faith >= 0: character.base_max_faith = 0
		for trait_data in previous.traits:
			character.active_traits.erase(trait_data)
		for ability in previous.granted_abilities:
			character.available_abilities.erase(ability)
			character.equipped_abilities.erase(ability.id)
	character.set_meta("class_data", class_data)
	CharacterClassSystem.new().apply_class(character)
	StatSystem.new().refresh_combatant(character)
	combat_system.ability_system.sync_granted_reactions(character)
	host.refresh_essential_hud()
	host.refresh_action_dock()
	gm_console.set_status("%s changed to %s." % [character.display_name, class_data.display_name])
	host.get_node("UILayer/Control").add_log_message("GM: %s is now %s." % [character.display_name, class_data.display_name])


func _gm_grant_ability(ability) -> void:
	var character := _gm_character()
	if character == null or ability == null:
		gm_console.set_status("Grant failed: no character or ability.")
		return
	if not character.available_abilities.has(ability): character.available_abilities.append(ability)
	if not ability.is_passive and not ability.reaction_only and not character.equipped_abilities.has(ability.id): character.equipped_abilities.append(ability.id)
	combat_system.ability_system.sync_granted_reactions(character)
	host.refresh_essential_hud()
	host.refresh_action_dock()
	gm_console.set_status("Granted %s to %s." % [ability.display_name, character.display_name])
	host.get_node("UILayer/Control").add_log_message("GM: granted %s." % ability.display_name)


func _gm_grant_skill(skill) -> void:
	var character := _gm_character()
	if character == null or skill == null:
		gm_console.set_status("Grant Skill failed: no character or skill.")
		return
	if not character.available_skills.has(skill):
		character.available_skills.append(skill)
	_sync_gm_character_to_run()
	host.refresh_action_dock()
	gm_console.set_status("Granted Skill %s to %s." % [skill.display_name, character.display_name])
	host.get_node("UILayer/Control").add_log_message("GM: granted Skill %s." % skill.display_name)


func _gm_change_attribute(attribute_name: String, delta: int) -> void:
	var character := _gm_character()
	var attributes := {"STR": "strength", "DEX": "dexterity", "CON": "constitution", "INT": "intelligence", "WIS": "wisdom", "CHA": "charisma"}
	var property_name: String = attributes.get(attribute_name, "")
	if character == null or property_name.is_empty():
		gm_console.set_status("Attribute change failed.")
		return
	character.set(property_name, maxi(1, int(character.get(property_name)) + delta))
	StatSystem.new().refresh_combatant(character)
	_sync_gm_character_to_run()
	host.refresh_essential_hud()
	host.refresh_combatant_nodes()
	host.refresh_action_dock()
	gm_console.set_status("%s %s: %d." % [character.display_name, attribute_name, int(character.get(property_name))])
	host.get_node("UILayer/Control").add_log_message("GM: %s %s changed to %d." % [character.display_name, attribute_name, int(character.get(property_name))])


func _sync_gm_character_to_run() -> void:
	if host.has_method("sync_run_party_state"):
		host.call("sync_run_party_state")


func _gm_command(command: String) -> void:
	if command == "reset_combat":
		if host.has_method("reset_combat"):
			host.call("reset_combat")
		return
	var character := _gm_character()
	if character == null:
		gm_console.set_status("Command failed: no character.")
		return
	var result_message := ""
	match command:
		"full_resources":
			character.hp = character.max_hp
			character.mana = character.max_mana
			character.faith = character.max_faith
			character.ap = character.max_ap
			result_message = "%s: resources restored." % character.display_name
		"reset_turn":
			character.ap = character.max_ap
			character.attacks_declared_this_turn = 0
			character.movement_remaining_feet = character.get_effective_speed()
			result_message = "%s: turn reset." % character.display_name
		"damage_target", "heal_target":
			var target := _gm_target(character, command)
			if target != null:
				target.hp = clampi(target.hp + (-5 if command == "damage_target" else 5), 0, target.max_hp)
				result_message = "%s: %s 5 HP." % [target.display_name, "damaged" if command == "damage_target" else "healed"]
			else:
				result_message = "Command failed: no target."
	host.refresh_essential_hud()
	host.refresh_combatant_nodes()
	host.refresh_action_dock()
	gm_console.set_status(result_message)
	host.get_node("UILayer/Control").add_log_message("GM: %s" % result_message)
