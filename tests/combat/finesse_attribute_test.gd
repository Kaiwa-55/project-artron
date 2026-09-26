extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var failures: Array[String] = []
	var actor := CombatantState.new()
	actor.id = "finesse_actor"
	actor.team = 1
	actor.max_ap = 10
	actor.ap = 10
	var target := CombatantState.new()
	target.id = "finesse_target"
	target.team = 2
	target.max_hp = 100
	target.hp = 100
	var system := CombatSystem.new()
	system.start_combat([actor, target])
	var dagger: AttackData = load("res://data/attack/dagger.tres").duplicate(true)
	dagger.ap_cost = 0
	actor.strength = 18
	actor.dexterity = 12
	check(dagger.resolve_attack_attribute(actor) == AttributeTypes.Type.STRENGTH, "Finesse chooses Strength when higher", failures)
	check(system.attack_system.resolve_attack(actor, target, dagger, true).attack_modifier == 4, "Finesse uses Strength for To Hit", failures)
	check(system.damage_system.calculate_damage(actor, target, dagger) == dagger.base_damage + 4, "Finesse uses Strength for damage", failures)
	actor.strength = 10
	actor.dexterity = 18
	check(dagger.resolve_attack_attribute(actor) == AttributeTypes.Type.DEXTERITY, "Finesse chooses Dexterity when higher", failures)
	check(system.attack_system.resolve_attack(actor, target, dagger, true).attack_modifier == 4, "Finesse uses Dexterity for To Hit", failures)
	check(system.damage_system.calculate_damage(actor, target, dagger) == dagger.base_damage + 4, "Finesse uses Dexterity for damage", failures)
	var ordinary := AttackData.new()
	ordinary.attack_attribute = AttackData.AttackAttribute.DEXTERITY
	actor.strength = 18
	actor.dexterity = 12
	check(ordinary.resolve_attack_attribute(actor) == AttributeTypes.Type.DEXTERITY, "Attacks without Finesse keep their authored attribute", failures)
	for failure in failures:
		push_error(failure)
	print("FINESSE_ATTRIBUTE_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
