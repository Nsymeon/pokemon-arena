# Kanto Adventure: current scope and route

The playable main progression now runs from Pallet to Champion across **57 compact areas**. All original map IDs are preserved; new location IDs are appended. This is the functional world/story foundation for the later graphics and encounter pass, not a tile-for-tile FireRed recreation.

## Main route

1. Pallet starter and Blue; Viridian Forest; Brock; Mt. Moon Rocket; Misty.
2. Nugget Bridge, Bill and S.S. Ticket; S.S. Anne rival; Cut; Surge.
3. Celadon Gym (Erika), Rocket Hideout guard, Lift Key and Giovanni for Silph Scope.
4. Lavender Tower: reveal the ghost, defeat Rocket, rescue Fuji for the Poke Flute. Play it at the coastal or cycling-road Snorlax event.
5. Fuchsia Gym (Koga); Safari Zone Gold Teeth and Secret House Surf; return teeth to the Warden for Strength.
6. Saffron Silph Co.: security fight, Card Key, Blue, Giovanni and President. A separate employee awards Lapras once. Saffron Gym has a panel question and Sabrina. The optional Dojo grants one choice of Hitmonlee or Hitmonchan.
7. Cinnabar Mansion statue and Secret Key; Cinnabar Gym quiz and Blaine.
8. Viridian Gym Giovanni requires seven badges. Victory Road requires eight badges plus Surf and Strength: activate the boulder plate, beat the Ace Trainer and Blue.
9. Indigo Plateau: heal, then enter the League chambers. Lorelei, Bruno, Agatha, Lance and the appropriate Blue starter variant follow in order. Champion victory saves the party's species and levels in the Hall of Fame.

Surge remains the earlier chapter's FireRed-style party. Later Gym/League parties reuse the existing researched Red/Blue trainer dataset with Adventure level scaling and explicit movesets. Intermediate Rocket/rival teams are adapted for this real-time progression. This is not a promise that every trainer, floor or optional item matches FireRed exactly.

## Navigation

Existing signed north/south/east/west exits still link the outdoor world. Additional doors, cave passages and Gym entrances appear as labeled markers near the lower part of their parent area. Approach and use the interaction key (default E). The region guide (default M) lists both signed exits and local entrances, with missing prerequisites. Every added area has a return passage.

| Parent area | Added destinations |
| --- | --- |
| Celadon | Gym, Rocket Hideout |
| Lavender | Pokemon Tower |
| Fuchsia | Gym, Safari Zone, Warden's House |
| Safari Zone | Secret House |
| Saffron | Silph Co., Gym, Fighting Dojo |
| Cinnabar | Mansion, Gym, Lab |
| Viridian | Gym, Route 2 |
| Routes 22-23 | Victory Road |
| Indigo Plateau | League chambers, then Hall of Fame |
| Sea Routes 19-20 | Seafoam Islands |
| Route 9 / Rock Tunnel | Power Plant, Route 10 |
| Vermilion | Diglett's Cave, Route 11, Fan Club (plus S.S. Anne and Gym) |
| Cerulean | Cerulean Cave after Champion (plus Nugget Bridge) |
| Routes 5/6 | Underground Path connection |
| Routes 7/8 | Underground Path connection |

All Kanto routes 1-25 are represented, sometimes grouped with neighboring routes. Original free exploration beyond Misty remains available. Story prerequisites gate the new interiors and events, rather than retroactively locking old saved positions in the outdoor region.

## Saving, progression and balance

- Existing saves need no reset. Missing `journey` flags default to unstarted. Badges, keys, gifts, puzzles, League stage and the last Hall of Fame party persist.
- Level cap is now 100. All Gen I level-based evolution chains, including final starters and Dragonite, are supported. The existing level-up move data already extends past level 30. Stone and trade evolution mechanics are not part of this map update.
- Late badges grant their TMs once. Lapras is placed in the party or storage; full capacity leaves the gift unclaimed. The Dojo allows only one gift choice.
- League battles preserve party health. There is no healing NPC inside. Bag medicines remain usable. Defeat resets the run; leaving the chambers for Indigo resets it too. A save between victories resumes at the next trainer. The Champion and Hall of Fame remain recorded when replaying.
- NPC prerequisites and one-time rewards are stored separately from the standalone Gym Leaders/League mode.

## Deliberate compact adaptations / deferred work

New interiors are simple functional rooms with existing trainer artwork. Key interactions stand in for multi-floor dungeon navigation: Card Key doors, statues, boulder plates and warp panels do not yet reproduce the original physical tile puzzles. Most optional ordinary trainers and pickups are not reproduced. Bill's event remains outside; the ship remains one deck. Surf/Cut/Strength are progression tools, not equipped battle HMs; sea routes still use the existing walkable paths. The bicycle voucher is recorded but not redeemable yet.

Power Plant, Cerulean Cave, Lab and some connector areas currently provide exploration space/information without legendary battles, fossil revival or side quests. Sevii Islands are outside this Kanto map pass.

Per user request, **no changes to existing grass/cave spawn tables or encounter mechanics**. No random encounters, Safari catch rules, new wild tables or legendary fights were added. Snorlax and the Tower ghost are scripted story interactions instead of new catchable encounters. The 27 new areas contain no wild spawns. Graphics upgrades and these encounter systems are the next major work.

## Verification

The smoke suite walks the progression from Erika to Champion using actual trainer-party battle dispatch and KO/return/reward hooks. It checks prerequisite gates, eight badges, gifts/TMs, late evolutions, level 100, save reload, League order, loss/exit reset and Hall of Fame. It also verifies the combined outdoor/portal graph reaches all 57 maps, every new entrance has a usable return, and new locations have no wild spawns. These are automated checks; real-player difficulty and pacing still need playtesting.

`--capture-finale` renders representative towns, interiors, the Hall of Fame and the region guide using a temporary save. It never reads or changes the player's actual Adventure save.

## Research references

The chapter order and key-item roles were checked against the [FireRed/LeafGreen walkthrough](https://bulbapedia.bulbagarden.net/wiki/Walkthrough:Pok%C3%A9mon_FireRed_and_LeafGreen): [Celadon and Tower](https://bulbapedia.bulbagarden.net/wiki/Walkthrough:Pok%C3%A9mon_FireRed_and_LeafGreen/Part_9), [Fuchsia](https://bulbapedia.bulbagarden.net/wiki/Walkthrough:Pok%C3%A9mon_FireRed_and_LeafGreen/Part_10), [Saffron](https://bulbapedia.bulbagarden.net/wiki/Walkthrough:Pok%C3%A9mon_FireRed_and_LeafGreen/Part_11), [Cinnabar](https://bulbapedia.bulbagarden.net/wiki/Walkthrough:Pok%C3%A9mon_FireRed_and_LeafGreen/Part_13), and [Indigo](https://bulbapedia.bulbagarden.net/wiki/Walkthrough:Pok%C3%A9mon_FireRed_and_LeafGreen/Part_17). Adaptations above are intentional game design decisions, not claims about cartridge mechanics.
