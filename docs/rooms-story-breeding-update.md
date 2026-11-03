# Interiors, opening story and breeding

## Adventure presentation

- Rugs have one quiet outer seam, without white stripes across the chairs or center.
- Source stair entrances create one continuous flight, with floor-specific direction. The same rule covers homes, Pokemon Centers and museum stairs.
- Home exits use an open cutaway threshold. Shop and Pokemon Center entrances retain glass doors. Only the center tile activates an indoor doorway; side tiles cannot exit or accept a movement target.
- The two Route 2 gatehouses are buildings instead of a grid of fences. Original collision and warp indices are retained.
- Marts have product shelves and registers. Home cabinets have drawers. Viridian School has a blackboard, windows and a desk. Blue's Town Map is a map on the table, not an NPC portrait.

## Opening and NPCs

A fresh Adventure starts in the player's bedroom. The creator saves a name and appearance, followed by the bedroom and Mom introductions. Oak remains absent until the north-exit rescue and escort. In his lab, inspect each of the three balls with the normal interaction key and choose a starter. Blue chooses the counter starter and interrupts the first attempted exit for the Lv.5 battle. The parcel handoff brings Blue back so both trainers receive a Pokedex; Oak walks to the desk and removes the devices.

Ordinary scripted signs now use the source dialogue resolver. Puzzle handlers only intercept their actual locations. Gender/facing/flag branches are interpreted where supported. The north gate's second-rival reminder is natural NPC dialogue.

Additional services: Daisy's Town Map and post-Champion grooming, Name Rater restrictions for traded Pokemon and Eggs, the $500 Magikarp salesman, the Water Labyrinth gentleman's high-friendship Togepi Egg, and imported simple item/TM gifts with one-time flags. Existing tutors, trades, aides, story quests and Sevii services remain in their existing handlers. This is not a general implementation of every original script opcode or multiplayer service.

## Four Island breeding

Four Island Day Care accepts two parents; Route 5 keeps its single-Pokemon service. Parent identities, growth, pending Egg and step count are saved independently. Retrieval costs $100 plus $100 per level gained. Keep a healthy party member and a usable Surf partner when required.

The breeding dataset covers all 386 Gen I-III species. Egg groups, baby species, incense requirements, hatch cycles and egg moves are compiled from the pinned FireRed source. Compatibility follows the original 70/50/20 percent categories, checked every 256 walking steps. Ditto/Undiscovered restrictions, Nidoran and Illumise offspring variants are supported. Three different IVs are inherited from randomly chosen parents. Moves combine the starting learnset, paternal egg/TM moves and shared level-up moves. Existing Adventure nature, ability and shiny generation applies; there is no modern Everstone/Destiny Knot inheritance.

Eggs occupy party/PC space and cannot battle, heal, learn moves, hold items or be traded to an NPC. Only party Eggs count walking steps. Hatching has its own animation, restores the new Lv.5 Pokemon to full health and registers its species in the Pokedex. The Bag's free relearn interface also retains inherited egg moves. Hatch time uses whole tile steps and `(cycles + 1) * 256`; the original game's global per-party hatch counter timing is not emulated cycle-for-cycle.

## Pokemon forms

- All 28 Unown forms, with source Tanoby chamber encounter weights.
- Castform's Normal/Sunny/Rainy/Snowy appearance and types follow Forecast and effective weather. Suppressed weather restores Normal.
- Deoxys Normal/Attack/Defense/Speed forms use their respective base stats. Adventure defaults to FireRed's Attack Form.
- Free Battles provides a FORM selector where applicable. Castform still changes through weather. The daily League's locked builds stay locked.
- Captures and saves preserve persistent forms; the Pokedex remembers caught variants. Normal and shiny form animation libraries are credited in `assets/forms/CREDITS.md`.

## Streaming and verification

Neighboring outdoor maps and nearby door destinations are prefetched. PNG decode/mipmap work runs off the main thread, while geometry and mesh batches yield between work slices. Cached scenes are reused, and pending work is cancelled safely when leaving the scene tree.

On the development Intel Iris Xe system, the measured largest cooperative work slice was about 20–28 ms across the final runs, down from about 51 ms before off-thread image preparation. This is a local measurement, not a universal frame-time guarantee: a first visit without completed prefetch still builds synchronously and can hitch, especially on large maps.

Validation uses temporary fixtures, not the player's save: opening/actual starter-ball interaction, one-shot gifts, center-only door exits, breeding compatibility/inheritance/Egg restrictions/save validation/hatching, form assets and Forecast, trainer/PC/counter/progression checks, combat regression, and construction of all 416 3D map scenes. Representative rooms and cutscenes are rendered for inspection. Existing saves retain their progress; use a fresh slot to experience the opening from the bedroom.
