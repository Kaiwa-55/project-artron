extends SceneTree


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var failures: Array[String] = []
	var ability: AbilityData = load("res://data/ability/ki_wave.tres")
	var template: AttackAnimationData = ability.animation_template
	check(template != null, "Ki Wave has an Ability animation template", failures)
	check(template.sprite_sheet != null and template.sprite_sheet.get_size() == Vector2(640, 576), "Ki Wave uses Assets_set1 Part 2 sprite sheet 69", failures)
	check(template.columns == 10 and template.rows == 9 and template.first_frame == 20 and template.last_frame == 29, "Ki Wave uses the cyan animation row", failures)
	check(template.animation_type == AttackAnimationData.Type.ATTACHED_DIRECTIONAL, "Ki Wave uses attached directional animation", failures)
	check(template.attached_offset_feet == 3.0, "Ki Wave configures its forward offset in feet", failures)

	var token := Combatant.new()
	root.add_child(token)
	var actor := CombatantState.new()
	actor.position = Vector2(100, 100)
	token.setup(actor)
	token.play_attack_animation(template, actor.position, Vector2(400, 100), 2.5, 12.0)
	check(token.attack_sprite != null and token.attack_sprite.frame == 20 and token.is_attack_animating(), "Ki Wave starts on its configured first frame", failures)
	var expected_effect_position := actor.position + Vector2.RIGHT * template.attached_offset_feet * 12.0
	check(token.attack_sprite.global_position == expected_effect_position, "Ki Wave animation starts at its configured forward offset", failures)
	check(is_equal_approx(token.attack_sprite.rotation, PI * 0.5), "Ki Wave rotates toward the selected line direction", failures)
	var observed_last_frame := false
	var remained_attached := true
	while token.is_attack_animating():
		if is_instance_valid(token.attack_sprite):
			observed_last_frame = observed_last_frame or token.attack_sprite.frame == 29
			remained_attached = remained_attached and token.attack_sprite.global_position == expected_effect_position
		await process_frame
	check(observed_last_frame, "Ki Wave reaches its configured final frame", failures)
	check(remained_attached, "Ki Wave animation does not travel away from its user", failures)
	check(token.attack_sprite == null and actor.position == Vector2(100, 100), "Ki Wave animation cleans up without changing logical position", failures)
	token.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("KI_WAVE_ANIMATION_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
