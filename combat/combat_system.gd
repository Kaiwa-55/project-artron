class_name CombatSystem
extends RefCounted

const StatsSystemScript = preload("res://combat/stat/stat_system.gd")
const AbilitySystemScript = preload("res://combat/ability/ability_system.gd")
const MapRulesScript = preload("res://combat/map/map_rules.gd")
const TraitSystemScript = preload("res://combat/trait/trait_system.gd")
const ReactionSystemScript = preload("res://combat/reaction/reaction_system.gd")
const SkillSystemScript = preload("res://combat/skill/skill_system.gd")
const EquipmentSystemScript = preload("res://combat/equipment/equipment_system.gd")
const AncestrySystemScript = preload("res://combat/ancestry/ancestry_system.gd")
const ClassSystemScript = preload("res://combat/class/class_system.gd")
const ReactionEffectDataScript = preload("res://data/reaction/reaction_effect_data.gd")
const TargetingSystemScript = preload("res://combat/targeting/targeting_system.gd")
const SkillDataScript = preload("res://data/skill/skill_data.gd")
const ActiveAbilityExecutorScript = preload("res://combat/ability/active_ability_executor.gd")
const AbilityMovementExecutorScript = preload("res://combat/ability/ability_movement_executor.gd")
const EquipmentActionExecutorScript = preload("res://combat/equipment/equipment_action_executor.gd")
const TurnCoordinatorScript = preload("res://combat/turn/turn_coordinator.gd")
const CombatActionExecutorScript = preload("res://combat/action/combat_action_executor.gd")
const ReactionResolverScript = preload("res://combat/reaction/reaction_resolver.gd")
const AreaActionExecutorScript = preload("res://combat/targeting/area_action_executor.gd")
const AttackSequenceExecutorScript = preload("res://combat/attack/attack_sequence_executor.gd")
const ProgressionSystemScript = preload("res://combat/progression/progression_system.gd")

var combat_state: CombatState

var dice_system: DiceSystem
var attribute_system: AttributeSystem
var defense_system: DefenseSystem
var damage_system: DamageSystem
var effect_system: EffectSystem
var stat_system
var ability_system
var map_rules
var trait_system
var targeting_system

var attack_system: AttackSystem
var movement_system: MovementSystem
var initiative_system: InitiativeSystem

var turn_system: TurnSystem
var action_system: ActionSystem
var reaction_system
var skill_system
var equipment_system
var ancestry_system
var class_system
var progression_system

var event_system: EventSystem
var turn_coordinator
var equipment_action_executor
var combat_action_executor
var reaction_resolver
var pending_action: ActionRequest:
	get: return reaction_resolver.pending_action if reaction_resolver != null else null
	set(value):
		if reaction_resolver != null: reaction_resolver.pending_action = value
var pending_reaction: Dictionary:
	get: return reaction_resolver.pending_reaction if reaction_resolver != null else {}
	set(value):
		if reaction_resolver != null: reaction_resolver.pending_reaction = value
var pending_reaction_queue:
	get: return reaction_resolver.pending_queue if reaction_resolver != null else []
	set(value):
		if reaction_resolver != null: reaction_resolver.pending_queue = value
var area_action_executor
var pending_area_context:
	get:
		return area_action_executor.pending_context if area_action_executor != null else null
	set(value):
		if area_action_executor != null:
			area_action_executor.pending_context = value
var step_back_move_actor_id: String:
	get: return reaction_resolver.move_actor_id if reaction_resolver != null else ""
	set(value):
		if reaction_resolver != null: reaction_resolver.move_actor_id = value
var step_back_move_distance_feet: float:
	get: return reaction_resolver.move_distance_feet if reaction_resolver != null else 0.0
	set(value):
		if reaction_resolver != null: reaction_resolver.move_distance_feet = value
var pending_reaction_move_name: String:
	get: return reaction_resolver.move_name if reaction_resolver != null else ""
	set(value):
		if reaction_resolver != null: reaction_resolver.move_name = value
var reaction_move_resumes_action: bool:
	get: return reaction_resolver.move_resumes_action if reaction_resolver != null else false
	set(value):
		if reaction_resolver != null: reaction_resolver.move_resumes_action = value
var pending_defensive_reaction_move: Dictionary:
	get: return reaction_resolver.pending_defensive_move if reaction_resolver != null else {}
	set(value):
		if reaction_resolver != null: reaction_resolver.pending_defensive_move = value
var ability_movement_executor
var ability_move_actor_id: String:
	get: return ability_movement_executor.actor_id if ability_movement_executor != null else ""
	set(value):
		if ability_movement_executor != null: ability_movement_executor.actor_id = value
var ability_move_id: String:
	get: return ability_movement_executor.ability_id if ability_movement_executor != null else ""
	set(value):
		if ability_movement_executor != null: ability_movement_executor.ability_id = value
var active_ability_executor
var attack_sequence_executor
var pending_active_ability_context: Dictionary:
	get:
		return active_ability_executor.pending_context if active_ability_executor != null else {}
	set(value):
		if active_ability_executor != null:
			active_ability_executor.pending_context = value
var resolution_context:
	get: return reaction_resolver.resolution_context if reaction_resolver != null else null


func _init() -> void:

	dice_system = DiceSystem.new()

	attribute_system = AttributeSystem.new()
	stat_system = StatsSystemScript.new()
	ability_system = AbilitySystemScript.new()
	map_rules = MapRulesScript.new()
	trait_system = TraitSystemScript.new()
	targeting_system = TargetingSystemScript.new()
	effect_system = EffectSystem.new()

	defense_system = DefenseSystem.new(effect_system)

	damage_system = DamageSystem.new(
		attribute_system,
		effect_system
	)

	attack_system = AttackSystem.new(
		dice_system,
		defense_system,
		damage_system,
		effect_system,
		ability_system,
		trait_system
	)

	movement_system = MovementSystem.new()
	movement_system.map_rules = map_rules
	movement_system.ability_system = ability_system
	attack_system.map_rules = map_rules

	initiative_system = InitiativeSystem.new(
		dice_system
	)

	turn_system = TurnSystem.new()
	skill_system = SkillSystemScript.new(ability_system)
	equipment_system = EquipmentSystemScript.new()
	ancestry_system = AncestrySystemScript.new()
	class_system = ClassSystemScript.new()
	progression_system = ProgressionSystemScript.new()

	action_system = ActionSystem.new(
		attack_system,
		movement_system,
		skill_system
	)
	reaction_system = ReactionSystemScript.new(
		attack_system,
		action_system,
		map_rules
	)

	event_system = EventSystem.new()
	reaction_resolver = ReactionResolverScript.new(self)
	active_ability_executor = ActiveAbilityExecutorScript.new(self)
	attack_sequence_executor = AttackSequenceExecutorScript.new(self)
	ability_movement_executor = AbilityMovementExecutorScript.new(self)
	area_action_executor = AreaActionExecutorScript.new(self)
	equipment_action_executor = EquipmentActionExecutorScript.new(self)
	turn_coordinator = TurnCoordinatorScript.new(self)
	combat_action_executor = CombatActionExecutorScript.new(self)

func start_combat(
	combatants: Array[CombatantState]
) -> void:
	turn_coordinator.start_combat(combatants)

func execute_action(
	request: ActionRequest
) -> ActionResult:
	return combat_action_executor.execute(request)


func cancel_remaining_movement(combatant: CombatantState) -> void:
	if combatant == null or not combatant.movement_in_progress:
		return
	combatant.movement_in_progress = false
	combatant.movement_remaining_feet = 0.0


func execute_ground_skill(combatant_id: String, skill_id: String, target_point: Vector2) -> ActionResult:
	return area_action_executor.execute_skill(combatant_id, skill_id, target_point)


func execute_ground_ability(combatant_id: String, ability_id: String, target_point: Vector2) -> ActionResult:
	return area_action_executor.execute_ability(combatant_id, ability_id, target_point)


func get_ground_skill(actor: CombatantState, skill_id: String):
	return area_action_executor.get_skill(actor, skill_id)


func validate_ground_skill_start(combatant_id: String, skill_id: String) -> ActionResult:
	return area_action_executor.validate_skill_start(combatant_id, skill_id)


func validate_ground_ability_start(combatant_id: String, ability_id: String) -> ActionResult:
	return area_action_executor.validate_ability_start(combatant_id, ability_id)


func continue_area_skill(carried_events: Array[CombatEvent] = []) -> ActionResult:
	return area_action_executor.continue_action(carried_events)


func continue_area_action(carried_events: Array[CombatEvent] = []) -> ActionResult:
	return area_action_executor.continue_action(carried_events)


func open_reaction_prompt(request: ActionRequest, prompt: Dictionary) -> bool:
	return reaction_resolver.open_prompt(request, prompt)


func get_reaction_depth() -> int:
	return reaction_resolver.get_depth()


func has_pending_reaction() -> bool:
	return reaction_resolver.has_pending()


func continue_reaction_queue(carried_events: Array[CombatEvent] = []) -> ActionResult:
	return reaction_resolver.continue_queue(carried_events)
func apply_ai_defensive_reaction(prompt: Dictionary, reaction_index: int, result: ActionResult) -> void:
	reaction_resolver.apply_ai_defensive(prompt, reaction_index, result)
	return
func choose_ai_reaction_destination(reactor: CombatantState, attacker: CombatantState, distance_feet: float) -> Vector2:
	return reaction_resolver.choose_ai_destination(reactor, attacker, distance_feet)
func has_pending_step_back_move() -> bool:
	return reaction_resolver.has_pending_move()


func has_pending_ability_movement() -> bool:
	return ability_movement_executor.has_pending()


func begin_ability_movement(combatant_id: String, ability_id: String) -> ActionResult:
	return ability_movement_executor.begin(combatant_id, ability_id)


func execute_pending_ability_movement(destination: Vector2) -> ActionResult:
	return ability_movement_executor.execute(destination)


func use_weapon_ability(combatant_id: String, target_id: String, ability_id: String) -> ActionResult:
	return active_ability_executor.execute(combatant_id, target_id, ability_id)


func use_active_ability(combatant_id: String, target_id: String, ability_id: String) -> ActionResult:
	return active_ability_executor.execute(combatant_id, target_id, ability_id)


func apply_active_ability_effects(actor: CombatantState, target: CombatantState, ability, attack_events: Array[CombatEvent], output_events: Array[CombatEvent], include_always: bool = true, include_conditional: bool = true) -> void:
	active_ability_executor.apply_effects(actor, target, ability, attack_events, output_events, include_always, include_conditional)


func build_scaled_ability_effect(actor: CombatantState, entry) -> EffectData:
	return active_ability_executor.build_scaled_effect(actor, entry)


func apply_dynamic_ability_effect(actor: CombatantState, target: CombatantState, ability, entry, output_events: Array[CombatEvent]) -> void:
	active_ability_executor.apply_dynamic_effect(actor, target, ability, entry, output_events)


func offer_step_back(request: ActionRequest, attacker: CombatantState, target: CombatantState, result: ActionResult) -> void:
	reaction_resolver.offer_step_back(request, attacker, target, result)


func offer_mobile_shooter(request: ActionRequest, attacker: CombatantState, attack: AttackData, attack_result: AttackResult, result: ActionResult) -> void:
	reaction_resolver.offer_mobile_shooter(request, attacker, attack, attack_result, result)


func resolve_pending_reaction(reaction_index: int) -> ActionResult:
	return reaction_resolver.resolve_choice(reaction_index)


func resolve_damage_intervention_choice(request: ActionRequest, prompt: Dictionary, reaction) -> ActionResult:
	return reaction_resolver.resolve_damage_intervention_choice(request, prompt, reaction)


func execute_step_back_move(destination: Vector2) -> ActionResult:
	return reaction_resolver.execute_move(destination)


func cancel_step_back_move() -> ActionResult:
	return reaction_resolver.cancel_move()


func finish_defensive_reaction_move(movement_events: Array[CombatEvent]) -> ActionResult:
	return reaction_resolver.finish_defensive_move(movement_events)


func emit_events(events: Array[CombatEvent]) -> void:
	for event in events:
		event_system.emit(event)

func get_combat_state() -> CombatState:
	return combat_state


func refresh_stats(combatant: CombatantState) -> void:
	stat_system.refresh_combatant(combatant)


func toggle_ability(combatant_id: String, ability_id: String) -> ActionResult:
	if combat_state == null:
		return ActionResult.failure("Combat has not started.")
	if has_pending_ability_movement():
		return ActionResult.failure("Choose the pending Ability movement destination first.")

	var combatant := combat_state.get_combatant(combatant_id)
	if combatant == null:
		return ActionResult.failure("Combatant does not exist.")
	if combat_state.is_finished() or combat_state.current_actor_id != combatant.id:
		return ActionResult.failure("Abilities can only be changed during this character's turn.")
	var result: ActionResult = ability_system.toggle_ability(combatant, ability_id)
	if result.success:
		ability_system.sync_granted_reactions(combatant)
		cancel_remaining_movement(combatant)
	return result


func toggle_equipment(combatant_id: String, item, target_slot: int = -1) -> ActionResult:
	return equipment_action_executor.toggle(combatant_id, item, target_slot)


func set_active_weapon_slot(combatant_id: String, target_slot: int) -> ActionResult:
	return equipment_action_executor.set_active_weapon_slot(combatant_id, target_slot)


func advance_turn() -> void:
	turn_coordinator.advance_turn()


func start_current_turn() -> void:
	turn_coordinator.start_current_turn()


func reaction_has_trait(reaction, trait_id: String) -> bool:
	if reaction == null:
		return false
	for trait_data in reaction.traits:
		if trait_data != null and trait_data.id == trait_id:
			return true
	return false


func clear_hidden(combatant: CombatantState, reason: String) -> void:
	if combatant != null and combatant.remove_status("hidden"):
		event_system.emit(CombatEvent.new(EventTypes.Type.EFFECT_EXPIRED, combatant.id, "", {"effect_name": "Hidden", "reason": reason}))


func check_for_combat_end() -> bool:
	if combat_state == null or combat_state.is_finished():
		return combat_state != null and combat_state.is_finished()

	var living_teams: Dictionary = {}
	for combatant in combat_state.combatants.values():
		if not combatant.is_dying():
			living_teams[combatant.team] = true

	if living_teams.size() > 1:
		return false

	var winning_team := 0
	if living_teams.size() == 1:
		winning_team = int(living_teams.keys()[0])
	combat_state.winner_team = winning_team
	combat_state.turn_state = CombatEnums.TurnState.END
	for combatant in combat_state.combatants.values():
		effect_system.clear_all_effects(combatant)

	if winning_team == 1:
		combat_state.combat_result = CombatEnums.CombatResult.VICTORY
		event_system.emit(CombatEvent.new(EventTypes.Type.COMBAT_VICTORY, "", "", {"winner_team": winning_team}))
	else:
		combat_state.combat_result = CombatEnums.CombatResult.DEFEAT
		event_system.emit(CombatEvent.new(EventTypes.Type.COMBAT_DEFEAT, "", "", {"winner_team": winning_team}))
	return true


func emit_effect_resolutions(
	target: CombatantState,
	resolutions: Array[Dictionary]
) -> void:
	for resolution in resolutions:
		var event_type := EventTypes.Type.EFFECT_RESOURCE_CHANGED
		if resolution["type"] == "damage":
			event_type = EventTypes.Type.EFFECT_DAMAGE_APPLIED
		elif resolution["type"] == "heal":
			event_type = EventTypes.Type.EFFECT_HEAL_APPLIED

		event_system.emit(
			CombatEvent.new(event_type, "", target.id, resolution)
		)
