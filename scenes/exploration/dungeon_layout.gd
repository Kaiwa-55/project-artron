extends RefCounted

# World units correspond to the 1600px reference, not the 5120px source image.
# Rectangles are deliberately explicit so artists can refine them independently.
const SIZE := Vector2(1600, 1600)
const INTERIOR := Rect2(170, 170, 1260, 1260)
const STAIRS := Rect2(177, 590, 108, 230)
const STAIR_LANDING := Vector2(235, 790)
const START := Vector2(760, 1500)
const RADIUS := 10.0
const HOSTILE_ID := "ground_hall_guards"
const HOSTILE_AREA := Rect2(720, 510, 190, 180)
const HOSTILE_POSITIONS := [Vector2(790,590), Vector2(860,630)]
const COMBAT_ENEMY_POSITIONS := [Vector2(790,590), Vector2(860,630), Vector2(820,540), Vector2(740,640)]

static func walls(floor_id: int) -> Array[Rect2]:
	var result: Array[Rect2] = [
		Rect2(150,150,1300,20), Rect2(150,150,20,1300),
		Rect2(1430,150,20,1300), Rect2(150,1430,570,20), Rect2(800,1430,650,20),
		Rect2(310,170,20,230), Rect2(550,170,20,230), Rect2(790,170,20,230),
		Rect2(170,870,390,20), Rect2(550,880,20,44), Rect2(550,996,20,434),
		Rect2(950,880,20,44), Rect2(950,996,20,434), Rect2(960,870,470,20),
		Rect2(1200,630,230,20),
		Rect2(166,570,6,250), Rect2(292,570,6,250), Rect2(170,567,126,6),
		Rect2(-20,-20,1640,20), Rect2(-20,1600,1640,20),
		Rect2(-20,0,20,1600), Rect2(1600,0,20,1600)
	]
	if floor_id == 0:
		result.append_array([
			Rect2(320,390,124,20), Rect2(516,390,88,20),
			Rect2(676,390,168,20), Rect2(916,390,284,20),
			Rect2(1190,170,20,376), Rect2(1190,616,20,68), Rect2(1190,756,20,114)
		])
	else:
		result.append_array([
			Rect2(320,390,80,20), Rect2(480,390,200,20),
			Rect2(760,390,80,20), Rect2(920,390,280,20),
			Rect2(1190,170,20,270), Rect2(1190,520,20,160), Rect2(1190,760,20,110),
			Rect2(720,1430,80,20)
		])
	return result

static func can_stand(point: Vector2, floor_id: int) -> bool:
	if floor_id not in [0, 1]:
		return false
	var bounds := Rect2(Vector2.ZERO, SIZE) if floor_id == 0 else INTERIOR
	if not bounds.grow(-RADIUS).has_point(point):
		return false
	for rect in walls(floor_id):
		var closest := point.clamp(rect.position, rect.end)
		if point.distance_squared_to(closest) < RADIUS * RADIUS:
			return false
	return true

# Stair guide rails, map limits and the upper-floor fall barrier only stop
# movement. They are not tall walls and must not cast sight shadows.
static func sight_walls(floor_id: int) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var movement_only: Array[Rect2] = [
		Rect2(166,570,6,250), Rect2(292,570,6,250), Rect2(170,567,126,6),
		Rect2(720,1430,80,20)
	]
	for rect in walls(floor_id):
		if rect in movement_only or not INTERIOR.intersects(rect.grow(1)):
			continue
		result.append(rect)
	return result


static func world_to_combat_feet(position: Vector2) -> Vector2:
	return (position - SIZE * 0.5) / 12.0


static func combat_wall_objects(floor_id: int) -> Array[Dictionary]:
	var objects: Array[Dictionary] = []
	var walls := sight_walls(floor_id)
	for index in range(walls.size()):
		var rect: Rect2 = walls[index]
		objects.append({
			"id": "wall_%d" % index,
			"kind": "obstacle",
			"label": "Stone Wall",
			"rect_feet": Rect2(world_to_combat_feet(rect.position), rect.size / 12.0),
			"blocks_movement": true,
			"blocks_line_of_sight": true,
		})
	return objects
