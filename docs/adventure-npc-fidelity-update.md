# Ordered NPC dialogue — 2026-11-16

The ordinary NPC/sign dialogue layer now executes ordered commands from the pinned FireRed source, including calls, conditional jumps, flags, comparisons, gender/facing, item/money checks, Yes/No and multiple-choice menus. It replaces the unsafe generic rule that awarded the first gift mentioned in a script without evaluating its prerequisites.

The compiler accepts **693 source object/background-script entry points**. It records 918 other source entries separately: battles, item pickups, shops, cutscenes, puzzles and engine-specific services retain their dedicated handlers or text fallback. These are source-wide counts, including excluded multiplayer/prototype maps; they are not counts of broken or fully recreated NPCs. This bounded executor does not make the whole FireRed script engine complete.

Working examples include Route 1's Potion, Mr Psychic's TM29, the Fan Club chairman and Bicycle exchange, Old/Good Rod choices, Oak's five aides, Celadon's Tea, the department-store vending machines and all three drink/TM exchanges, Game Corner coin gifts, Memorial Pillar, the school notebook/blackboard and Cerulean's badge guide. The ordinary Game Corner and Safari information NPCs no longer all open service menus. Existing source story/battle/service handlers keep priority.

Gift, consumption and completion flags are staged together. Closing a choice follows its original No/Exit branch. Interrupted conversations cannot leave a partial reward, and expired button callbacks are ignored. A full pocket restores the current exchange's input items and flags; earlier successful purchases in the same vending session are retained. This item-loss protection is deliberate: the cartridge Thirsty Girl script removes the drink before checking reward capacity.

Existing generic-gift and aide completion markers are recognized. No save reset is needed. Temporary conversation flags reset on map/slot changes. Persistent source variables are validated. Source HM references still unlock this project's field tools, with the existing badge requirements; Fly and Surf retain their learned-move requirement. Drinks use the arena's percentage healing.

Verification: every supported entry point is exercised in initial and advanced story fixtures (1,386 executions), plus affirmative/refusal/cancellation, bag-full retry, purchase costs, exchange consumption, old-save migration, real-map NPC routing and post-story dialogue tests. The broader story and smoke suites also run. These checks are automated and do not constitute an uninterrupted manual playthrough of the full campaign.

Reproduce: `python tools/import-npc-programs.py --check`, then Godot `--headless --path . --script tools/check-npc-programs.gd -- --qa-npcs`. Add `--qa-render` without `--headless` to capture the choice panels. Diagnostic captures are ignored by Git.
