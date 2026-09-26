extends SceneTree

const Catalog = preload("res://data/creation/default_creation_catalog.tres")

var failures: Array[String] = []


func _init() -> void:
	var draft = load("res://scenes/character_creation/creation_draft.gd").new()
	draft.setup(Catalog)
	var specs := [
		["test_head", EquipmentData.Slot.HEAD, 4],
		["test_legs", EquipmentData.Slot.LEGS, 5],
		["test_boots", EquipmentData.Slot.BOOTS, 6],
		["test_gloves", EquipmentData.Slot.GLOVES, 7],
		["test_accessory_1", EquipmentData.Slot.ACCESSORY, 8],
		["test_accessory_2", EquipmentData.Slot.ACCESSORY, 9],
		["test_accessory_3", EquipmentData.Slot.ACCESSORY, 10],
	]
	for spec in specs:
		var item := EquipmentData.new()
		item.id = spec[0]
		item.display_name = spec[0]
		item.slot = spec[1]
		item.reflex_bonus = 1
		draft.owned_equipment.append(item)
		draft.equip(item, spec[2])
		check(draft.equipment_slots.get(spec[2]) == item, "%s equips in its chosen slot" % item.id)
	var head: EquipmentData = draft.equipment_slots[4]
	draft.equip(head, 8)
	check(draft.equipment_slots.get(4) == head and draft.equipment_slots.get(8) != head, "Head equipment cannot occupy an Accessory slot")
	var accessory: EquipmentData = draft.equipment_slots[8]
	draft.equip(accessory, 10)
	check(draft.equipment_slots.get(10) == accessory and draft.equipment_slots.get(8) == null, "Moving an Accessory clears its old slot")
	draft.equip(accessory, 8)
	draft.equip(draft.owned_equipment[-1], 10)
	var saved: CharacterData = draft.raw_character()
	for spec in specs:
		check(int(saved.starting_equipment_slots.get(spec[0], -1)) == spec[2], "%s slot survives Character Creation" % spec[0])
	var actor: CombatantState = saved.create_combatant_state()
	var equipment := EquipmentSystem.new()
	equipment.initialize_combatant(actor)
	equipment.refresh_equipment(actor)
	for spec in specs:
		check(actor.equipped_items.get(spec[2]) != null and actor.equipped_items[spec[2]].id == spec[0], "%s loads in the same Combat slot" % spec[0])
	check(actor.equipment_reflex_bonus >= specs.size(), "All worn slots contribute equipment bonuses")
	var boots: EquipmentData = actor.equipped_items.get(6)
	if boots != null:
		check(not equipment.toggle_equipment(actor, boots, 6).success, "Worn gear remains locked during Combat")
		check(equipment.toggle_equipment_without_cost(actor, boots, 6).success and actor.equipped_items.get(6) == null, "Boots can be removed outside Combat")
		check(equipment.toggle_equipment_without_cost(actor, boots, 6).success and actor.equipped_items.get(6) == boots, "Boots can be equipped outside Combat")
	check(EquipmentSystem.LOADOUT_SLOTS.size() == 10, "Loadout includes both hands, Body, Head, Legs, Boots, Gloves, and three Accessories")
	for failure in failures:
		push_error(failure)
	print("EQUIPMENT_SLOTS_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
