class_name EncounterData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var battlefield_texture: Texture2D
@export var map_size_feet: Vector2 = Vector2(250.0, 250.0)
# Positions and radii are authored in feet relative to the map center.
# "obstacle" objects currently feed both MapRules and battlefield visuals.
@export var map_objects: Array[Dictionary] = []
# Each entry supports: character (CharacterData), id, display_name,
# position_feet and use_created_character. Positions are map-center relative.
@export var player_team: int = 1
@export var player_party: Array[Dictionary] = []
@export var enemies: Array[CharacterData] = []
