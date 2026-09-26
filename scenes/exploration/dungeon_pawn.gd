extends CharacterBody2D

const Layout = preload("res://scenes/exploration/dungeon_layout.gd")
var input_enabled := true
var facing := Vector2.DOWN
var token: Texture2D
var speed := 190.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = Layout.RADIUS
	collider.shape = shape
	add_child(collider)
	z_index = 5
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO
	if input_enabled:
		direction.x = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		direction.y = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	if not direction.is_zero_approx():
		facing = direction.normalized()
	velocity = direction.normalized() * speed
	move_and_slide()
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2(0,4), 17, Color(0,0,0,0.4))
	draw_circle(Vector2.ZERO, 15, Color("e7c583"))
	draw_circle(Vector2.ZERO, 12.5, Color("24414c"))
	if token != null:
		draw_texture_rect(token, Rect2(-12,-12,24,24), false)
	else:
		draw_circle(Vector2.ZERO, 8, Color("8ce0cf"))
	draw_line(facing * 15, facing * 23, Color("fff2d1"), 3, true)
