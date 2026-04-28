# Document Collection — Design Review Log

> Review history for `design/gdd/document-collection.md` (system #17, *The Paris Affair*).

---

## Review — 2026-04-27 — Verdict: MAJOR REVISION NEEDED → revision pass applied → APPROVED

**Scope signal**: L (multi-system coordination — LS callback contract change, ADR-0008 amendment, audio architectural clarification, writer brief deliverable, §G.1 cross-constraint enforcement, 8 BLOCKING AC fixes)

**Specialists consulted**: 8 + creative-director synthesis
- game-designer (8 findings — fantasy/Pillar adherence + tutorial doc tension + tonal register slips)
- systems-designer (8 findings — F.1/F.2/F.3 boundary-value math + §G.1 cross-constraint contradictions)
- narrative-director (8 findings — writer brief absence + Pillar 1 enforcement gap + Bomb Chamber climax)
- audio-director (10 findings — dead cross-references + dB semantic + Option A/B inversion + lifecycle gaps)
- level-designer (7 findings — Plaza Doc 2 fails F.2 + multi-strand path ambiguity + missing artifacts)
- performance-analyst (8 findings — F.1 estimates not measured + O(N) Big-O wrong + connection mode unspecified)
- godot-specialist (10 findings: 2 CRITICAL — LSS callback arity + null-deref + spawn-gate ordering)
- qa-lead (23 findings, 8 BLOCKING — test naming + tolerance + unblock + missing CRs/edge cases + regex)
- creative-director synthesis: MAJOR REVISION NEEDED with 10 BLOCKING items

**Blocking items**: 10 | **Recommended**: ~20

**Re-review status**: User accepted revisions without independent re-review (verdict acknowledged after revision pass; user judgment that all 10 BLOCKING items have been concretely addressed in this session).

**Summary**: First design review of Document Collection. Vision (Player Fantasy "Reading the Room", Pillar 2 patient-observer reward, Pillar 1 typographic comedy) is among the strongest in the project. Two engine-level defects (LSS callback arity 1-arg vs 3-arg + null-deref absent from pseudocode despite AC asserting it) were first-day-of-implementation crashes. §G.1 cross-constraints internally contradictory (off-path ratio cap 1.0 invalidated 3 structural anchor documents; per-section minimums summed below total minimum). Plaza Doc 2's "8–10 m" example failed F.2's 10 m off-path threshold. Writer brief entirely deferred to /localize time — Pillar 1 had no enforcement contract. Audio cross-references pointed to non-existent audio.md sections.

Revision pass resolved all 10 BLOCKING items in a single session: (1) CR-5/CR-6 + §C.6 pseudocode rewrites (DC no longer registers own LS callback; MLS orchestrates `dc.restore(state)`); (2) null-deref guards added symmetrically to spawn-gate + pickup handler; (3) F.1 worked example reconciled + O(N) Big-O corrected + AC-DC-9.4 wall-clock timing AC NEW; (4) §G.1 cross-constraint invariants added (off-path cap 0.86, Plaza min 3, per-section sum ≥ 15) + AC-DC-1.4/1.5 NEW lints; (5) Plaza Doc 2 distance 12–15 m; (6) §C.5.7 furniture taxonomy NEW + §C.5.8 DocumentBody.tscn template stub; (7) qa-lead's 8 BLOCKING AC items addressed (test file renaming, tolerance, BLOCKED-on removal, AC upgrades, NEW ACs for CR-17 + E.5, regex word-boundary fixes, evidence path correction); (8) writer brief authored as new file `design/narrative/document-writer-brief.md` (480 lines, 7 sample documents per category + 9-name clerk cast + canonical-fact registry + Bomb Chamber closing cross-references); (9) duplicate-discipline contract clarified vs ADR-0003; (10) audio cross-references corrected + dB semantic clarification.

**§F.5 coord items expanded 4+3 → 7+3 BLOCKING** (3 new MVP items: .tscn template / writer brief / MLS DC restore orchestration; audio dB clarification promoted MVP-blocking).

**CI lint count expanded 8 → 11** (cross-constraint lint #9 + tscn-template lint #10 + no-quest-counter aggregate-grep lint #11).

**Retired items**: VG-DC-2 (replaced by explicit duplicate-discipline contract in CR-6); VG-DC-3 (made obsolete by CR-5 restore-orchestration restructure).

**GDD growth**: 1,218 → 1,360 lines (+142 lines, +12%).

**New artifacts created**:
- `design/narrative/document-writer-brief.md` (NEW, 480 lines)
- `design/narrative/` directory (NEW)
- `design/gdd/reviews/document-collection-review-log.md` (THIS file)

**Prior verdict resolved**: First review (no prior).

**Next steps**: 7 BLOCKING coord items must close before MVP sprint kickoff (MLS GDD §C.5 amendment + ADR-0008 amendment + Localization Scaffold authoring guideline + Section-validation CI implementation 11 lints + DocumentBody.tscn template + writer brief author/review pass + audio.md dB-semantic clarification). 3 BLOCKING for VS sprint (MLS GDD §C.5 VS expansion + Document Overlay UI #20 GDD + HSS #19 GDD). Producer should treat as L-scope coordination work, not a tuning pass.

