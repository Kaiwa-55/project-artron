class_name TargetingSelectionPresentation
extends Node

func find_combatant_at(world_position: Vector2, combatant_nodes: Array, units_per_foot: float):
	for combatant_node in combatant_nodes:
		if not is_instance_valid(combatant_node) or combatant_node.state == null or combatant_node.state.is_dying():
			continue
		var radius: float = combatant_node.state.collision_radius_feet * units_per_foot
		if world_position.distance_to(combatant_node.global_position) <= radius:
			return combatant_node
	return null

func apply_selection(combatant_nodes: Array, selected_id: String) -> void:
	for combatant_node in combatant_nodes:
		if is_instance_valid(combatant_node) and combatant_node.state != null:
			combatant_node.set_selected(combatant_node.state.id == selected_id)
