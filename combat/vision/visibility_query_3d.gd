extends RefCounted

const VISIBILITY_MASK := 1 | 2 | 4
const EPSILON := 0.001

func is_segment_clear(world: Node3D, from: Vector3, to: Vector3) -> bool:
	if world == null or from.is_equal_approx(to):
		return true
	var direction := (to - from).normalized()
	var parameters := PhysicsRayQueryParameters3D.create(from + direction * EPSILON, to - direction * EPSILON, VISIBILITY_MASK)
	parameters.hit_back_faces = true
	parameters.hit_from_inside = true
	return world.get_world_3d().direct_space_state.intersect_ray(parameters).is_empty()

func query(world: Node3D, observer, target) -> Dictionary:
	var eye: Vector3 = observer.world_position + observer.eye_offset
	var samples: Array[Dictionary] = []
	var clear := 0
	for ratio in [0.9, 0.6, 0.35]:
		var point: Vector3 = target.world_position + Vector3.UP * target.body_height_feet * ratio
		var direction := (point - eye).normalized()
		# Walkable floor, walls, and railings block sight in either direction.
		# Movement-only invisible walls (layer 8) deliberately do not.
		var parameters := PhysicsRayQueryParameters3D.create(eye + direction * EPSILON, point - direction * EPSILON, VISIBILITY_MASK)
		parameters.hit_back_faces = true
		parameters.hit_from_inside = true
		var hit := world.get_world_3d().direct_space_state.intersect_ray(parameters)
		var passed := hit.is_empty()
		if passed:
			clear += 1
		samples.append({"clear": passed, "from": eye, "target": point,
			"position": point if passed else hit.position,
			"occluder_type": "" if passed else hit.collider.get_meta("occluder_type", "UNKNOWN"),
			"collider": null if passed else hit.collider})
	return {"state": "HIDDEN" if clear == 0 else ("PARTIAL" if clear == 1 else "VISIBLE"),
		"clear_samples": clear, "total_samples": 3, "samples": samples,
		"observer_position": eye, "cover": ["TOTAL", "HEAVY", "LIGHT", "NONE"][clear]}
