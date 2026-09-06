# Project Artron tests

Test scripts are grouped by the system they verify:

- `ability/` — active, passive, cooldown, class, and granted abilities
- `combat/` — targeting, area actions, reactions, and statuses
- `equipment/` — equipment flow and weapon traits
- `progression/` — XP thresholds and level rewards
- `scenes/` — playable-scene smoke tests

Run a test from the project root with Godot in headless mode:

```powershell
Godot --headless --path . --script res://tests/combat/targeting_area_test.gd
```
