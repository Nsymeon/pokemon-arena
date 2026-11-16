# Vs. Seeker — 2026-11-16

Receive the device from the woman in Vermilion's Pokemon Center. Walk 100 tiles to charge it, then activate it from Bag / Key Items outdoors. Defeated trainers within seven horizontal and five vertical tiles have a 70% acceptance check. Accepted trainers display a rematch marker; talk to one before walking another 100 tiles or leaving the map. Gym, cave and indoor use is refused. Obtaining the device never reopens a completed Gym.

The pinned FireRed source supplies 221 rematch ladders, including skipped progression slots and trainers who reuse their original team. A trainer's first unbeaten replacement team is capped by the Vs. Seeker gift, Celadon/Fuchsia visits, Champion and Celio's completed network. Exact species, levels, ordered moves, held items and trainer items use the existing source battle-builder. A win advances the corresponding ladder; a loss does not. Invitations are consumed on battle entry. Charge, invitations and trainer history are validated with the save; old saves acquire this state only when needed.

The response presentation uses markers and a message rather than the cartridge's original jumping animation. Source double battles still use sequential arena fights pending the separate double-battle implementation. No claim of completed stage 8 is made.

Validation includes all 221 ladders, first/advanced gated teams, 100-step charging/expiry, nearby acceptance, unbeaten-trainer exclusion, map exits, exact battle creation, consumed invitations, save round trips, invalid values, loss/win progression and completed-Gym protection. The import is reproducible with `tools/import-vs-seeker.py --check`.
