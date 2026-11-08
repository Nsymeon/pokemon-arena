# Adventure trainer fidelity — step 2 — 2026-11-08

Adventure now resolves ordinary map trainers and story battles to the pinned
[FireRed source](https://github.com/pret/pokefirered/tree/ce6406d8c2eaf46d543c8a2606de0c3cb1951982).
The importer reads `trainers.h`, `trainer_parties.h`, the FireRed branch of
`level_up_learnsets.h`, its species pointers, and source battle script labels.
No map coordinates, save data, quest rewards or economy values are rewritten.

## Coverage

- 639 concrete source builds (including rematch variants), with species, levels,
  held items, custom/default moves, trainer bag inventory and double-battle metadata.
  Unused placeholder macros without concrete members are excluded. This number
  is a definition count, not 639 newly playable trainer encounters.
- 727 direct source-script identities; all 443 existing map actors with trainer
  parties resolve through these identities. Ordinary battle completion keys remain
  unchanged, preserving defeated-trainer flags in existing saves.
- Seven Blue story chapters with three starter variants each; first Champion and
  rematch Champion variants. The source's placeholder rival name is displayed as
  Blue, matching this project's existing name.
- First and postgame Elite Four parties. The stronger League still requires both
  Champion status and completion of Celio's Network Machine.
- Rocket Hideout/Silph Giovanni, Nugget Bridge recruiter, Dojo master, Three Island
  bikers, Icefall Cave Rocket and Gideon. Existing compact-map placeholders resolve
  to named source trainers from their corresponding areas.

Custom moves are copied exactly in order, including fewer than four moves. For
default-move trainers, the importer follows `GiveBoxMonInitialMoveset`: scan the
species' ordered source learnset through its level, skip currently known moves,
and replace the oldest move when four slots are full. It does not substitute the
player's modern Free Battle pool. FireRed-only branch selection preserves cases
such as Dugtrio's starting move order. Existing normalized aliases are respected.

Dive, used by Lorelei's Cloyster and Painter Celina's Smeargle, was absent from
the Adventure move catalog. Source trainers now resolve it from the existing
battle catalog, preserving its existing arena behavior without adding an HM or
changing player move eligibility.

## Items and battle behavior

Gym and other source trainers share one finite bag implementation. Every fight
gets the original inventory; each slot can be spent once, with later slots
reserved according to the source's living-party condition. Switching cannot
replenish items. Potions use the same percentage healing as the player. Full
Restore is used below one-quarter HP and restores HP plus major status/confusion.
An item consumes an action and one second of movement recovery. It cannot be
used during send-out, switching, charging/recovery, Fly/Dig, a Surf ride, pauses,
menus or faint resolution. CPU item use never spends the player's bag.

Held items remain attached to individual enemy fighters. Sitrus already worked;
new support covers Black Belt's 10% Fighting boost and typed cure berries:
Cheri/paralysis, Chesto/sleep, Persim/confusion. Berries are consumed once and
respect Unnerve. Held Stardust/Nugget have no passive combat bonus. Source held
items are not silently added to shop inventories or the Free Battle selector.

## Compatibility and boundaries

- Existing saves need no reset. Gym rematch locks also apply to direct source
  Gym actor calls, rather than just the quest menu route.
- Daily fixed Lv.50 teams, player generation/build locks, Free Battle presets,
  wild encounters and the custom Champion Challenges/Battle Tower are separate.
- Stats, IV/nature/ability assignment, move power/effects, PP, status durations,
  sprint/dodges and switch limits retain the project's real-time adaptations.
- This imports source trainer builds, not the entire cartridge AI/script engine.
  Original double-battle rosters still appear sequentially in the existing arena;
  full two-versus-two combat remains its own step.
- Vs. Seeker rematch build data is present, but the complete rematch activation
  and progression system is not implemented by this update.
- NPC scripts, dialogue branches, rewards/economy and trainer presentation assets
  beyond the existing supported portraits remain later review areas.

## Verification

`python tools/import-adventure-trainers.py --check` recomputes the export from
the pinned source and compares it with the committed JSON. The Gym source check
continues to verify the separately maintained eight-leader data.

`tools/check-adventure-trainers.gd` starts all 443 map actor battles and checks
actual fighter species/levels, ordered moves, held items and trainer inventory.
It covers all rival/League starter and postgame variants, real story entry paths,
default-move spot checks, a live Dive cast, a normal trainer approach/completion,
AI Full Restore use, finite inventory across switches, typed berry activation,
Unnerve, Black Belt and isolation from other modes. `--qa-render` captures the
live League healing announcement. The regression runs in CI.

Additional checks: combat/save smoke suite, story/Daily progression, National
postgame, and the step-one Gym regression. Test saves are isolated and Adventure
saving is disabled for the source-party probes. These automated battles are not
a complete fresh-save manual playthrough or a difficulty/balance guarantee.

Next proposed step, pending user confirmation: NPC scripts, conditional dialogue
and one-time gifts/services.
