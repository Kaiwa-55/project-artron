class_name EncounterData
extends Resource

enum Type {
	COMBAT,
	AMBUSH,
	DEFENSE,
	SURVIVAL,
	ESCAPE,
	BOSS,
}

@export var id: String = ""
@export var display_name: String = ""
@export var encounter_name: String = ""
@export_multiline var encounter_description: String = ""
@export var encounter_image: Texture2D
@export var type: Type = Type.COMBAT
@export var battlefield_texture: Texture2D
@export var battlefield: PackedScene
@export var map_size_feet: Vector2 = Vector2(250.0, 250.0)
# Positions and radii are authored in feet relative to the map center.
# "obstacle" objects currently feed both MapRules and battlefield visuals.
@export var map_objects: Array[Dictionary] = []
# Each entry supports: character (CharacterData), id, display_name,
# position_feet and use_created_character. Positions are map-center relative.
@export var player_team: int = 1
@export var player_party: Array[Dictionary] = []
# Spawn positions are matched to party members by index and are authored in
# feet relative to the map center. These also apply to parties from RunState.
@export var player_spawn_positions_feet: Array[Vector2] = []
@export var enemies: Array[CharacterData] = []
# Optional data-driven extensions. The existing prototype can continue using
# `enemies`, while authored encounters may group enemies and define objectives.
@export var enemy_groups: Array[Resource] = []
@export var objectives: Array[Resource] = []
@export var victory_event: Resource
@export var partial_victory_event: Resource
@export var defeat_event: Resource
@export var escape_event: Resource
@export var rewards: Array[Resource] = []


func get_encounter_name() -> String:
	return encounter_name if not encounter_name.is_empty() else display_name


func get_player_spawn_position_feet(index: int, party_entry: Dictionary = {}) -> Vector2:
	if index >= 0 and index < player_spawn_positions_feet.size():
		return player_spawn_positions_feet[index]
	if party_entry.has("position_feet"):
		return Vector2(party_entry.get("position_feet", Vector2.ZERO))
	# Safe formation fallback for older EncounterData resources.
	return Vector2(-40.0 - index * 16.0, -83.3333 + index * 18.0)
