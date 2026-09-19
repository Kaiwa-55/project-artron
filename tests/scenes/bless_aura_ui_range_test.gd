extends SceneTree

const BlessAura := preload("res://data/ability/effect/bless_aura.tres")
const PrototypeCombat := preload("res://scenes/prototype/prototype_combat.gd")


func _init() -> void:
	var prototype = PrototypeCombat.new()
	prototype.combat_system = CombatSystem.new()
	var devotee := CombatantState.new()
	devotee.collision_radius_feet = 2.5

	var actual_radius: float = prototype.get_aura_visual_radius_world_units(devotee, BlessAura)
	var expected_radius: float = (devotee.collision_radius_feet + BlessAura.aura_radius_feet) \
		* prototype.combat_system.map_rules.world_units_per_foot
	var success := is_equal_approx(actual_radius, expected_radius)

	if not success:
		push_error("Bless Aura UI radius must include the caster radius used by real edge-to-edge range checks")
	print("BLESS_AURA_UI_RANGE_TEST: " + ("PASS" if success else "FAIL"))
	quit(0 if success else 1)
