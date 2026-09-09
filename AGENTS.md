# Project ARTON

Godot 4 project written in GDScript. Preserve unrelated uncommitted changes.

## Working rules

- Make the smallest change that fixes the requested behavior.
- Keep the current component architecture; do not move or rewrite unrelated systems.
- Use `StatSystem` as the shared source for derived HP, Mana, AP, defenses, and Speed.
- Apply Ancestry and Class rules once. Keep ancestry Mana in `ancestry_max_mana_bonus` and class Mana in `base_max_mana`.
- Preserve character values across Character Creation, `RunState`, Level Up, and Combat.
- Add or update focused tests for behavior changes, then run the relevant group before the full regression suite.

## Tests

Godot executable: `tools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe`

Run a focused group:

```powershell
powershell -ExecutionPolicy Bypass -File tests/run_regression.ps1 -Target tests/creation
```

Run all regression tests:

```powershell
powershell -ExecutionPolicy Bypass -File tests/run_regression.ps1
```

The runner prints a compact summary and saves failing logs under `work/test-results/`.

## Response format

Keep the final response concise. Report only:

- outcome and user-visible behavior;
- files changed;
- tests run and pass/fail totals;
- remaining material risk or blocker, if any.

