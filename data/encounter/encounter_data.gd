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

## Author-controlled result for an Event Encounter when the party is defeated.
enum EventDefeatOutcome {
	END_RUN,
	REVIVE_AT_ONE_HP,
}

@export var id: String = ""
@export var display_name: String = ""
@export var encounter_name: String = ""
@export_multiline var encounter_description: String = ""
@export var encounter_image: Texture2D
## Optional image shown as a cutscene before this encounter starts.
@export var cutscene_image: Texture2D
@export var type: Type = Type.COMBAT
@export var battlefield_texture: Texture2D
@export var battlefield: PackedScene
## Optional shared 2.5D world. When set, Combat no longer builds a separate 2D map.
@export var building_map: BuildingMapData
@export var starting_surface_id: StringName = &"ground"
@export var map_size_feet: Vector2 = Vector2(250.0, 250.0)
@export_range(0, 3) var initial_light_level: int = 1
@export_group("Desert Storm")
@export var desert_storm_enabled: bool = false
@export_range(0.0, 1.0, 0.05) var desert_storm_intensity: float = 0.5
@export var desert_storm_wind: Vector2 = Vector2(1.0, 0.25)
@export_range(0.0, 5.0, 0.05) var desert_storm_speed: float = 1.0
@export_range(0.0, 20.0, 0.1) var desert_storm_density: float = 1.0
@export var desert_storm_color: Color = Color(0.88, 0.69, 0.40)
@export_range(0.0, 1.0, 0.05) var desert_storm_opacity: float = 0.45
@export_range(0.1, 5.0, 0.05) var desert_storm_particle_size: float = 1.0
@export_group("")
# Positions and radii are authored in feet relative to the map center.
# "obstacle" objects may independently use `blocks_movement` and
# `blocks_line_of_sight`; either defaults to true for older encounter data.
@export var map_objects: Array[Dictionary] = []
# Each entry supports: character (CharacterData), id, display_name,
# position_feet and use_created_character. Positions are map-center relative.
@export var player_team: int = 1
@export var player_party: Array[Dictionary] = []
# Spawn positions are matched to party members by index and are authored in
# feet relative to the map center. These also apply to parties from RunState.
@export var player_spawn_positions_feet: Array[Vector2] = []
## Optional random area for each party member, in feet from the map center.
## An empty rectangle keeps the authored fixed spawn position.
@export var player_spawn_areas_feet: Array[Rect2] = []
@export var enemies: Array[CharacterData] = []
# Optional data-driven extensions. The existing prototype can continue using
# `enemies`, while authored encounters may group enemies and define objectives.
@export var enemy_groups: Array[Resource] = []
@export var pre_combat_statuses: Array[Resource] = []
@export var objectives: Array[EncounterObjective] = []
@export var victory_event: Resource
@export var partial_victory_event: Resource
@export var defeat_event: Resource
@export var event_defeat_outcome: EventDefeatOutcome = EventDefeatOutcome.END_RUN
@export var escape_event: Resource
@export var rewards: Array[Resource] = []
## A victory continues directly into this encounter before opening Run rewards.
@export var next_encounter: EncounterData


func get_encounter_name() -> String:
	return encounter_name if not encounter_name.is_empty() else display_name


func get_player_spawn_position_feet(index: int, party_entry: Dictionary = {}, rng: RandomNumberGenerator = null) -> Vector2:
	if index >= 0 and index < player_spawn_areas_feet.size() and player_spawn_areas_feet[index].has_area():
		var area := player_spawn_areas_feet[index].abs()
		var generator := rng if rng != null else RandomNumberGenerator.new()
		if rng == null:
			generator.randomize()
		return Vector2(generator.randf_range(area.position.x, area.end.x), generator.randf_range(area.position.y, area.end.y))
	if index >= 0 and index < player_spawn_positions_feet.size():
		return player_spawn_positions_feet[index]
	if party_entry.has("position_feet"):
		return Vector2(party_entry.get("position_feet", Vector2.ZERO))
	# Safe formation fallback for older EncounterData resources.
	return Vector2(-40.0 - index * 16.0, -83.3333 + index * 18.0)
