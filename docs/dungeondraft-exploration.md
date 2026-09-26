# Dungeondraft exploration prototype

Open the project in Godot 4.7.2, start the game, create/choose your party, then use
**EXPLORE BUILDING · 2 FLOORS** on the Run Map. For standalone testing, open
`scenes/exploration/DungeonExploration.tscn` and run the current scene (F6).

- WASD / arrows: walk. Enter the building through its south door.
- Walk to the west staircase and press E (or the stairs button) to change floor.
- Tab: full-map overview. Mouse wheel: follow-camera zoom.
- R: roof inspection; pauses walking. The roof otherwise fades when indoors.
- F2: show collision rectangles for the current floor.
- Home: return to the ground entrance. Escape / Return: return to Run Map.

## Integration and scope

Walls now cast opaque sight shadows from the leader's position. Door openings
transmit sight, and floor changes replace the blockers immediately. Overview
retains the same occlusion; roof inspection only shows the roof above it.
The staircase guide rails and upper fall barrier block movement but not sight.
There is no explored-area memory or sight-radius cutoff. Shadow polygons are
cached while stationary. The visibility query and mask share the active floor.
This is exploration visibility, not the turn-based combat targeting system.

## Hall-guard combat

Two red guard markers wait in the central ground-floor hall. Enter their area and
press F (or select **Engage hostiles**) to start combat. The existing Combat Arena
uses Ground.png as its backdrop, imports the ground floor's walls as rectangular
movement and line-of-sight blockers, and spawns the party at its exploration
location. Victory removes the guards and returns the party to that location;
defeat also returns to exploration with the synced party state. This encounter is
ground-floor only. Upper-floor combat, stair movement during turns, rewards, and
combat fog-of-war remain outside this prototype.

The explorer uses the existing leader's token via TokenImageBuilder. It does not
alter character stats, inventory, combat state, gold, or run progression. Location
is retained on the active RunState as metadata for this session; a new run starts
at the entrance. The selected run route is restored on return.

This is a playable exploration mode, not a replacement for turn-based combat.
Enemies, attacks across floors, line of sight, party formations, AP movement,
interactive doors and persistent disk saves are not implemented in this scene.

## Art assessment

Ground, Level1 and roof are aligned 5120 × 5120 images. Level1 and roof have real
alpha transparency. Source PNGs are copied unchanged to
`assets/maps/dungeondraft/`. All are displayed in the same 1600 × 1600 world.
No TileMapLayer is required for these full-map textures.

Walls are measured manually from the supplied reference and approximated using
rectangles in `scenes/exploration/dungeon_layout.gd`. Ground and Level1 have
different door positions, so each uses separate collision geometry (physics
layers 2 and 3). The pawn switches its collision mask when changing floors.
The upper south opening is blocked because no balcony exists in the artwork.
The staircase has side rails and an explicit key action to avoid auto-bouncing.
Destination positions are checked against the floor bounds and wall geometry.

Painted doors are treated as open passageways; their baked pixels remain visible.
Opening/closing visuals require separate door artwork. Shadows and lighting are
also baked. The roof is one image, so visibility currently applies to the whole
building, not individual rooms. Original textures alone require approximately
300 MiB of uncompressed RGBA memory (before optional mipmaps/driver overhead);
lower-resolution exports or chunks should be evaluated for mobile.

## Validation

Run focused tests first:
`powershell -ExecutionPolicy Bypass -File tests/run_regression.ps1 -Target tests/exploration`

The layer test checks physical wall/door movement on both floors, stair guards,
unsafe destinations and roof behavior. The roundtrip test exercises the real Run
Map button and scene transitions, route/resource preservation, location restore,
and a fresh run. Then run the full regression runner without -Target.
