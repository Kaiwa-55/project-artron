extends Control

const VisionSystemScript = preload("res://combat/vision/vision_system.gd")

@onready var vision_input: SpinBox = %VisionInput
@onready var dark_vision_input: SpinBox = %DarkVisionInput
@onready var base_input: SpinBox = %BaseInput
@onready var bonus_input: SpinBox = %BonusInput
@onready var light_input: OptionButton = %LightInput
@onready var los_input: CheckButton = %LosInput
@onready var target_zone_input: OptionButton = %TargetZoneInput
@onready var result_label: Label = %ResultLabel
@onready var formula_label: Label = %FormulaLabel

var observer := CombatantState.new()
var target := CombatantState.new()


func _ready() -> void:
	light_input.add_item("Bright Light", 0)
	light_input.add_item("Normal Light", 1)
	light_input.add_item("Dim Light", 2)
	light_input.add_item("Darkness", 3)
	light_input.select(3)
	target_zone_input.add_item("Bright Light", 0)
	target_zone_input.add_item("Dim Light", 2)
	target_zone_input.add_item("Darkness", 3)
	target_zone_input.select(2)
	for input in [vision_input, dark_vision_input, base_input, bonus_input]:
		input.value_changed.connect(_on_value_changed)
	light_input.item_selected.connect(_on_light_selected)
	target_zone_input.item_selected.connect(_on_target_zone_selected)
	los_input.toggled.connect(_on_los_toggled)
	_update_result()


func _on_value_changed(_value: float) -> void:
	_update_result()


func _on_light_selected(_index: int) -> void:
	_update_result()


func _on_target_zone_selected(_index: int) -> void:
	light_input.select(target_zone_input.get_selected())
	_update_result()


func _on_los_toggled(_pressed: bool) -> void:
	_update_result()


func _update_result() -> void:
	observer.vision = int(vision_input.value)
	observer.dark_vision = int(dark_vision_input.value)
	target.base_concealment = int(base_input.value)
	target.concealment_bonus = int(bonus_input.value)
	var light_level := target_zone_input.get_selected_id()
	var result := VisionSystemScript.get_visibility_result(observer, target, light_level, los_input.button_pressed)
	var names := ["VISIBLE", "PARTIALLY VISIBLE", "NOT VISIBLE"]
	result_label.text = "%s%s" % [names[result.visibility], "  |  Attack -4" if result.attack_penalty < 0 else ""]
	formula_label.text = "Zone: %s\nTotal: %d  |  Effective: %d  |  Vision: %d" % [
		target_zone_input.get_item_text(target_zone_input.selected),
		result.total_concealment,
		result.effective_concealment,
		observer.vision
	]
	match result.visibility:
		VisionSystemScript.Visibility.VISIBLE:
			result_label.modulate = Color("72e59a")
		VisionSystemScript.Visibility.PARTIALLY_VISIBLE:
			result_label.modulate = Color("ffd166")
		_:
			result_label.modulate = Color("ff6b6b")
	queue_redraw()


func _draw() -> void:
	var observer_position := Vector2(75, 258)
	var target_positions := [Vector2(170, 258), Vector2(275, 258), Vector2(380, 258)]
	var target_position: Vector2 = target_positions[target_zone_input.selected]
	var line_color := Color("69d2e7") if los_input.button_pressed else Color("ff6b6b")
	# Three adjacent areas are deliberately colored to make lighting effects clear.
	draw_rect(Rect2(20, 180, 105, 145), Color("fff0a8", 0.35), true)
	draw_rect(Rect2(125, 180, 105, 145), Color("7580b5", 0.38), true)
	draw_rect(Rect2(230, 180, 170, 145), Color("151827", 0.9), true)
	draw_string(ThemeDB.fallback_font, Vector2(44, 202), "BRIGHT\n+0", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(151, 202), "DIM\n+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(280, 202), "DARKNESS\n+2", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	draw_line(observer_position, target_position, line_color, 3.0)
	if not los_input.button_pressed:
		draw_rect(Rect2(220, 220, 24, 78), Color("6f7480"), true)
		draw_string(ThemeDB.fallback_font, Vector2(204, 315), "STONE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	draw_circle(observer_position, 28.0, Color("4f8cff"))
	draw_circle(target_position, 28.0, Color("d678c8"))
	draw_string(ThemeDB.fallback_font, observer_position + Vector2(-34, 50), "Observer", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	draw_string(ThemeDB.fallback_font, target_position + Vector2(-24, 50), "Target", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
