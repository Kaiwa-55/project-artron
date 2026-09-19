class_name PreCombatStatusSystem
extends RefCounted


func apply(encounter: EncounterData, combatants: Array[CombatantState], effect_system: EffectSystem) -> int:
	if encounter == null or effect_system == null:
		return 0
	var applied_count := 0
	for entry in encounter.pre_combat_statuses:
		if entry == null:
			continue
		# Allow an EffectData to be dropped directly into the Resource array as a
		# convenient shorthand for applying it once to the whole player party.
		var status_effect: EffectData = entry as EffectData
		var applications := 1
		var is_player_party_target := status_effect != null
		if status_effect == null:
			if not entry.has_method("matches"):
				continue
			status_effect = entry.get("effect") as EffectData
			applications = maxi(1, int(entry.get("applications")))
		if status_effect == null:
			continue
		for combatant in combatants:
			var matches_target := combatant.team == encounter.player_team if is_player_party_target else bool(entry.matches(combatant, encounter.player_team))
			if not matches_target:
				continue
			for application in applications:
				if effect_system.apply_effect(combatant, status_effect, "pre_combat", "Pre-combat Status"):
					applied_count += 1
	return applied_count
