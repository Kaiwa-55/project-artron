class_name PartyMemberCard
extends PanelContainer

signal create_requested(slot: int)
signal edit_requested(slot: int)
signal remove_requested(slot: int)
signal leader_requested(slot: int)

@export var slot_index: int = 0
var character: CharacterData


func setup(p_slot: int, p_character: CharacterData, leader: bool) -> void:
	slot_index = p_slot
	character = p_character
	$Margin/Content/Leader.visible = leader and character != null
	$Margin/Content/Portrait.texture = character.token_texture if character != null else null
	$Margin/Content/Name.text = character.display_name if character != null else "EMPTY CHARACTER SLOT"
	$Margin/Content/Class.text = _identity_text() if character != null else "Create a hero for Slot %d" % (slot_index + 1)
	$Margin/Content/Stats.text = _stats_text() if character != null else "You may begin the Run without filling every slot."
	$Margin/Content/Ready.text = "● READY FOR ADVENTURE" if character != null else ""
	$Margin/Content/Actions/Create.visible = character == null
	$Margin/Content/Actions/Edit.visible = character != null
	$Margin/Content/Actions/Remove.visible = character != null


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	$Margin/Content/Actions/Create.pressed.connect(func(): create_requested.emit(slot_index))
	$Margin/Content/Actions/Edit.pressed.connect(func(): edit_requested.emit(slot_index))
	$Margin/Content/Actions/Remove.pressed.connect(func(): remove_requested.emit(slot_index))


func _on_gui_input(event: InputEvent) -> void:
	if character != null and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		leader_requested.emit(slot_index)


func _identity_text() -> String:
	var ancestry_name: String = String(character.ancestry.display_name) if character.ancestry != null else "Unknown"
	var class_name_text: String = String(character.character_class.display_name) if character.character_class != null else "Adventurer"
	return "%s · %s · LEVEL %d" % [ancestry_name.to_upper(), class_name_text.to_upper(), character.level]


func _stats_text() -> String:
	var state := character.create_combatant_state()
	AncestrySystem.new().apply_ancestry(state)
	CharacterClassSystem.new().apply_class(state)
	StatSystem.new().refresh_combatant(state)
	return "Maximum HP                 %d\nAction Points                 %d\nSpeed                         %.0f ft\nReflex / Fort / Will      %d / %d / %d" % [state.max_hp, state.max_ap, state.speed, state.reflex, state.fortitude, state.will]
