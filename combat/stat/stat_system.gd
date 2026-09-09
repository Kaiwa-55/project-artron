class_name StatSystem
extends RefCounted


func initialize_combatant(combatant: CombatantState) -> void:
	refresh_combatant(combatant, true)


func refresh_combatant(
	combatant: CombatantState,
	reset_resources: bool = false
) -> void:
	if combatant == null:
		return

	combatant.max_hp = max(
		1,
		combatant.base_max_hp \
		+ combatant.get_modifier(combatant.constitution) * combatant.level \
		+ combatant.max_hp_bonus
	)
	combatant.max_mana = max(
		0,
		combatant.base_max_mana
		+ combatant.ancestry_max_mana_bonus
		+ combatant.max_mana_bonus
	)
	combatant.max_ap = max(0, combatant.base_max_ap + combatant.max_ap_bonus)
	combatant.max_faith = max(0, combatant.base_max_faith + AbilitySystem.new().get_passive_max_faith_bonus(combatant))
	combatant.speed = max(0.0, combatant.base_speed + combatant.speed_bonus)

	combatant.reflex = 10 \
		+ combatant.get_modifier(combatant.dexterity) \
		+ combatant.reflex_stat_bonus \
		+ combatant.equipment_reflex_bonus
	combatant.fortitude = 10 \
		+ combatant.get_modifier(combatant.constitution) \
		+ combatant.fortitude_stat_bonus \
		+ combatant.equipment_fortitude_bonus
	combatant.will = 10 \
		+ combatant.get_modifier(combatant.wisdom) \
		+ combatant.will_stat_bonus \
		+ combatant.equipment_will_bonus

	if reset_resources:
		combatant.hp = combatant.max_hp
		combatant.mana = combatant.max_mana
		combatant.ap = combatant.max_ap
		combatant.finishing_gauge = 0
		combatant.faith = combatant.max_faith
	else:
		combatant.hp = clampi(combatant.hp, 0, combatant.max_hp)
		combatant.mana = clampi(combatant.mana, 0, combatant.max_mana)
		combatant.ap = clampi(combatant.ap, 0, combatant.max_ap)
		combatant.finishing_gauge = clampi(combatant.finishing_gauge, 0, combatant.max_finishing_gauge)
		combatant.faith = clampi(combatant.faith, 0, combatant.max_faith)
