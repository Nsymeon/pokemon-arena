# Daily coverage and Surf balance

The daily player team is still six unique random Kanto Pokemon, seeded by the UTC date. Generation now rejects teams whose default moves leave a matchup without a practical offensive answer. The fixed opponent rosters and their existing moves are unchanged.

All 70 species in the daily pool have four reviewed legal moves in `data/daily-movesets.json`: useful STAB, coverage suited to their attacking stats, and support where appropriate. Ditto retains its Transform kit. These defaults are separate from Adventure learnsets, opponent presets and Free Battle choices.

A generated team must supply:

- Two different Pokemon with a reliable super-effective attack against **every individual opponent**, across all 13 trainers, including dual types and relevant ability immunities such as Levitate.
- At least eight offensive move types, two physical attackers and two special attackers. Mixed attackers may fill both roles.
- Six distinct species from the existing pool.

Coverage credit requires at least 60 base power / 23 arena damage, accuracy of at least 85 (or an always-hit move), no charge/recharge requirement, and an attacking stat at least 70% of that Pokemon's stronger offensive stat. The curated sets exclude sleep-dependent and other conditional damage moves. This checks available offensive answers, not a simulated guarantee of winning regardless of positioning, switching or player choices.

Move customization remains available. Daily edits are saved separately by date, side, slot and species, so Free Battle edits cannot silently remove the day's default coverage. Resetting a daily Pokemon's moves restores its coverage set; the next date starts with the new team's defaults.

Legacy daily saves are validated using the old generator and upgraded to team rules 2. Today's team is regenerated with coverage, while badges already earned that day and recorded Champion history are preserved. Normal midnight rollover still resets daily progress. Adventure saves are unaffected.

Surf's wave now travels **760 arena units instead of 899**, approximately 15.5% less. Wave speed, width, damage and rider behavior are unchanged. Travel is clamped at the endpoint even when the last frame is unusually long; rain increases width as before, without extending travel. CPU range selection uses the new distance.

Validation: `tools/check-daily-coverage.gd` checks 730 consecutive dates, independent matchup coverage, all legal movesets, instance determinism, species/team variety, actual save migration, Free/Daily customization isolation, spawned fighters and locked stats, unchanged opponent moves, and Surf's endpoint and hit detection on both sides in clear weather/rain. The sampled dates produced 730 distinct teams spanning all 70 species. This check also runs in the Windows release workflow.
