class_name CombatantState
extends RefCounted

const DyingStatus = preload("res://data/status/dying.tres")

var token_texture: Texture2D
var token_scale: float = 1.0
var token_offset: Vector2 = Vector2.ZERO


var id: String = ""
var display_name: String = ""
var team: int = 0

var position: Vector2 = Vector2.ZERO
var ancestry_id: String = ""
var ancestry_display_name: String = ""
var class_id: String = ""
var class_display_name: String = ""
# Radius in feet. Targeting and movement measure from a character's edge.
var collision_radius_feet: float = 2.5

var level: int = 1
var experience: int = 0
var ability_points: int = 0
var attribute_points: int = 0
var progression_rewards_granted_through_level: int = 0
var selected_ability_ids: Array[String] = []
var granted_ability_ids: Array[String] = []
var selected_level_attributes: Array[int] = []
var pending_level_up_choices: Array[Dictionary] = []
var selected_ability_costs_applied: bool = false
var base_max_hp: int = 1
var base_max_mana: int = 0
var base_max_ap: int = 1
var base_speed: float = 0.0

var max_hp_bonus: int = 0
var max_mana_bonus: int = 0
var max_ap_bonus: int = 0
var speed_bonus: float = 0.0
var reflex_stat_bonus: int = 0
var fortitude_stat_bonus: int = 0
var will_stat_bonus: int = 0
var equipment_reflex_bonus: int = 0
var equipment_fortitude_bonus: int = 0
var equipment_will_bonus: int = 0

var hp: int = 0
var max_hp: int = 0

var mana: int = 0
var max_mana: int = 0

var faith: int = 0
var max_faith: int = 0
var temporary_faith: int = 0

var ap: int = 0
var max_ap: int = 0
var effective_max_ap: int = 0

var speed: float = 0.0
var movement_in_progress: bool = false
var movement_remaining_feet: float = 0.0
var movement_distance_this_turn: float = 0.0

var strength: int = 10
var dexterity: int = 10
var constitution: int = 10
var intelligence: int = 10
var wisdom: int = 10
var charisma: int = 10
var ancestry_attribute_choices: Array[int] = []
var class_attribute_choices: Array[int] = []

var effects: Array[EffectInstance] = []

var reflex: int = 0
var fortitude: int = 0
var will: int = 0
var defense_bonus: int = 0
var reflex_bonus: int = 0
var fortitude_bonus: int = 0
var damage_resistances: Dictionary = {}
var equipment_damage_resistances: Dictionary = {}
var damage_immunities: Array[String] = []

var available_abilities: Array = []
var equipped_abilities: Array = []
var equipped_weapon_attack: AttackData
var natural_attack: AttackData
var unarmed_attack: AttackData
var equipment_inventory: Array = []
var equipped_items: Dictionary = {}
var active_weapon_slot: int = 0
var starting_equipment: Array = []
var starting_equipment_slots: Dictionary = {}
var available_skills: Array = []
var skill_cooldowns: Dictionary = {}
var ability_cooldowns: Dictionary = {}
var ability_cooldown_skip_next_reduction: Dictionary = {}
var ability_stacks: Dictionary = {}
var ability_uses_this_turn: Dictionary = {}
var attacks_declared_this_turn: int = 0
var active_traits: Array = []
var active_reactions: Array = []
var ai_profile: Resource
var last_attack_declared_round: int = 0
var last_step_back_round: int = 0
var reaction_last_used_round: Dictionary = {}

var initiative: int = 0
var initiative_bonus: int = 0

var life_state: CombatEnums.LifeState = \
	CombatEnums.LifeState.ALIVE

func get_modifier(value: int) -> int:
	return floori((value - 10) / 2.0)

func get_attribute_modifier(
	attribute: AttributeTypes.Type
) -> int:
	match attribute:
		AttributeTypes.Type.STRENGTH:
			return get_modifier(strength)
		AttributeTypes.Type.DEXTERITY:
			return get_modifier(dexterity)
		AttributeTypes.Type.CONSTITUTION:
			return get_modifier(constitution)
		AttributeTypes.Type.WISDOM:
			return get_modifier(wisdom)
		AttributeTypes.Type.INTELLIGENCE:
			return get_modifier(intelligence)
		AttributeTypes.Type.CHARISMA:
			return get_modifier(charisma)
	return 0


func is_alive() -> bool:
	return life_state == CombatEnums.LifeState.ALIVE


func is_dying() -> bool:
	return life_state == CombatEnums.LifeState.DYING


func apply_damage(amount: int) -> void:
	if amount <= 0:
		return

	if is_dying():
		return

	hp = max(0, hp - amount)
	remove_status("hidden")

	if hp == 0:
		life_state = CombatEnums.LifeState.DYING
		add_effect(DyingStatus)


func heal(amount: int) -> int:
	if amount <= 0 or is_dying():
		return 0

	var previous_hp := hp
	hp = min(max_hp, hp + amount)
	return hp - previous_hp


func spend_ap(amount: int) -> bool:
	if amount < 0:
		return false

	if ap < amount:
		return false

	ap -= amount
	return true


func restore_ap(amount: int) -> void:
	if amount <= 0:
		return

	ap = min(max_ap, ap + amount)


func change_ap(amount: int) -> int:
	var previous_ap := ap
	ap = clampi(ap + amount, 0, max_ap)
	return ap - previous_ap


func change_mana(amount: int) -> int:
	var previous_mana := mana
	mana = clampi(mana + amount, 0, max_mana)
	return mana - previous_mana


func get_total_faith() -> int:
	return faith + temporary_faith


func gain_faith(amount: int) -> Dictionary:
	var gained_base := 0
	var gained_temporary := 0
	if amount > 0 and max_faith > 0:
		gained_base = mini(amount, maxi(0, max_faith - faith))
		faith += gained_base
		gained_temporary = amount - gained_base
		temporary_faith += gained_temporary
	return {"faith": gained_base, "temporary_faith": gained_temporary, "total": gained_base + gained_temporary}


func spend_faith(amount: int) -> bool:
	if amount < 0 or get_total_faith() < amount:
		return false
	var temporary_spent := mini(temporary_faith, amount)
	temporary_faith -= temporary_spent
	faith -= amount - temporary_spent
	return true


func decay_temporary_faith(amount: int = 1) -> int:
	var previous := temporary_faith
	temporary_faith = maxi(0, temporary_faith - maxi(0, amount))
	return previous - temporary_faith


func clear_temporary_defense() -> void:
	defense_bonus = 0
	reflex_bonus = 0
	fortitude_bonus = 0


func add_effect(effect: EffectData) -> EffectInstance:
	for active_effect in effects:
		if active_effect.data.id == effect.id:
			match effect.stack_mode:
				EffectData.StackMode.ADD_STACKS:
					active_effect.stack_count = mini(effect.max_stacks, active_effect.stack_count + effect.stacks_on_apply)
					active_effect.remaining_turns = maxi(active_effect.remaining_turns, effect.duration_turns)
				EffectData.StackMode.KEEP_STRONGER:
					if effect.potency > active_effect.data.potency:
						active_effect.data = effect
						active_effect.stack_count = 1
						active_effect.remaining_turns = effect.duration_turns
					elif effect.potency == active_effect.data.potency:
						active_effect.remaining_turns = maxi(active_effect.remaining_turns, effect.duration_turns)
				_:
					active_effect.remaining_turns = maxi(active_effect.remaining_turns, effect.duration_turns)
			return active_effect

	var instance := EffectInstance.new(effect)
	effects.append(instance)
	return instance


func has_status(status_id: String) -> bool:
	for effect_instance in effects:
		if effect_instance.data.id == status_id:
			return true
	return false


func remove_status(status_id: String) -> bool:
	for index in range(effects.size() - 1, -1, -1):
		if effects[index].data.id == status_id:
			effects.remove_at(index)
			return true
	return false


func get_effective_speed() -> float:
	var penalty := 0.0
	var bonus := 0.0
	for effect_instance in effects:
		penalty += effect_instance.data.speed_penalty_per_stack * effect_instance.stack_count
		bonus += effect_instance.data.speed_bonus_per_stack * effect_instance.stack_count
	return maxf(0.0, speed + bonus - penalty)


func get_damage_resistance(damage_type: String) -> int:
	var key := damage_type.strip_edges().to_lower()
	return max(0, int(damage_resistances.get(key, 0)) + int(equipment_damage_resistances.get(key, 0)))


func is_immune_to_damage(damage_type: String) -> bool:
	return damage_immunities.has(damage_type.strip_edges().to_lower())
