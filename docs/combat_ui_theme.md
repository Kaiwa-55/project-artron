# Compact Combat UI

The Combat HUD uses native Godot controls (no generated bitmap UI).

- `scenes/ui/artron_ui_theme.gd`: shared Inventory/Character/Combat palette,
  button states, semantic resource colors and surface factory.
- `scenes/ui/themes/combat_theme.tres`: saved **Artron / Compact Combat** Theme
  resource, assigned to the Combat root; default type sizes and spacing.
- `scenes/ui/combat_ui_theme.gd`: Combat-specific typography roles and widget
  styling. `BODY`, `HEADING`, `DOCK_HEIGHT`, `DOCK_WIDTH`, `HEADER_HEIGHT` are the
  compact presentation tokens. Explicit roles override the Theme defaults.
- `scenes/prototype/prototype_ui_controller.gd`: responsive positioning and
  interaction; gameplay/stat calculations remain in the existing systems.

Default HUD: 94 logical pixels tall, 440 wide; header 30 tall and sized to its
contents. Project stretch scales logical units to the physical window.
Secondary character information lives in the portrait tooltip and Character
window. Action choices open above the dock, close on selection, and retain the
drawer during submenu navigation. Combat history remains opt-in.

Unused scene nodes removed: old `Turn_Order`, `GridContainer2` placeholder
slots, `BG` backdrop, and decorative major-action TextureRects. Shared assets
were retained because other controls still use them. These deletions are
recoverable from Git; unrelated project components were not removed.

Verification: focused scene regressions plus rendered HUD/action/history/
reaction screenshots. To regenerate screenshots, run the Godot executable
with `--path . --script tests/scenes/combat_presentation_test.gd -- --capture-combat`
(not headless). Images are written under `work/combat-polished-*.png`.
UI test fixtures suppress random opening enemy actions without changing game AI.
