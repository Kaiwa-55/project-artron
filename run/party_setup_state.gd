class_name PartySetupState
extends Resource

const MAX_MEMBERS := 3
var members: Array[CharacterData] = []


func set_member(slot: int, character: CharacterData) -> void:
	if slot < 0 or slot >= MAX_MEMBERS or character == null:
		return
	while members.size() <= slot:
		members.append(null)
	members[slot] = character


func remove_member(slot: int) -> void:
	if slot >= 0 and slot < members.size():
		members.remove_at(slot)


func get_valid_members() -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for member in members:
		if member != null:
			result.append(member)
	return result
