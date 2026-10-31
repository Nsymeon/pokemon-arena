# Route 22 and reference-driven terrain pass

- Route 22's three original x=33 approach lanes now launch the early Blue scene. His party is Pidgey 9 plus the starter strong against the player's starter, level 9. A victory persists the trainer completion flag; losing permits another attempt. The inert source Blue object is hidden, leaving a single animated scene actor.
- Original Boulder through Earth checkpoint coordinates are exported to badge-checkpoints.json. Movement into a checkpoint checks the corresponding badge. Both warps and outdoor connections apply entrance requirements; Route 23 requires Boulder, Victory Road/Indigo require eight badges, and the existing Elite Four progression requirements remain.
- Visual fences must occupy source-blocked cells. Expanded horizontal/vertical fence recognition does not change source collision. Cerulean stair tiles are explicitly scoped to that city because secondary tileset indices are not global.
- Waist-high Cut saplings, deeper green layered foliage, blue water with subdued reflections, continuous turf-topped brown cliff faces, warm wooden fences, silver stair treads and mottled outdoor ground follow the supplied BDSP reference palette.

Validation: check-adventure-fixes.gd covers Blue, badge denial/acceptance, source collision for every rendered fence, and previous interaction regressions. check-kanto-3d.gd builds all 392 maps and captures representative scenes without modifying the player's save.

Art status: this remains procedural geometry, not a 1:1 BDSP recreation. NPCs retain the existing chibi rigs. Full landscape elevation, bespoke rock/leaf textures, and reference-quality character art remain unfinished; the cliff caps and architecture are still simpler than the supplied image.
