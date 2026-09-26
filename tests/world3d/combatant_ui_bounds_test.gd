extends SceneTree

const CombatScene = preload("res://scenes/prototype/PrototypeCombat.tscn")
const Bleeding = preload("res://data/status/bleeding.tres")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run_test() -> void:
	var arena = CombatScene.instantiate()
	root.add_child(arena)
	await process_frame
	var visual = arena.spatial_combatants.front()
	var token: Combatant = visual.proxy
	token.state.collision_radius_feet = 5.0
	token.set_selected(true)
	token.ensure_concealment_badge()
	token.concealment_badge.text = "C 1"
	token.concealment_badge.visible = true
	token.state.add_effect(Bleeding)
	visual.sync_state()
	check(visual.label.text == token.state.display_name, "Enemy name no longer includes HP text")
	check(visual.concealment_visual.position.x > token.state.collision_radius_feet and visual.concealment_visual.position.z > 0.0, "Concealment sits below the right end of the health arc")
	check(token.get_concealment_badge_position().x > token.state.collision_radius_feet * token.state.spatial_units_per_foot and token.get_concealment_badge_position().y > 0.0, "2D Concealment badge uses the same lower-right position")
	check(visual.selection_visual.visible and visual.selection_visual.get_parent() == visual, "Selection frame renders outside the capture viewport")
	check(visual.concealment_visual.visible and visual.concealment_visual.text == "C 1", "Concealment badge renders outside the capture viewport")
	check(visual.status_visuals.get_child_count() == 1, "Status icon renders outside the capture viewport")
	check(token.selection_frame.visibility_layer == 0 and token.concealment_badge.visibility_layer == 0, "Legacy selection and concealment UI are not captured")
	check(token.status_icon_layer.visibility_layer == 0 and token.status_icon_layer.get_child(0).visibility_layer == 0, "Status icon descendants are not captured")
	token.visual_offset = Vector2(300, 75)
	visual.sync_state()
	check(visual.capture_camera.position.is_equal_approx(token.global_position + token.visual_offset), "Capture follows the melee lunge instead of clipping the token")
	check(is_equal_approx(visual.sprite.position.x, 300.0 / token.state.spatial_units_per_foot) and is_equal_approx(visual.sprite.position.z, 75.0 / token.state.spatial_units_per_foot), "3D token follows the melee lunge")
	token.visual_offset = Vector2.ZERO
	visual.sync_state()
	token.show_combat_value_feedback(7, false)
	check(token.floating_value_labels.size() == 1 and token.floating_value_labels[0] is Label3D, "Damage number renders directly in 3D")
	if token.floating_value_labels.size() == 1:
		check(token.floating_value_labels[0].get_parent() == visual, "Damage number is not confined to the token capture")
	token.clear_combat_value_feedback()
	var projectile := Sprite2D.new()
	projectile.texture = preload("res://assets/ui/ui03.png")
	token.add_child(projectile)
	projectile.global_position = token.global_position + Vector2(600, 0)
	token.attack_sprite = projectile
	visual.sync_state()
	check(visual.attack_visual != null and visual.attack_visual.visible, "Projectile renders directly in 3D beyond the token capture")
	check(projectile.visibility_layer == 0, "Projectile is excluded from token capture")
	check(is_equal_approx(visual.attack_visual.global_position.x, projectile.global_position.x / token.state.spatial_units_per_foot), "Projectile preserves its position outside the token bounds")
	token.clear_attack_sprite()
	visual.sync_state()
	check(not visual.attack_visual.visible, "Finished projectile is hidden")
	token.state.remove_status("bleeding")
	visual.sync_state()
	await process_frame
	check(visual.status_visuals.get_child_count() == 0, "Expired status icon is removed from the 3D presentation")
	arena.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("COMBATANT_UI_BOUNDS_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
