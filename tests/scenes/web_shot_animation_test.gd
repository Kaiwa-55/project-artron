extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var token := Combatant.new()
	root.add_child(token)
	var actor := CombatantState.new()
	actor.position = Vector2(100, 100)
	token.setup(actor)
	var attack = load("res://data/attack/web_shot.tres")
	var template = attack.animation_template
	var success: bool = template != null and template.sprite_sheet.get_size() == Vector2(512, 640)
	var ap := actor.ap
	token.play_attack_animation(template, actor.position, Vector2(400, 100), 2.5, 12.0)
	success = success and token.attack_sprite.frame == 0 and token.is_attack_animating()
	var observed: Array[int] = []
	while token.is_attack_animating():
		if is_instance_valid(token.attack_sprite):
			var frame: int = token.attack_sprite.frame
			if not observed.has(frame):
				observed.append(frame)
		await process_frame
	success = success and observed == [0, 1, 2, 3, 4, 5, 6]
	success = success and token.attack_sprite == null and actor.position == Vector2(100, 100) and token.global_position == actor.position and actor.ap == ap
	token.play_attack_animation(template, actor.position, Vector2(400, 100), 2.5, 12.0)
	token.setup(actor)
	success = success and token.attack_sprite == null and not token.is_attack_animating()
	token.queue_free()
	await process_frame
	print("WEB_SHOT_ANIMATION_TEST: " + ("PASS" if success else "FAIL"))
	quit(0 if success else 1)
