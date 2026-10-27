# Audio and run settings check - 2026-10-28

Godot 4.3 smoke suite: PASS, including cry migration, independent volume/gain, asset decoding and toggle press/release/repeat behavior.

Manual UI check used a copied project with a separate PokemonArena-AudioQA-20261027 user directory. Original Adventure progress was not used.

Verified: title/settings navigation, independent cry slider (25% to 50% with Master remaining 65%), JSON persistence, preview button activation, Restore Defaults (65%/25%), mode selection, new trainer creation, entry into Pallet Town, cardinal right-click walking, stopping before an NPC, and opening/closing the Adventure menu with Escape. Updated settings layout shows RUN: Toggle on/off with Master and Pokemon Cries below it without overlapping buttons.

Limitations: audio loudness was reduced numerically; no subjective listening assessment is claimed. This was an opening-area manual check, not a completed campaign. Interaction keys sent through the UI automation did not visibly act; Escape and mouse input did. Keyboard automation versus gameplay handling remains unconfirmed. No first battle or full campaign manual pass is claimed.


## Follow-up: proper opening sequence

A second fresh isolated save (PokemonArena-IntroQA-20261028) was played through character creation and walking north. The mouse stopped at the map edge, revealing that the original Oak interception required crossing the boundary. Interception now also runs on the northern edge tile. After restarting the updated QA copy at that naturally reached saved position, the Oak escort was observed, followed by automatic lab arrival and starter selection. Charmander was selected manually, Blue announced Squirtle, and the Lv.5 versus Lv.5 battle opened automatically. This verifies battle startup, not a completed manual battle victory.

Added regression coverage for northern interception, no interception after obtaining a starter, all three counter-starter selections, and no replay after defeating Blue. The complete smoke suite passed. The lab introduction resumes when loading an unfinished opening save.
