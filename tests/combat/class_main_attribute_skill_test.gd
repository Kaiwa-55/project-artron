extends SceneTree

const Assassin := preload("res://data/class/assassin.tres")
const MartialArtist := preload("res://data/class/martial_artist.tres")
const Devotee := preload("res://data/class/devotee.tres")
const Arcanist := preload("res://data/class/arcanist.tres")
const ArcaneBolt := preload("res://data/skill/arcane_bolt.tres")


func _init() -> void:
	var failures: Array[String] = []
	check(Assassin.main_attribute == AttributeTypes.Type.DEXTERITY, "Assassin Main Attribute should be Dexterity.", failures)
	check(MartialArtist.main_attribute == AttributeTypes.Type.STRENGTH, "Martial Artist Main Attribute should be Strength.", failures)
	check(Devotee.main_attribute == AttributeTypes.Type.WISDOM, "Devotee Main Attribute should be Wisdom.", failures)
	check(Arcanist.main_attribute == AttributeTypes.Type.INTELLIGENCE, "Arcanist Main Attribute should be Intelligence.", failures)

	var actor := CombatantState.new()
	actor.set_meta("class_data", Arcanist)
	actor.strength = 20
	actor.intelligence = 14
	var skill_system := SkillSystem.new(AbilitySystem.new())
	var configured_skill: SkillData = ArcaneBolt.duplicate()
	configured_skill.attack_data = ArcaneBolt.attack_data.duplicate()
	configured_skill.attack_data.attack_attribute = AttributeTypes.Type.STRENGTH
	var skill_attack := skill_system.get_attack_data(configured_skill, actor)
	check(skill_attack.attack_attribute == AttackData.AttackAttribute.CLASS_MAIN_ATTRIBUTE, "A Skill should select the Class Main Attribute Attack option.", failures)
	check(skill_attack.resolve_attack_attribute(actor) == AttributeTypes.Type.INTELLIGENCE, "An Arcanist should resolve Class Main Attribute to Intelligence.", failures)
	check(actor.get_attribute_modifier(skill_attack.resolve_attack_attribute(actor)) == 2, "The Skill Attack Modifier should come from Intelligence for an Arcanist.", failures)
	check(configured_skill.attack_data.attack_attribute == AttributeTypes.Type.STRENGTH, "Building a Skill Attack must not mutate its source Resource.", failures)

	var classless_actor := CombatantState.new()
	check(skill_system.get_attack_data(configured_skill, classless_actor).attack_attribute == AttributeTypes.Type.STRENGTH, "A classless Skill user should retain the Skill's configured Attack Attribute.", failures)

	for failure in failures:
		push_error(failure)
	print("CLASS_MAIN_ATTRIBUTE_SKILL_TEST: PASS" if failures.is_empty() else "CLASS_MAIN_ATTRIBUTE_SKILL_TEST: FAIL")
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
