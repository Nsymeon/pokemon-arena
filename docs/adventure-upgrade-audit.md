# Adventure upgrade audit

## Automated coverage

- `node tools/validate-data.mjs`: 158 species, current stats/types, legal moves and sprite assets.
- `node tools/validate-trainers.mjs`: 15 historical trainer presets and move lists.
- `python tools/audit-adventure.py`: 392 map dimensions, 1,237 destination warp indexes, all map connection targets, and reachability from Pallet including the existing ferry ports. 388 maps connect; Route 6/19/23 and Seven Island unused houses have no original entrance. Link/Union rooms and dynamic elevator return destinations are explicitly classified. All 158 cry asset hashes are verified.
- Godot `--headless --path . -- --smoke-test`: existing world, puzzles, field tools, NPC collisions, trainer approaches, inventory, Safari/Day Care, story chapters, eight badges, League ordering, Hall of Fame, reset/recovery and combat checks; new nature pairs, real stat effects, PC transfer/release safety, EV berry consumption, historical Pokedex save/reload, AI Protect/immunity and all cry decoders.
- `--capture-collection`: Summary, PC filters/boxes, shiny Pokedex entry and Sound settings visual checks, without writing the player's save.

## Corrections found during integration

The PC protects the last healthy teammate, preserves a usable Surf partner, and returns held items on confirmed storage release. Day Care now also checks the last Surf partner. Captures preserve the fought Pokemon's nature; old saves use neutral Hardy. Sound playback uses a pool so simultaneous attacks do not cut each other's audio. Upstream mislabeled MP3 cries are stored with their correct extension and decoded appropriately.

## Practical limits

Graph connectivity does not prove a walkable route through every conditional puzzle configuration. The quest tests simulate victories and prerequisites; they are not a manual, unassisted playthrough from Pallet to Champion. Original FireRed scripts are still adapted rather than fully interpreted. Link Cable now supports the four Kanto trade evolutions; network trading remains unavailable. Boxes retain the existing global 100-storage cap; they are not 30-slot cartridge boxes. Historical Seen/Caught migration can reconstruct current owned Pokemon and recorded encounter flags, not encounters absent from old save data. Berries affect EVs only; friendship, mints and breeding are not part of this update.
