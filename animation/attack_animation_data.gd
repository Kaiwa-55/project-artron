class_name AttackAnimationData
extends Resource

enum Type { LUNGE_RETURN, SPRITE_PROJECTILE }
@export var animation_type: Type = Type.LUNGE_RETURN
@export var sprite_sheet: Texture2D
@export_range(1, 64) var columns: int = 8
@export_range(1, 64) var rows: int = 10
@export_range(0, 4095) var first_frame: int = 0
@export_range(0, 4095) var last_frame: int = 6
@export_range(1.0, 60.0) var frames_per_second: float = 14.0
@export var effect_scale: Vector2 = Vector2(1.5, 1.5)
@export var orient_to_target: bool = true
@export var rotation_offset_degrees: float = 0.0

@export_range(0.01, 2.0) var approach_seconds: float = 0.15
@export_range(0.0, 2.0) var impact_seconds: float = 0.06
@export_range(0.01, 2.0) var return_seconds: float = 0.18
@export_range(0.0, 10.0) var contact_gap_feet: float = 0.0
@export_range(0.0, 5.0) var anticipation_feet: float = 0.5
@export_range(0.01, 1.0) var anticipation_seconds: float = 0.06
