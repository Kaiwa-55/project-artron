extends SceneTree

const Visibility = preload("res://scenes/exploration/dungeon_visibility.gd")
const Scene = preload("res://scenes/exploration/DungeonExploration.tscn")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run_test")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func masked(sight: Node2D, point: Vector2) -> bool:
	for polygon in sight.shadow_polygons:
		if Geometry2D.is_point_in_polygon(point,polygon):
			return true
	return false

func run_test() -> void:
	var dungeon = Scene.instantiate()
	root.add_child(dungeon)
	await process_frame
	dungeon.player.set_physics_process(false)
	dungeon.set_floor(0,Vector2(480,440))
	var sight = dungeon.sight
	check(sight.can_see(Vector2(480,300)), "Ground doorway transmits sight")
	check(not masked(sight,Vector2(480,300)), "Visual mask leaves doorway visible")
	check(not sight.can_see(Vector2(350,300)), "Ground wall blocks sight")
	check(masked(sight,Vector2(350,300)), "Wall casts opaque visual shadow")
	dungeon.set_floor(1,Vector2(480,440))
	check(not sight.can_see(Vector2(480,300)) and masked(sight,Vector2(480,300)), "Changing floors immediately replaces occlusion")
	dungeon.set_floor(1,Vector2(440,440))
	check(sight.can_see(Vector2(440,300)) and not masked(sight,Vector2(440,300)), "Upper doorway transmits sight")
	dungeon.set_floor(0,Vector2(235,790))
	check(sight.can_see(Vector2(350,790)), "Invisible staircase rail does not block sight")
	dungeon.player.position = Vector2(760,1100)
	dungeon.update_view(0.1)
	check(sight.observer == dungeon.player.position, "Walking updates observer")
	var count: int = sight.rebuild_count
	dungeon.update_view(0.1)
	check(sight.rebuild_count == count, "Standing still reuses cached polygons")
	dungeon.toggle_overview()
	dungeon.update_view(0.1)
	check(sight.visible and sight.rebuild_count == count, "Overview preserves fog and does not rebuild for camera movement")
	# Compare the visual shadow with independent ray/rectangle intersection
	# across the map, avoiding exact edges where rasterization is ambiguous.
	for level in range(2):
		for origin in [Vector2(760,1300),Vector2(235,790),Vector2(440,350)]:
			dungeon.set_floor(level,origin)
			for x in range(33,1600,83):
				for y in range(37,1600,79):
					var point := Vector2(x,y)
					# Wall artwork remains visible at the occlusion boundary;
					# sight queries still reject targets embedded in walls.
					if sight.blockers.any(func(rect: Rect2): return rect.has_point(point)):
						continue
					check(masked(sight,point) == not sight.can_see(point),
						"Mask and sight query agree at %s, floor %d, origin %s" % [point,level,origin])
	check(Visibility.segment_hits_rect(Vector2(0,0),Vector2(20,20),Rect2(10,10,5,5)), "Corner ray is blocked")
	check(not Visibility.segment_hits_rect(Vector2(0,0),Vector2(0,20),Rect2(10,10,5,5)), "Parallel separated ray is clear")
	dungeon.queue_free()
	await process_frame
	print("DUNGEON_VISIBILITY_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
