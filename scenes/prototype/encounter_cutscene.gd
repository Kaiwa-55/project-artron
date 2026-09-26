extends Control

const COMBAT_SCENE := "res://scenes/prototype/PrototypeCombat.tscn"

@onready var image_rect: TextureRect = $Image
@onready var title_label: Label = $CaptionBackdrop/CaptionMargin/Caption/Copy/Title
@onready var description_label: Label = $CaptionBackdrop/CaptionMargin/Caption/Copy/Description
@onready var continue_button: Button = $CaptionBackdrop/CaptionMargin/Caption/ContinueButton

var transition_started := false


func _ready() -> void:
	var encounter := get_tree().get_meta("active_encounter_data", null) as EncounterData
	if encounter == null or encounter.cutscene_image == null:
		push_error("Encounter cutscene needs an active encounter with a cutscene image.")
		return
	image_rect.texture = encounter.cutscene_image
	title_label.text = encounter.get_encounter_name()
	description_label.text = encounter.encounter_description
	continue_button.pressed.connect(start_combat)
	continue_button.grab_focus.call_deferred()
	image_rect.modulate.a = 0.0
	create_tween().tween_property(image_rect, "modulate:a", 1.0, 0.55)


func start_combat() -> void:
	if transition_started:
		return
	transition_started = true
	var change_error := get_tree().change_scene_to_file(COMBAT_SCENE)
	if change_error != OK:
		transition_started = false
		description_label.text = "Could not start encounter: %s" % error_string(change_error)
