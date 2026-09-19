class_name EncounterObjective
extends Resource

enum Type {
	DEFEAT_ALL,
	DEFEAT_TARGET,
	SURVIVE_TURNS,
	REACH_AREA,
}

@export var id: StringName
@export_multiline var description: String = ""
@export var type: Type = Type.DEFEAT_ALL
@export var required: bool = true

# DefeatAll
@export var target_team: int = 2

# DefeatTarget
@export var target_id: String = ""

# SurviveTurns
@export_range(1, 999, 1) var turn_count: int = 1

# ReachArea. Empty actor_id means any living member of actor_team may reach it.
@export var actor_id: String = ""
@export var actor_team: int = 1
@export var area_center_feet: Vector2 = Vector2.ZERO
@export_range(0.1, 999.0, 0.1) var area_radius_feet: float = 5.0


func get_display_text() -> String:
	if not description.is_empty():
		return description
	match type:
		Type.DEFEAT_ALL:
			return "Defeat all enemies"
		Type.DEFEAT_TARGET:
			return "Defeat %s" % target_id
		Type.SURVIVE_TURNS:
			return "Survive %d turns" % turn_count
		Type.REACH_AREA:
			return "Reach the target area"
	return "Objective"
