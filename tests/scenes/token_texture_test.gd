extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var data := CharacterData.new()
	data.token_texture = load("res://assets/icon/skill_icons22.png")
	data.token_scale = 1.5
	data.token_offset = Vector2(0, -5)
	var state := data.create_combatant_state()
	var token := Combatant.new()
	root.add_child(token)
	token.setup(state)
	token.set_selected(true)
	var token_image := state.token_texture.get_image()
	var success := state.token_texture != data.token_texture and state.token_texture.get_size() == Vector2(256, 256)
	success = success and token_image.get_pixel(0, 0).a == 0.0 and token_image.get_pixel(128, 128).a > 0.0
	success = success and state.token_scale == 1.0 and state.token_offset == Vector2.ZERO
	state.position = Vector2(60, 0)
	token.refresh_from_state()
	await create_timer(0.3).timeout
	success = success and token.global_position == state.position
	token.play_attack_animation(load("res://animation/lunge_return.tres"), state.position, Vector2(180, 0), 2.5, 12.0)
	await create_timer(0.6).timeout
	success = success and token.visual_offset.is_zero_approx() and token.global_position == state.position
	state.token_texture = null
	token.refresh_from_state()
	await process_frame
	token.queue_free()
	await process_frame
	print("TOKEN_TEXTURE_TEST: " + ("PASS" if success else "FAIL"))
	quit(0 if success else 1)
