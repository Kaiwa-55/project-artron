extends SceneTree

const PartyMemberCardScene := preload("res://scenes/run/PartyMemberCard.tscn")
const PlayerData := preload("res://data/character/player.tres")

var failures: Array[String] = []


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _init() -> void:
	var card: PartyMemberCard = PartyMemberCardScene.instantiate()
	card.character = PlayerData.duplicate(true)
	var calculated := card.create_calculated_state()
	check(calculated != null, "Party card creates a calculated CombatantState")
	check(calculated.ancestry_id == "human", "Calculated stats include Ancestry")
	check(not calculated.class_id.is_empty(), "Calculated stats include Class")
	check(not calculated.equipped_items.is_empty(), "Calculated stats include Starting Equipment")
	var text := card._stats_text()
	check(text.contains("Maximum HP                 %d" % calculated.max_hp), "Party card shows calculated Maximum HP")
	check(text.contains("Class DC                       %d" % calculated.class_dc), "Party card shows calculated Class DC")
	check(text.contains("STR / DEX / CON          %d / %d / %d" % [calculated.strength, calculated.dexterity, calculated.constitution]), "Party card shows calculated Attributes")
	check(text.contains("Reflex / Fort / Will      %d / %d / %d" % [calculated.reflex, calculated.fortitude, calculated.will]), "Party card shows calculated Defenses")
	card.free()
	for failure in failures:
		push_error(failure)
	print("PARTY_MEMBER_CARD_STATS_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
