class_name EnemyGroupData
extends Resource

## Data-driven enemy wave used when an Encounter is built.
@export var id: String = "group"
@export var enemy: CharacterData
@export_range(1, 50, 1) var count: int = 1
@export var spawn_center_feet: Vector2 = Vector2.ZERO
## Optional random area in feet from the map center. Empty uses the fixed formation.
@export var spawn_area_feet: Rect2 = Rect2()
@export var spacing_feet: float = 8.0
@export var min_party_level: int = 1
@export var max_party_level: int = 0 # 0 means no upper limit.
@export var required_run_flags: Dictionary = {}

func is_active(party_level: int, run_flags: Dictionary = {}) -> bool:
	if enemy == null or count <= 0:
		return false
	if party_level < min_party_level:
		return false
	if max_party_level > 0 and party_level > max_party_level:
		return false
	for key in required_run_flags:
		if bool(run_flags.get(key, false)) != bool(required_run_flags[key]):
			return false
	return true

func get_spawn_position(index: int, rng: RandomNumberGenerator = null) -> Vector2:
	if spawn_area_feet.has_area():
		var area := spawn_area_feet.abs()
		var generator := rng if rng != null else RandomNumberGenerator.new()
		if rng == null:
			generator.randomize()
		return Vector2(generator.randf_range(area.position.x, area.end.x), generator.randf_range(area.position.y, area.end.y))
	if index <= 0:
		return spawn_center_feet
	var ring := int(ceil(float(index) / 6.0))
	var slot := (index - 1) % 6
	var angle := TAU * float(slot) / 6.0
	return spawn_center_feet + Vector2.from_angle(angle) * spacing_feet * float(ring)
