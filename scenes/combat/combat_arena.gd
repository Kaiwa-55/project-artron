extends Node2D

const PlayerData = preload("res://data/character/player.tres")
const EnemyData = preload("res://data/character/enemy.tres")
const StunData = preload("res://data/status/stunned.tres")
const LongReachAbility = preload("res://data/ability/long_reach.tres")
const MeleeTrait = preload("res://data/trait/melee.tres")
const ArcaneBoltSkill = preload("res://data/skill/arcane_bolt.tres")
const ArcaneBurstSkill = preload("res://data/skill/arcane_burst.tres")

var combat_system: CombatSystem
var move_mode: bool = false
var selected_target_id: String = "enemy"
var ground_skill_mode: String = ""
var ground_targeting_kind: String = ""
var ground_targeting_id: String = ""
var pending_target_attack: AttackData
var pending_single_target_kind: String = ""
var pending_single_target_source
var movement_presentation


func get_all_combatant_nodes() -> Array:
	if has_node("BattlefieldWorld"):
		return $BattlefieldWorld.get_children().filter(func(child): return child is Combatant)
	return get_children().filter(func(child): return child is Combatant)


func get_player_controlled_actor() -> CombatantState:
	if combat_system == null or combat_system.get_combat_state() == null:
		return null
	var state = combat_system.get_combat_state()
	var primary: CombatantState = state.get_combatant("player")
	var current: CombatantState = state.get_current_actor()
	if primary != null and current != null and current.team == primary.team:
		return current
	return primary


func get_player_controlled_actor_id() -> String:
	var actor := get_player_controlled_actor()
	return actor.id if actor != null else "player"


func is_player_party_turn() -> bool:
	if combat_system == null or combat_system.get_combat_state() == null:
		return false
	var state = combat_system.get_combat_state()
	var primary: CombatantState = state.get_combatant("player")
	var current: CombatantState = state.get_current_actor()
	return primary != null and current != null and current.team == primary.team


func _ready() -> void:
	movement_presentation = preload("res://scenes/combat/movement_presentation.gd").new()
	add_child(movement_presentation)
	start_test_combat()


func is_movement_animating() -> bool:
	return movement_presentation != null and movement_presentation.sync_movement()


func start_test_combat() -> void:
	combat_system = CombatSystem.new()
	move_mode = false
	selected_target_id = "enemy"

	var player_data = PlayerData
	if get_tree().has_meta("created_character_data"):
		player_data = get_tree().get_meta("created_character_data")
	var player: CombatantState = player_data.create_combatant_state()
	var enemy: CombatantState = EnemyData.create_combatant_state()
	$BattlefieldWorld/PlayerCharacter.setup(player)
	$BattlefieldWorld/EnemyCharacter.setup(enemy)

	combat_system.start_combat([
		player,
		enemy
	])
	$UILayer/Control.reset_for_combat()
	$UILayer/Control.setup(combat_system)
	if not $UILayer/Control.reaction_choice_selected.is_connected(resolve_reaction_choice):
		$UILayer/Control.reaction_choice_selected.connect(resolve_reaction_choice)
	update_target_selection()
	run_enemy_ai_if_needed()

func test_attack_sword() -> void:
	var player: CombatantState = combat_system.get_combat_state().get_combatant("player")
	var weapon: AttackData = player.equipped_weapon_attack if player != null else null
	if weapon == null:
		$UILayer/Control.add_log_message("Equip a weapon before attacking.")
		return

	var request := ActionRequest.new(
		"player",
		ActionTypes.Type.ATTACK
	)

	request.target_id = selected_target_id
	request.attack_data = weapon

	var result := combat_system.execute_action(request)
	sync_move_mode_from_state()

	print("=== ATTACK TEST ===")
	print("Success: ", result.success)

	for event in result.events:
		print("Event: ", event.type)
		print("Data: ", event.data)

	$UILayer/Control.record_action_result(result)


func end_turn() -> void:
	next_turn()


func next_turn() -> void:
	if combat_system.has_pending_reaction() or combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement():
		$UILayer/Control.set_mode_hint("Resolve the pending Reaction or movement before ending the turn.")
		return
	if movement_presentation != null and movement_presentation.defer_until_settled(next_turn):
		return
	move_mode = false
	combat_system.advance_turn()
	run_enemy_ai_if_needed()
	$UILayer/Control.set_mode_hint("Choose an action to test.")
	$UILayer/Control.update_ui()


func run_enemy_ai_if_needed() -> void:
	if combat_system.get_combat_state().is_finished():
		return
	if combat_system.get_combat_state().current_actor_id != "enemy":
		return

	var enemy: CombatantState = combat_system.get_combat_state().get_combatant("enemy")
	var player: CombatantState = combat_system.get_combat_state().get_combatant("player")
	if enemy == null or player == null or enemy.is_dying() or player.is_dying():
		return

	var enemy_attack: AttackData = enemy.equipped_weapon_attack
	if enemy_attack == null:
		$UILayer/Control.add_log_message("Enemy AI: has no equipped weapon.")
		return

	if combat_system.map_rules.is_target_in_range(enemy, player, enemy_attack.range_feet):
		var attack_request := ActionRequest.new("enemy", ActionTypes.Type.ATTACK)
		attack_request.target_id = "player"
		attack_request.attack_data = enemy_attack
		$UILayer/Control.add_log_message("Enemy AI: attacks the Player.")
		var attack_result := combat_system.execute_action(attack_request)
		$UILayer/Control.record_action_result(attack_result)
		if attack_result.requires_reaction_choice:
			$UILayer/Control.show_reaction_prompt(attack_result.reaction_prompt)
			$UILayer/Control.set_mode_hint("Choose one Reaction before the attack resolves.")
			return
	else:
		var combined_radii: float = combat_system.map_rules.get_combatant_radius_world_units(enemy) \
			+ combat_system.map_rules.get_combatant_radius_world_units(player)
		var desired_center_distance: float = combined_radii + 5.0 * combat_system.map_rules.world_units_per_foot
		var move_distance: float = minf(
			enemy.speed * combat_system.map_rules.world_units_per_foot,
			maxf(0.0, enemy.position.distance_to(player.position) - desired_center_distance)
		)
		if move_distance > 0.0:
			var movement := MovementData.new()
			movement.ap_cost = 1
			movement.world_units_per_foot = combat_system.map_rules.world_units_per_foot
			var move_request := ActionRequest.new("enemy", ActionTypes.Type.MOVE)
			move_request.target_position = enemy.position + enemy.position.direction_to(player.position) * move_distance
			move_request.movement_data = movement
			$UILayer/Control.add_log_message("Enemy AI: moves toward the Player.")
			var move_result := combat_system.execute_action(move_request)
			$UILayer/Control.record_action_result(move_result)
			if move_result.requires_reaction_choice:
				$UILayer/Control.show_reaction_prompt(move_result.reaction_prompt)
				$UILayer/Control.set_mode_hint("Choose whether to use Opportunity Attack before the enemy moves.")
				return
			if move_result.success:
				$BattlefieldWorld/EnemyCharacter.refresh_from_state()

	if not combat_system.get_combat_state().is_finished():
		combat_system.advance_turn()


func resolve_reaction_choice(reaction_index: int) -> void:
	$UILayer/Control.hide_reaction_prompt()
	var result := combat_system.resolve_pending_reaction(reaction_index)
	$UILayer/Control.record_action_result(result)
	$BattlefieldWorld/PlayerCharacter.refresh_from_state()
	$BattlefieldWorld/EnemyCharacter.refresh_from_state()
	if result.requires_reaction_choice:
		$UILayer/Control.show_reaction_prompt(result.reaction_prompt)
		$UILayer/Control.set_mode_hint("Choose whether to use Step Back after the attack.")
		$UILayer/Control.update_ui()
		return
	if combat_system.has_pending_step_back_move():
		move_mode = true
		$UILayer/Control.set_mode_hint("Step Back: click a destination up to half your Speed away.")
		$UILayer/Control.update_ui()
		return
	if not combat_system.get_combat_state().is_finished() \
		and combat_system.get_combat_state().current_actor_id == "enemy":
		combat_system.advance_turn()
	var player: CombatantState = combat_system.get_combat_state().get_combatant("player")
	if player != null and player.movement_in_progress:
		move_mode = true
		$UILayer/Control.set_mode_hint(
			"Continue Move: %.1f ft remaining. Using another action forfeits it." \
			% player.movement_remaining_feet
		)
	elif not result.success:
		move_mode = true
		$UILayer/Control.set_mode_hint("Move failed: %s Choose another destination." % result.failure_reason)
	else:
		$UILayer/Control.set_mode_hint("Choose an action to test.")
	$UILayer/Control.update_ui()


func reset_test() -> void:
	start_test_combat()
	$UILayer/Control.set_mode_hint("Test reset. Equip abilities, then choose an action.")


func begin_move() -> void:
	if is_movement_animating():
		return
	var actor := get_player_controlled_actor()
	if actor == null or not combat_system.movement_system.can_begin_or_continue_move(actor, 1):
		$UILayer/Control.set_mode_hint("Cannot Move: no Speed or AP available.")
		return
	pending_target_attack = null
	pending_single_target_kind = ""
	pending_single_target_source = null
	ground_targeting_id = ""
	move_mode = true
	$UILayer/Control.set_mode_hint("Move mode active: click a destination on the battlefield.")
	$UILayer/Control.add_log_message("Move mode: click a destination on the battlefield.")


func begin_ground_skill(skill_id: String) -> void:
	begin_ground_targeting("skill", skill_id)


func begin_ground_ability(ability_id: String) -> void:
	begin_ground_targeting("ability", ability_id)


func begin_ground_targeting(kind: String, source_id: String) -> void:
	var actor_id := get_player_controlled_actor_id()
	var validation: ActionResult = combat_system.validate_ground_skill_start(actor_id, source_id) if kind == "skill" else combat_system.validate_ground_ability_start(actor_id, source_id)
	if not validation.success:
		$UILayer/Control.set_mode_hint("Cannot target: %s" % validation.failure_reason)
		$UILayer/Control.add_log_message("Targeting failed: %s" % validation.failure_reason)
		return
	ground_targeting_kind = kind
	ground_targeting_id = source_id
	ground_skill_mode = source_id if kind == "skill" else ""
	move_mode = false
	var source = get_ground_targeting_data()
	$UILayer/Control.set_mode_hint("%s: choose a point. Left-click confirms; right-click or Esc cancels." % source.display_name)
	$UILayer/Control.add_log_message("Area Targeting active: %s." % source.display_name)


func get_ground_targeting_data():
	if ground_targeting_id.is_empty() or combat_system == null:
		return null
	var player: CombatantState = get_player_controlled_actor()
	return combat_system.get_ground_skill(player, ground_targeting_id) if ground_targeting_kind == "skill" else combat_system.ability_system.get_available_ability(player, ground_targeting_id)


func cancel_ground_targeting() -> void:
	if ground_targeting_id.is_empty():
		return
	var source = get_ground_targeting_data()
	$UILayer/Control.add_log_message("%s targeting cancelled." % (source.display_name if source != null else "Area Action"))
	ground_targeting_kind = ""
	ground_targeting_id = ""
	ground_skill_mode = ""
	$UILayer/Control.set_mode_hint("Choose an action.")
	queue_redraw()


func cancel_attack_targeting() -> void:
	pending_target_attack = null
	$UILayer/Control.set_mode_hint("Choose an action.")
	queue_redraw()


func confirm_attack_target(_mouse_position: Vector2) -> bool:
	return false


func cancel_single_targeting() -> void:
	pending_single_target_kind = ""
	pending_single_target_source = null
	$UILayer/Control.set_mode_hint("Choose an action.")
	queue_redraw()


func confirm_single_target(_mouse_position: Vector2) -> bool:
	return false


func clear_selected_target() -> void:
	selected_target_id = ""
	$UILayer/Control.set_selected_target("None", "")


func has_selected_character() -> bool:
	return false


func cast_ground_skill(target_point: Vector2) -> void:
	confirm_ground_targeting(target_point)


func confirm_ground_targeting(target_point: Vector2) -> void:
	var actor_id := get_player_controlled_actor_id()
	var result := combat_system.execute_ground_skill(actor_id, ground_targeting_id, target_point) if ground_targeting_kind == "skill" else combat_system.execute_ground_ability(actor_id, ground_targeting_id, target_point)
	if result.requires_reaction_choice:
		ground_targeting_kind = ""; ground_targeting_id = ""; ground_skill_mode = ""
		$UILayer/Control.show_reaction_prompt(result.reaction_prompt)
		$UILayer/Control.set_mode_hint("Resolve the target's Defensive Reaction.")
	elif result.success:
		ground_targeting_kind = ""; ground_targeting_id = ""; ground_skill_mode = ""
		$UILayer/Control.set_mode_hint("Area Action resolved. Choose an action.")
		$BattlefieldWorld/PlayerCharacter.refresh_from_state()
		$BattlefieldWorld/EnemyCharacter.refresh_from_state()
	else:
		$UILayer/Control.set_mode_hint("Area Targeting failed: %s Choose another point." % result.failure_reason)
	$UILayer/Control.record_action_result(result)
	$UILayer/Control.update_ui()


func _unhandled_input(event: InputEvent) -> void:
	if is_movement_animating():
		get_viewport().set_input_as_handled()
		return
	if combat_system.has_pending_step_back_move() and ((event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed) or event.is_action_pressed("ui_cancel")):
		var cancel_result := combat_system.cancel_step_back_move()
		move_mode = false
		if cancel_result.requires_reaction_choice:
			$UILayer/Control.show_reaction_prompt(cancel_result.reaction_prompt)
			$UILayer/Control.set_mode_hint("Movement cancelled. Resolve the next Reaction.")
		else:
			$UILayer/Control.set_mode_hint("Reaction movement cancelled. The original Attack continues.")
		$UILayer/Control.record_action_result(cancel_result)
		$UILayer/Control.update_ui()
		get_viewport().set_input_as_handled()
		return
	if move_mode and not combat_system.has_pending_step_back_move() and not combat_system.has_pending_ability_movement() and ((event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed) or event.is_action_pressed("ui_cancel")):
		move_mode = false
		get_viewport().set_input_as_handled()
		return
	if not pending_single_target_kind.is_empty() and ((event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed) or event.is_action_pressed("ui_cancel")):
		cancel_single_targeting()
		get_viewport().set_input_as_handled()
		return
	if pending_target_attack != null and ((event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed) or event.is_action_pressed("ui_cancel")):
		cancel_attack_targeting()
		get_viewport().set_input_as_handled()
		return
	if not ground_targeting_id.is_empty() and ((event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed) or event.is_action_pressed("ui_cancel")):
		cancel_ground_targeting()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed \
		and (not selected_target_id.is_empty() or has_selected_character()):
		clear_selected_target()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed:
		var mouse_position := get_global_mouse_position()
		if not pending_single_target_kind.is_empty():
			confirm_single_target(mouse_position)
			get_viewport().set_input_as_handled()
			return
		if pending_target_attack != null:
			confirm_attack_target(mouse_position)
			get_viewport().set_input_as_handled()
			return
		if not ground_targeting_id.is_empty():
			confirm_ground_targeting(mouse_position)
			get_viewport().set_input_as_handled()
			return
		if combat_system.has_pending_step_back_move() or combat_system.has_pending_ability_movement():
			move_player(mouse_position)
			get_viewport().set_input_as_handled()
			return
		if move_mode:
			move_player(mouse_position)
			get_viewport().set_input_as_handled()
			return
		if select_target_at(mouse_position):
			get_viewport().set_input_as_handled()
			return
		if move_mode:
			move_player(mouse_position)
		get_viewport().set_input_as_handled()


func select_target_at(mouse_position: Vector2) -> bool:
	for combatant_node in [$BattlefieldWorld/EnemyCharacter, $BattlefieldWorld/PlayerCharacter]:
		if combatant_node.state == null:
			continue
		var radius: float = combatant_node.state.collision_radius_feet * combat_system.map_rules.world_units_per_foot
		if mouse_position.distance_to(combatant_node.global_position) <= radius:
			if combatant_node.state.team == combat_system.get_combat_state().get_combatant("player").team:
				$UILayer/Control.add_log_message("Select an enemy target.")
				return true
			selected_target_id = combatant_node.state.id
			move_mode = false
			update_target_selection()
			$UILayer/Control.add_log_message("Target selected: %s." % combatant_node.state.display_name)
			return true
	return false


func update_target_selection() -> void:
	$BattlefieldWorld/PlayerCharacter.set_selected(false)
	$BattlefieldWorld/EnemyCharacter.set_selected($BattlefieldWorld/EnemyCharacter.state != null and $BattlefieldWorld/EnemyCharacter.state.id == selected_target_id)
	var target = combat_system.get_combat_state().get_combatant(selected_target_id)
	$UILayer/Control.set_selected_target(target.display_name if target != null else "None")


func move_player(destination: Vector2) -> void:
	if is_movement_animating():
		return
	if combat_system.has_pending_ability_movement():
		var ability_move_result := combat_system.execute_pending_ability_movement(destination)
		if ability_move_result.success:
			move_mode = false
			$BattlefieldWorld/PlayerCharacter.refresh_from_state()
			$UILayer/Control.set_mode_hint("Ability movement completed. Choose an action.")
		else:
			$UILayer/Control.set_mode_hint("Ability movement failed: %s Choose another destination." % ability_move_result.failure_reason)
		$UILayer/Control.record_action_result(ability_move_result)
		$UILayer/Control.update_ui()
		return
	if combat_system.has_pending_step_back_move():
		var reaction_move_name: String = combat_system.pending_reaction_move_name if not combat_system.pending_reaction_move_name.is_empty() else "Step Back"
		var step_result := combat_system.execute_step_back_move(destination)
		if step_result.requires_reaction_choice:
			move_mode = false
			$UILayer/Control.show_reaction_prompt(step_result.reaction_prompt)
			$UILayer/Control.set_mode_hint("Movement completed. Resolve the next Reaction.")
		elif step_result.success:
			move_mode = false
			$BattlefieldWorld/PlayerCharacter.refresh_from_state()
			$UILayer/Control.set_mode_hint("%s completed." % reaction_move_name)
			if reaction_move_name == "Step Back" and not combat_system.get_combat_state().is_finished() and combat_system.get_combat_state().current_actor_id == "enemy":
				combat_system.advance_turn()
		else:
			$UILayer/Control.set_mode_hint("Step Back failed: %s Choose another destination." % step_result.failure_reason)
		$UILayer/Control.record_action_result(step_result)
		$UILayer/Control.update_ui()
		return
	var movement := MovementData.new()
	movement.ap_cost = 1
	movement.world_units_per_foot = combat_system.map_rules.world_units_per_foot

	var acting_player := get_player_controlled_actor()
	if acting_player == null:
		return
	var request := ActionRequest.new(acting_player.id, ActionTypes.Type.MOVE)
	request.target_position = destination
	request.movement_data = movement

	var result := combat_system.execute_action(request)
	if result.requires_reaction_choice:
		$UILayer/Control.show_reaction_prompt(result.reaction_prompt)
		$UILayer/Control.set_mode_hint("Choose one Reaction before the Opportunity Attack resolves.")
		$UILayer/Control.record_action_result(result)
		return
	if result.success:
		$BattlefieldWorld/PlayerCharacter.refresh_from_state()
		var player: CombatantState = acting_player
		move_mode = player.movement_in_progress
		if move_mode:
			$UILayer/Control.set_mode_hint(
				"Continue Move: %.1f ft remaining. Using another action forfeits it." \
				% player.movement_remaining_feet
			)
		else:
			$UILayer/Control.set_mode_hint("Move completed. Choose an action to test.")

	$UILayer/Control.record_action_result(result)


func test_attack_unarmed() -> void:
	var unarmed := AttackData.new()
	unarmed.id = "unarmed_attack"
	unarmed.display_name = "Unarmed Attack"
	unarmed.attack_attribute = AttributeTypes.Type.STRENGTH
	unarmed.defense_type = DefenseTypes.Type.REFLEX
	unarmed.requires_to_hit = true
	unarmed.ap_cost = 1
	unarmed.base_damage = 2
	unarmed.range_feet = 5
	unarmed.damage_type = "blunt"
	unarmed.is_unarmed = true

	var request := ActionRequest.new("player", ActionTypes.Type.ATTACK)
	request.target_id = selected_target_id
	request.attack_data = unarmed

	var result := combat_system.execute_action(request)
	sync_move_mode_from_state()
	$UILayer/Control.record_action_result(result)


func cast_arcane_bolt() -> void:
	var request := ActionRequest.new("player", ActionTypes.Type.SKILL)
	request.target_id = selected_target_id
	request.skill_data = ArcaneBoltSkill
	var result := combat_system.execute_action(request)
	sync_move_mode_from_state()
	$UILayer/Control.record_action_result(result)

func test_attack_Heavy() -> void:

	var Heavy := AttackData.new()

	Heavy.id = "Heavy_attack"
	Heavy.display_name = "Heavy Attack"
	Heavy.attack_attribute = AttributeTypes.Type.CONSTITUTION
	Heavy.defense_type = DefenseTypes.Type.HIGHEST
	Heavy.requires_to_hit = true
	Heavy.ap_cost = 2
	Heavy.base_damage = 7
	Heavy.range_feet = 5
	Heavy.effects_on_hit = [StunData]

	var request := ActionRequest.new(
		"player",
		ActionTypes.Type.ATTACK
	)

	request.target_id = selected_target_id
	request.attack_data = Heavy

	var result := combat_system.execute_action(request)
	sync_move_mode_from_state()

	print("=== ATTACK TEST ===")
	print("Success: ", result.success)

	for event in result.events:
		print("Event: ", event.type)
		print("Data: ", event.data)

	$UILayer/Control.record_action_result(result)


func sync_move_mode_from_state() -> void:
	var player: CombatantState = get_player_controlled_actor()
	move_mode = player != null and player.movement_in_progress
