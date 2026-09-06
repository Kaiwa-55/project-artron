class_name DiceSystem
extends RefCounted


func roll(count: int, sides: int) -> int:
	if count <= 0:
		return 0

	if sides <= 0:
		return 0

	var total := 0

	for i in count:
		total += randi_range(1, sides)

	return total


func roll_3d8() -> int:
	return roll(3, 8)


func roll_percent() -> int:
	return randi_range(1, 100)
