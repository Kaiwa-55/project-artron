extends Button
var sword: AttackData
var combat_system: CombatSystem

func  setup(combatsystem: CombatSystem):
	combat_system = combatsystem
	sword = AttackData.new()
	sword.id = "sword_attack"
	sword.display_name = "Sword Attack"

	sword.attack_attribute = AttributeTypes.Type.STRENGTH
	sword.defense_type = DefenseTypes.Type.REFLEX

	sword.requires_to_hit = true

	sword.ap_cost = 1
	sword.base_damage = 5
	sword.range_feet = 5.0

func _on_pressed() -> void:
	var request := ActionRequest.new(
		"player",
		ActionTypes.Type.ATTACK
	)
	request.target_id = "enemy"
	request.attack_data = sword
	var result := combat_system.execute_action(request)
