class_name CharacterData
extends Resource

const StatsSystemScript = preload("res://combat/stat/stat_system.gd")
const DefaultUnarmedAttack = preload("res://data/attack/unarmed_attack.tres")

@export var id: String = ""
@export var display_name: String = ""
@export var portrait: Texture2D
@export var token_texture: Texture2D
@export_range(0.1, 5.0, 0.1) var token_scale: float = 1.0
@export var token_offset: Vector2 = Vector2.ZERO
@export var team: int = 0
@export var position: Vector2 = Vector2.ZERO
@export var ancestry: Resource
@export var ancestry_attribute_choices: Array[int] = []
@export var character_class: Resource
@export var class_attribute_choices: Array[int] = []
@export_range(0.1, 50.0, 0.1) var collision_radius_feet: float = 2.5

@export_range(1, 10) var level: int = 1
@export var experience: int = 0
@export var ability_points: int = 0
@export var attribute_points: int = 0
@export var progression_rewards_granted_through_level: int = 0
@export var selected_ability_ids: Array[String] = []
@export var granted_ability_ids: Array[String] = []
@export var selected_level_attributes: Array[int] = []
@export var pending_level_up_choices: Array[Dictionary] = []
@export var selected_ability_costs_applied: bool = false
@export var base_max_hp: int = 1
@export var base_max_mana: int = 0
@export var base_max_faith: int = 0
@export var base_max_ap: int = 1
@export var base_speed: float = 0.0

@export var max_hp_bonus: int = 0
@export var max_mana_bonus: int = 0
@export var max_ap_bonus: int = 0
@export var speed_bonus: float = 0.0
@export var reflex_stat_bonus: int = 0
@export var fortitude_stat_bonus: int = 0
@export var will_stat_bonus: int = 0

@export var strength: int = 10
@export var dexterity: int = 10
@export var constitution: int = 10
@export var intelligence: int = 10
@export var wisdom: int = 10
@export var charisma: int = 10

@export var reflex: int = 0
@export var fortitude: int = 0
@export var will: int = 0
@export var initiative_bonus: int = 0

@export var damage_resistances: Dictionary = {}
@export var damage_immunities: Array[String] = []
@export var starting_effects: Array[EffectData] = []
@export var available_abilities: Array = []
@export var equipped_abilities: Array = []
@export var equipped_weapon_attack: AttackData
@export var natural_attack: AttackData
@export var unarmed_attack: AttackData = DefaultUnarmedAttack
@export var equipment_inventory: Array = []
@export var item_inventory: Array[ItemStackData] = []
@export var starting_equipment: Array = []
@export var starting_equipment_slots: Dictionary = {}
@export var skills: Array = []
@export var traits: Array = []
@export var reactions: Array = []
@export var ai_profile: Resource


func create_combatant_state() -> CombatantState:
	var state := CombatantState.new()
	state.id = id
	state.display_name = display_name
	state.token_texture = token_texture
	state.token_scale = token_scale
	state.token_offset = token_offset
	state.team = team
	state.position = position
	state.ancestry_attribute_choices = ancestry_attribute_choices.duplicate()
	var selected_class_choices: Array = class_attribute_choices.duplicate()
	if has_meta("selected_class_attribute_choices"):
		selected_class_choices = get_meta("selected_class_attribute_choices").duplicate()
	state.set_meta("class_attribute_choices", selected_class_choices)
	state.set_meta("ancestry_data", ancestry)
	state.set_meta("class_data", character_class)
	state.collision_radius_feet = collision_radius_feet

	state.level = level
	state.experience = experience
	state.ability_points = ability_points
	state.attribute_points = attribute_points
	state.progression_rewards_granted_through_level = progression_rewards_granted_through_level
	state.selected_ability_ids = selected_ability_ids.duplicate()
	state.granted_ability_ids = granted_ability_ids.duplicate()
	state.selected_level_attributes = selected_level_attributes.duplicate()
	state.pending_level_up_choices = pending_level_up_choices.duplicate(true)
	state.selected_ability_costs_applied = selected_ability_costs_applied
	state.base_max_hp = base_max_hp
	state.base_max_mana = base_max_mana
	state.base_max_faith = base_max_faith
	state.max_faith = base_max_faith
	state.base_max_ap = base_max_ap
	state.base_speed = base_speed
	state.max_hp_bonus = max_hp_bonus
	state.max_mana_bonus = max_mana_bonus
	state.max_ap_bonus = max_ap_bonus
	state.speed_bonus = speed_bonus
	state.reflex_stat_bonus = reflex_stat_bonus
	state.fortitude_stat_bonus = fortitude_stat_bonus
	state.will_stat_bonus = will_stat_bonus

	state.strength = strength
	state.dexterity = dexterity
	state.constitution = constitution
	state.intelligence = intelligence
	state.wisdom = wisdom
	state.charisma = charisma

	state.initiative_bonus = initiative_bonus
	state.damage_resistances = damage_resistances.duplicate(true)
	state.damage_immunities = damage_immunities.duplicate()
	state.available_abilities = available_abilities.duplicate()
	state.equipped_abilities = equipped_abilities.duplicate()
	state.equipped_weapon_attack = equipped_weapon_attack
	state.natural_attack = natural_attack
	state.unarmed_attack = unarmed_attack
	state.equipment_inventory = equipment_inventory.duplicate()
	state.item_inventory.clear()
	for stack_data in item_inventory:
		if stack_data != null and stack_data.item != null and stack_data.quantity > 0:
			state.item_inventory.append(stack_data.create_runtime_stack())
	state.starting_equipment = starting_equipment.duplicate()
	state.starting_equipment_slots = starting_equipment_slots.duplicate()
	state.available_skills = skills.duplicate()
	state.active_traits = traits.duplicate()
	state.active_reactions = reactions.duplicate()
	state.ai_profile = ai_profile

	for effect in starting_effects:
		state.add_effect(effect)

	var stat_system := StatsSystemScript.new()
	stat_system.initialize_combatant(state)

	return state
