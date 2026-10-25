# Pokémon Arena — Kanto 151 + retained extras

Godot 4.3 desktop arena prototype. All 151 original Kanto species are playable, plus the seven existing non-Kanto Pokémon: Chikorita, Sudowoodo, Umbreon, Duskull, Snorunt, Klink and Rookidee. Total: **158**.

## Download for Windows

[Download the latest tested build](https://github.com/Nsymeon/pokemon-arena/releases/latest). Choose PokemonArena-Windows.zip, extract the entire ZIP and run PLAY.bat. No Godot installation is needed. CHECK-FOR-UPDATES.bat opens the same page for future updates. Single-player against AI.

## Map object collision

Visible item balls block their tile until collected. Face an adjacent object and press the interaction key (E by default); diagonal and behind-the-player interactions do not activate objects. Cut trees and Strength boulders stay solid until removed or moved, and boulders cannot be pushed onto item balls. Rock Smash rocks render as cracked stones and block passage; Rock Smash field use is not yet implemented.

## Adventure movement performance

All four walking directions share the same foot anchor, including mirrored right-facing sprites. Nearby walkable placement searches outward rather than scanning an entire cave for every story NPC each frame, while retaining nearest-tile selection and live puzzle collision. Use `--profile-world` for repeatable NPC-placement timings in Mt. Moon, Victory Road and Cerulean Cave; `--capture-walk` captures direction previews.

## Adventure character

On the first Play → Adventure entry, choose boy/girl and independent shirt, shoes, hair and trouser colors. The creator previews three map directions and the battle trainer live. Save & Start Adventure stores the appearance in your adventure save and uses it on the map and in battle (including Poké Ball throw positioning). Existing saves show the creator once without resetting progress. Reset Adventure removes the appearance along with that run, allowing a new character. Back to Menu discards unfinished appearance choices. Gym Leaders and Free Battles retain their usual trainers.

## Play

Double-click `play.bat`, or import `project.godot` in Godot and press F5. All assets and roster data are local; playing needs no network access.

- Search by name or Pokédex number. Filter by either type, Gen 1, or retained extras.
- Left-click selects the active side; right-click always selects CPU.
- YOU / CPU tabs or Tab switch the selected side. Enter / Start Battle begins.
- Default mode is **6 vs 6**. Click a team slot at the bottom, or press **1–6**, then choose its Pokémon. Both teams are editable. **T** switches between teams and the original 1 vs 1 duel. Click outside search before using keyboard shortcuts. Duplicates are allowed.
- Scroll, PgUp/PgDn or Prev/Next browse nine pages. Arrow keys move the selected Pokémon through the filtered list when the search field is not focused.
- WASD / arrows or right-click a destination: movement. Keyboard movement cancels the clicked destination. Mouse: aim. Q / left mouse, E, F and C use the displayed moves. Hold **Space** while moving for **35% faster running**. Sprint follows your keyboard or clicked destination, uses 12 energy/second instead of regenerating energy, and grants no invulnerability. Space while standing still does not move you. Dash-type Pokémon attacks retain their own movement.
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
- Healing restores 25% maximum HP. **Rest** heals fully, cures the previous major status and puts the user to sleep for 2.5 seconds. Protect/Reflect/Light Screen retain the arena's 50% guard for 3 seconds.
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


## Adventure chapter 1: Pallet to Pewter

Choose **Play → Adventure** on the title screen. This is a playable first chapter, not a complete FireRed remake. The existing Arena and saved League remain separate modes.

- Speak to Oak outside the lab to choose Bulbasaur, Charmander or Squirtle. Battle Blue on the north path to unlock Route 1.
- Travel north through Route 1, Viridian City and Viridian Forest. Beat the Bug Catcher to reach Pewter City and challenge Brock's Geodude and Onix for the Boulder Badge.
- WASD/arrows or right-click move; hold Space to run. E interacts with nearby people or visible wild Pokemon. E also closes dialogue. P opens your party/storage, F5 saves, Esc opens the adventure menu.
- Battles retain the existing arena controls. G throws a Poke Ball at a wild Pokemon; lower HP and status improve the chance. Trainer Pokemon cannot be caught. After the whole encounter ends, R or Enter returns to the map.
- Captures fill your six-member party, then storage (100 slots). In P, choose your lead; storage adds to a free slot or swaps with your lead when the party is full.
- HP persists between encounters. Mom and Pokemon Centers heal for free. Defeat returns you to your last healing town. The Viridian shop sells five balls for $100; victories award money.
- Survivors gain shared XP, levels up to 30, and supported early-route evolutions. Level scaling remains adapted for the arena. Kanto Adventure moves now follow FireRed level-up learnsets (see below).
- Adventure autosaves on the world map and after encounters in `user://adventure-v1.json`, with a validated backup. Closing during combat resumes from the encounter checkpoint; mid-battle positions and attacks are not saved. League progress uses a separate file.
- Buildings are currently exterior interaction points. Town graphics and some NPC sprite stand-ins are prototype art. Later routes, interiors, story chapters and the remaining badges are not yet part of Adventure.

Development validation: `--smoke-test` covers adventure progression, one-member battles, capture, save reload/backup, defeat healing, evolution, Brock's second Pokemon, and isolation from League. `--capture-adventure` saves preview images using a separate test save.


## Adventure moves, Bag and TMs

Press **I** on the map or when ready to act in a battle to open the Bag. Battles pause while choosing an item; a successful use consumes one item and the shared one-second action gate. No-effect uses keep the item. Potions restore 20% HP, Super Potions 50%, and Revive restores a fainted party member to 50%. These percentages are arena adaptations. Antidote, Paralyze Heal, Awakening, Burn Heal, Ice Heal and Full Heal remove their matching conditions. Saved conditions carry into the next fight, using the existing timed arena status rules. Centers heal HP and clear status.

**P → MOVESETS** shows current moves, new moves waiting for a slot, relearnable level-up moves, and future levels. New moves fill empty slots automatically; a full set never loses a move without your choice. Relearning eligible level-up moves is free. Evolved Pokemon retain learned moves. Starters and wild/trainer encounters use level-appropriate sets; e.g. Charmander starts with Scratch/Growl and learns Ember at 7 and Metal Claw at 13. Existing adventure saves gain appropriate moves and a starter medicine kit once, retaining progress, HP, money and captured Pokemon.

**I → TM CASE** checks compatibility, lets you choose a move slot, and consumes a TM only on successful teaching. The data contains all 50 Gen III TMs; this chapter offers TM09, TM17 and TM40 in the Mart, and Brock awards TM39 once. Existing Boulder Badge saves receive that reward once on migration. Later TM locations are not implemented. The Mart also sells medicines and Poké Balls. Misty awards TM03 once in the Cerulean chapter.

Learnset and TM compatibility sources: [pret/pokefirered level-up tables](https://github.com/pret/pokefirered/blob/master/src/data/pokemon/level_up_learnsets.h) and [TM/HM tables](https://github.com/pret/pokefirered/blob/master/src/data/pokemon/tmhm_learnsets.h). Retained species absent from FireRed use the latest recorded level-up generation from the existing Showdown snapshot, with modern machine compatibility mapped to the same move names. `node tools/build-adventure-learnsets.mjs` regenerates the compact runtime catalog from checked-in sources.

Move eligibility is cartridge-based; execution remains the real-time arena adaptation with modern typings/categories, energy and cooldowns rather than PP. Specialized move effects are not all exact cartridge equivalents. Leech Seed now drains HP and heals the opposing active Pokemon over eight seconds, with Grass immunity. The Adventure level cap is now 30.

The friendly team HUD now displays each Pokemon portrait inside its Poké Ball, with an active outline and crossed-out fainted icons, across all battle modes.


## Battle balance and evolution presentation

- Opponents react to visible incoming projectiles, beams, Surf waves and marked impact areas. Dodges sprint up to 0.5 seconds at 1.35x speed, cost 12 energy/second, and have a random 3.5-7-second decision cooldown after each threat decision, with a 45% chance to attempt an escape. No invulnerability; immobilization, charging and riding moves prevent sprint. Escape choices account for court edges and rock cover.
- Movement, knockback, rushes and Surf riders share legal foot-position bounds. Field battles keep Pokemon inside the painted court with sprite clearance; cavern battles use the cavern inner edge. Trainers retain their side positions.
- Attack, defense, special attack, special defense, speed, accuracy and evasion stages persist until withdrawal, fainting, a new battle or an explicit clearing move such as Haze. Defeating one enemy does not clear the survivor's stages.
- Sleep lasts 2-3 seconds, Rest sleeps for 2.5 seconds, and paralysis lasts 3 seconds. Paralysis keeps its existing speed penalty and move-failure chance. Saved adventure status uses shorter durations on battle entry too.
- Evolution shows old and evolved Pokemon side by side, fades in the evolved portrait and waits for Continue. Multiple evolutions display in order; learned moves are kept.


## Title menu, KO experience and chapter 2

The game starts with **Play**, then **Adventure / Gym Leaders / Free Battles**. Gym Leaders keeps the separate saved League progression (gyms, Elite Four, Champion). The roster screen and Gym Leaders hub offer a return to modes; exiting Adventure restores the arena team before returning to modes.

Adventure now continues from Pewter through **Route 3, Mt. Moon and Route 4 to Cerulean City**. Brock gates the Route 3 exit; a Team Rocket Grunt must be defeated to leave Mt. Moon. Route 3 also has a Lass. New wild species include Spearow, Jigglypuff, Nidoran, Zubat, Geodude, Paras, Clefairy, Ekans and Sandshrew. Cerulean has healing, supplies and Misty's Staryu/Starmie battle. The Cascade Badge and TM03 Water Pulse are awarded once. Existing saves remain compatible; the level cap is now 100 and additional early evolutions are supported. Routes are compact connected prototype maps, not full cartridge layouts or interior story recreations.

XP is awarded once **per opposing Pokemon knocked out**, after committed attacks and the KO animation resolve and before the next enemy enters. Standing party members share the reward; their live stats, HP and learned moves update immediately. Finishing the trainer battle awards money/progression without awarding the same XP twice. Level-up and learned/pending skill messages appear during battle. A blue EXP bar appears under the friendly battle HUD and under each party member on the world map. Pending move replacements remain available through **P → MOVESETS** after the battle. Evolution portraits display when returning to the map.

XP and party health save at these KO checkpoints. Reloading during combat restarts the encounter with the saved party progress; enemy combat position and defeated slots are not resumed. `--smoke-test` covers per-KO level updates, move notifications, duplicate-credit prevention, chapter gates, healing and badge/TM persistence. `--capture-progress` captures the title, mode menu, KO notification and new towns using an isolated test save.

## Reset Adventure

On the Adventure world map, open **Esc → RESET ADVENTURE**, then choose **YES / START A NEW ADVENTURE**. Cancel or close the confirmation to keep the current run. Reset clears the adventure party/storage, starter, levels/moves, badges/story flags, money, items and TMs, then starts at Pallet Town with the initial supplies. Gym Leaders progression and Free Battles are unaffected. The reset is saved immediately and refreshes the automatic recovery backup. Before replacing the save, a timestamped `.before-reset-*` recovery copy is preserved separately; it is not loaded automatically. Reset is unavailable during combat.

Quick Attack tracks a moving opponent within its original 320-unit reach and deals one contact hit along its zigzag path. Capturing a wild Pokemon throws the ball from the trainer hand to the opponent.


## Roost and Kanto exploration

Roost retains its arena healing and removes Flying from the user's effective types for 1.5 combat seconds. Dual types keep their other type; pure Flying becomes Normal temporarily. Damage, STAB, immunity, terrain movement and the type HUD use the effective types. Expiry or withdrawal restores Flying without modifying species data. Committed attacks keep their launch-time offensive snapshot.

Adventure now connects all ten Kanto towns/cities plus Indigo Plateau across 57 compact maps. Added Saffron, Vermilion, Lavender, Celadon, Fuchsia and Cinnabar, with Centers, shops, resident guides and distinct landmark exteriors. New routes contain level 18-27 wild Pokemon. The current level cap is 100.

After Misty's Cascade Badge, follow the signed exits from Cerulean; **M** or the pause menu opens the Kanto guide with current connections. Other links return through Pallet and Viridian. North/south exits are at the central path; east/west exits use the lower crossroad. This is a compact adapted layout, not a tile-for-tile FireRed map. Sea routes currently use walkable ferry paths without an HM requirement. Town healing points persist and are used after defeat. Existing saves keep their map IDs and progress.

New landmarks are exterior exploration areas: building interiors, Safari gameplay, Silph/Tower/Mansion quests and the later Adventure gym/League campaign are not yet implemented. All gym leaders and the Elite Four/Blue remain available in the separate Gym Leaders mode.

Location reference: [FireRed/LeafGreen Kanto world map](https://pokedream.com/games/fireleaf/worldmap/index.php).


## Custom battle moves and area attacks

In Free Battles and the Gym Leaders team builder, click a move in the lower Pokemon detail card to open its scrollable dropdown. Defaults are unchanged until edited. Choices include recorded level, machine, tutor, egg and event moves across generations, inherited pre-evolution moves and the existing arena defaults. This is an unrestricted cross-generation sandbox, not a single competitive-format legality checker. Duplicate moves in a set are disabled. Reset restores that Pokemon's four default moves.

Selections persist in `user://battle-moves.json` per side, team slot and species, separately from Adventure learned moves and inventory. Free Battles allows editing both custom teams; Gym Leaders edits your team while retaining the original opposing trainer moves. The added catalog uses the existing real-time move adaptations; not every cartridge-specific special rule has a dedicated implementation.

Ice Beam now has a 20-unit half-width (previously 48). Earthquake expands from the cast position to a radius of one fifth of the playable arena width. Whirlpool creates a fixed 2.5-second vortex around the cast position, radius one sixth of that width, dealing one contact hit and pulling affected opponents inward at up to 165 units/second. Circles show their damage/pull boundaries.

Fly skips the old stationary charge: the Pokemon rises, tracks the opponent during its first 0.6 seconds, locks a 115-unit landing circle, then dives at 1.5 seconds. The target can leave the marked area to dodge. The caster cannot move, switch or attack while airborne and avoids normal incoming hits. Committed impacts still resolve after caster fainting.

`node tools/build-battle-learnsets.mjs` rebuilds the 158-species move catalog from the checked-in source data. Adventure learnsets remain separate.


## Dig, Whirlpool eruption and opponent substitutions

Whirlpool now warns for 0.55 seconds, then erupts in upward water jets while its spiral pulls inward. Its radius is one sixth of playable arena width; Earthquake uses one fifth. Whirlpool rolls a 30% chance of 0.4-second flinch once on a successful hit, never each frame.

Dig uses a 1.5-second underground phase, with a locked emergence warning like Fly. Most hits and targeted statuses miss underground, and sand/hail damage is avoided. Earthquake and Magnitude hit for double damage; Fissure can also connect (retaining this game's adapted damage). Abilities/Lock-On exceptions are not simulated. The source rule reference is https://bulbapedia.bulbagarden.net/wiki/Dig_(move).

Opposing trainers/custom teams may make at most three voluntary substitutions per battle. They look for healthier or better attacking matchups, initially after eight combat seconds, then wait 12-20 seconds between successful changes. They cannot switch while trapped, underground, airborne, charging, or while committed attacks remain in flight. Recall/send-out pauses combat. Reserves retain HP, energy and major status; all four move cooldowns reset on arena entry; withdrawal clears stat stages and volatile effects. Forced replacements after fainting do not consume the three-change budget. The fight ends only when the whole enemy team is exhausted, including earlier members who withdrew. Wild single-Pokemon battles cannot switch.

Adventure main progression now reaches all eight badges and Champion Blue, with saved Hall of Fame, key-item quests and the League gauntlet. Interiors are compact functional areas, ready for the later art/encounter pass. The separate Gym Leaders mode already includes the full leader/Elite Four/Blue challenges.


### Adventure chapter 3: Bill, S.S. Anne and Lt. Surge

Story now continues beyond Misty to the third badge. From Cerulean take the west exit to Nugget Bridge, then north to Bill. His ticket admits S.S. Anne via Vermilion's north exit; beat Blue and speak to the Captain for the Cut field tool. Enter Vermilion Gym to the west, solve the two-switch puzzle, and defeat Surge. Key items appear in the Bag and all progress persists in existing saves. New maps add no wild encounters and do not alter grass/cave encounter behavior. See [the Adventure roadmap](docs/adventure-roadmap.md) for the exact current scope, adaptations and remaining Kanto chapters.


### Full Kanto progression / 57 areas

Continue beyond Surge through Celadon/Erika and Rocket Hideout, Lavender Tower/Fuji, Fuchsia/Koga and Safari field tools, Silph Co./Sabrina, Mansion/Blaine, Viridian/Giovanni, Victory Road, Elite Four and Champion. Additional landmarks include Seafoam, Power Plant, Diglett's Cave, the Underground Paths, Route 2/10/11 connectors, Cinnabar Lab, Cerulean Cave and Hall of Fame. Approach labeled entrance markers and press E; M lists connections and requirements. Existing saves are preserved.

The level cap is 100 with all Gen I level-based evolutions. League health persists between trainers; defeat or leaving the chambers resets the current run. Winning saves the party in the Hall of Fame. Existing wild encounter mechanics/tables are unchanged. New interiors use simple layouts and reused artwork; original multi-floor puzzles, graphics upgrades and random/legendary encounters are deferred. See [current scope and route](docs/adventure-roadmap.md).


### Shinies and passive abilities

Adventure now assigns persistent normal ability slots (equal odds) and shininess (FireRed base rate 1/8192). All 158 species have shiny animations and a brief send-out sparkle. In Free/Gym setup, click ABILITY below the moves to select a legal normal ability for that team slot. Existing Adventure saves are retained. This is the FRLG ability roster, without Hidden Abilities; passives for doubles, held items or deferred encounter systems remain contextual. See [rules, adaptations and sources](docs/shinies-and-abilities.md).


### Canonical Kanto overworld (current)
Adventure now renders 256 FireRed map layouts: towns, routes, building interiors, caves and League rooms. Walk with the existing movement bindings/right click; approach doors, stairs, trainers or visible wild Pokemon and press the interact binding (default E). M lists local connections. No random grass/cave encounters or trainer sight-trigger encounters were added.

Existing saves migrate to a walkable position in their corresponding area. Subsequent saves retain the exact map/floor and coordinates. Existing campaign quests, badges, gifts, party, bag, shininess and abilities are retained. There are 288 imported trainer placements with parsed FireRed party species/levels, alongside the existing campaign encounters; battle moves continue to use this game's level-aware loadouts.

This is a spatial/art conversion, not a full FireRed event-engine port. Story dialogue, quest consoles and League progression remain adapted; conditional NPC visibility, ledge rules, movable boulders, animated map tiles, elevators and cartridge-specific scripted puzzles are not faithfully reproduced yet. Original script-only or conditional battles are not all imported. Trade/link rooms and Sevii are outside this map set. Existing visible wild encounter tables are retained rather than replaced with FireRed random tables.

Map provenance is recorded in assets/kanto/source.json. Rebuild with tools/import-kanto.py after placing the pinned pret/pokefirered checkout under data/source/pokefirered (ignored by Git). Runtime builds include compiled images and JSON, not the source checkout. Use --capture-world for canonical-world screenshots; --capture-kanto retains the legacy preview utility.


### Kanto events and physical puzzles
The canonical overworld now has a persistent event layer. Press E beside bins, statues, card doors, items and boulders. Event geometry uses the original FireRed metatiles and changes both artwork and collision.

- Vermilion: 15 bins, randomized first switch and adjacent second switch; a wrong second choice resets the locks. The electric barrier physically opens.
- Cinnabar: six original quiz topics; correct answers or victories over their trainers open the corresponding doors. Incorrect answers initiate the associated trainer battle.
- Saffron: use the actual warp-pad layout to reach Sabrina instead of the former two-button shortcut. Koga's invisible walls retain the map collision.
- Silph Co.: find the Card Key on 5F and unlock individual doors; their states persist. Elevators in Silph, the department store and Rocket Hideout have floor selection; Rocket's lift needs its key.
- Rocket Hideout: the Game Corner poster reveals its entrance; directional tiles force movement, and the B4F guards control Giovanni's barrier. The lift-key grunt awards the key on victory.
- Mansion: statue switches alternate the original door sets across floors; the Secret Key is a map pickup.
- Victory Road: push boulders with Strength onto the original floor switches to remove barriers. M resets a room's boulders while retaining completed switches.
- Seafoam: boulders fall into the lower floors through the original holes. Two boulders calm each current and apply the original stopped-current layout. M explicitly resets ALL Seafoam boulders/currents together to recover from a bad push.
- Field/story events: Cut trees, Surf water access, Oak's parcel delivery flag, sleeping Snorlax/Poke Flute battle and catch, Bill/Captain placement, defeated overworld trainers, and usable item/TM/key pickups persist. Unsupported item kinds remain visible and explain that they cannot be used yet.
- Elite Four/Champion battles now use their separate rooms; victory unlocks the next chamber and leaving resets the current run. Hall of Fame requires the Champion title.

This is still an adapted event system, not an interpreter for every FireRed script. Cinematic sequences, all incidental NPC dialogue/visibility conditions, ledge jumps, fossil revival, every original item effect and the exact Victory Road falling-boulder sequence remain unfinished. Existing campaign party presets and several quest requirements are retained. Random encounters and sight-triggered battles remain disabled.

Rebuild event assets with tools/import-kanto-events.py (also refreshes base maps). Event regression checks run with --smoke-test; --capture-events renders Surge's barrier before/after. Source remains the pinned pret/pokefirered revision in assets/kanto/source.json.


Adventure walking uses cardinal tile-to-tile steps (including right-click movement); sprint changes the step speed. Battle movement is unchanged. Face an NPC and press E to talk across a single original counter tile, including the Center nurse and Mart clerks. Interaction prompts use the same counter reach rule.


### Automatic travel, scenes and player-triggered wild searches (current)
Doors, stairs and warp pads now activate when stepped on; blocked door graphics also accept walking into them. Arrival is latched until the player leaves that tile, preventing immediate return loops. Ordinary map entry has no dismiss-to-continue dialog. Interaction pressed during a walking step is buffered until the tile center.

Normal overworld trainers use their imported facing direction and sight distance, reject obstructed paths, show an alert, approach, then start the existing arena battle with their existing party. Defeated trainers retain their saved flag. Gym leaders and story quest characters still have their own interaction rules. Roaming trainer rotations are not simulated yet.

Wild encounters are ONLY requested by the interact binding (default E) in grass, surf water or eligible cave floor tiles. Walking alone never rolls a wild battle. The old visible wild markers are removed. FireRed land/surf slots, slot weights and level ranges are exported for 66 Kanto maps by tools/import-kanto-encounters.py; explicit E replaces the cartridge's per-step encounter chance. Fishing/rock-smash encounters are not added. Shininess, abilities, catching and arena combat keep their existing rules.

Timed, skippable scenes now cover Oak's warning/escort and lab introduction, Bill's transporter, the Captain's Cut reward, Fuji's rescue, the Silph President and Hall of Fame, plus trainer approaches. Dialogue advances automatically; Enter/interact advances a line, Esc skips to the outcome. Story completion flags persist; the scene layer is cleaned up when leaving the application. These are adapted in-engine scenes, not every original FireRed cinematic or NPC script. Use --capture-scenes for the trainer alert/approach preview.
