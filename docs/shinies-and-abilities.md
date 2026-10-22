# Individual identity, shinies and abilities

Ruleset: FireRed/LeafGreen normal ability slots, including Gen II/III guests; Klink and Rookidee use their modern normal slots. There are 158 species and 58 distinct abilities. Hidden Abilities are not enabled, selectable or randomly assigned in this ruleset. Modern typings/move pools elsewhere in the arena remain unchanged. In particular, Gengar has FRLG Levitate, not modern Cursed Body.

New Adventure starters, gifts and opponents roll one of their legal normal slots with equal probability (50/50 for two slots, 100% for one). Independently, the shiny roll is exactly one successful integer out of 8,192 (0.01220703125%). This is the Gen III–V base rate; the usual Gen VI+ base rate is 1/4,096. No Charm, breeding or chaining bonuses are implemented. No random encounter system was added.

Ability slot, gender and shininess belong to each individual. Capture copies them from the actual enemy; save/load, storage, level-up and evolution preserve them. Evolution resolves the preserved slot against the evolved species. Old saves migrate to normal coloration and slot zero without rerolling on load. Free/Gym setup lets players click ABILITY below the four moves; choices are validated per species and stored separately for each side/team slot. These loadouts cannot override Adventure ownership.

All 158 species have shiny portraits and PMDCollab animation sheets. Shiny send-outs emit a short gold/white sparkle, including switches and Agatha's shadow entrance. Battle portraits, party portraits, evolution pictures and Hall of Fame use the same identity. Shininess gives no stat advantage.

## Combat effects

- Overgrow, Blaze, Torrent, Swarm: matching damage ×1.5 at or below one-third HP. Guts: physical damage ×1.5 while afflicted, ignoring the burn attack penalty. Thick Fat halves Fire/Ice damage. Flash Fire absorbs Fire and grants ×1.5 Fire damage until withdrawal.
- Water/Volt Absorb prevent the corresponding hit and heal 25% max HP. Levitate prevents Ground hits. Soundproof blocks sound-flagged hits/statuses. FRLG Sturdy blocks OHKO moves; it does not act as a Focus Sash. Battle/Shell Armor prevent critical hits.
- Intimidate lowers opposing Attack once per entry. Trace copies the opponent's passive until withdrawal. Clear Body, Hyper Cutter and Keen Eye block their corresponding hostile stat drops.
- Chlorophyll/Swift Swim double movement in sun/rain. Cloud Nine suppresses weather effects while active; the underlying weather timer continues. Sand Veil reduces incoming accuracy to 80% and prevents sand chip. Compound Eyes multiplies accuracy by 1.3. These accuracy modifiers do not turn always-hit moves into miss rolls; physical projectile dodging still applies.
- Insomnia/Vital Spirit, Immunity, Limber, Water Veil, Own Tempo and Inner Focus block the matching status/volatile effects. Insomnia/Vital Spirit also prevent Rest. Early Bird halves sleep duration. Shed Skin has a one-third cure chance every five combat seconds. Natural Cure clears major status on withdrawal.
- Static, Poison Point and Flame Body have 30% contact triggers. FRLG Effect Spore has a 10% contact trigger, then an equal sleep/poison/paralysis choice. Cute Charm has 30% opposite-gender contact activation, adapted to five seconds of infatuation with 50% action failure. Genderless Pokémon are excluded. Synchronize reflects burn, paralysis and poison once, without a reflection loop.
- Shield Dust blocks move secondaries; Serene Grace doubles secondary chances. Rock Head prevents recoil. Liquid Ooze reverses draining healing. Damp blocks Explosion/Self-Destruct. Arena Trap prevents grounded switches; Flying and Levitate escape it. Magnet Pull prevents Steel switches.
- Pressure is explicitly adapted to the existing energy system: opposing damaging attacks cost double energy. Most attacks do not yet have PP. Pickup is adapted to the existing Bag: 10% chance of a Potion after a won Adventure battle, rather than FRLG's full held-item loot table.

Context-only passives are labeled in the selector tooltips: FRLG Lightning Rod, Plus and Minus require doubles; Sticky Hold and Unnerve require held items/berries; Illuminate and FRLG Stench require random encounters; Run Away requires an escape action. Those systems are not implemented, so these abilities do not receive invented combat bonuses. Hidden Ability acquisition is deferred.

## Sources and reproducibility

- [FRLG species ability slots, pret decompilation](https://github.com/pret/pokefirered/blob/master/src/data/pokemon/species_info.h), checked in as `data/source/frlg-species-info.h`; rebuild with `python tools/build-abilities.py`.
- [Ability selection and normal/Hidden distinction](https://bulbapedia.bulbagarden.net/wiki/Ability).
- [Personality value / Gen III–IV ability slot](https://bulbapedia.bulbagarden.net/wiki/Personality_value).
- [Shiny generation odds](https://bulbapedia.bulbagarden.net/wiki/Shiny_Pok%C3%A9mon).
- [PokeAPI shiny portraits](https://github.com/PokeAPI/sprites), [PMDCollab animations](https://github.com/PMDCollab/SpriteCollab), pinned to the revision in `assets/animated/source.json`. Per-species shiny artist credits are in `assets/shiny/<id>/CREDITS.md`. Re-fetch with `python tools/fetch-shinies.py`.

Validation includes equal-slot sampling with a fixed test RNG, illegal loadout rejection, battle hooks, capture/save/load identity, evolved-slot resolution, portrait/animation coverage and rendered entrance/selector screenshots. The test RNG is separate from battle RNG and randomized again after tests.

Free Battles also offers a double-sparkle toggle in the upper-right corner of each editable moves panel. Gold means shiny, outlined gray means normal. The cosmetic preference persists per species, side and team slot in battle-shinies.json, and is ignored by Adventure and Gym campaign battles.
