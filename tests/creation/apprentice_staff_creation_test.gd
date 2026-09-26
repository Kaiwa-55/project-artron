extends SceneTree

const Catalog = preload("res://data/creation/default_creation_catalog.tres")
const ApprenticeStaff = preload("res://data/equipment/apprentice_staff.tres")
const CreationDraftScript = preload("res://scenes/character_creation/creation_draft.gd")

var failures: Array[String] = []


func _init() -> void:
	var draft = CreationDraftScript.new()
	draft.setup(Catalog)
	check(Catalog.equipment.has(ApprenticeStaff), "Apprentice Staff appears in Character Creation equipment")
	var gold_before: int = draft.gold
	check(draft.buy_equipment(ApprenticeStaff) and draft.gold == gold_before - ApprenticeStaff.purchase_price, "Apprentice Staff can be purchased with starting Gold")
	draft.equip(ApprenticeStaff, 0)
	check(draft.equipment_slots.get(0) == ApprenticeStaff and draft.equipment_slots.get(3) == ApprenticeStaff, "Apprentice Staff fills both hand slots in Character Creation")
	var saved: CharacterData = draft.raw_character()
	check(saved.starting_equipment.has(ApprenticeStaff) and saved.starting_equipment_slots.get(ApprenticeStaff.id) == 0, "Selected Staff is saved for Combat")
	var actor: CombatantState = saved.create_combatant_state()
	EquipmentSystem.new().initialize_combatant(actor)
	EquipmentSystem.new().refresh_equipment(actor)
	check(actor.equipped_items.get(0) == ApprenticeStaff and actor.equipped_items.get(3) == ApprenticeStaff, "Combat starts with Apprentice Staff in both hands")
	check(actor.max_mana == draft.preview.max_mana, "Character Creation and Combat show the same Max Mana")
	for failure in failures:
		push_error(failure)
	print("APPRENTICE_STAFF_CREATION_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
