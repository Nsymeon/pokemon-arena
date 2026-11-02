# National roster, event islands and connected outdoor maps

## Playable additions

- National IDs 1–386, plus the existing Klink and Rookidee guests: 388 species.
  Modern stats/types and previous curated moves remain; new species have recorded
  learnable defaults, FRLG level/TM tables, abilities, gender ratios, EXP/EV data,
  portraits, normal/shiny animations and cries. All 386 have FireRed Dex entries.
- Celio's completed Network Machine activates one Lv.50 roaming legendary:
  Bulbasaur → Entei, Charmander → Suicune, Squirtle → Raikou. Its route movement
  uses the source adjacency table (including 1/16 distant moves); manual habitat
  searches have a 1/4 chance when it shares the route. Identity, HP and status
  persist. Catching or defeating it ends its availability. Tracking is in the
  Sevii postgame journal after the first sighting. In real-time combat it attempts
  to escape after 12 active seconds; sleep, freeze and trapping prevent escape.
- Claim Mystic/Aurora Tickets in the Seagallop menu after National Dex and Celio's
  Network Machine. This offline distribution replaces the historical external
  ticket events. They lead to Navel Rock (Ho-Oh/Lugia Lv.70) and Birth Island
  (Deoxys Lv.30). The triangle uses the original coordinates and step caps,
  resets after excessive steps or leaving, and needs eleven interactions.
- Seven ordinary Sevii islands remain separate from the two event islands.
  Map coverage is 416 maps, 412 connected playable maps, 1,281 valid warp targets.
- Tanoby's existing seven-boulder puzzle now unlocks real Unown encounter slots.
- Original and post-Network League parties, moves and levels are imported from
  FireRed, including all three starter-dependent Champion variants. Gym badge
  rematch locks remain. National level/stone/friendship/trade-item evolution rules
  are imported; trade evolution uses the existing single-player Link Cable.
- Smeargle's Sketch copies a previously used move; Unown Hidden Power uses IV
  parity for its type. New combat passives include Wonder Guard, Speed Boost,
  weather setters, Shadow Tag, Rough Skin, Forecast and Truant's extra recovery.

## Latest requested changes

- Modern 3D outdoor connections preload the adjacent terrain and buildings using
  the original connection offsets. Cached scenes are reused on crossing; camera
  coordinates rebase without jumping to the center of the destination map.
  Doors, stairs and separate interiors continue to load as separate rooms.
  Cache size is bounded, and changed puzzle geometry invalidates cached scenes.
- Character strides follow distance traveled, blend into idle, turn smoothly and
  use articulated knees/ankles with grounded feet. Avatar colors remain intact.
- Adventure's last menu button is now **SAVE & MAIN MENU**, which saves and
  returns to mode selection. Escape still closes the menu.
- Gym Leaders daily challenge: both sides are Lv.50, Hardy nature, first legal
  ability slot, perfect IVs, no held items. Builds are locked and ignore saved
  Free Battle overrides. Moves remain editable; only the player's six species
  change daily. Adventure and Free Battles keep their existing rules.

## Validation and limits

Combat smoke checks, source data/asset audits, story/save regressions, the
Adventure UI regression and the new National regression exercise these changes.
GPU checks build all 416 maps and capture connected-map crossings and character
poses. The National suite covers roaming persistence/capture, ticket gates,
triangle resets/completion, both Navel encounters, evolution and challenge locks.
Test profiles are isolated from player saves.

This remains a FireRed adaptation to real-time arena combat, not a byte-for-byte
port. A complete conditional NPC-script port, breeding, every original trainer
rematch branch and species-form visuals such as all 28 Unown glyphs are not
claimed complete. All National species are selectable in Free Battles; original
FireRed encounter availability is retained instead of placing every species in
Kanto grass. Single-player Link Cable, manual encounters, field tools and offline
event tickets are intentional differences.

Source: pinned `pret/pokefirered` revision
`ce6406d8c2eaf46d543c8a2606de0c3cb1951982`, particularly `src/roamer.c`,
`src/field_specials.c`, `src/data/trainer_parties.h`, `src/data/pokemon/evolution.h`
and the Navel Rock/Birth Island map scripts. New sprite credits retain the same
SpriteCollab revision as the existing roster; see `CREDITS.md` and asset manifests.
