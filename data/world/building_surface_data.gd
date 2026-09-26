class_name BuildingSurfaceData
extends Resource

@export var surface_id: StringName
@export var display_name: String
@export var elevation_feet: float = 0.0
@export var texture: Texture2D
@export var walkable_rects: Array[Rect2] = []
@export var opening_rects: Array[Rect2] = []
@export var wall_rects: Array[Rect2] = []
@export var wall_rect_heights_feet: Array[float] = []
@export var wall_segments: Array[Resource] = []
@export var railing_rects: Array[Rect2] = []
@export var invisible_wall_rects: Array[Rect2] = []
@export var objects: Array[BuildingObjectData] = []
@export var doors: Array[BuildingDoorData] = []

func solid_rects() -> Array[Rect2]:
	return _subtract_rects(walkable_rects, opening_rects)

func wall_solid_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for entry in wall_solid_entries():
		result.append(entry.rect)
	return result


func wall_solid_entries() -> Array[Dictionary]:
	var cuts: Array[Rect2] = []
	for door in doors:
		if door != null:
			cuts.append(door.rect)
	var result: Array[Dictionary] = []
	for index in range(wall_rects.size()):
		var single: Array[Rect2] = [wall_rects[index]]
		for solid in _subtract_rects(single, cuts):
			result.append({"rect": solid, "height_feet": wall_rect_heights_feet[index] if index < wall_rect_heights_feet.size() else 9.0})
	return result


func wall_solid_segments(pixels_per_foot: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for wall in wall_segments:
		if wall == null or wall.from_position.is_equal_approx(wall.to_position):
			continue
		var intervals: Array[Vector2] = [Vector2(0.0, 1.0)]
		for door in doors:
			if door == null:
				continue
			var cut := _segment_inside_rect_interval(wall.from_position, wall.to_position, door.rect.grow(wall.width_feet * pixels_per_foot * 0.5))
			if cut.x < 0.0:
				continue
			var remaining: Array[Vector2] = []
			for interval in intervals:
				if cut.x > interval.x + 0.0001:
					remaining.append(Vector2(interval.x, minf(interval.y, cut.x)))
				if cut.y < interval.y - 0.0001:
					remaining.append(Vector2(maxf(interval.x, cut.y), interval.y))
			intervals = remaining
		var direction: Vector2 = wall.to_position - wall.from_position
		for interval in intervals:
			if interval.y > interval.x + 0.0001:
				result.append({"from": wall.from_position + direction * interval.x, "to": wall.from_position + direction * interval.y, "width_feet": wall.width_feet, "height_feet": wall.height_feet})
	return result


func _segment_inside_rect_interval(start: Vector2, finish: Vector2, rect: Rect2) -> Vector2:
	var direction := finish - start
	var first := 0.0
	var last := 1.0
	for side in [Vector2(-direction.x, start.x - rect.position.x), Vector2(direction.x, rect.end.x - start.x), Vector2(-direction.y, start.y - rect.position.y), Vector2(direction.y, rect.end.y - start.y)]:
		if is_zero_approx(side.x):
			if side.y < 0.0:
				return Vector2(-1.0, -1.0)
			continue
		var progress: float = side.y / side.x
		if side.x < 0.0:
			first = maxf(first, progress)
		else:
			last = minf(last, progress)
		if first > last:
			return Vector2(-1.0, -1.0)
	return Vector2(first, last)

func _subtract_rects(original: Array[Rect2], cuts: Array[Rect2]) -> Array[Rect2]:
	var result: Array[Rect2] = original.duplicate()
	for opening in cuts:
		var next: Array[Rect2] = []
		for rect in result:
			var cut := rect.intersection(opening)
			if not cut.has_area():
				next.append(rect)
				continue
			for piece in [Rect2(rect.position, Vector2(rect.size.x, cut.position.y - rect.position.y)), Rect2(Vector2(rect.position.x, cut.end.y), Vector2(rect.size.x, rect.end.y - cut.end.y)), Rect2(Vector2(rect.position.x, cut.position.y), Vector2(cut.position.x - rect.position.x, cut.size.y)), Rect2(Vector2(cut.end.x, cut.position.y), Vector2(rect.end.x - cut.end.x, cut.size.y))]:
				if piece.has_area():
					next.append(piece)
		result = next
	return result
