extends SceneTree

const AreaVisual = preload("res://scenes/world3d/area_visual_3d.gd")
const ArcaneBurst = preload("res://data/skill/arcane_burst.tres")

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var visual = AreaVisual.new()
	world.add_child(visual)
	visual.configure(SkillData.AreaShape.CIRCLE, Vector3.ZERO, Vector3(10, 10, 0), 7.5, 0.0, 0.0, 90.0, Color(1, 0, 0, 0.2), Color.RED)
	var bounds: AABB = visual.fill.get_aabb()
	var passed := bounds.size.x > 14.0 and bounds.size.z > 14.0 and bounds.position.y > 10.0
	visual.set_animation(ArcaneBurst.attack_data.animation_template, SkillData.AreaShape.CIRCLE, Vector3.ZERO, Vector3(10, 10, 0), 7.5, 0.0, 0.0, 12.0)
	passed = passed and visual.animation_sprite != null and visual.animation_sprite.get_parent() == visual
	visual.configure(SkillData.AreaShape.CONE, Vector3.ZERO, Vector3(10, 0, 0), 0.0, 15.0, 0.0, 90.0, Color(1, 0, 0, 0.2), Color.RED)
	passed = passed and visual.fill.mesh != null and visual.outline.mesh != null
	visual.play(0.1)
	await create_timer(0.2).timeout
	passed = passed and not is_instance_valid(visual)
	world.queue_free()
	print("AREA_VISUAL_3D_TEST: " + ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
