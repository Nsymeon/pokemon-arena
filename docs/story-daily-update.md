# Story, defeat recovery and daily League

Implemented against the local `pret/pokefirered` checkout at
`ce6406d8c2eaf46d543c8a2606de0c3cb1951982`.
This is a source-informed adaptation to the existing arena game, not a claim
that every original FireRed script has been ported or manually played through.

## Adventure

- All eight Gym Leaders refuse a battle once their badge is owned. The central
  battle entry also enforces this; the postgame menu cannot bypass it.
- Restart is disabled in Adventure combat, including the pause screen.
  Victory returns via Enter/interact; an exhausted party automatically blacks out.
- Blackout shows a black screen for 4.6 seconds, restores HP/status, resets the
  Elite Four run and returns to the exact last healing location. The save records
  the return and penalty before dismissing the screen, preventing duplicate charges.
  Existing saves without a precise checkpoint fall back to their last healing town.
- Money lost is `min(wallet, highest party level * 4 * badge multiplier)`.
  Multipliers for 0–8 badges: `2, 4, 6, 9, 12, 16, 20, 25, 30`, from
  `src/overworld.c::ComputeWhiteOutMoneyLoss`. Empty wallets stay at zero.
- Parcel delivery, Tea for Saffron, seven badges for Viridian Gym, and the original
  badge checkpoints gate progress. The previously requested mandatory early Route22
  rival remains an intentional difference from FireRed.
- Nugget Bridge uses its five actual trainers. Blue triggers in Cerulean, S.S. Anne,
  Pokemon Tower 2F, Silph 7F and late Route22; the late rival no longer waits inside
  Victory Road. `assets/kanto/story-parties.json` contains 21 starter-dependent
  rival parties plus Brock's party, imported from the original trainer tables.
- Fuji requires the three Tower guards, returns to his house and gives the Flute
  there. Warden, Fan Club chairman, Safari attendant and Silph president use their
  source NPC positions. The president gives one functional Master Ball.
- Oak aides count historically **caught**, rather than just seen/currently owned,
  Kanto species: 10 Flash/Lantern, 20 Everstone, 30 Itemfinder, 40 Amulet Coin,
  50 Exp. Share. Everstone blocks level evolutions; Amulet Coin doubles the existing
  trainer prize when its holder participated. Itemfinder locates source hidden items.

## Sevii and ending

- After Blaine, Bill brings the player to Celio and grants the Tri-Pass/Meteorite.
  Islands 1–3 include the biker chain, Lostelle/Hypno rescue, reunion and return trip.
- National Dex requires Champion, visited One Island, and 60 caught Kanto species.
  Oak performs the upgrade; Celio then starts the Network Machine quest.
- Both Mt. Ember guards yield the first password and open the Ruby path. Delivering
  Ruby grants the Rainbow Pass to Islands 4–7. Lorelei's Icefall rescue and Cut open
  Dotted Hole. The stolen Sapphire supplies the second warehouse password; both
  Rocket Admins must fall before Gideon. Returning Sapphire completes the network.
- Cerulean Cave/Mewtwo require Champion + National Dex + completed network. The
  cave guard leaves once eligible. Articuno requires the lower Seafoam current puzzle
  and Surf; Zapdos requires Surf; Moltres requires Tri-Pass and Strength access.
- Beating Champion Blue automatically starts Oak's ceremony, then shows the actual
  winning party (including shinies) in the Hall of Fame and returns home.
- Evolution uses a darkening sprite, alternating silhouettes, colored reveal and
  fireworks. Multiple pending evolutions and shiny variants are supported.

## Daily Gym Leaders mode

Only the player's six unique Pokemon change each UTC date. All 13 opponents keep
fixed six-member expanded Kanto teams. All fighters use actual level-100 stats;
moves/abilities/items can still be configured using the existing editor. Species
replacement is locked. The six are identical for the same date/build across PCs.
Daily progress uses `daily-league-v1.json`; the previous League save is preserved.
Adventure and Free Battles retain their separate progression/selection behavior.

## Validation and remaining fidelity work

`tools/check-story-progression.gd` exercises positive/negative story gates, badge
locks, exact heal spots and blackout, source rival parties, aides, save round trips,
Sevii chain, evolution queue, Hall of Fame and daily rollover/actual combat levels.
Its headless run is required by GitHub Actions. GPU runs additionally capture the
blackout, evolution stages, Hall of Fame and daily hub. Combat smoke tests and the
existing Adventure regression suite also pass. The map audit verifies 392 maps,
1,237 warp targets and 388 connected playable maps (four original unused houses).

The roster remains 158 species. National mode exposes the currently supported
roster; this update does not add all 386 National Dex species or the roaming Johto
legendary trio. Tanoby's existing boulder puzzle remains, but Unown is not in the
roster. Navel Rock/Birth Island event-ticket encounters are not part of the seven
regular islands and are not implemented here. Full conditional NPC-dialogue parity,
all postgame trainer rematch variants, and an uninterrupted human playthrough of
every story branch are still outstanding. Existing custom systems (manual wild
encounters, HM tools, real-time combat and optional Battle Tower) are preserved.
