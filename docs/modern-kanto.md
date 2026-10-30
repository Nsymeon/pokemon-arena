# Modern Kanto overworld

Adventure now defaults to a 3D presentation of the existing FireRed layouts.
Settings → Graphics switches between Modern 3D and Classic 2D. This is a global
graphics preference (`user://world-graphics.cfg`), independent of save slots.
Progress does not need migration or a restart.

The visual direction uses the elevated camera, small characters, rounded vegetation
and colorful miniature architecture of Brilliant Diamond/Shining Pearl as a reference:
https://www.nintendo.com/sg/switch/bdsp/index.html
All new meshes are procedural project assets; no BDSP models are bundled.
This is an initial modular 3D art pass, not a reproduction of the commercial game's
asset quality. Unique landmarks and bespoke interiors still need individual art.
Some original puzzle decals and special Pokémon portraits remain 2D within the world.

## Architecture

- `kanto_world.gd` remains authoritative for all 392 maps, collision, NPC positions,
  warps, manual encounters, events, saves and four-direction movement.
- `kanto_world_3d.gd` renders those coordinates in an isolated SubViewport. One world
  unit equals one 48-pixel gameplay tile. Right-click raycasts to the ground plane;
  it never substitutes 3D physics for gameplay collision. Cutscene markers use the
  same projection as actors.
- `kanto_model_kit.gd` shares meshes/materials and batches static scenery into
  MultiMeshes. Actors are reused and animated; collected items, cleared trees,
  smashed rocks and pushed boulders follow the existing event state.
- Rendering sleeps outside Adventure and during battles. Only the current map is
  retained; transitions release old geometry. City roofs derive from actual indoor
  entrances, partition attached buildings, and avoid hiding walkable courtyard tiles.
- `assets/kanto/world-3d.json` and `assets/kanto/modern/*.png` cover every source map.
  `tools/build-kanto-3d.py` regenerates these from the local pinned FireRed source
  checkout using Pillow. Its visual heuristics do not modify original map files.

## Verification

`python tools/audit-kanto-3d.py` checks map coverage, ground texture dimensions,
building bounds and walkable tiles under roof interiors. CI runs it before release.

`godot --path . --script tools/check-kanto-3d.gd -- --qa-render` uses unsaved fixtures,
captures representative towns/forest/cave/lab/Center/Gym/ocean, constructs all 392
maps, verifies projection roundtrips, progress preservation across graphics modes,
and disabling the 3D viewport during battle. Captures are local and gitignored.

The complete gameplay smoke suite also passes. These are automated rendering and
gameplay checks; they do not constitute a manual playthrough of every quest.
