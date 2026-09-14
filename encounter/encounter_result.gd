class_name EncounterResult
extends RefCounted

enum Type {
	VICTORY,
	PARTIAL_VICTORY,
	DEFEAT,
	ESCAPE,
}

var type: Type
var details: Dictionary


func _init(p_type: Type, p_details: Dictionary = {}) -> void:
	type = p_type
	details = p_details
