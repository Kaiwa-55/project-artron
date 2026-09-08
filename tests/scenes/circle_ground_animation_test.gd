extends SceneTree

const PrototypeScene := preload("res://scenes/prototype/PrototypeCombat.tscn")
const ArcaneBurst := preload("res://data/skill/arcane_burst.tres")
const ArcaneCone := preload("res://data/skill/arcane_cone.tres")
const FrozenGround := preload("res://data/skill/frozen_ground.tres")
const PlayerTemplate := preload("res://data/character/player.tres")
const EnemyTemplate := preload("res://data/character/enemy.tres")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var failures: Array[String] = []
	var template: AttackAnimationData = ArcaneBurst.attack_data.animation_template
	check(template != null and template.animation_type == AttackAnimationData.Type.CIRCLE_GROUND, "Arcane Burst uses the reusable ground Circle FX", failures)
	check(ArcaneCone.attack_data.animation_template.animation_type == AttackAnimationData.Type.CONE_BURST, "Arcane Cone keeps its separate Cone FX", failures)
	check(FrozenGround.attack_data.animation_template.animation_type == AttackAnimationData.Type.CIRCLE_GROUND, "Frozen Ground uses a ground Circle FX", failures)
	var caster: CombatantState = PlayerTemplate.create_combatant_state()
	var enemy: CombatantState = EnemyTemplate.create_combatant_state()
	var second_enemy: CombatantState = EnemyTemplate.create_combatant_state()
	second_enemy.id = "enemy_2"
	caster.position = Vector2.ZERO
	enemy.position = Vector2(15.0 * 12.0, 0.0)
	second_enemy.position = Vector2(17.0 * 12.0, 0.0)
	caster.available_skills = [ArcaneBurst]
	caster.base_max_mana = 10
	var system := CombatSystem.new()
	system.start_combat([caster, enemy, second_enemy])
	system.combat_state.current_actor_id = caster.id
	caster.ap = caster.max_ap
	caster.mana = 10
	var target_point := Vector2(16.0 * system.map_rules.world_units_per_foot, 0.0)
	var result: ActionResult = system.execute_ground_skill(caster.id, ArcaneBurst.id, target_point)
	var animation_events := result.events.filter(func(event): return event.type == EventTypes.Type.SKILL_CAST and event.data.get("animation_template") == template)
	check(result.success and animation_events.size() == 1, "A multi-target Circle emits one shared ground FX event", failures)
	if animation_events.size() == 1:
		check(float(animation_events[0].data.get("area_radius_feet", 0.0)) == ArcaneBurst.area_radius_feet, "Circle FX receives the Skill's real radius", failures)
	var arena = PrototypeScene.instantiate()
	root.add_child(arena)
	await process_frame
	var token: Combatant = arena.get_node("BattlefieldWorld/PlayerCharacter")
	token.play_attack_animation(template, Vector2.ZERO, target_point, 0.0, system.map_rules.world_units_per_foot, 0.0, 90.0, ArcaneBurst.area_radius_feet)
	check(token.attack_sprite != null and token.attack_sprite.global_position.is_equal_approx(target_point), "Circle FX appears at the selected ground point", failures)
	var sprite_frames := token.attack_sprite.get_node_or_null("SpriteFrames") as Sprite2D
	check(sprite_frames != null and sprite_frames.frame == template.first_frame, "Circle FX displays the configured first Sprite Sheet frame", failures)
	await create_timer(0.2).timeout
	check(is_instance_valid(sprite_frames) and sprite_frames.frame > template.first_frame, "Circle FX advances through its Sprite Sheet frames", failures)
	var duration := float(template.last_frame - template.first_frame + 1) / template.frames_per_second
	await create_timer(duration).timeout
	check(token.attack_sprite == null and not token.is_attack_animating(), "Circle FX cleans itself up after the final frame", failures)
	arena.queue_free()
	for failure in failures:
		push_error(failure)
	print("CIRCLE_GROUND_ANIMATION_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
