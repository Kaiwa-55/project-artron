extends SceneTree

const BlueBlood := preload("res://data/ancestry/human_blue_blood.tres")
const Catalog := preload("res://data/creation/default_creation_catalog.tres")
const MartialArtist := preload("res://data/class/martial_artist.tres")


func _init() -> void:
	var failures: Array[String] = []
	var data := CharacterData.new()
	data.id = "blue"
	data.ancestry = BlueBlood
	data.character_class = MartialArtist
	data.ancestry_attribute_choices = [AttributeTypes.Type.STRENGTH, AttributeTypes.Type.WISDOM]
	data.base_max_hp = 0
	data.base_max_mana = 0
	data.base_speed = 0
	var actor := data.create_combatant_state()
	AncestrySystem.new().apply_ancestry(actor)
	CharacterClassSystem.new().apply_class(actor)
	StatSystem.new().initialize_combatant(actor)
	check(actor.base_max_hp == 6, "Blue Blood grants 6 base HP", failures)
	check(actor.ancestry_max_mana_bonus == 5, "Blue Blood keeps its 5 Mana ancestry bonus after class rules", failures)
	check(actor.max_mana == 5 and actor.mana == 5, "Blue Blood Martial Artist starts with 5/5 Mana", failures)
	check(actor.base_speed == 15.0, "Blue Blood 5 ft Speed combines with Martial Artist 10 ft Speed", failures)
	check(actor.strength == 11 and actor.wisdom == 11, "Human Adapt Blue increases two different Attributes", failures)
	check(actor.granted_ability_ids.has("human_adapt_blue"), "Human Adapt Blue is granted automatically", failures)
	check(BlueBlood.granted_abilities[0].required_level == 0 and BlueBlood.granted_abilities[0].is_passive, "Human Adapt Blue is a Level 0 Passive", failures)
	check(Catalog.ancestries.has(BlueBlood), "Blue Blood appears in Character Creation", failures)
	if failures.is_empty():
		print("HUMAN_BLUE_BLOOD_TEST: PASS")
		quit(0)
	for failure in failures:
		push_error(failure)
	quit(1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
