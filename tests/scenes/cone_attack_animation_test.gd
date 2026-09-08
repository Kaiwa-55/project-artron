extends SceneTree

const PrototypeScene := preload("res://scenes/prototype/PrototypeCombat.tscn")
const FlameWave := preload("res://data/skill/flame_wave.tres")
const ArcaneConeTemplate := preload("res://animation/arcane_cone.tres")
const PlayerTemplate := preload("res://data/character/player.tres")
const EnemyTemplate := preload("res://data/character/enemy.tres")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var failures: Array[String] = []
	var template: AttackAnimationData = FlameWave.attack_data.animation_template
	check(template != null and template.animation_type == AttackAnimationData.Type.CONE_BURST, "Flame Wave uses the reusable Cone FX template", failures)
	check(template.cone_play_once, "Cone Sprite Sheet animation defaults to one complete playback", failures)
	var caster: CombatantState = PlayerTemplate.create_combatant_state()
	var enemy: CombatantState = EnemyTemplate.create_combatant_state()
	var second_enemy: CombatantState = EnemyTemplate.create_combatant_state()
	second_enemy.id = "enemy_2"
	caster.position = Vector2.ZERO
	enemy.position = Vector2(10.0 * 12.0, 0.0)
	second_enemy.position = Vector2(9.0 * 12.0, 3.0 * 12.0)
	caster.available_skills.append(FlameWave)
	caster.base_max_mana = 10
	var system := CombatSystem.new()
	system.start_combat([caster, enemy, second_enemy])
	system.combat_state.current_actor_id = caster.id
	caster.ap = caster.max_ap
	caster.mana = 10
	var result: ActionResult = system.execute_ground_skill(caster.id, FlameWave.id, Vector2(15.0 * system.map_rules.world_units_per_foot, 0.0))
	var animation_events := result.events.filter(func(event): return event.type == EventTypes.Type.SKILL_CAST and event.data.get("animation_template") == template)
	check(result.success and animation_events.size() == 1 and int(animation_events[0].data.get("area_target_count", 0)) == 2, "A multi-target Cone action emits one shared FX event", failures)
	if animation_events.size() == 1:
		check(float(animation_events[0].data.get("area_length_feet", 0.0)) == 15.0 and float(animation_events[0].data.get("cone_angle_degrees", 0.0)) == 90.0, "Cone FX receives the Skill's real length and angle", failures)
	var arena = PrototypeScene.instantiate()
	root.add_child(arena)
	await process_frame
	var actor: CombatantState = arena.combat_system.get_combat_state().get_combatant("player")
	var token: Combatant = arena.get_node("BattlefieldWorld/PlayerCharacter")
	var target: Vector2 = actor.position + Vector2.RIGHT * 15.0 * arena.combat_system.map_rules.world_units_per_foot
	token.play_attack_animation(template, actor.position, target, 0.0, arena.combat_system.map_rules.world_units_per_foot, 15.0, 90.0)
	check(token.attack_sprite != null and token.is_attack_animating(), "Cone FX appears at the user and animates", failures)
	var expected_template_position: Vector2 = actor.position + actor.position.direction_to(target) * template.attached_offset_feet * float(arena.combat_system.map_rules.world_units_per_foot)
	check(token.attack_sprite.global_position.is_equal_approx(expected_template_position), "Cone FX uses the Template's attached offset", failures)
	var flame_frames := token.attack_sprite.get_node_or_null("SpriteFrames") as Sprite2D
	check(flame_frames != null and flame_frames.frame == template.first_frame, "Flame Wave displays the configured first Sprite Sheet frame", failures)
	await create_timer(0.2).timeout
	check(is_instance_valid(flame_frames) and flame_frames.frame > template.first_frame, "Flame Wave advances through its Sprite Sheet frames", failures)
	var flame_duration := float(template.last_frame - template.first_frame + 1) / template.frames_per_second
	await create_timer(flame_duration).timeout
	check(token.attack_sprite == null and not token.is_attack_animating(), "Cone FX cleans itself up after playing", failures)
	token.play_attack_animation(ArcaneConeTemplate, actor.position, target, 0.0, arena.combat_system.map_rules.world_units_per_foot, 15.0, 90.0)
	var sprite_frames := token.attack_sprite.get_node_or_null("SpriteFrames") as Sprite2D
	check(sprite_frames != null and sprite_frames.frame == ArcaneConeTemplate.first_frame, "Cone FX displays the configured first Sprite Sheet frame", failures)
	await create_timer(0.2).timeout
	check(is_instance_valid(sprite_frames) and sprite_frames.frame > ArcaneConeTemplate.first_frame, "Cone FX advances through the Sprite Sheet frames", failures)
	var arcane_duration := float(ArcaneConeTemplate.last_frame - ArcaneConeTemplate.first_frame + 1) / ArcaneConeTemplate.frames_per_second
	await create_timer(arcane_duration).timeout
	check(token.attack_sprite == null and not token.is_attack_animating(), "Sprite Sheet Cone FX cleans itself up after the final frame", failures)
	var offset_template: AttackAnimationData = ArcaneConeTemplate.duplicate(true)
	offset_template.attached_offset_feet = 3.0
	token.play_attack_animation(offset_template, actor.position, target, 0.0, arena.combat_system.map_rules.world_units_per_foot, 15.0, 90.0)
	var expected_offset: Vector2 = actor.position + Vector2.RIGHT * 3.0 * float(arena.combat_system.map_rules.world_units_per_foot)
	check(token.attack_sprite.global_position.is_equal_approx(expected_offset), "Cone FX supports attached_offset_feet in the aimed direction", failures)
	token.clear_attack_sprite()
	arena.queue_free()
	for failure in failures:
		push_error(failure)
	print("CONE_ATTACK_ANIMATION_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
