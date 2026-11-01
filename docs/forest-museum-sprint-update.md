# Forest, gym, museum and movement fixes

Trainer import now handles nested custom moves and bounds each party at the next declaration, including declarations whose closing braces share a line. Script lookup is scoped to individual labels. This restores Anthony's two Caterpie (7, 8), Liam and other missing Kanto trainers. Empty local IDs no longer cause unrelated gym trainers to be suppressed as duplicate quest actors. Non-battling forest guides remain civilians.

Battle sprint is a separate hold-only action, Space by default; Adventure run retains X and its toggle preference. Attack 2 defaults to E. Existing control saves migrate the former Space attack to an available battle key without sharing Space with sprint. The settings list exposes both actions. Controller RB holds sprint in battle and retains its Adventure behavior. Input tests cover press/release, stamina, preventing an accidental attack, and retaining the Adventure toggle.

Pewter Museum now has two fossil skeleton displays downstairs, meteorites and a shuttle upstairs. City building coverage includes the Celadon restaurant/hotel/condominiums, Vermilion Fan Club and museum wing. Indoor Safari/forest entrance rooms use interior rendering. Stairs, escalators and ladders use source behavior IDs as well as known interior tiles, and renderer indices are converted from JSON numbers before lookup. Adjacent door tiles share a doorway; Pokemon Centers and Marts use open framed glass entrances. Source collisions and warps are unchanged.

Validation: audit-world-followup.py checks 210 Kanto trainers, city interior destinations (excluding boundary gates/harbors/ship transitions), museum displays, stairs and ladders. check-adventure-fixes.gd verifies visibility and actual trainer battle initiation. check-battle-sprint.gd and check-controller-ui.gd verify movement and UI. check-kanto-3d.gd builds all 392 maps and captures museum floors. No player save is modified by these QA fixtures.

Visual limitation: the procedural museum models, interiors and terrain remain simpler than BDSP. These changes are not an exact recreation of its art.
