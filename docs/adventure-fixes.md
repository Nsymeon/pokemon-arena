# Adventure interaction and map repair

Default controls are X (run toggle), Space (talk/use an object), E (search the
current grass, water or cave tile). Existing saves keep their progress. Old control
files without a separate encounter action migrate these three bindings; the
settings screen still allows rebinding. Controller A talks, left-stick click searches.
Walk onto an exit to leave: talking no longer invokes nearby warps or the old map's
interaction coordinates.

The Mt. Moon fossil guard now has Miguel's original Grimer, Voltorb and Koffing,
all level 12. Defeat remains recorded. Pallet's repeatable legacy Blue is removed,
and the lab Blue disappears after the initial rival fight. Oak walks to the desk
and returns before granting the Pokédex; moving quest actors no longer leave a
duplicate original actor behind. Pokédex devices have a dedicated prop, and species
entries show full-body sprites.

The right-side Adventure menu includes Pokédex, Pokémon, Bag, Journal, Save,
Options and save management. Map PC interaction opens storage. Counter dialogue,
healing and facing rules are shared by the visible prompts and actual interaction.

Trees use coverage of the source tree cells. Jump ledges have low relief instead of
cliff-sized blocks. Fence rails connect along adjacent fence tiles in both axes.
Trainer approach animation uses the direction of travel. House interiors retain
their original parquet, rugs and stair artwork, with distinct beds, chairs and
tables. These are still procedural models, not a finished BDSP-quality asset set.

EXP uses FireRed species yields and growth groups, exported by
`tools/import-kanto-experience.py` from the local `pret/pokefirered` source checkout.
Reward is floor(base yield × defeated level / 7), with a 1.5 multiplier for trainers.
Capture EXP is the existing custom rule; it uses the same wild reward. Participant
splitting and held Exp. Share behavior are unchanged. Klink and Rookidee, absent
from FireRed, retain an explicit 100-yield/Medium Fast fallback. Existing party,
storage and Day Care Pokémon preserve their level and relative XP-bar progress
when converting to the new curve.

Validation: the full Godot smoke suite; `tools/check-adventure-fixes.gd` exercises
the actual input handler, NPC/PC/counter interactions, Miguel, Oak's scene, Blue,
menu return, XP migration and four-direction approach/model alignment, and captures
rendered views. `tools/check-kanto-3d.gd` builds all 392 maps and checks mouse
projection, graphics fallback and avatar updates. Geometry audits verify source
coverage and building footprints. This is regression coverage, not a claim that
every campaign route has been manually played from start to Champion.
