# Visual audit — 22 October 2026

## Verified

- All 601 battle catalog moves executed through the real `execute_move` dispatcher
  without runtime errors. Accuracy was forced to succeed for this emission test;
  combat accuracy remains covered separately by the smoke suite.
- All Adventure move IDs belong to that tested catalog.
- Cast, projectile and impact drawing ran for every catalog move at three ages.
  This verifies 5,409 renderer invocations, not 5,409 actual gameplay effects:
  self-target moves do not normally produce projectiles.
- Contact sheets were exported for the entire catalog; selected sheets were
  visually inspected, including the corrected blades, punches, tails and spins.
- Arena captures exercised dedicated beams, Surf, weather variants, targeted
  lightning, psychic attacks and rocks. Solar Beam, Surf and Thunderbolt images
  were inspected in this audit. Existing combat regression checks passed,
  including beam ranges, area boundaries, homing, faint persistence and recovery.

## Corrections

Leaf Blade and Solar Blade now use blades; Comet Punch uses fists. Meteor Beam,
Flash Cannon and Signal Beam use energy streaks instead of stars/solid shards.
Solar Beam and the Absorb family no longer inherit the generic Grass leaf effect.
Spinning attacks and tail strikes have separate cast motions. Tailwind no longer
matches the physical tail rule. Smokescreen, Haze, Mist and Clear Smog use smoke;
Rage Powder/Pollen Puff use clouds. Body attacks use a forward impact crescent
instead of claw scratches. These are visual changes, with no damage/range edits.

## What this does not establish

The catalog is visually covered, but it does not have 601 bespoke anime animations.
Many moves still share a type/action family. For example, Bonemerang still uses
the Ground fragment motif, Egg Bomb the seed motif, and Pay Day the Normal motif.
Those are functional placeholders, not confirmed authentic depictions. Exact
species-specific attachment points, all simultaneous effect combinations and
all camera/weather combinations have not been manually verified.

## Reproduce

- `--headless --path . -- --audit-vfx`: actual cast dispatcher; writes
  `captures/vfx-runtime.csv` (a copy is committed alongside this report).
- `--path . res://tools/vfx-gallery.tscn`: renderer coverage and contact sheets.
- `--path . -- --capture-skills`: dedicated arena skill captures.
- `--headless --path . -- --smoke-test`: combat and visual-family regressions.
