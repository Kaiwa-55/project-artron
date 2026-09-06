class_name AreaActionContext
extends RefCounted

enum SourceType { SKILL, ABILITY }
enum CancelScope { NONE, CURRENT_TARGET, REMAINING_TARGETS, ENTIRE_ACTION }

var source_type: int = SourceType.SKILL
var actor: CombatantState
var source_data
var skill_data
var ability_data
var target_point: Vector2 = Vector2.ZERO
var attack: AttackData
var targets: Array[CombatantState] = []
var current_index: int = 0
var current_target: CombatantState
var target_results: Array[Dictionary] = []
var costs_consumed: bool = false
var cooldown_started: bool = false
var cancelled: bool = false
var cancel_scope: int = CancelScope.NONE
var cancellation_reason: String = ""
var completed: bool = false

func setup_skill(p_actor: CombatantState, skill, p_target_point: Vector2, p_attack: AttackData, p_targets: Array[CombatantState]) -> void:
	source_type = SourceType.SKILL
	actor = p_actor
	source_data = skill
	skill_data = skill
	ability_data = null
	target_point = p_target_point
	attack = p_attack
	targets = p_targets.duplicate()
	current_index = 0
	current_target = null
	target_results.clear()
	cancelled = false
	cancel_scope = CancelScope.NONE
	cancellation_reason = ""
	completed = false

func setup_ability(p_actor: CombatantState, ability, p_target_point: Vector2, p_attack: AttackData, p_targets: Array[CombatantState]) -> void:
	source_type = SourceType.ABILITY
	actor = p_actor
	source_data = ability
	skill_data = null
	ability_data = ability
	target_point = p_target_point
	attack = p_attack
	targets = p_targets.duplicate()
	current_index = 0
	current_target = null
	target_results.clear()
	cancelled = false
	cancel_scope = CancelScope.NONE
	cancellation_reason = ""
	completed = false

func has_remaining_targets() -> bool:
	return not cancelled and current_index < targets.size()

func take_next_target():
	if not has_remaining_targets():
		current_target = null
		return null
	current_target = targets[current_index]
	current_index += 1
	return current_target

func record_target_result(target: CombatantState, attack_result: AttackResult) -> void:
	if target == null or attack_result == null:
		return
	target_results.append({
		"target_id": target.id,
		"hit": attack_result.hit,
		"margin": attack_result.margin,
		"critical": attack_result.critical,
		"damage": attack_result.final_damage,
		"cancelled": false,
	})

func record_skipped_target(target: CombatantState, reason: String) -> void:
	if target == null:
		return
	target_results.append({"target_id": target.id, "skipped": true, "reason": reason, "cancelled": false})

func cancel(scope: int, reason: String) -> void:
	cancel_scope = scope
	cancellation_reason = reason
	if scope == CancelScope.REMAINING_TARGETS or scope == CancelScope.ENTIRE_ACTION:
		cancelled = true

func finish() -> void:
	completed = true
	current_target = null
