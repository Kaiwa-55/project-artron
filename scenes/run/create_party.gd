extends Control

const CHARACTER_CREATION_SCENE := "res://scenes/character_creation/CharacterCreation.tscn"
const RUN_MAP_SCENE := "res://scenes/run/RunMap.tscn"

@onready var cards: Array[PartyMemberCard] = [$Margin/Layout/Main/Slots/Slot1, $Margin/Layout/Main/Slots/Slot2, $Margin/Layout/Main/Slots/Slot3]
@onready var count_label: Label = $Margin/Layout/Header/Count
@onready var summary_label: Label = $Margin/Layout/Main/Summary
@onready var status_label: Label = $Margin/Layout/Footer/Status
@onready var start_button: Button = $Margin/Layout/Footer/Start

var party_state: PartySetupState
var leader_slot: int = 0


func _ready() -> void:
	party_state = get_tree().get_meta("party_setup_state", PartySetupState.new()) as PartySetupState
	get_tree().set_meta("party_setup_state", party_state)
	for index in range(cards.size()):
		cards[index].create_requested.connect(open_character_creation)
		cards[index].edit_requested.connect(open_character_creation)
		cards[index].remove_requested.connect(remove_character)
		cards[index].leader_requested.connect(set_leader)
	$Margin/Layout/Footer/Back.pressed.connect(back)
	start_button.pressed.connect(start_run)
	refresh()


func refresh() -> void:
	for index in range(cards.size()):
		var character: CharacterData = party_state.members[index] if index < party_state.members.size() else null
		cards[index].setup(index, character, index == leader_slot)
	var members := party_state.get_valid_members()
	count_label.text = "%d / 3   \nPARTY MEMBERS" % members.size()+"   "
	summary_label.text = "PARTY SUMMARY     Total Members  %d     Party Leader  %s" % [members.size(), _leader_name()]
	start_button.disabled = members.is_empty()
	status_label.text = "Create at least one character. Each hero keeps separate progression."


func open_character_creation(slot: int) -> void:
	get_tree().set_meta("party_creation_slot", slot)
	get_tree().set_meta("party_creation_return_scene", scene_file_path)
	get_tree().change_scene_to_file(CHARACTER_CREATION_SCENE)


func remove_character(slot: int) -> void:
	party_state.remove_member(slot)
	leader_slot = clampi(leader_slot, 0, maxi(0, party_state.get_valid_members().size() - 1))
	refresh()


func set_leader(slot: int) -> void:
	leader_slot = slot
	refresh()


func start_run() -> void:
	var members := party_state.get_valid_members()
	if members.is_empty():
		return
	if leader_slot > 0 and leader_slot < party_state.members.size():
		var leader := party_state.members[leader_slot]
		if leader != null:
			party_state.members.remove_at(leader_slot)
			party_state.members.push_front(leader)
	get_tree().set_meta("active_party_characters", party_state.get_valid_members())
	get_tree().change_scene_to_file(RUN_MAP_SCENE)


func back() -> void:
	get_tree().quit()


func _leader_name() -> String:
	if leader_slot >= 0 and leader_slot < party_state.members.size() and party_state.members[leader_slot] != null:
		return party_state.members[leader_slot].display_name
	return "None"
