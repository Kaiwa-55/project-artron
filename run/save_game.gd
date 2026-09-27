extends Node

const SAVE_DIR := "user://saves"
const SAVE_VERSION := 1
const RUN_MAP := "res://scenes/run/RunMap.tscn"
const EXPLORATION := "res://scenes/exploration/DungeonExploration.tscn"
const REWARD := "res://scenes/run/RewardSelection.tscn"
const STATE_FIELDS := [
	"id", "display_name", "team", "level", "experience", "ability_points", "attribute_points",
	"progression_rewards_granted_through_level", "selected_ability_ids", "granted_ability_ids",
	"selected_level_attributes", "pending_level_up_choices", "selected_ability_costs_applied",
	"ancestry_id", "ancestry_display_name", "class_id", "class_display_name",
	"ancestry_attribute_choices", "class_attribute_choices", "strength", "dexterity", "constitution",
	"intelligence", "wisdom", "charisma", "base_max_hp", "base_max_mana", "base_max_ap",
	"base_max_faith", "base_speed", "max_hp_bonus", "ancestry_max_mana_bonus", "max_mana_bonus",
	"max_ap_bonus", "speed_bonus", "reflex_stat_bonus", "fortitude_stat_bonus", "will_stat_bonus",
	"hp", "mana", "ap", "faith", "temporary_faith", "max_finishing_gauge", "finishing_gauge",
	"life_state", "ability_uses_this_turn", "available_abilities", "equipped_abilities",
	"available_skills", "learned_spell_ids", "spell_choices_by_grantor", "skill_ranks",
	"active_traits", "active_reactions", "status_immunities", "damage_immunities",
	"damage_resistances", "skill_cooldowns", "ability_cooldowns", "ability_stacks",
	"effects",
	"item_inventory", "equipment_inventory", "active_weapon_slot", "starting_equipment_slots",
	"ammunition", "focus_draught_ready_bonus", "focus_draught_skill_bonus", "token_scale", "token_offset"
]

var active_slot: int = 0
var last_error: String = ""
var save_directory: String = SAVE_DIR


func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [save_directory, slot]


func get_slot_summary(slot: int) -> Dictionary:
	var snapshot := _read_snapshot(slot)
	if snapshot.is_empty():
		return {}
	return {"seed": int(snapshot.get("seed", 0)), "node": String(snapshot.get("node", "start")), "saved_at": String(snapshot.get("saved_at", "")), "phase": String(snapshot.get("phase", "map"))}


func save_active_run(phase: String = "map") -> bool:
	var run := get_tree().get_meta("active_run_state", null) as RunState
	return save_run(run, phase)


func save_run(run: RunState, phase: String = "map") -> bool:
	if run == null or active_slot < 1 or active_slot > 3:
		last_error = "No active Run or save slot."
		return false
	var party: Dictionary = {}
	for member_id in run.party_progression_states:
		var member: CombatantState = run.party_progression_states[member_id]
		if member != null:
			party[String(member_id)] = _save_member(member)
	var members: Array = []
	for member in run.party_character_data:
		members.append(_encode(member))
	var snapshot := {
		"version": SAVE_VERSION, "saved_at": Time.get_datetime_string_from_system(),
		"phase": phase, "seed": run.seed, "node": run.current_node_id,
		"act": run.act, "nodes": _encode(run.nodes), "completed": run.completed_node_ids,
		"claimed": run.reward_claimed_node_ids, "reward_history": _encode(run.reward_history),
		"gold": run.gold, "party_max_hp_bonus": run.party_max_hp_bonus,
		"party_ability_point_bonus": run.party_ability_point_bonus,
		"applied_party_ability_point_bonuses": run.applied_party_ability_point_bonuses,
		"game_state": _encode(run.game_state), "party": party, "party_characters": members,
		"exploration": _encode(run.get_meta("dungeondraft_exploration", {})),
		"dungeon_defeated": _encode(run.get_meta("dungeon_defeated_encounters", {}))
	}
	var directory := ProjectSettings.globalize_path(save_directory)
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		last_error = "Could not create the save directory."
		return false
	var final_path := ProjectSettings.globalize_path(slot_path(active_slot))
	var temp_path := final_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		last_error = "Could not write the save file."
		return false
	file.store_string(JSON.stringify(snapshot))
	file.flush()
	file.close()
	if FileAccess.file_exists(final_path):
		DirAccess.copy_absolute(final_path, final_path + ".bak")
	var error := DirAccess.rename_absolute(temp_path, final_path)
	if error != OK:
		last_error = "Could not finish writing the save file."
		return false
	last_error = ""
	return true


func load_slot(slot: int) -> bool:
	var snapshot := _read_snapshot(slot)
	if snapshot.is_empty():
		return false
	var run := _load_run(snapshot)
	if run == null:
		last_error = "Save data is incomplete."
		return false
	active_slot = slot
	var tree := get_tree()
	tree.set_meta("active_run_state", run)
	tree.set_meta("active_party_characters", run.party_character_data)
	for key in ["active_run_node_id", "active_encounter_data", "active_event_encounter", "active_event_encounter_data", "pending_event_encounter_result", "dungeon_combat_return", "restart_run_seed"]:
		if tree.has_meta(key):
			tree.remove_meta(key)
	var phase := String(snapshot.get("phase", "map"))
	if phase == "reward":
		tree.set_meta("active_run_node_id", run.current_node_id)
	var destination := EXPLORATION if phase == "exploration" else REWARD if phase == "reward" else RUN_MAP
	var error := tree.change_scene_to_file(destination)
	if error != OK:
		last_error = "Could not open the saved scene."
		return false
	last_error = ""
	return true


func _read_snapshot(slot: int) -> Dictionary:
	if slot < 1 or slot > 3:
		return {}
	for path in [slot_path(slot), slot_path(slot) + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and int(parsed.get("version", -1)) == SAVE_VERSION and parsed.get("party", null) is Dictionary and parsed.get("nodes", null) is Array:
			return parsed
	last_error = "No compatible save in this slot."
	return {}


func _load_run(snapshot: Dictionary) -> RunState:
	var run := RunState.new()
	run.seed = int(snapshot.get("seed", 0))
	run.act = int(snapshot.get("act", 1))
	run.current_node_id = String(snapshot.get("node", "start"))
	run.nodes.assign(_decode(snapshot.get("nodes", [])))
	if run.nodes.is_empty() or run.get_current_node() == null:
		return null
	run.completed_node_ids.assign(snapshot.get("completed", []))
	run.reward_claimed_node_ids.assign(snapshot.get("claimed", []))
	run.reward_history.assign(_decode(snapshot.get("reward_history", [])))
	run.gold = int(snapshot.get("gold", 0))
	run.party_max_hp_bonus = int(snapshot.get("party_max_hp_bonus", 0))
	run.party_ability_point_bonus = int(snapshot.get("party_ability_point_bonus", 0))
	run.applied_party_ability_point_bonuses = snapshot.get("applied_party_ability_point_bonuses", {})
	run.game_state = _decode(snapshot.get("game_state", {})) as GameState
	if run.game_state == null:
		return null
	for entry in snapshot.get("party_characters", []):
		var character := _decode(entry) as CharacterData
		if character != null:
			run.party_character_data.append(character)
	for member_id in snapshot.get("party", {}):
		var member := _load_member(snapshot["party"][member_id])
		if member != null:
			run.party_progression_states[String(member_id)] = member
	if run.party_progression_states.is_empty():
		return null
	run.player_progression_state = run.party_progression_states.get("player")
	run.applied_party_ability_point_bonus = int(run.applied_party_ability_point_bonuses.get("player", 0))
	run.set_meta("dungeondraft_exploration", _decode(snapshot.get("exploration", {})))
	run.set_meta("dungeon_defeated_encounters", _decode(snapshot.get("dungeon_defeated", {})))
	return run


func _save_member(member: CombatantState) -> Dictionary:
	var fields := {}
	for name in STATE_FIELDS:
		if name in ["equipment_inventory", "item_inventory"]:
			continue
		fields[name] = _encode(member.get(name))
	var equipment: Array = []
	for item in member.equipment_inventory:
		equipment.append(_encode(item))
	var equipped := {}
	for slot in member.equipped_items:
		var index := member.equipment_inventory.find(member.equipped_items[slot])
		if index >= 0:
			equipped[str(slot)] = index
	return {"fields": fields, "equipment": equipment, "equipped": equipped,
		"items": _encode(member.item_inventory), "token": _encode(member.token_texture),
		"ancestry": _encode(member.get_meta("ancestry_data", null)),
		"class": _encode(member.get_meta("class_data", null))}


func _load_member(saved: Dictionary) -> CombatantState:
	var member := CombatantState.new()
	_restore_fields(member, saved.get("fields", {}))
	member.equipment_inventory = _decode(saved.get("equipment", []))
	member.item_inventory.assign(_decode(saved.get("items", [])))
	for slot in saved.get("equipped", {}):
		var index := int(saved["equipped"][slot])
		if index >= 0 and index < member.equipment_inventory.size():
			member.equipped_items[int(slot)] = member.equipment_inventory[index]
	member.token_texture = _decode(saved.get("token", null)) as Texture2D
	member.set_meta("ancestry_data", _decode(saved.get("ancestry", null)))
	member.set_meta("class_data", _decode(saved.get("class", null)))
	member.set_meta("creation_rules_applied", true)
	EquipmentSystem.new().refresh_equipment(member)
	StatSystem.new().refresh_combatant(member)
	return member


func _encode(value: Variant) -> Variant:
	if value == null or value is bool or value is int or value is float or value is String or value is StringName:
		return str(value) if value is StringName else value
	if value is Vector2:
		return {"_kind": "vec2", "x": value.x, "y": value.y}
	if value is Vector3:
		return {"_kind": "vec3", "x": value.x, "y": value.y, "z": value.z}
	if value is Array:
		var output: Array = []
		for entry in value:
			output.append(_encode(entry))
		return output
	if value is Dictionary:
		var output := {}
		for key in value:
			output[str(key)] = _encode(value[key])
		return output
	if value is ItemStack:
		return {"_kind": "item_stack", "item": _encode(value.item), "quantity": value.quantity}
	if value is EffectInstance:
		return {"_kind": "effect_instance", "data": _encode(value.data), "remaining_turns": value.remaining_turns,
			"stack_count": value.stack_count, "source_ability_id": value.source_ability_id,
			"source_ability_name": value.source_ability_name, "source_combatant_id": value.source_combatant_id,
			"source_combatant_name": value.source_combatant_name, "source_class_dc": value.source_class_dc,
			"is_stance": value.is_stance}
	if value is EquipmentData and String(value.id).contains("_plus_"):
		var parts := String(value.id).rsplit("_plus_", true, 1)
		if parts.size() == 2 and parts[1].is_valid_int():
			return {"_kind": "enhanced", "base_id": parts[0], "level": int(parts[1])}
	if value is Texture2D:
		if not value.resource_path.is_empty() and value.resource_path.begins_with("res://"):
			return {"_kind": "resource", "path": value.resource_path}
		var image: Image = value.get_image()
		return {"_kind": "image", "png": Marshalls.raw_to_base64(image.save_png_to_buffer())} if image != null else null
	if value is Resource:
		if not value.resource_path.is_empty() and value.resource_path.begins_with("res://"):
			return {"_kind": "resource", "path": value.resource_path}
		var script: Script = value.get_script()
		if script == null or script.resource_path.is_empty():
			return null
		var fields := {}
		for property in value.get_property_list():
			var name := String(property.name)
			if int(property.usage) & PROPERTY_USAGE_STORAGE and name not in ["script", "resource_name", "resource_path", "resource_local_to_scene"]:
				fields[name] = _encode(value.get(name))
		return {"_kind": "object", "script": script.resource_path, "fields": fields}
	return null


func _decode(value: Variant) -> Variant:
	if value is Array:
		var result: Array = []
		for entry in value:
			result.append(_decode(entry))
		return result
	if not value is Dictionary:
		return value
	match String(value.get("_kind", "")):
		"vec2": return Vector2(float(value.get("x", 0)), float(value.get("y", 0)))
		"vec3": return Vector3(float(value.get("x", 0)), float(value.get("y", 0)), float(value.get("z", 0)))
		"resource":
			var path := String(value.get("path", ""))
			return load(path) if path.begins_with("res://data/") or path.begins_with("res://assets/") else null
		"enhanced":
			var base_id := String(value.get("base_id", ""))
			for path in WeaponEnhancementCatalog.WEAPON_PATHS:
				var base: EquipmentData = load(path)
				if base != null and base.id == base_id:
					return base.create_enhanced(int(value.get("level", 0)))
			return null
		"image":
			var image := Image.new()
			if image.load_png_from_buffer(Marshalls.base64_to_raw(String(value.get("png", "")))) == OK:
				return ImageTexture.create_from_image(image)
			return null
		"item_stack": return ItemStack.new(_decode(value.get("item", null)), int(value.get("quantity", 0)))
		"effect_instance":
			var data := _decode(value.get("data", null)) as EffectData
			if data == null:
				return null
			var effect := EffectInstance.new(data, String(value.get("source_ability_id", "")), String(value.get("source_ability_name", "")), bool(value.get("is_stance", false)), String(value.get("source_combatant_id", "")), int(value.get("source_class_dc", 0)))
			effect.remaining_turns = int(value.get("remaining_turns", data.duration_turns))
			effect.stack_count = int(value.get("stack_count", 1))
			effect.source_combatant_name = String(value.get("source_combatant_name", ""))
			return effect
		"object":
			var path := String(value.get("script", ""))
			if not (path.begins_with("res://data/") or path.begins_with("res://run/") or path.begins_with("res://core/state/")):
				return null
			var script: Script = load(path)
			if script == null:
				return null
			var object = script.new()
			_restore_fields(object, value.get("fields", {}))
			return object
	var result := {}
	for key in value:
		result[key] = _decode(value[key])
	return result


func _restore_fields(object: Object, fields: Dictionary) -> void:
	var valid_names := {}
	for property in object.get_property_list():
		valid_names[String(property.name)] = true
	for name in fields:
		if not valid_names.has(String(name)):
			continue
		var decoded = _decode(fields[name])
		var current = object.get(name)
		if current is Array and decoded is Array:
			current.assign(decoded)
			object.set(name, current)
		else:
			object.set(name, decoded)
