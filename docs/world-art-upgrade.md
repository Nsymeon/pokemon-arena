# Kanto world art update

The world keeps FireRed's layouts and uses an original modular art set inspired
by BDSP. This is not a copy of BDSP's models or a claim of equivalent production
quality. The changes apply through the shared renderer to all 392 maps.

## Art and integration

- Houses have timber siding, window frames, curtains, flower boxes, chimneys,
  gutters and curved roof tiles. Public buildings keep their distinct colors.
- Trees use three layered crowns with individual leaf scales, flared roots,
  visible trunks and soft contact shadows. Cut saplings remain smaller.
- Tall grass uses curved, folded leaves with central veins and gentle wind.
- Pond surfaces have slow ripples and subdued highlights. Continuous banks,
  shoreline foam and flowing waterfall materials replace the old hard edging.
- Cliffs have continuous sculpted faces and strata. Cave walls have rock caps;
  boulders share a rough mineral material. Jump ledges have continuous turf tops.
- Picket fences join along their actual horizontal/vertical source connections.
- Stair flights have separate treads, darker nosings and edge handrails. Home
  exits use a cutaway threshold; glass service doors slide when approached.
- Homes use warmer parquet, striped wallpaper, wooden trim, checked tablecloths,
  quilted beds and furniture contact shadows. Front walls are lowered so they
  do not hide exits. Rear architectural tiles no longer become service counters.
- Four-sample antialiasing and adjusted sun/ambient balance improve silhouettes.

`kanto_art_assets.gd` creates and caches the custom meshes and materials.
`kanto_model_kit.gd` instances them through MultiMesh batches. No gameplay
collision, trainer trigger, save schema or warp coordinate is changed. Source
puzzle decals remain visible; old stair/door floor drawings are replaced by the
new geometry. All textures are loaded directly in portable builds.

## Verification tools

- `tools/check-art-mesh.gd`: finite mesh geometry, mesh reuse, outward crown and
  cliff normals, and upward roof normals. This caught reversed surface winding
  during development and is included in Windows build CI.
- `tools/preview-art.gd`: seven unsaved art fixtures: Pallet, Viridian, Route 22,
  Viridian Forest, Mt. Moon and both floors of the player's house.
- `tools/check-kanto-3d.gd`: GPU screenshots, construction of all 392 scenes,
  click-to-world projection, graphics fallback, avatar changes, battle suspension.
- `tools/audit-kanto-3d.py`: texture coverage and 129 building footprints.
- `tools/audit-world-followup.py`: 210 Kanto trainer records, city entrances,
  museum exhibits and source stair/ladder coverage.
- `tools/check-adventure-fixes.gd`: input, PC/counter access, Oak/Blue progression,
  forest/gym trainer presence and a real forest trainer battle trigger.

The fixtures disable saving. These are scripted visual and gameplay tests,
not a manual playthrough of every quest. Local captures are in `captures/` and
are excluded from releases. Map-build timings are not frame-rate benchmarks.

The 2026-11-01 run passed the mesh test, both Python audits, the 392-map GPU
check, the adventure regression and the complete combat/adventure smoke test.
The all-map run reported a maximum scene construction time of 181 ms on the
local Intel Iris Xe system. First-load shader compilation can take longer.

## Visual references

- [BDSP exterior reference](https://us.millenium.gg/guide/25645.html)
- [BDSP house and early-game references](https://www.pokeballinsider.com/pokemon-brilliant-diamond-shining-pearl-walkthrough/oreburgh-city-gym/)
- The user's BDSP screenshot: layered trees, bright broad grass, calm blue water,
  terracotta cliff faces and pale steps with warm rails.
