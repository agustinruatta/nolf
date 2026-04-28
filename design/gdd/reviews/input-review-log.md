# Input GDD — Review Log

This log tracks `/design-review` passes on `design/gdd/input.md` so future re-reviews can see what changed between sessions.

---

## Review — 2026-04-27 — Verdict: MAJOR REVISION NEEDED → Approved pending Coord items (revision pass applied inline)

**Scope signal**: XL (foundational system; 11+ downstream dependents; cross-GDD coordination required; ADR-0004 amendment + Proposed→Accepted promotion blocking; Pillar 5 framing rewrite)

**Specialists consulted**: game-designer, systems-designer, godot-specialist, gameplay-programmer, qa-lead, ux-designer, creative-director (senior synthesis)

**Blocking items**: 13 (all resolved inline)
**Recommended items**: 15 (all resolved inline)
**Nice-to-have items**: 5 (subset addressed; remainder deferred — non-blocking)
**Pre-implementation gates remaining (cross-doc)**: 3 BLOCKING — sprint cannot start until they close

**Summary of key findings (from creative-director senior synthesis)**:

> The single most damaging finding was a **3-way GDD contradiction shipping in three documents simultaneously**: Input GDD lines 90–91 ship shared `F` binding with Combat-as-router; Settings GDD CR-22 ships split (`takedown=KEY_Q`, `use_gadget=KEY_F`); Inventory CR-4 (line 121) reads `InputActions.TAKEDOWN_OR_GADGET` — a third name in neither catalog nor constants table. Senior ruling: **Settings CR-22 wins** — split bindings, two distinct InputMap actions, no router. Combat reads `&"takedown"` only; Inventory reads `&"use_gadget"` only. Inventory's `TAKEDOWN_OR_GADGET` deleted.
>
> The second-most-load-bearing finding: **`InputContext.LOADING` is missing from BOTH this GDD and ADR-0004 itself**. ADR-0004 enumerates `{GAMEPLAY, MENU, DOCUMENT_OVERLAY, PAUSE, SETTINGS}` — `LOADING` is referenced by Level Streaming (LS-Gate-2), Failure & Respawn (coord #4), and Mission Scripting as a required pre-impl gate. Without `LOADING`, every level transition guarantees input pass-through (Pillar 3 violation by construction). Requires ADR-0004 amendment.
>
> Compounding both: **ADR-0004 status is "Proposed", not "Accepted"**. Per project rules, stories citing Proposed ADRs are auto-blocked. ADR-0004 must be promoted Proposed → Accepted before this Input GDD can clear the sprint gate, even after the LOADING amendment.
>
> **Pillar 5 framing is overclaiming.** Number-key weapon slots (1–5), F5/F9 quicksave, and mousewheel cycling are 1990s-FPS conventions the Player Fantasy section explicitly disclaims (`"no radial weapon wheels, no mobile-style quick-action menus"`). Resolution: added "Period Authenticity Carve-outs" subsection naming each exception with diegetic justification — anchor *"the dossier names what your hands already know."* F5/F9 carve-out conditional on a diegetic dossier-register confirmation toast forward-dep on HUD Core (otherwise drops to menu-only saves).
>
> **StringName "compile-detectable error" claim (Core Rule 2) was false.** `&"action_name"` is a literal, not registry-validated. Retracted; replaced with the accurate weaker claim. AC-INPUT-1.2 grep heuristic acknowledges its own limitations.
>
> Verdict: **MAJOR REVISION NEEDED** because the revision could not fully complete inside this session. ADR-0004 must be amended and 4 GDDs touched (Input + Settings confirmed-as-owner + Inventory CR-4 + Combat CR-3). User elected to revise inline (Input only) and accept revisions without fresh re-review, deferring cross-doc work to a coordinated session. Status set to **Approved pending Coord items** — sprint cannot start until the 3 PRE-IMPL GATES close.

**User-adjudicated decisions (4 design choices made during inline revision)**:

1. **Cross-doc scope**: Input GDD only (defer Inventory CR-4 + Combat CR-3 + ADR-0004 amendment to coord session).
2. **Takedown adjudication**: Settings CR-22 wins — `use_gadget = KEY_F / JOY_BUTTON_Y`, `takedown = KEY_Q / JOY_BUTTON_X`. Two distinct InputMap actions, no router.
3. **F5/F9 fate**: Diegetic confirmation toast (~1.5s "Field log saved — 14:32") rendered by HUD Core in dossier register. Forward-dep on HUD Core.
4. **`pickup_alternate` / OQ-2**: Define `interact` priority queue precisely as a hard rule (document > terminal > item > door, tie-break by raycast distance) + add level-design constraint (no co-located targets within 1.5 m forward raycast). Close OQ-2; do not ship `pickup_alternate` at MVP.

**Structural changes applied to GDD**:

- **Header rename**: "Detailed Design" → "Detailed Rules" (project standard).
- **Player Fantasy**: New "Period Authenticity Carve-outs" subsection (number-key weapons / mousewheel cycling / F5+F9 each named with diegetic justification).
- **Detailed Rules**: Core Rules expanded 7 → 11. New: CR-8 mouse capture mode owner; CR-9 held-key flush on rebind; CR-10 `interact` priority hard rule + level-design constraint; CR-11 debug-action handler-gated registration mechanism. CR-2 retracted StringName "compile-detectable" claim. CR-3 expanded with canonical Context enum reference + LOADING gap note + "stateless" boundary clarification. CR-4 added `release_focus()` rule for `hide()` modals. CR-6 fenced `await` between erase/add. CR-7 added order-of-operations rule (consume before pop) for silent-swallow prevention.
- **Section C action catalog**: Group 3 Gadgets `takedown` row split (`KEY_Q / JOY_BUTTON_X`); `use_gadget` row updated to acknowledge dedicated action (no router). Group 2 Combat catalog updated with gamepad direct-slot parity flagged as Vertical Slice forward dep. Catalog header count corrected: "33 gameplay/UI + 3 debug = 36 actions". Binding-owner-of-record callout added pointing at Settings CR-22.
- **Edge Cases**: Added Esc silent-swallow during context transition / mouse mode lost after modal close / held-key rebind mid-hold (Vertical Slice).
- **Tuning Knobs**: Deadzone parameter index corrected (4th → 5th); radial vs per-axis note; Godot 4.6 default and safe-range failure modes documented honestly.
- **Dependencies**: New "Pre-implementation gates (BLOCKING for sprint start)" subsection enumerates the 3 cross-doc gates + 2 in-Input gates (closed in this pass). New "Forward dependencies (Vertical Slice scope)" subsection consolidates HUD Core toast / Inventory chord bindings / Settings rebinding UI + Hold-toggle accessibility + glyph swap + SDL2→SDL3 migration.
- **Cross-References**: Added Settings GDD CR-22 (binding-owner-of-record), ADR-0007 autoload load order, Inventory CR-4 PRE-IMPL GATE, Combat CR-3 PRE-IMPL GATE.
- **Acceptance Criteria**: Full rewrite. 16 → 25 ACs; 9 new (AC-INPUT-7.1/7.2/7.3 order-of-ops + mouse mode + held-key flush; AC-INPUT-8.1 LOADING context BLOCKED pending amendment; AC-INPUT-9.1/9.2 InputActions path + autoload load order; AC-INPUT-4.4 full rebind round-trip; AC-INPUT-10.1 quicksave toast; AC-INPUT-6.3 `_unhandled_input` enforcement). All ACs now carry story-type tags `[Logic]/[Integration]/[Code-Review]/[Config]` + exact test paths under `tests/{unit,integration}/input/` + exact CI grep commands under `tools/ci/`. AC-INPUT-2.1 rewritten (was AC #4 — scope-boundary violation testing Combat behavior; now tests Input's gate condition). AC-INPUT-4.2 split (Input scope vs Settings scope). AC-INPUT-1.3 corrected count to 36. AC-INPUT-6.1 grep extended to JOY_BUTTON_*/JOY_AXIS_*/MOUSE_BUTTON_*.
- **Open Questions**: 5 → 1. Closed: OQ-1 `use_gadget` priority (resolved by split); OQ-2 `pickup_alternate` (resolved by hard rule + constraint); OQ-4 sensitivity location (resolved by Player Character + Settings); OQ-5 `InputActions` location (resolved to `res://src/core/input/`). OQ-3 gamepad rebinding parity timeline remains, owner Producer.

**File size**: 278 → 343 lines (+65).

**Pre-implementation gates remaining (BLOCKING for sprint start)**:

1. ADR-0004 amendment to add `InputContext.LOADING` enum value + push/pop contract for Level Streaming / Save/Load.
2. ADR-0004 promotion `Proposed` → `Accepted` (2 verification gates from ADR-0004 itself: Godot 4.6 `Control.accessibility_*` property names; Theme inheritance property name).
3. Inventory GDD CR-4 amendment (drop `TAKEDOWN_OR_GADGET` ghost name, read `&"use_gadget"` directly in Inventory's own handler, acknowledge differentiated defaults per Settings CR-22).
4. Combat GDD CR-3 confirmation that `_unhandled_input` reads `&"takedown"` only (no router dispatch into Inventory).

(Items 1+2 are bundled as ADR-0004 amendment work; items 3+4 are cross-GDD touch-ups. All 4 must close before any sprint consuming Input can start.)

**Forward dependencies (Vertical Slice scope, not blocking MVP)**:

- HUD Core diegetic save toast (F5/F9 carve-out contract).
- Inventory & Gadgets gamepad direct-slot parity (chord bindings or held-modifier scheme).
- Settings & Accessibility runtime rebinding UI + Hold-to-toggle accessibility + dynamic glyph swapping + SDL2→SDL3 migration story for legacy `user://settings.cfg`.

**Prior verdict resolved**: First review — no prior verdict.

**Re-review recommendation**: Creative-director recommended fresh `/design-review` in a clean session before sprint planning. User elected Accept-without-re-review (consistent with recent project pattern: SAI 4th-pass, Combat 2nd-pass, Inventory, F&R). Producer should sequence ADR-0004 amendment → cross-GDD coord session → Input re-review (recommended even if optional) before sprint planning.
