class_name AttackAnimationData
extends Resource

enum Type { LUNGE_RETURN, SPRITE_PROJECTILE, ATTACHED_DIRECTIONAL, CONE_BURST, CIRCLE_GROUND }
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
# Used by ATTACHED_DIRECTIONAL and CONE_BURST. The effect stays at this
# distance from its user, measured forward along the selected direction.
@export_range(0.0, 100.0, 0.1) var attached_offset_feet: float = 0.0

# Used by CONE_BURST. Its length and angle come from the Skill or Ability so
# one template can be reused by differently sized cones.
@export var cone_fill_color: Color = Color(1.0, 0.35, 0.08, 0.42)
@export var cone_edge_color: Color = Color(1.0, 0.78, 0.25, 0.95)
@export_range(4, 64, 1) var cone_arc_segments: int = 24
@export_range(0.05, 2.0, 0.01) var cone_duration_seconds: float = 0.45
# When a Cone template has a Sprite Sheet, fit each frame over the real
# targeting area. Disable this when the source art already has the intended size.
@export var cone_fit_sprite_to_area: bool = true
# Play every configured Sprite Sheet frame once. When disabled, the frames loop
# for cone_duration_seconds instead.
@export var cone_play_once: bool = true

# Used by CIRCLE_GROUND. The radius comes from the Skill or Ability so the
# same template can be reused by differently sized ground effects.
@export var circle_fill_color: Color = Color(0.25, 0.65, 1.0, 0.3)
@export var circle_edge_color: Color = Color(0.6, 0.9, 1.0, 0.95)
@export_range(8, 96, 1) var circle_segments: int = 32
@export_range(0.05, 5.0, 0.01) var circle_duration_seconds: float = 0.6
@export var circle_fit_sprite_to_area: bool = true
@export var circle_play_once: bool = true

@export_range(0.01, 2.0) var approach_seconds: float = 0.15
@export_range(0.0, 2.0) var impact_seconds: float = 0.06
@export_range(0.01, 2.0) var return_seconds: float = 0.18
@export_range(0.0, 10.0) var contact_gap_feet: float = 0.0
@export_range(0.0, 5.0) var anticipation_feet: float = 0.5
@export_range(0.01, 1.0) var anticipation_seconds: float = 0.06
