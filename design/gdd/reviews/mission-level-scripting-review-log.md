# Mission & Level Scripting — Review Log

## Review — 2026-04-24 — Verdict: APPROVED (post-revision; accepted on author confidence per user decision)

**Initial verdict (pre-revision)**: MAJOR REVISION NEEDED
**Final verdict (post-revision)**: APPROVED — accepted without re-review per user choice; revisions applied in-session.
**Scope signal**: XL (multi-system save assembler + section authoring contract + mission state machine + scripted comedy taxonomy; 11 upstream + 7 downstream + 6 ADR deps + 16 pre-impl coord items)
**Specialists consulted**: game-designer, systems-designer, qa-lead, narrative-director, level-designer, ai-programmer, economy-designer, performance-analyst, godot-specialist, creative-director (synthesis)
**Review depth**: full (all 9 specialist agents + creative-director senior review)
**Blocking items at review start**: 16
**Recommended items at review start**: ~18
**Prior verdict resolved**: First review (no prior log)

### Summary of key findings

The pre-revision GDD was structurally coherent at the systems level but had three root causes producing many surface findings: (A) the GDD enforced what is cheap to grep rather than what matters to the player (e.g., F.4 budget contradiction CI'd numbers but missed blocking-call topology; pillar-5 markers grep'd while spatial cache distribution was advisory); (B) systems were designed for content that did not yet exist (3-deep supersede cascade for non-existent alt-routes; F.7 latch coordination against an unwritten F&R save format; ADR-0007 slot #9 against an unwritten amendment); (C) Pillar 1 was treated as an absence (no UI) rather than a presence (legibility) — the Player Fantasy promised diegetic deduction but the 5-section linear pipeline encoded no navigational legibility. Three independent specialists converged on F.7/OQ-MLS-2 as a hard MVP blocker; F.4 was mathematically inconsistent (6 × 1.0 ms cap vs 5.0 ms ceiling); AC-MLS-12.2 self-contradicted with §C.8 FP-8; and `@export Callable` on a Resource was engine-incorrect for Godot 4.6.

### Revisions applied (16 BLOCKING items resolved)

1. **Navigation/Discovery problem (game-killing)** — added new **CR-21 Discovery Surface guarantee** and new §C.9 Discovery Surface Catalog with per-section diegetic clues for Sections 1–4; added BLOCKING CI rule on `discovery_surface_ids: Array[StringName]` section-root export. Closes Pillar 2 navigation gap.
2. **F.7 type ambiguity / OQ-MLS-12** — closed as `Dictionary[StringName, bool]`; CR-6 step-ordering revised; new AC-MLS-14.7.
3. **F.4 budget contradiction + "off per-frame clock" misstatement** — reconciled to per-system 1.0 ms binding with derived 6.0 ms chain ceiling + disk I/O (2–15 ms HDD) + 21 ms total < 33 ms fade window. Honest framing: chain consumes the fade frame's budget (NOT exempt).
4. **`@export Callable` engine-incorrect** — switched to `completion_filter_method: StringName` pattern in CR-18.
5. **ADR-0007 slot #9 forward-claim** — CR-17 reframed as forward-pending; explicit BLOCKING gate on bundled amendment.
6. **ADR-0002 alert_state_changed amendment** — added as coord item #16 (frame-zero blocker).
7. **AC-MLS-12.2 ↔ FP-8 contradiction** — FP-8 promoted to scope-aware grep CI; OQ-MLS-9 closed.
8. **F.1 vacuous-truth softlocks** — CR-18 load-time validation; new AC-MLS-2.6 (cycle detection) + AC-MLS-2.7 (vacuous truth).
9. **F.3 severity/AlertState terminology bug** — variable renamed to `alert_state`.
10. **CR coverage gaps (CR-8, CR-11, CR-19)** — new ACs AC-MLS-14.1, 14.2, 14.3.
11. **Section Authoring Contract extraction** — deferred to a separate session per user decision; coord item #12 added; in-place pointer note in §C.5 header.
12. **Section passivity grep wrong syntax** — fixed pattern to match Godot 4.x `.emit()` AND legacy `emit_signal()`.
13. **Empty Biscuit Tin → T1 placeholder** — replaced T3 anchor with placeholder T1 "Foreman's Lunch Inventory"; OQ-MLS-13 created for narrative-director sign-off.
14. **CR-14 absolute → default disposition** — demoted FP-3 to advisory; authorized 2 deadpan + 4 non-verbal Eve cues; new AC-MLS-14.8 + revised §G.7.
15. **Cache CI inversion** — promoted pistol-per-section-max + 10 m off-path + SectionBoundsHint AABB to BLOCKING; OQ-MLS-4 closed.
16. **Starting reserve audit (cross-system Inventory)** — added as coord item #13.

### Recommended/soft revisions also applied

- T6 same-frame N-fire bound (per-frame=1) in §C.4 + AC-MLS-14.6
- Plaque Debate forced sightline composition requirement
- Luggage Tag ↔ logbook narrative connection
- Parfum locked-door cinematic blocker + absurdist core
- AC-MLS-3.3 rewritten (drop 5s wall-clock)
- AC-MLS-4.3 rewritten (Jolt-tunneling absence test)
- AC-MLS-5.2 legibility definition (≥48pt at 2 m)
- AC-MLS-9.1 retagged Integration
- `find_child` `owned=true` direct-child-only specified
- Save timing AC added (AC-MLS-14.5)
- ADR-0006 Triggers layer + Jolt body_exited citation added as coord items #14, #15

### Open / cross-system blockers (NOT resolved by revision — require external work)

- **OQ-MLS-2** — F&R `triggers_fired` capture in dying-state save (F&R + save/load coord)
- **OQ-MLS-3** — `_is_section_live` guard (implementation-decision OQ)
- **OQ-MLS-6** — MLSTrigger self-passivity (implementation-decision OQ)
- **OQ-MLS-13** — Lower Scaffolds final dialogue (narrative-director sprint)
- **Coord item #1** — ADR-0007 amendment (slot #8 F&R + slot #9 MLS bundled)
- **Coord item #14** — ADR-0006 Triggers layer amendment
- **Coord item #15** — ADR-0006 Jolt body_exited citation
- **Coord item #16** — ADR-0002 alert_state_changed 4-param amendment
- **Coord item #12** — Section Authoring Contract extraction (separate session)
- **Coord item #13** — Starting reserve audit (Inventory amendment + playtest)

### Stats

- Doc length: 834 → 890 lines (+56)
- ACs: 53 → 63 (+10; was self-reported as 50, recount during review revealed 53)
- BLOCKING ACs: 42 → 51 (+9)
- ADVISORY ACs: 11 → 12 (+1)
- Core Rules: 20 → 21 (added CR-21 Discovery Surface)
- §C.5.6 BLOCKING CI rules: 12 → 16 (+4 promotions: Discovery Surface, pistol per-section max, pistol off-path 10 m, SectionBoundsHint AABB)
- Open Questions: 12 → 13 (closed 9, 12; obsoleted ANIM-1; added 13)
- Pre-impl coord items: 11 → 16 (+5: contract extraction, starting reserve, ADR-0006 ×2, ADR-0002)

### Sign-off

User accepted revisions without independent re-review per /design-review post-revision widget choice (option B). Three ADR amendments and 4 cross-system coord items remain BLOCKING for sprint start. F&R coord item #11 was previously closed by MLS authorship; remains closed.
