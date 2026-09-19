class_name PreCombatStatus
extends Resource

enum TargetMode {
	PLAYER_PARTY,
	ENEMIES,
	TEAM,
	CHARACTER_ID,
	ALL_COMBATANTS,
}

@export var effect: EffectData
@export var target_mode: TargetMode = TargetMode.PLAYER_PARTY
@export var team: int = 1
@export var character_id: String = ""
@export_range(1, 99, 1) var applications: int = 1


func matches(combatant: CombatantState, player_team: int) -> bool:
	if combatant == null:
		return false
	match target_mode:
		TargetMode.PLAYER_PARTY:
			return combatant.team == player_team
		TargetMode.ENEMIES:
			return combatant.team != player_team
		TargetMode.TEAM:
			return combatant.team == team
		TargetMode.CHARACTER_ID:
			return not character_id.is_empty() and combatant.id == character_id
		TargetMode.ALL_COMBATANTS:
			return true
	return false
