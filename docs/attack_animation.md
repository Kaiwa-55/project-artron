# Attack animation templates

## Sprite projectile / Web Shot

`res://animation/web_shot.tres` uses Free Smoke Fx Pixel 04, an 8-column,
10-row sheet with 64x64 cells. Frames 0 through 6 (inclusive, first row) play
once at 14 FPS while the effect travels from caster to target. The caster token
does not move. Pixel filtering is nearest; the temporary sprite is removed at
completion or reset. Hit and miss use the same visual; combat rules are unchanged.

Assign this template to any AttackData's Animation Template to reuse it. Duplicate
it to customize independently. Animation Type = Sprite Projectile exposes texture,
columns/rows, first/last frame, FPS, scale, and direction/rotation settings.
The default Lunge Return type still uses the existing sword movement settings.

Sword attacks reference `res://animation/lunge_return.tres` through the
`animation_template` property on AttackData. Assign the same resource to another
attack to reuse the animation. Leave it empty to disable attack animation.

Select the template in Godot's FileSystem to edit anticipation, approach, impact
pause, return duration, and contact gap (feet). Duplicate the resource first to
give an attack independent timing; editing the shared resource affects all users.

The token draws with a visual offset: its Node2D position and CombatantState
position stay unchanged. The animation does not execute Move, spend Speed/AP,
or generate movement reactions. A short anticipation remains visible when the
combatants are already touching. Tokens return to zero offset on completion/reset.

The existing presentation controller queues final ATTACK_HIT/ATTACK_MISS events
in emission order. Declaration/roll events do not play animations. Attacks which
are cancelled without a final hit/miss event do not lunge. Input and prototype AI
wait for queued animations using the same presentation lock as movement.

This is a code-driven Tween template, not an AnimationPlayer timeline. Current
HP and combat log updates remain synchronous with combat resolution; they are
not delayed to the visual impact frame. Visual offsets apply to the current
drawn token; future Sprite2D artwork should use an equivalent visual-only child.

Regression: `tests/scenes/attack_animation_test.gd` checks template loading,
final-result dispatch, movement without changing combat position/AP/Speed,
return, no replay, and reset during playback.
