extends Node2D

const Layout = preload("res://scenes/exploration/dungeon_layout.gd")
const SHADOW_REACH := 5000.0 # Longer than the entire map diagonal.
const SHADOW_COLOR := Color(0.025, 0.035, 0.045, 1.0)
var observer := Vector2.INF
var floor_id := -1
var blockers: Array[Rect2] = []
var shadow_polygons: Array[PackedVector2Array] = []
var rebuild_count := 0

func update_observer(position: Vector2, level: int) -> void:
	if position == observer and level == floor_id:
		return
	if floor_id != level:
		blockers = Layout.sight_walls(level)
	observer = position
	floor_id = level
	rebuild_shadows()

func rebuild_shadows() -> void:
	shadow_polygons.clear()
	var bounds := PackedVector2Array([
		Vector2.ZERO, Vector2(1600,0), Layout.SIZE, Vector2(0,1600)
	])
	for wall in blockers:
		# The convex hull of the wall and its projected corners is its shadow.
		# Opaque fills form a union: overlapping shadows never get darker.
		var corners := PackedVector2Array([
			wall.position, Vector2(wall.end.x,wall.position.y),
			wall.end, Vector2(wall.position.x,wall.end.y)
		])
		var projected := corners.duplicate()
		for corner in corners:
			projected.append(corner + observer.direction_to(corner) * SHADOW_REACH)
		var hull := Geometry2D.convex_hull(projected)
		# Keep the wall's own artwork readable. Other, nearer walls still hide
		# it normally; only the area behind this blocker is filled.
		for behind_wall in Geometry2D.clip_polygons(hull,corners):
			for clipped in Geometry2D.intersect_polygons(behind_wall,bounds):
				if clipped.size() >= 3:
					shadow_polygons.append(clipped)
	rebuild_count += 1
	queue_redraw()

func can_see(point: Vector2) -> bool:
	if floor_id < 0 or not Rect2(Vector2.ZERO,Layout.SIZE).has_point(point):
		return false
	for wall in blockers:
		if segment_hits_rect(observer,point,wall):
			return false
	return true

static func segment_hits_rect(start: Vector2, finish: Vector2, rect: Rect2) -> bool:
	# Slab intersection, including parallel rays and corner tangencies.
	var direction := finish - start
	var entry := 0.0
	var exit_time := 1.0
	for axis in range(2):
		if absf(direction[axis]) < 0.000001:
			if start[axis] < rect.position[axis] or start[axis] > rect.end[axis]:
				return false
		else:
			var first := (rect.position[axis] - start[axis]) / direction[axis]
			var last := (rect.end[axis] - start[axis]) / direction[axis]
			entry = maxf(entry,minf(first,last))
			exit_time = minf(exit_time,maxf(first,last))
			if entry > exit_time:
				return false
	return true

func _draw() -> void:
	for polygon in shadow_polygons:
		draw_colored_polygon(polygon,SHADOW_COLOR)
