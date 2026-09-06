class_name InitiativeSystem
extends RefCounted


var dice_system: DiceSystem


func _init(
	p_dice_system: DiceSystem
) -> void:

	dice_system = p_dice_system


func get_buff_initiative_bonus(
	combatant: CombatantState
) -> int:

	# Phase 1:
	# Buff System ยังไม่ได้ Implement
	return 0


func roll_initiative(
	combatant: CombatantState
) -> int:

	var roll := dice_system.roll_3d8()

	return (
		roll
		+ combatant.wisdom
		+ combatant.initiative_bonus
		+ get_buff_initiative_bonus(combatant)
	)

func build_turn_order(
	combatants: Array[CombatantState]
) -> Array[String]:

	var entries: Array[Dictionary] = []

	for combatant in combatants:

		combatant.initiative = \
			roll_initiative(combatant)

		entries.append({
			"id": combatant.id,
			"initiative": combatant.initiative
		})

	entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return a["initiative"] > b["initiative"]
	)

	var order: Array[String] = []

	for entry in entries:
		order.append(entry["id"])

	return order
