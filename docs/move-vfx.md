# Move effects

The arena now resolves every move in the 601-move battle catalog to a visual
family. Explicit move identities take priority over physical action names,
move kinds and elemental types. Adventure uses the same renderer. This is an
anime-inspired procedural treatment, not 601 individually reproduced anime
animations. Species-specific mouth, bulb and hand attachment points remain
approximated by body position and facing direction.

Recognizable treatments include serrated spinning Razor Leaf blades, paired
Vine Whip vines, translucent Bubble/Bubble Beam spheres, separate Ember flames,
the Fire Blast fire figure, faceted ice shards, pointed Poison Sting needles,
blue Aura Sphere energy, hypnotic waves, powder clouds, webs, sound waves with
notes, teeth, fists, boots, slash arcs, hearts, stars, healing sparkles and
hexagonal protective barriers. Weather casts have sun/rain/snow/sand motifs.
Other moves inherit their action or elemental family rather than an unrelated
generic projectile. Impact fragments use the original move's family too.

Existing dedicated mechanics and effects remain for beams, Surf, targeted
lightning, Earthquake, Fly, Dig, Whirlpool and tracking rushes. Beam charge
indicators now use their move's color and width. No changes to damage, reach,
collision radius, status duration, energy costs or attack timing were made.
Decorative trails/fragments are not additional damage zones.

## Simultaneous attacks

The sprite frame selector previously let a damage flash choose Hurt even while
Attack/Shoot was playing. Attack/Shoot now keeps priority for its full playback;
damage still flashes the sprite and Hurt plays normally outside attacks. Every
fighter/projectile/impact has its own timer and move data; rendering never
advances another effect's timer. Smoke tests compare both fighters' texture and
frame before/after a simultaneous hit and verify the normal Hurt fallback.

## References

Anime appearance descriptions used as visual references (adapted, no artwork
copied):

- [Razor Leaf](https://bulbapedia.bulbagarden.net/wiki/Razor_Leaf_%28move%29)
- [Vine Whip](https://bulbapedia.bulbagarden.net/wiki/Vine_Whip_%28move%29)
- [Water Gun](https://bulbapedia.bulbagarden.net/wiki/Water_Gun_%28move%29)
- [Ember](https://bulbapedia.bulbagarden.net/wiki/Ember)
- [Hypnosis](https://bulbapedia.bulbagarden.net/wiki/Hypnosis_%28move%29)
- [Ice Shard](https://bulbapedia.bulbagarden.net/wiki/Ice_Shard_%28move%29)
- [Bubble](https://bulbapedia.bulbagarden.net/wiki/Bubble)

## Verification

`--headless --path . -- --smoke-test` includes regression coverage for attack
frame priority and key move classifications, alongside existing combat tests.
`--path . res://tools/vfx-gallery.tscn` renders every catalog move's cast,
projectile and impact at three ages (5,409 drawing combinations). It saves
three representative contact sheets under ignored `captures/vfx-*.png`.
The gallery intentionally draws all three stages even for self-target moves
that never create a projectile during gameplay, to exercise renderer branches.
