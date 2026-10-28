# Trainers and NPC dialogue

- Trainers with multi-direction movement definitions now change facing every 1.8-2.6 seconds within their allowed directions. Fixed-facing trainers retain their original facing. Sight uses the same direction as the sprite and respects obstacles/defeated state.
- Approach snapshots endpoints, animates walking, stops next to the player and invokes the battle callback automatically after the alert and introduction. Manual interaction also uses this sequence.
- Original text is compiled from the existing pinned pret/pokefirered checkout into npc-dialogue.json. Unconditional call/goto references are followed with cycle/depth limits. Trainer intro and post-battle text are kept separately. Badge, Pokedex and Champion flag branches are read from existing progress; no original script code is executed.
- Long conversations preserve paragraph breaks and have E-driven pages. New conversations discard leftover pages.
- Ordinary Mart customers now talk instead of opening the shop or handing out Oak's parcel. Only the clerk handles those interactions. Right-click can select a blocked door tile so the existing automatic warp can run.

Validation: Godot smoke checks cover automatic alert progression, changed actor position, adjacent stop, single completion callback, facing changes, defeated trainers, paragraph pagination and page cleanup. Map audit verifies 392 map records, 1237 warp destinations and 388 connected maps (four original unused houses excluded). Render checks inspect approach and a Pewter house dialogue; these are scripted visual checks, not a full manual campaign.

Limits: this does not implement the entire FireRed script engine. Conditional branches needing unsupported script variables, choices, gifts and special services still rely on existing quest implementations; some retain custom text. NPC walking patrol routes are not implemented here: scanning changes facing in place. Full one-to-one story/dialogue fidelity is not claimed.
