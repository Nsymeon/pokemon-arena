# Adventure: Kanto story plan

## Research and direction

Use the FireRed/LeafGreen story as the progression reference, with our real-time arena battles. The world remains a compact adaptation rather than a tile-for-tile remake. Current arena rosters, healing, learnsets, move selection, inventory, capture controls and party persistence are reused.

References:
- [Overall FireRed/LeafGreen walkthrough](https://bulbapedia.bulbagarden.net/wiki/Walkthrough:Pok%C3%A9mon_FireRed_and_LeafGreen): regional chapter order.
- [Cerulean, Routes 24/25 and Bill](https://bulbapedia.bulbagarden.net/wiki/Walkthrough:Pok%C3%A9mon_FireRed_and_LeafGreen/Part_5): rival, bridge trainers, Bill's transporter and S.S. Ticket.
- [Vermilion and S.S. Anne](https://bulbapedia.bulbagarden.net/wiki/Walkthrough:Pok%C3%A9mon_FireRed_and_LeafGreen/Part_6): ship rival, Captain/Cut, Gym switches, Surge's party, Thunder Badge and TM34.

## Playable now: third badge

After Misty, take Cerulean's WEST exit to the new Nugget Bridge area. Beat Blue, the five bridge trainers in sequence, then the Rocket recruiter. The nugget reward is converted directly to $5000 once. Continue north to Sea Cottage: speak to Bill and activate his console to receive the ticket.

Use the existing compact Kanto connections to Vermilion. Its NORTH exit enters S.S. Anne once the ticket is owned. The deck has a healing passenger, an optional sailor, Blue and the Captain. Blue's evolved starter counters your original choice. After that rival battle, the Captain gives Cut as a permanent field tool.

Vermilion's WEST exit leads to the Gym after obtaining Cut. Inspect switch boxes: box 2 opens the first lock, adjacent box 3 opens the second; a wrong second choice resets the puzzle. Defeat Surge for the third Adventure badge and one TM34. His Voltorb/Pikachu/Raichu levels and Electric movesets follow the reference.

All story flags, bridge progress, key items and puzzle state save with the existing Adventure file. Old saves default to the new chapter being unstarted; no reset is needed. Key items appear in the Bag. Existing Kanto map IDs and exploration access are retained. New areas append IDs 26-29.

Deliberate adaptations: west/north exits follow our compact map, Bill's event is outside his cottage, the ship is a single deck, the switch pair is fixed instead of randomized, and Cut does not require teaching an HM into a battle slot. The ship remains available. Bill and supporting NPCs currently reuse existing trainer sprites; dedicated character art is still pending. This update does not recreate all optional trainers/items, indoor floors, bike, fishing, trades or the cartridge's exact path gates.

## Next implementation chapters

1. Lavender and Celadon: route travel, Tower mystery, Erika, Rocket Hideout, Silph Scope and a return to the Tower to rescue Mr. Fuji and obtain the Poke Flute. Give each quest persistent prerequisites and one-time rewards.
2. Fuchsia: Snorlax route gates, cycling/coastal travel, Koga, Safari exploration objectives for Surf and the Warden's Strength reward. Safari encounter rules are postponed with other wild encounter work.
3. Saffron: Silph Co. access/card doors, rival and Giovanni, Lapras reward, Fighting Dojo choice and Sabrina.
4. Cinnabar and Viridian: water traversal, Mansion key puzzle, Blaine, final Giovanni Gym, eight-badge access to Victory Road.
5. Indigo: rival checkpoint, Elite Four sequence, Champion, Hall of Fame save and a clear postgame entry point.

Before later chapters exceed the current level-30 cap: expand level scaling, evolution coverage, trainer learnsets, rewards and save validation together. Later Gyms in the separate Gym Leaders mode do not count as completed Adventure chapters.

## Deferred by request

No new grass/cave encounter method, random encounter checks, encounter frequencies or new wild spawn tables. Existing visible Pokemon and manual interaction remain as before. The four new story areas contain no wild encounters. Fishing, surfing encounters, Safari catches, roaming and legendary encounters belong to a later dedicated pass.

## Verification

The smoke suite covers old save compatibility, ticket/Cut/bridge gates, no progression after defeat, bridge counters, transporter ordering, Blue/Surge party dispatch, puzzle reset, one-time TM reward, save reload, malformed story data and zero wild spawns in new areas. All Kanto exits are traversed in both directions with unlocked story prerequisites. The --capture-story flag renders each new map using a temporary save, never the player's real save.
