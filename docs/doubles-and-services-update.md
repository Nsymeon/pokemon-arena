# Double battles and Adventure services — 2026-11-17

Reference data: pinned `pret/pokefirered` revision `ce6406d8c2eaf46d543c8a2606de0c3cb1951982`.

## Simultaneous double battles

Original double-trainer encounters now field two Pokemon on each side. The player controls one partner while the other uses AI. Select an already active partner through B / team menu or its party hotkey to transfer control without recalling it or clearing its cooldowns. Selecting a reserve replaces only the controlled lane. Each partner has its own cooldowns, status, ability entry and faint/arrival animation. Opponent substitutions share the existing maximum-three-switch budget.

Area attacks can hit both opponents; team screens cover both allies. Both active partners participate in EXP, while reserves retain the existing Exp. Share / EV rules. A surviving partner takes control when the selected Pokemon faints. A reserve fills a vacated lane. Already released attacks resolve even after total party faint, including a draw. Paired trainer actors share victory state and cannot award a second identical battle.

This is a real-time adaptation: no friendly fire, separate player/AI partner control, existing screen multipliers and arena timing. It is not the cartridge's turn engine.

## Services

- **Move Maniac, Two Island:** choose a partner, forgotten level-up move and replacement slot. Pay one Big Mushroom or two Tiny Mushrooms only after a valid completed choice; cancellation, eggs, incompatible/already known moves and unsafe Surf replacement consume nothing. The custom party moveset menu remains available.
- **Fame Checker:** Cerulean Blue awards the Key Item; existing saves past that battle can use it too. All 16 profiles, 96 facts and completion letters are imported. Supported source NPC/sign programs unlock their facts; portrait-state operations no longer masquerade as fact indices. Some dedicated story handlers still bypass original Fame Checker operations, so importing every fact does not yet prove all 96 are obtainable normally.
- **Teachy TV:** the original Viridian approach tiles trigger the Old Man demonstration after Parcel delivery. He gives the permanent Key Item. Six illustrated, replayable lessons cover battles, status, typing, catching, TMs and tools/controls. Demonstration resources are isolated from real inventory. Lessons and presentation are rewritten for this game's controls, not the cartridge's prerecorded tutorial battles.
- **Safari:** source integer catch factors, four shake comparisons, bait/rock flee-factor rounding/caps and rock-expiry reset. Eating ends without undoing the persistent catch-factor reduction. Captures register immediately, show a new Dex entry and award the requested capture EXP to the lead / Exp. Share holders; no money or capture EVs. Safari interaction is still a menu, without a field-specific ball animation.
- **Game Corner:** 50/500-coin purchases, source Pokemon/TM/held-item/flute prizes, exact prices and atomic capacity checks. Prize-room patrons retain their dialogue. Usable slot-machine tiles open three 21-symbol source reels with 1/2/3-coin lines and source payouts. Desktop stop timing is an adaptation; the cartridge's machine-bias/reel-slip engine is not ported. Yellow Flute cures confusion without consumption. Miracle Seed, Charcoal and Mystic Water boost the matching move type by 10%.
- **Trainer Tower:** separate from the existing custom level-50 BP Battle Tower. Four formats (Single, Double, Knockout, Mixed), eight floors, floor-specific team selection, source species/moves/items/IVs/EVs/natures and fixed shiny personalities. Opponent levels match the highest non-egg party member. Double floors use simultaneous battles; Knockout floors chain three trainers. Source actor graphics and format visibility are restored. Stairs require floor completion. Timed records and one-time prizes are saved independently for each format; no EXP, EVs or money are awarded. Defeat returns healed to the lobby without a blackout fee. An interrupted battle invalidates the timed run on load. Source equipment is assigned, but not every imported held-item effect is implemented by the arena yet; e-Reader sets and original format-dependent floor geometry are not ported.

## Verification

The broad regression run exposed excessive startup memory: every normal and shiny animation sheet was decoded up front. Startup now reads metadata; a least-recently-used texture cache loads on demand and retains at most 24 variants / 128 MiB of animation textures (an individual oversized species may exceed the byte target). Normal/shiny/forms stay separate and evicted textures reload. This does not include other scene textures or external references to a displayed/faint frame. `check-art-cache.gd` decodes and validates all **776 normal/shiny variants** while checking eviction and reload behavior.

- `tools/check-double-battles.gd`: four active fighters, controls, switching, screens, bidirectional area hits, autonomous casts, reserves, shared EXP, duplicate-victory protection and delayed draw.
- `tools/check-service-fidelity.gd`: transactional relearner, source Fame Checker operation, tutorial isolation and all six pages, coin/prize boundaries, reel payouts, Safari arithmetic/capture registration/EXP and save validation.
- `tools/check-trainer-tower.gd`: **52 source battles** across all four formats, actor/stair reachability, lobby shop, return-only elevator, team builds, level scaling, progress gates, prizes, records, actual double victory/defeat return, interrupted-run recovery and malformed-save rejection.
- GPU captures: Fame Checker, Move Reminder, Teachy TV, slots and simultaneous battle. Manual computer-use checked active-partner control and reserve substitution. The UI tool sent the letter B with a Tab physical scan code; physical B is verified separately through an actual Godot input event.

No real player save is used in fixtures. This update does not complete the outstanding full-story, all-puzzle-state, presentation/performance review or uninterrupted fresh-save playthrough; those remain in the work plan.

Local regression checks also passed: combat smoke, story progression, National Dex/postgame, rooms/story/breeding, ordinary NPC programs, economy/storage, Day Care, Vs. Seeker, daily coverage, save deletion, map trainers and Adventure gyms. Tower floors were additionally rendered on the GPU.
