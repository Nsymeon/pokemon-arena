# Protection, healing and team support

Arena balance values (real-time seconds, not turn durations):

- Protect and Detect block incoming hits and hostile status for 1.5 seconds. Both share a 12-second cooldown on the same Pokemon. First attempt succeeds; successive successful uses reduce the next chance to 1/3, 1/9, 1/27, etc. A failure, another move or switching out resets the sequence. Waiting alone does not reset it. The HUD shows the next chance. Existing poison/burn and weather damage continue.
- Each direct healing move has 5 PP per Pokemon per battle, shown on its move card. Switching preserves PP; a new battle restores it. These are arena balance values, not a complete cartridge PP system. Damaging drain moves do not spend healing PP.
- Healing casts root the user for 1 second; drain moves also root the user when healing on hit. Switching cannot bypass this root. Passive residual healing does not repeatedly root the user.
- Reflect halves physical damage; Light Screen halves special damage. Aurora Veil covers both and requires hail/snow to activate. Combining screens does not stack their reduction. Fixed damage bypasses screens.
- Safeguard prevents incoming major status and confusion. Mist prevents opponent-inflicted stat drops. Tailwind doubles movement speed. These effects, Reflect, Light Screen and Aurora Veil each last 60 seconds of active battle, persist across switches, and end when the battle resets. Recasting refreshes the duration.
- Each active team effect has a colored spherical outline and remaining time around the active Pokemon. Actual stat stages have separate bright positive or dark negative orbs, with the stat and signed stage number. Screens reduce damage directly rather than granting extra defense stages.

Validation: the regular --smoke-test suite includes deterministic Protect probability checks, blocked hits/status, expiry, screen categories, side isolation, switch persistence, Mist/Safeguard, healing PP exhaustion and reset, and the healing movement lock. --capture-support renders the combined shield/stat/HUD scene into captures/team-support.png.

Mechanics references: [Protect](https://pokemondb.net/move/protect), [Reflect](https://pokemondb.net/move/reflect). Durations, healing PP and cooldowns above are specific to this real-time game.
