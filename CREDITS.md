# Data and artwork

- Pokémon species data, modern base stats, types, move metadata and recorded learnsets: [Pokémon Showdown](https://github.com/smogon/pokemon-showdown), via the public JSON endpoints at `https://play.pokemonshowdown.com/data/`. Exact source URLs and snapshot SHA-256 hashes are saved in `data/sources.json`.
- Pokémon sprites: [PokéAPI sprites repository](https://github.com/PokeAPI/sprites), `sprites/pokemon/{national-dex-number}.png`. The repository distributes Pokémon artwork; these are not original drawings by this project. Pokémon characters and original artwork belong to their respective rights holders.
- Arena visuals, interface, combat implementation and synthesized sound effects: this prototype.
- Trainer battle sprites: original Pokémon FireRed/LeafGreen (Generation III) artwork by Game Freak / Nintendo / Creatures, distributed through the [Pokémon Showdown trainer archive](https://play.pokemonshowdown.com/sprites/trainers/). The 14 `*-gen3.png` files are stored unchanged in `assets/trainers/`; source URLs and SHA-256 hashes are in `assets/trainers/sources.json`. Display mirroring, positioning, shadows and Poké Ball effects are handled at runtime. No community redraw variants are used.
- Animated battle sprites: [PMD SpriteCollab](https://github.com/PMDCollab/SpriteCollab). All 158 species have local Idle, Walk, Attack, Shoot and Hurt sheets where provided. See [per-species artist credits](assets/animated/CREDITS.md), original credit histories, and pinned source revision in `assets/animated/source.json`. Community contributions are covered by the repository's noncommercial attribution policy (CC BY-NC 4.0); original Mystery Dungeon artwork is credited to Chunsoft and the respective rights holders.

This is an unofficial Pokémon fan prototype. The project does not claim ownership of Pokémon artwork or affiliation with the franchise.


Shiny variants: PokeAPI/sprites portraits and PMDCollab/SpriteCollab animations, pinned to the same revision as assets/animated/source.json. Artist credits are preserved in assets/shiny/<species>/CREDITS.md. Normal ability slots use pret/pokefirered src/data/pokemon/species_info.h; later guest slots and move flags use the existing Pokemon Showdown source snapshot. See docs/shinies-and-abilities.md.

- Kanto map layouts, metatiles, palettes and overworld character sprites: original Pokémon FireRed artwork/data, Game Freak / Nintendo / Creatures, reconstructed from [pret/pokefirered](https://github.com/pret/pokefirered). Pinned revision and generated map count: assets/kanto/source.json. The pret project provides the decompilation; original artwork is not claimed as original or freely licensed by this prototype.
