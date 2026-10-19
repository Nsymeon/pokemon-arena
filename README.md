# Pokémon Arena — Kanto 151 + retained extras

Godot 4.3 desktop arena prototype. All 151 original Kanto species are playable, plus the seven existing non-Kanto Pokémon: Chikorita, Sudowoodo, Umbreon, Duskull, Snorunt, Klink and Rookidee. Total: **158**.

## Download for Windows

[Download the latest tested build](https://github.com/Nsymeon/pokemon-arena/releases/latest). Choose PokemonArena-Windows.zip, extract the entire ZIP and run PLAY.bat. No Godot installation is needed. CHECK-FOR-UPDATES.bat opens the same page for future updates. Single-player against AI.

## Play

Double-click `play.bat`, or import `project.godot` in Godot and press F5. All assets and roster data are local; playing needs no network access.

- Search by name or Pokédex number. Filter by either type, Gen 1, or retained extras.
- Left-click selects the active side; right-click always selects CPU.
- YOU / CPU tabs or Tab switch the selected side. Enter / Start Battle begins.
- Default mode is **6 vs 6**. Click a team slot at the bottom, or press **1–6**, then choose its Pokémon. Both teams are editable. **T** switches between teams and the original 1 vs 1 duel. Click outside search before using keyboard shortcuts. Duplicates are allowed.
- Scroll, PgUp/PgDn or Prev/Next browse nine pages. Arrow keys move the selected Pokémon through the filtered list when the search field is not focused.
- WASD / arrows: movement. Mouse: aim. Q / left mouse, E, F and C use the displayed moves. Hold **Space** while moving for **35% faster running**. Sprint follows your movement keys, uses 12 energy/second instead of regenerating energy, and grants no invulnerability. Space while standing still does not move you. Dash-type Pokémon attacks retain their own movement.
- During team battles, **B** opens a paused team menu; click a healthy reserve or press **1–6**. Number keys also switch directly during combat. **B / Esc** closes the menu. The active and fainted Pokémon cannot be selected. Switching recalls the current Pokémon and sends out the chosen member, preserving HP, energy, status and move cooldowns. A four-second combat-time cooldown separates switches; reserves do not regenerate while benched. The next healthy member enters automatically after a knockout, including earlier slots you switched away from.
- Tab returns to the roster. R restarts the current matchup. Esc pauses.

The move slots no longer have a fixed role: a physical contact move dashes, a ranged move launches a projectile, and a support move applies its listed effect. Inspect the move cards before a fight.

## Champion Hall presentation

- All 158 Pokémon use local PMD SpriteCollab animated sheets in battle, with eight-direction idle/walk/attack/hurt states and authored frame timings. Selection cards retain the original portrait artwork.
- Blue tiled champion hall, championship dais with steps/carpet, wall banners, gold floor inlays, a Poké Ball emblem, flame lamps, portrait health bars, type badges and six team indicators. The trainers keep their original screen positions on the left/right edges. They now have distinct cap/hair silhouettes, shaded clothing, backpacks, boots and articulated throwing arms.
- Elemental effects: flickering flame streams, spiralling water jets, branching lightning, ice crystals, flying crescents, leaves and spectral orbs. Contact attacks use layered slash arcs. Element-specific impact bursts, splashes and shards accompany fading cracks/scorch marks. Beam tails are limited to the actual distance travelled from the caster. These present the existing arena move rules, not cartridge-exact animations.
- After a knockout, the Pokémon falls, flashes black and returns to its trainer's ball. If reserves remain, the next team member enters through a new ball throw. The survivor keeps its health/energy/cooldowns and remains visible. Combat pauses during this transition. Victory is decided when a team has no Pokémon remaining; simultaneous final knockouts draw.
- Original statistics, typings, four-move loadouts and arena collision dimensions are retained. Teams are selected before a match and can switch among their healthy members during battle. Mega Evolution and camera zooms from the reference reel are not implemented.

Animation sources and artist attribution are recorded in `assets/animated/CREDITS.md`. `node tools/fetch-animations.mjs` fetches a pinned snapshot of the current SpriteCollab revision; `node tools/animation-credits.mjs` rebuilds the attribution table. Playing uses only local assets.

## Stats and typing

Species retain their **modern** base HP, Attack, Defense, Special Attack, Special Defense and Speed, and modern single/dual types. This is the original 151 species, not a reproduction of Red/Blue's old Special stat or old type chart. Clefairy is Fairy; Magnemite is Electric/Steel. All six base values and their total (BST) are visible in selection.

Arena mapping:

- Maximum HP = 130 + 2 × base HP.
- Movement speed = min(340, round(150 + 1.1 × base Speed)).
- Physical damage uses Attack / Defense; special damage uses Sp. Attack / Sp. Defense.
- Stat factor = clamp((50 + attacking stat) / (50 + defending stat), 0.35, 2.5).
- Damage = arena move power × stat factor × STAB × effectiveness × buffs × guard, rounded to 0.1.
- STAB = 1.5 when either user type matches the move. Effectiveness multiplies across both defending types: 4, 2, 1, 0.5, 0.25 or 0.
- Move power, cost and cooldown are scaled for real-time combat. Variable-power moves have an arena baseline. Accuracy uses the source move value and accuracy stages. Focus Energy enables a 50% chance of a 1.5× critical hit while active; a general critical-hit system, PP, abilities, IVs/EVs, natures and held items are not simulated.

Stronger species are intentionally stronger: this update does not equalize Magikarp and Mewtwo.

## Movesets

[Full stats and all movesets](data/movesets.md) are generated alongside the roster. Every species has four distinct actions. **629 moves** are checked against recorded learnsets, including moves inherited from pre-evolutions and moves recorded in different generations. This is a National Dex-style cross-generation selection, not legality for one particular cartridge.

Ditto is the explicit exception: it learns only Transform. It starts with Transform plus three marked arena actions (Reposition, Struggle, Guard). Transform copies the opponent's types, stats, appearance and moves while retaining Ditto's maximum/current HP; rematching restores Ditto.

Real-time adaptations:

- **Every action has a shared 1-second gate**, for player and CPU, so pressing a different attack key cannot bypass the turn interval. Existing per-move cooldowns and energy costs also apply. Failed paralysis/confusion attempts consume the shared interval. Space sprint does not consume an action.
- **Charge moves** (Solar Beam, Dig, Bounce in the current roster) hold position for 1 second before executing, then lock all actions for 2 seconds. Sleep, freeze or flinch cancels charging; switching cannot bypass it. Recharge-flagged moves execute immediately and lock actions for 2 seconds. All timing pauses during menus, send-outs and recalls. Charge/recharge metadata comes from source flags; no recharge-flagged move is currently in the curated roster.
- Healing restores 25% maximum HP. **Rest** heals fully, cures the previous major status and puts the user to sleep for 3 seconds. Protect/Reflect/Light Screen retain the arena's 50% guard for 3 seconds.
- Stat-changing moves and hit effects now change the actual Attack, Defense, Sp. Attack, Sp. Defense, Speed or accuracy stages (−6 to +6, lasting 8 seconds), rather than a generic damage buff or slow. Accuracy reduction can make a move miss. Defense buffs and screens remain arena adaptations, not full cartridge implementations.
- **Sleep:** random 1–5 seconds; no movement, sprint or attacks. **Freeze:** random 1–5 seconds with the same restrictions; damaging Fire attacks thaw it, and defrost-flagged moves can thaw their user. **Paralysis:** 8 seconds, half speed and a 25% chance to fail each attempted action.
- **Burn:** 8 seconds, 2% max HP per second and half physical damage. **Poison:** 8 seconds, 3% max HP per second. **Toxic:** 8 seconds, increasing damage of 1%, 2%, … 8% max HP per tick. Damage ticks bypass ordinary hit invulnerability. Only one major status can be active at once.
- **Confusion:** 6 seconds, one-third chance to replace an action with 3% max-HP self damage. **Flinch:** interrupts attacks/charging and stops movement for 0.4 seconds. **Partial trapping** (Sand Tomb): 5 seconds, 2% max HP per second and no switching. Volatile statuses and stat stages clear on manual switching; major statuses and their remaining durations persist and freeze while benched. Toxic's escalating counter resets on switching.
- Fire is immune to burn; Poison/Steel to poison/Toxic; Electric to paralysis; Ice to freeze. Ground is immune to Thunder Wave and Grass to powder statuses. Type immunities block the secondary effects of immune hits.
- Damaging moves use their source secondary-effect chances: e.g. Flamethrower 10% burn, Ice Beam 10% freeze, Thunderbolt 10% paralysis, Water Pulse 20% confusion, and Rock Slide 30% flinch. Tri Attack has a 20% chance to inflict one of burn/paralysis/freeze. Self-stat effects (such as Flame Charge) are also applied. This covers the major conditions and the effects in this roster; terrain, abilities and every franchise-specific volatile condition are outside this prototype. Weather adaptations are documented below.
- Drain moves recover 40% of damage dealt; recoil costs 20%. Splash restores 15 energy and gives brief invulnerability.
- Area attacks use a local pulse; ranged attacks use projectiles; contact moves use a damaging dash. Status-only attacks affect the opponent within 260 units and use their source accuracy. Exact cartridge move behaviors are not all modeled.

CPU opponents use the same move costs and cooldowns, consider type effectiveness, heal/guard/buff when useful, and close distance when their moves require contact. Rocks block movement and projectiles and can be destroyed.

The crystal cavern field is **2400 × 1200 world units**, 78% more area than the 1800 × 900 field. A smooth camera follows your Pokémon at 0.8 scale with a 220-unit offset toward the opponent, clamped to the arena edges. Mouse aim uses the camera transform. A minimap shows both Pokémon, the visible area, and the trainers, who remain on the left and right edges. Initial Pokémon spawns are closer together so both fit in the opening combat view.

Each side has its own pixel-art trainer holding a Poké Ball. At the start of every match, both trainers throw their balls along an arc. The balls open with a flash, the Pokémon materialize, and the empty balls return to the trainers. Combat begins after the 3.2-second send-out sequence.

At zero HP, the defeated Pokémon tips forward onto the ground and flashes between normal colors and a black silhouette. Its trainer then recalls it with a red beam: the sprite shrinks and travels into the Poké Ball, which closes with a glow. Combat stops during the 2.9-second sequence; the result appears afterwards. This works for either side, simultaneous knockouts, and transformed Ditto. Pause freezes both sequences; rematch replays the send-out.

Already-launched attacks **continue after their caster faints**. They retain the caster's offensive stats at launch and still collide with opponents, rocks and field boundaries until hitting or expiring. No new attacks, charges or movement start during knockout resolution. Current target defenses and hit invulnerability still apply. Drain cannot revive a fainted caster. Results and automatic team replacements wait until all projectiles resolve and each defeated Pokémon completes its own faint/recall animation; a late hit can turn victory/defeat into a double knockout. Pause freezes both projectiles and recalls.

## Sources and reproducibility

See [CREDITS.md](CREDITS.md) and `data/sources.json`. Data is from Pokémon Showdown; sprites from PokéAPI's sprite repository. Sources are cached locally under `data/source/`.

- `node tools/import-data.mjs`: download missing source snapshots.
- `node tools/build-roster.mjs`: generate roster and human-readable moveset table from curated family/species selections, validating recorded learnsets.
- `node tools/update-move-rules.mjs`: refresh condition probabilities, accuracy and charge/recharge flags from the cached source without changing movesets.
- `node tools/fetch-sprites.mjs`: download/cache the 158 sprites.
- `node tools/validate-data.mjs`: independently verify IDs, all six base stats, types, move legality/category, and PNG files.
- Godot `--headless --path . -- --smoke-test`: test all 632 actions, every species as CPU, damage categories, dual types, status immunities, guard, poison, Transform/reset, energy, sprint, all eight sprite directions, manual switching/state persistence/recall/cooldown, team exhaustion, projectile collisions, filters and pagination. Failing checks return a nonzero exit code.
- Godot `--path . -- --capture`: render roster, final page and battle previews into `captures/`.

One arena, local single-player battles, animated species sprites and real-time adaptations of Pokémon mechanics. This remains a fan prototype.


## Directional arena skills

- Solar Beam: locked thin aiming line during the existing 1-second charge, then an instantaneous 1150-unit beam; 2-second recovery remains. Ice Beam and Aurora Beam also use line collision and luminous beams.
- Surf: 360-unit-wide traveling wave, moving 620 units/second for 1.45 seconds. It carries its living caster while movement respects cover and boundaries. Each opponent is hit once. A wave continues after its caster faints.
- Thunderbolt / Thunder: mouse-targeted ground circle (850-unit maximum range), 0.75-second warning, then a single lightning strike. The target point stays fixed, so stepping out avoids it. CPU targets the player position at cast time.
- Earthquake: expanding ground shockwave with cracks and rising stone, reaching 310 units.
- These wide attacks damage each obstacle once and pass through it. Offensive stats and effects are captured at launch; delayed strikes still resolve after a knockout.
- `--capture-skills` renders the Solar Beam warning/beam, Surf wave, and Thunderbolt warning/strike. Smoke tests cover line damage, single-hit behavior, riding, delayed strikes after fainting, and camera aiming/bounds.

## Arena weather and expanded effects

Before starting, use the **Weather** dropdown beside the roster filters. Clear, sunlight, rain, sandstorm and hail are fixed arena baselines. Changing weather cycles Clear → Sun → Rain → Sand → Hail every 25 seconds of active combat. Weather moves override the baseline for 20 seconds; afterwards the baseline returns (or the dynamic cycle advances). Weather pauses with battle menus, send-outs and knockout resolution, and survives Pokémon substitutions.

- Sun: Fire damage ×1.5, Water ×0.5; Solar Beam fires immediately with the normal 1-second action gate. Fire attack areas increase 12% as an arena adaptation.
- Rain: Water damage ×1.5, Fire ×0.5; Water attack areas increase 12%. Thunder and Hurricane skip accuracy rolls, but opponents can still leave their target area. Thunderbolt does not receive this accuracy rule.
- Solar Beam has half damage in rain, sand and hail. Thunder/Hurricane accuracy is 50% in sun. Blizzard skips accuracy rolls in hail; the shared rules also support future Snow and Weather Ball moves.
- Sand: Rock Pokémon receive ×1.5 Special Defense. Rock/Ground/Steel are immune to weather chip damage. Hail: Ice Pokémon are immune. Chip damage is adapted to 1% maximum HP per active combat second; this is not cartridge turn timing. Hail and modern Snow have separate rules: Snow buffs Ice physical defense without chip damage.
- Synthesis/Moonlight restore 33.3% HP in sun, 25% in clear weather and 12.5% in adverse weather, scaled to arena healing. Rest is unchanged.
- Offensive weather strength/size are captured when the action is committed, so an existing attack retains them through later weather changes and knockouts. The defender's weather defense is evaluated on impact.

Four legal loadouts now have weather moves in **C**: Ninetales / Sunny Day, Golduck / Rain Dance, Sandslash / Sandstorm, Dewgong / Hail. Source stats, other species' loadouts and all 158 animations remain intact. The rules are centralized in weather_rules.gd rather than tied to particular species.

Flamethrower now uses a forward flame cone with a hot core and sparks; Hydro Pump uses a long water jet with spiraling streams and spray. Rock Slide marks a ground circle and drops boulders after 0.75 seconds; Hurricane creates a spinning funnel over its marked area. Fire Blast has a five-pronged flame burst, and Razor Leaf has spinning leaves with slicing trails. Existing Solar Beam, Surf, Ice Beam, lightning and Earthquake behavior is preserved.

Weather reference: [Bulbapedia weather conditions](https://bulbapedia.bulbagarden.net/wiki/Weather_conditions). Timings, healing amounts and size changes above are explicit real-time arena adaptations.

## Crystal cavern visual pass

The supplied local oak_giov.mp4 reference was inspected through timestamped frames across its 173-second duration. The arena now uses original procedural purple stone slabs, varied cracks, mineral facets, crystal clusters, cyan boundary light, drifting dust and a subdued engraved center. Scenery geometry is cached and floor details outside the camera are culled. Trainers retain their left/right positions; camera, map size and weather controls are preserved. No video textures or game footage are bundled.

Psychic and Psystrike now mark a fixed 110-unit target circle, gather orbiting energy for 0.75 seconds, and resolve once with expanding rings and a bright core. Psystrike adds stone fragments. Leaving the marked area avoids the strike; launched bursts continue through caster knockout. Shadow Ball, Energy Ball and Aura Sphere now have layered glow, orbiting wisps and fading trails. The reference inspired the dark backdrop and luminous energy effects; this is an original procedural adaptation, not a reproduction of its assets.

## Anime tournament arenas

Choose **Arena** in the roster screen independently of the opponent and weather. The original Crystal cavern remains available alongside nine tournament-inspired maps: Indigo stadium, Grass, Rock, Water, Ice, Forest, Town, Wasteland, and Water & rock. These are original procedural interpretations, not extracted anime backgrounds. Stadium seating, field markings and trainer decks frame the maps. Trainers retain their original side positions and Poké Ball animations.

Water and Water & rock have animated pools and safe islands. Ordinary walking/sprinting is 22% slower in water for Pokémon without Water or Flying typing; land, islands, attacks, knockback and Surf keep their existing behavior. Ice types walk/sprint 15% faster on Ice. These are arena balance choices, not cartridge terrain rules. Rock, Forest, Wasteland and Water & rock include destructible rock cover; trees, model buildings and distant ice formations are scenery. All species remain usable on every field. Weather effects remain independent.

**League / field change** starts on one of Grass/Rock/Water/Ice. Once either team loses three Pokémon and the match can continue, the old attacks and recall sequence finish, then a shutter transition reveals a different classic field. This happens once per match, resets field cover and recent ground scars, and repositions the active Pokémon on safe spawns without healing them or resetting weather. Ordinary switches do not count as knockouts. This mode uses the current teams; it does not implement tournament brackets or anime battle rosters.

Research: [Indigo Conference](https://bulbapedia.bulbagarden.net/wiki/Indigo_Conference) establishes the four classic preliminary fields and the final stadium. [Ever Grande](https://bulbapedia.bulbagarden.net/wiki/EverGrande_Tournament) describes the field change after three Pokémon are defeated. [Lumiose Conference](https://bulbapedia.bulbagarden.net/wiki/Lumiose_Conference) adds forest, town, wasteland, and mixed water/rock fields. Arena tests are included in `--smoke-test`; `--capture-fields` exports map overviews, a battle preview and the arena selector to `captures/`.

## Kanto Gym Leaders, Elite Four and Champion opponents

The opponent dropdown also includes all eight Kanto Gym Leaders: Brock (2 Pokémon), Misty (2), Lt. Surge (3), Erika (3), Koga (4), Sabrina (4), Blaine (4), and Giovanni (5). Their party order, original levels and move selections follow [Red/Blue gym teams](https://www.serebii.net/rb/gyms.shtml). Original two- and three-move sets remain intact. Each leader has a distinct slim trainer design and uses the existing send-out/recall animations from their side of the arena.

Gym move adaptations: Bide stores incoming hit damage while charging for 2 seconds, then returns double within 300 units; Disable locks the opponent's last recorded move for 4 seconds within 260 units; Minimize raises evasion for the normal stat-stage duration. Sonic Boom deals 20 fixed damage; Psywave deals 0.5–1.5 times its reference level. Self-Destruct hits within 300 units and faints its caster. Light Screen uses the existing short guard mechanic. `--capture-gyms` renders all eight trainer designs and sample gym menus/battles.

Choose an opponent from the upper-right dropdown on the roster screen: Lorelei, Bruno, Agatha, Lance, or Blue with Charizard / Blastoise / Venusaur. Elite Four parties contain five Pokémon, Blue has six. You keep your own editable six-Pokémon team. Click an opponent party chip to inspect its exact moves; opponent presets cannot be overwritten by roster clicks. Custom team restores free opponent editing. Each challenge is an independent match, not a persistent League gauntlet.

[All historical teams, levels and moves](data/trainer-teams.md) are stored separately from the playable roster. Red/Blue party order and move selections are retained, including duplicate species, Lance’s Barrier Dragonite and Blue’s three-move Exeggutor. Original levels are reference metadata; existing modern base stats, types, damage categories and arena HP remain in use. Trainer items and cartridge-specific AI bugs are not simulated.

Real-time adaptations for these moves: Night Shade uses the recorded opponent level as fixed damage, Dragon Rage deals 40 fixed damage, Dream Eater requires sleep, Counter reflects twice the physical damage received within two combat seconds at close range, and Haze clears both sides’ stat stages. Mirror Move copies the opponent’s latest recorded move and respects charge/recharge. Roar/Whirlwind push and briefly interrupt instead of forcing a switch. Fissure/Horn Drill deal 65 base arena damage with 30% accuracy rather than an instant KO. Multi-hit moves combine their power into one hit; Rage grants an Attack stage on hit; Thrash uses the normal single attack flow. These adaptations preserve the move identities without claiming cartridge-exact battle mechanics.

All 14 trainer identities now use the full-body FireRed/LeafGreen battle sprites instead of procedural figures. Blue's three teams and the custom rival share Blue's sprite. The sprites face into the arena, retain each character's outfit and battle pose, and use individual hand anchors for Poké Ball send-out and recall. Their side positions stay unchanged. These are static battle poses with a small send-out lift, not walking animation sheets. Source files and attribution are recorded in `assets/trainers/sources.json` and `CREDITS.md`; `node tools/fetch-trainers.mjs` refreshes the files.

Hydro Pump's beam and hitbox are about 29% narrower: collision half-width is 34 arena units instead of 48 (38.08 in rain). Its range is halved from 1150 to 575 units. Ice Beam reaches 650, Aurora Beam 600, Hyper Beam 900, and Solar Beam retains 1150. Charge guides, rendered beams and collision use the same range; rain increases water width/power but does not extend range. Damage and duration are unchanged. Thunderbolt/Thunder, Rock Slide, Hurricane and Psychic/Psystrike now use the visible 110-unit circle without the old extra 19-unit damage margin. Flamethrower's hit cone matches its rendered outer width, including sun scaling.

Build/check: `node tools/build-trainers.mjs`, `node tools/validate-trainers.mjs`, and the normal Godot smoke suite. `--capture-league` renders the trainer gallery and opponent menu/battle previews. Sources: [Indigo Plateau / Generation I](https://bulbapedia.bulbagarden.net/wiki/Indigo_Plateau/Generation_I) for parties and move selections; the existing cached Showdown move definitions supply arena conversion metadata.

Special entrances and rush attacks:
- Agatha's Gengar emerges from a dark floor shadow during send-out.
- Quick Attack follows a zigzag toward the opponent's position at launch (320 range).
- Extreme Speed follows a straight rush (420 range); available on Arcanine's C slot.
- Aqua Jet carries the Pokemon in an oval water envelope (320 range).
- Rushes hit once, retain the general action cooldown, and committed effects survive KO.

Windows friend playtest: dist/PokemonArena-Windows.zip. Extract the whole ZIP,
then run PLAY.bat. Includes Godot runtime; no installation needed. Single-player
against AI only. This is a portable source build, not a dedicated release export.

Beam clashes (video-inspired): Flamethrower is now a narrow rolling flame stream
with a 520-unit range. Hydro Pump retains 575 units. Opposing beams stop at their
contact point and consume attack integrity for about 0.42 seconds. Integrity uses
base damage, offensive stats/stages, STAB, burn and launch-time weather. Equal
attacks cancel; a surviving attack deals proportionally reduced damage. Projectiles
also clash using swept paths. Ground AoEs, Surf and physical rushes are excluded.
Fire/water contact generates steam. Already-launched attacks still survive KO.

GitHub updates: .github/workflows/windows-playtest.yml builds a portable Windows
ZIP on each push to main/master after roster, trainer and combat checks pass.
Successful builds create versioned GitHub Releases marked latest. A stable link is
https://github.com/Nsymeon/pokemon-arena/releases/latest.
The friend downloads PokemonArena-Windows.zip and extracts it into a new folder.
This does not automatically update an already-installed copy or push unsaved edits.
Use VS Code Commit + Sync after testing changes; no tokens belong in project files.



## League campaign and saves

The game opens on Kanto League. Select Continue League, build your six-Pokemon
team, and press Enter / Start Battle. Defeat Brock, Misty, Lt. Surge, Erika, Koga,
Sabrina, Blaine and Giovanni to collect eight badges, then Lorelei, Bruno, Agatha,
Lance and Blue. Completed trainers can be replayed; future opponents stay locked.
Blue uses the existing Charizard Champion party. Winning records your team in the
Hall of Fame. Free Battle remains independent of campaign progression.

The first campaign version heals the team between trainers and allows team edits
before each match. Defeat/draw preserves the checkpoint. Tab leaves a League battle
for the hub; R on the final result returns to the hub. Closing mid-battle restarts
that trainer, rather than resuming individual HP, projectiles or timers.

Team composition is saved when starting a League match or returning from team
selection to the hub. Progress is awarded only after the last Pokemon and all
pending attacks resolve. Saves live outside the game folder in Godot's user data
location as `league-progress-v1.json`, with a `.bak` recovery copy. Updating or
extracting a new release does not erase progress. Saves are local to each PC,
not synced by GitHub. An invalid/unsupported save is preserved with an on-screen
message. Automated tests use separate temporary saves, never your campaign.
