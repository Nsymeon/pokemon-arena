# Adventure Gym fidelity — step 1 — 2026-11-07

The eight Adventure Gym Leaders now have a separate, reproducible FireRed data
source. Old Free Battle trainer presets can no longer overwrite their builds.
No save reset or migration is needed; already-earned badges still prevent rematches.

Source: [pret/pokefirered at ce6406d8c2eaf46d543c8a2606de0c3cb1951982](https://github.com/pret/pokefirered/tree/ce6406d8c2eaf46d543c8a2606de0c3cb1951982),
`src/data/trainer_parties.h`, `src/data/trainers.h` and item-selection conditions
in `src/battle_ai_switch_items.c`.

## Source teams and finite trainer inventories

| Leader | Party in source order | Trainer items |
| --- | --- | --- |
| Brock | Geodude 12, Onix 14 | None |
| Misty | Staryu 18, Starmie 21 | Super Potion |
| Lt. Surge | Voltorb 21, Pikachu 18, Raichu 24 | Super Potion, Full Heal |
| Erika | Victreebel 29, Tangela 24, Vileplume 29 | Hyper Potion, Full Heal |
| Koga | Koffing 37, Muk 39, Koffing 37, Weezing 43 | 2 Hyper Potions, Full Heal |
| Sabrina | Kadabra 38, Mr. Mime 37, Venomoth 38, Alakazam 43 | 2 Hyper Potions, Full Heal |
| Blaine | Growlithe 42, Ponyta 40, Rapidash 42, Arcanine 47 | 2 Hyper Potions, Full Heal |
| Giovanni | Rhyhorn 45, Dugtrio 42, Nidoqueen 44, Nidoking 45, Rhyhorn 50 | 2 Hyper Potions, Full Heal |

Every source move is imported in order, with no filler for MOVE_NONE. Brock's
Geodude has Tackle/Defense Curl; Onix has Tackle/Bind/Rock Tomb. Erika's three
partners have their FireRed Giga Drain sets. None of these teams holds an item;
trainer bag inventory is separate from held gear. Full definitions are in
`assets/kanto/gym-leaders.json`.

## Real-time item rules

Leaders can spend an item instead of an attack at an AI decision. Potions trigger
below one-quarter HP or when missing more HP than the item restores. Later bag
slots are reserved while too many team members remain, following the source's
living-party condition. Each item slot is spent once for the whole fight, including
switches; a newly started battle gets a fresh inventory. Full Heal cures the
supported major statuses and confusion. Items cannot revive fainted partners.

Healing uses the same existing amounts as the player's bag: Super Potion 50%,
Hyper Potion 80%. It is capped at maximum HP. Use costs one second of action and
movement recovery, never launches a simultaneous attack, and grants no invulnerability.
Items wait during charging, attack recovery, Fly/Dig, riding a wave, send-out,
switches, pauses, menus and faint resolution. The player's bag is never charged.

This is an arena adaptation of item timing and healing, not cartridge turn-based
combat. Stat scaling, random Adventure IVs/natures, legal ability assignment,
status durations, move effects and the existing voluntary-switch limits remain
as before. Trainer prizes and the wider economy are a later step.

## Checks

- `python tools/import-adventure-gyms.py --check`: all eight imported teams,
  levels, ordered moves, absent held items and trainer inventories match the pinned
  source. Running without `--check` regenerates only the dedicated Gym JSON.
- `tools/audit-firered-runtime.gd`: independently compares actual spawned Gym
  parties with the source audit's expected data, including move order.
- `tools/check-adventure-gyms.gd`: real NPC battle entry, each live party slot,
  every source move attempted, finite item use through the AI, healing/cures,
  action gates, switching, source-data isolation, preserved Daily/Free teams and
  all eight badge locks after a save-data round trip. CI runs this test.
- Full combat smoke suite and story/Daily progression regression.
- Optional `--qa-render` captures Brock's battle and Misty's item announcement.

Tests use isolated runtime data with Adventure saving disabled. They do not
constitute a fresh-save manual playthrough or a difficulty/balance guarantee.

The next step requires the user's confirmation: remaining Adventure trainers'
original builds and inventories. No later fidelity step is included here.
