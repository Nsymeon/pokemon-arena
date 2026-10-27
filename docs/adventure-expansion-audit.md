# Adventure expansion verification

Implemented areas: one-level Back navigation; Link Cable; held combat/training items; configurable AI difficulty; tracked quest routes; Champion rematches, Elite Four gauntlet, Battle Tower/BP rewards.

## Checks performed

- Godot 4.3 headless smoke suite including isolated save/load tests and the existing story progression suite through eight badges and Hall of Fame.
- `--smoke-test --campaign-audit` emits captures/campaign-audit.json. The initial full audit passed 324 filtered campaign, save, item, evolution and navigation assertions; subsequent regression checks also cover fresh replacements clearing Choice lock.
- Link Cable preserves individual identity; incompatible uses keep the item. All four evolutions are exercised.
- Back returns item targets to Bag, moves to party selection, replacement to the exact moveset and TM targets to the TM list. The rendered Back navigation was also checked.
- Choice lock, correct physical multiplier, clearing lock on replacement, once-only berry consumption/cure, Leftovers timing and targeted/doubled EV yields.
- Every rematch resolves to an actual team, including Surge and the correct Blue starter variant. Tower combat levels are 50 while stored levels remain unchanged. Tower gives no EXP/EV, prevents Bag use, grants BP once and recovers interrupted saves. BP shop accounting and negative BP rejection are tested. Elite rematch stages and 28 total completion BP are verified.
- All 392 map dimensions, 1,237 warp destinations and 388 connected maps with ferries remain valid. Four unused houses are excluded; routes are map-graph suggestions, not collision-aware navigation through every puzzle state.
- `--capture-expansion` renders Champion hub, replacement/Back, journal, difficulty, held-item editor and hit particles without changing player saves. It also verifies no missing particle text-key render errors.

## Playthrough scope

The campaign progression audit is automated and simulates victories when testing quest transitions. It checks story prerequisites, rewards and save recovery through Champion, but is not an unassisted manual playthrough or a proof of balance at every level. A normal-speed manual campaign, including economy/grinding and every optional NPC, remains uncompleted. No claim of having manually played the whole game is made.

## Adaptations and sources

Battle Tower and rematches use the arena's existing Pokemon/trainer data and an explicitly documented custom format. Difficulty adjusts decisions and reactions rather than stats. Five real-time combat seconds substitute for a turn for Leftovers. Power-item yields use the modern +8 rule, movement speed substitutes for turn-order Speed, and healthy teammates follow the established shared-EXP rule. Consumable held berries are permanently consumed in Adventure/Tower.

References: https://bulbapedia.bulbagarden.net/wiki/Power_item ; https://bulbapedia.bulbagarden.net/wiki/Choice_item ; https://bulbapedia.bulbagarden.net/wiki/Sitrus_Berry ; https://bulbapedia.bulbagarden.net/wiki/Leftovers ; https://bulbapedia.bulbagarden.net/wiki/Lum_Berry .
