class_name EventContext
extends RefCounted

var game_state: GameState
var party: Array[CombatantState] = []
var actor_id: String = ""
var combat_system: CombatSystem
var rng: RandomNumberGenerator
var data: Dictionary = {}


func _init(p_game_state: GameState = null, p_party: Array[CombatantState] = []) -> void:
	game_state = p_game_state if p_game_state != null else GameState.new()
	party = p_party
	rng = RandomNumberGenerator.new()
	rng.randomize()


func get_actor(requested_id: String = "") -> CombatantState:
	var lookup_id := requested_id if not requested_id.is_empty() else actor_id
	if not lookup_id.is_empty():
		for member in party:
			if member != null and member.id == lookup_id:
				return member
		return null
	return party[0] if not party.is_empty() else null


func find_party_member(member_id: String) -> CombatantState:
	for member in party:
		if member != null and member.id == member_id:
			return member
	return null


func get_stat(member: CombatantState, stat_id: StringName) -> float:
	if member == null:
		return 0.0
	var property_name := String(stat_id).strip_edges().to_lower()
	if property_name in ["strength", "dexterity", "constitution", "intelligence", "wisdom", "charisma", "reflex", "fortitude", "will", "level", "hp", "mana", "ap", "faith"]:
		return float(member.get(property_name))
	return 0.0


func get_item_quantity(item_id: StringName, member: CombatantState = null) -> int:
	var candidates: Array[CombatantState] = [member] if member != null else party
	var total := 0
	for candidate in candidates:
		if candidate == null:
			continue
		for stack in candidate.item_inventory:
			if stack != null and stack.item != null and stack.item.id == String(item_id):
				total += stack.quantity
	return total
