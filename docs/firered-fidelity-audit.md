# FireRed fidelity audit — updated 2026-11-08

**Verdict: the world layout and the main progression are based on FireRed, but this is not yet a complete FireRed remake with only graphics/combat changed.** Some differences are deliberate features requested for this project; others remain unfinished fidelity work. A percentage would be misleading because imported coordinates and dialogue text do not prove working scripts.

Reference: the locally pinned [pret/pokefirered source](https://github.com/pret/pokefirered/tree/ce6406d8c2eaf46d543c8a2606de0c3cb1951982), recorded in `assets/kanto/source.json`. This comparison targets that original English FireRed source, not a later rerelease. Earlier update documents are historical and can contain superseded limitations; this audit describes the current implementation.

## What matches / what is implemented

| Area | Evidence and practical limit |
| --- | --- |
| Map layout | All **416 imported maps** match source dimensions, cell data, warps, connections, object records and sign records exactly (ignoring the added battle metadata). The source contains 425 records; the nine exclusions are five multiplayer rooms and four unused prototype Sevii maps. |
| Reachability | **412 playable maps**, four original unused houses, **1,281 valid warp targets**. Graph reachability does not prove every conditional puzzle path is traversable in a normal playthrough. |
| World objects | Source records preserve **1,636 objects**, **702 signs/background events**, and **443 actors with imported trainer parties**. These are data counts, not a claim of 1,636 fully ported NPC scripts. |
| Wild encounter tables | All **124 encounter-map tables** match FireRed's imported land/water/rod species, levels, slot indices and relative slot weights. Searches are deliberately manual; cartridge per-step encounter frequency is not reproduced. |
| Main story | Bedroom/Mom, Oak's rescue, starter balls, first Blue battle, parcel/Pokedex, eight badges, the Rocket/Fuji/Silph chains, Elite Four, Champion and Oak/Hall of Fame have runtime handlers and progression tests. Cutscenes use adapted movement, timing and some custom dialogue. |
| Postgame | National Dex gates, Oak's five aides, the seven regular Sevii islands, Ruby/Sapphire network chain, gated Kanto legendaries, roaming beast, Unown/Tanoby and the two event islands are implemented. Automated tests cover representative prerequisites, rewards and save persistence. |
| Puzzles | Source warp panels, Gym locks/quizzes, Hideout spinners, Mansion switches, Strength/current puzzles, Icefall, Dotted Hole, Tanoby and Deoxys have handlers. This is not a manual validation of every possible puzzle state. |
| Pokemon systems | Source level/TM tables, EXP growth/yields, EV yields, National evolution restrictions, breeding data and normal/shiny/form assets exist. Real-time stats, attacks, recovery and several service rules are adaptations. |
| Saves | Three independent Adventure slots, autosave/recovery, reset and now explicit permanent deletion. Daily challenge progress is separate. |
| Adventure Gym builds | First fidelity step completed: all eight use exact source species, levels, ordered moves and held-item absence. Their original finite trainer-item inventories now work with the shared arena healing rules. See [Gym validation and limits](adventure-gym-fidelity-update.md). |
| Story/map trainer builds | Second fidelity step: 639 source build definitions and 727 direct script identities, with all 443 imported actors checked through battle creation. Rivals select the correct starter variant; first/rematch League teams use source moves and held items. See [trainer validation and limits](adventure-trainer-fidelity-update.md). |

## Confirmed fidelity gaps

1. **Gym builds corrected; battle rules still adapted.** The previous moveset mismatches and Giovanni's Rhydon/Rhyhorn mismatch are fixed by a dedicated Adventure import. Source ordering and missing fourth slots are preserved. This does not make arena stat scaling, nature/ability selection, cooldowns, move effects or percentage healing identical to cartridge combat. The separate Daily mode retains its expanded teams.
2. **Trainer build data corrected; some battle systems still adapted.** Map/story trainers now use source species, levels, custom moves or FireRed-generated default moves, held items and finite bag inventories. They retain the project's real-time stat/ability/IV/nature rules and battle AI; this is not a port of cartridge turn-based AI. Source rematch definitions are available, but the complete Vs. Seeker activation/progression system remains a later step. Source double-battle parties still fight sequentially until the separate two-versus-two system is implemented. Existing custom Champion Challenges remain separate from the source League rematches.
3. **The original script engine is only partially represented.** `kanto_scenes.gd::resolve_dialogue` resolves supported flags, gender and facing, but does not execute arbitrary source variables, comparisons, choices or special commands. Many quests/services have dedicated handlers. The audit finds 1,598 distinct object/sign script references, including 271 without a directly imported first text; that is **not** a count of broken NPCs, since battles, gifts and special services often have separate handlers. Source text existing does not prove all of its branches work.
4. **Economy differs.** A new Adventure starts with **$300 and 10 balls**, versus the source's $3,000 starting money. Normal trainer wins add a flat **$150** ($300 for a participating Amulet Coin holder), rather than the source trainer-class/level prize formula. Shop prices and percentage-based healing are customized. These need a deliberate balance/fidelity pass rather than being described as exact FireRed rules.
5. **Storage and side activities are adapted.** Storage has a global 100-Pokemon limit; FireRed has 14 boxes of 30. Game Corner uses simplified menus/random rewards, Safari uses its own interaction/ball/bait/rock implementation, and Day Care preserves chosen moves/pending learning instead of cartridge move replacement. Original Fame Checker, Teachy TV, multiplayer services and the full Trainer Tower formats are not faithfully reproduced. The added Champion Challenges/Battle Tower are our own systems.
6. **Presentation is an adaptation.** The 3D scenes use modular procedural models and the original map footprint, with custom UI/music and rewritten cutscene timings. They are neither original FireRed presentation nor the commercial BDSP asset set. Trainer facing/approach works, but original ambient NPC patrol choreography is not fully ported.

## Requested differences to preserve

- Real-time arena battles, aiming, held battle sprint, casts/cooldowns/PP adaptations, homing/clashing moves, status durations, switching, field weather and customized VFX.
- Manual habitat searches on E; conversation on Space; overworld running toggle on X. Lure and five-Pokemon hordes.
- Key-item field tools with badge requirements; Surf/Fly remain learned moves.
- Avatar/name customization, three saves and deletion, modern 3D presentation and connected outdoor transitions.
- The mandatory early Route 22 rival (requested earlier, although optional in FireRed).
- Capture EXP/entry presentation, the project's EXP-share/EV participation rules, single-player Link Cable, offline event-ticket distribution, modern typings and the existing extra species.
- Separate Free Battles and the daily Lv.50 Gym/League challenge with a changing player team and locked builds.

## Verification and next work

Ran source-data comparison, map/geometry/trainer audits, the combat/save smoke suite, story/Daily progression tests, National/postgame tests, opening/NPC-gift/breeding tests, and save-deletion tests. The deletion selector and confirmation were rendered and visually inspected using isolated test files. No real Adventure save was deleted.

The story tests simulate victories and prerequisite states. **An uninterrupted manual journey from a fresh save through all optional branches and the Sevii ending has not been completed.** Passing these checks is not proof of full cartridge parity or campaign balance.

The user approved working through the detailed plan one step at a time, with confirmation before each next step. **Steps 1 (eight Gym builds) and 2 (remaining map/story trainer builds and item inventories) are complete.** Next proposed step: functional NPC scripts, conditional dialogue and one-time gifts/services. Economy, side activities, quest gates and the full fresh-save playthrough remain later steps; their rules were not silently changed in these trainer updates.

Reproduce the source comparison with `tools/audit-firered-fidelity.py`, then run Godot with `--headless --path . --script tools/audit-firered-runtime.gd -- --qa-fidelity`. Diagnostic JSON is written to the ignored `captures/` folder. The runtime probe now asserts the eight corrected Gym parties and ordered moves; it makes no full-game parity claim. `tools/import-adventure-gyms.py --check` separately verifies their committed data and item inventories against the pinned source.
