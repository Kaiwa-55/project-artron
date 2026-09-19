class_name VisionSystem
extends RefCounted

enum Visibility { VISIBLE, PARTIALLY_VISIBLE, NOT_VISIBLE }

const MIN_LEVEL := 0
const MAX_LEVEL := 4
const PARTIAL_ATTACK_PENALTY := -4

static func clamp_level(value: int) -> int:
	return clampi(value, MIN_LEVEL, MAX_LEVEL)

static func light_concealment(light_level: int) -> int:
	# 0 bright, 1 normal, 2 dim, 3 darkness.
	return maxi(0, light_level - 1)

static func total_concealment(target, light_level: int = 1) -> int:
	var hidden_bonus := MAX_LEVEL if target.has_status("hidden") else 0
	return maxi(0, int(target.base_concealment) + int(target.concealment_bonus) + target.get_skill_rank("stealth") + _effect_total(target, "concealment_bonus") + hidden_bonus + light_concealment(light_level))

static func effective_concealment(observer, target, light_level: int = 1) -> int:
	var concealment: int = total_concealment(target, light_level) + target.get_concealment_bonus_against(observer.id) - target.get_concealment_reduction_against(observer.id)
	# Dark Vision only counters concealment originating from the scene light.
	concealment -= mini(light_concealment(light_level), int(observer.dark_vision) + _effect_total(observer, "dark_vision_bonus"))
	concealment -= _effect_total(observer, "reveal_concealment") + _effect_total(observer, "true_sight_concealment")
	return clamp_level(concealment)

static func get_visibility(observer, target, light_level: int = 1, has_los: bool = true) -> Visibility:
	if not has_los:
		return Visibility.NOT_VISIBLE
	var vision := 0 if observer.has_status("blind") else clamp_level(int(observer.vision) + observer.get_skill_rank("perception") + _effect_total(observer, "vision_bonus") - int(observer.vision_penalty))
	var concealment := effective_concealment(observer, target, light_level)
	if vision >= concealment:
		return Visibility.VISIBLE
	if vision == concealment - 1:
		return Visibility.PARTIALLY_VISIBLE
	return Visibility.NOT_VISIBLE

static func get_visibility_result(observer, target, light_level: int = 1, has_los: bool = true) -> Dictionary:
	var visibility := get_visibility(observer, target, light_level, has_los)
	var total: int = maxi(0, total_concealment(target, light_level) + target.get_concealment_bonus_against(observer.id) - target.get_concealment_reduction_against(observer.id))
	return {
		"visibility": visibility,
		"visible": visibility == Visibility.VISIBLE,
		"partially_visible": visibility == Visibility.PARTIALLY_VISIBLE,
		"not_visible": visibility == Visibility.NOT_VISIBLE,
		"attack_penalty": PARTIAL_ATTACK_PENALTY if visibility == Visibility.PARTIALLY_VISIBLE else 0,
		"total_concealment": total,
		"effective_concealment": effective_concealment(observer, target, light_level)
	}


static func _effect_total(combatant, property_name: String) -> int:
	if combatant == null:
		return 0
	var total := 0
	for instance in combatant.effects:
		if instance != null and instance.data != null:
			total += int(instance.data.get(property_name)) * instance.stack_count
	return total
