# Campaign and puzzle verification — 2026-11-18

Two progression faults found during the continuous campaign check are corrected:

- The first rival fight in Oak's lab now advances after either victory or defeat. Oak heals the party in place; losing does not charge a blackout fee or send the player home. This follows the pinned FireRed tutorial battle's `HEAL_AFTER` behavior and `EndRivalBattle` script.
- Both Mt. Ember Rocket actors now resolve their nested source battle labels after Celio starts the Network Machine quest. Their original parties are imported, completed fights cannot repeat, and defeating both unlocks the Ruby cave/password progression.

The trainer import now contains **639 source builds and 729 script identities**. Map coordinates and original party definitions are unchanged.

## Automated coverage

`tools/check-campaign-journey.gd` progresses one fresh campaign through **50 battles and nine persisted checkpoints**, ending with Celio's completed Ruby/Sapphire network quest. It covers the opening, eight badges, major Rocket chains, Lostelle, Champion/Hall of Fame, 60 registered captures, National Dex and the Sevii ending. An additional branch checks the first rival defeat. Progression rewards use runtime handlers, and checkpoint state is serialized and reloaded.

`tools/check-puzzle-paths.gd` searches legal walking/pushing routes and replays **143 boulder pushes** through the runtime: Victory Road, Seafoam's two current barriers and Tanoby Key. It checks puzzle save persistence and Seafoam reset behavior.

`tools/check-puzzle-transitions.gd` passes **305 cases**, including all six Cinnabar quizzes on both outcomes, adjacent Surge switch combinations, **80 Silph Card Key doors**, Sabrina's warp network, all Dotted Hole choices, **nine Icefall tiles**, and a complete Deoxys triangle route within the step limits.

CI runs these three checks in order, generating its own isolated checkpoint files before puzzle verification. They do not depend on untracked local saves or the local source checkout. A failed assertion, engine script error or missing success marker blocks packaging and release.

## Scope and limits

The campaign harness moves directly between maps, finishes cutscenes programmatically and resolves battles. It proves the tested progression chain, not combat balance, uninterrupted traversal or every optional branch. The boulder solver proves selected complete solutions; it does not exhaust every possible puzzle configuration.

The isolated manual launcher, `tools/playthrough-qa.gd`, gives each session unique QA save files. The title/mode/save/avatar flow and bedroom were visually inspected. Further manual playthrough was interrupted through Computer Use's Escape stop. **A full manual fresh-save journey through the Sevii ending remains outstanding.** No full FireRed parity claim is made.

## Project cleanup

Removed approximately **839.82 MiB** of old portable builds, video-processing dependencies and disposable capture/log/cache files. Runtime assets, source code, Git history, the pinned reference source and player saves were retained. Small campaign checkpoints and current test logs remain in the ignored `captures/` directory.
