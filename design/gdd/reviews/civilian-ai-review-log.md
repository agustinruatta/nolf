# Civilian AI — Design Review Log

This file tracks all `/design-review` passes against `design/gdd/civilian-ai.md`.
Future re-reviews append entries here so reviewers can track what was raised, what was resolved, and what carried forward.

---

## Review — 2026-04-25 — Verdict: MAJOR REVISION NEEDED → Resolved In-Session → Approved

**Scope signal**: L (multi-system integration; 11 upstream + 7 downstream + 6 ADR dependencies; 5 formulas; ADR-0008 amendment review required)

**Specialists consulted (8)**: game-designer, systems-designer, ai-programmer, qa-lead, performance-analyst, godot-specialist, audio-director, level-designer + creative-director (senior synthesis)

**Review depth**: full (default; user invoked `/design-review` without `--depth` flag)

**Blocking items raised**: 12 + 7 advisory coverage gaps (qa-lead) + 4 disagreements (cross-specialist)
**Recommended items raised**: 9
**Disagreements**: 4 (F.3 spike framing, cower-vs-flee, terminal panic, OQ classifications) — all adjudicated by creative-director

### Senior verdict (creative-director)

> "MAJOR REVISION NEEDED. The GDD is structurally complete and shows real rigor. But three things prevent approval: (1) the Player Fantasy as written is not delivered at MVP — the document does not acknowledge this; (2) multiple independent specialists found the same load-bearing implementation gaps (avoidance_enabled, animation name, panic_count target, F.3 framing) — when five specialists converge on the same defects, the document's confidence is unearned; (3) three OQs were mis-classified as ADVISORY when they gate VS Pillar 2, level-designer workflow, and a 3-4 week VO lead time. The good news: the revision is bounded. Eight to twelve BLOCKING items, most of them mechanical."

### Summary of findings

**Critical defects (multi-specialist convergence)**:
1. **`nav_agent.avoidance_enabled = true` missing from CR-1 / CR-8** (ai-programmer + godot-specialist) — Godot 4.x default is false; without this, civilians never move.
2. **Animation state name `panic-idle/cower` vs `cower` mismatch** (ai-programmer + qa-lead + godot-specialist) — `AnimationTree.travel()` silently fails on string mismatch.
3. **F.3 budget math dishonest about in-frame burst** (systems-designer + ai-programmer + performance-analyst + godot-specialist) — "non-frame cost analogous to save-write spikes" is wrong; signal dispatch is synchronous in-frame.
4. **`panic_count` rebuild reads non-existent `panicked` property** (audio-director + ai-programmer + godot-specialist) — needs public `is_panicked()` method.
5. **Cower-freeze liveness bug** (game-designer + ai-programmer) — when threat re-enters cower radius, civilian is permanently frozen.
6. **Player Fantasy gap at MVP** (game-designer) — schoolteacher anchor moment + BQA discovery + chorus recovery all require VS-tier; MVP delivers panic-only substrate.

**Per-specialist BLOCKING counts**:
- game-designer: 5 (Player Fantasy, terminal panic, BQA discovery, witness latch, cower visual)
- systems-designer: 2 CRITICAL + 3 HIGH (F.4 div-by-zero, F.3 spike, F.1 multi-floor, F.4 NavMesh snap, F.3 burst classification)
- ai-programmer: 6 BLOCKING (cower-freeze, avoidance_enabled, Phase 3 stacking, signal order non-determinism, LSS leak, F.3 dishonest)
- qa-lead: 7 ACs structurally invalid + 7 coverage gaps
- performance-analyst: 4 HIGH (RVO model, unverified C_per_civilian, AC false-green, panic-onset misclassification)
- godot-specialist: 18 issues; 5 BLOCKING incl class-resolver runtime order, NavMesh RID validity at restore, animation state name
- audio-director: 4 BLOCKING (cap saturation, no tween spec, Voice pool overflow, OQ-CAI-6 lead time)
- level-designer: 4 BLOCKING (panic_anchor SHOULD vs MUST, NavMesh bake order, per-section counts unspecified, OQ-CAI-5 misclassified)

### Resolution applied (in-session)

12 BLOCKING items resolved:

| # | Item | Fix |
|---|---|---|
| 1 | Player Fantasy honesty pass | §Player Fantasy rewritten with explicit MVP/VS/VS-tier-2 scope tier separation table; pillar mapping per tier; MVP playtest expectation note |
| 2 | Cower-freeze liveness bug | New CR-3a hybrid cower-exit rule (threat-leave 1Hz polling + 8.0s timeout via `$CowerExitTimer` child); two new state-machine rows; pseudocode for `_on_cower_exit_timer_timeout` |
| 3 | `nav_agent.avoidance_enabled` missing | New CR-1a "Required NavigationAgent3D initialization" with all 4 required properties; forbidden pattern #11 catches missing init |
| 4 | F.3 budget math dishonest | Complete F.3 rewrite. 4 cost components. Honest claim 0.30 ms p95 (revised from 0.15). Panic-onset spike allocated to ADR-0008 reserve with TD/producer sign-off. RVO O(n²) on 21-agent population not 8 |
| 5 | Animation state name mismatch | Consolidated to `cower` everywhere. Updated CR-8 + AC-CAI-5.4. Flee-speed reconciliation note added |
| 6 | `panic_count` rebuild non-existent property | New §C.0 "Public API surface" with `is_panicked() -> bool`; CR-10 updated; CR-0 also declares `FleeMode` enum |
| 7 | OQ-CAI-1/5/6 misclassified | All three reclassified ADVISORY → BLOCKING with reason text and revised resolution gates |
| 8 | F.4 div-by-zero + Phase 2 NavMesh snap target | `nav_map.is_valid()` guard; `raw_away.is_zero_approx()` guard; Phase 2 nav target uses `best_anchor_snapped` not `anchor.global_position`; section-scoped anchor filter |
| 9 | AC structural defects | AC-CAI-7.1 → Integration with constrained NavMesh ref scene; AC-CAI-8.1/8.2/8.3 → Config/Data with `tools/ci/lint_civilian_ai.sh` literal grep commands enumerated; AC-CAI-1.1 expanded to 8 explicit assertions; AC-CAI-5.4 locked to `cower`; AC-CAI-10.4 boundary semantics surface-to-surface |
| 10 | `FleeMode` enum undeclared | Declared in §C.0 |
| 11 | panic_anchor authoring gaps | §Overview locks Plaza 4-6 / Eiffel 4-6 / Restaurant 6-8; V.1 per-section count table with placed-vs-active distinction; CI must FAIL not warn at >8 simultaneously-active |
| 12 | LSS callback leak | CR-10 + CR-11 add `unregister_restore_callback` in `_exit_tree`; AC-CAI-3.4 verifies all 5 connections + LSS de-registration |

**Coverage gap ACs added (qa-lead)**: AC-CAI-2.8 (retarget nav update — GAP-1), AC-CAI-2.9 (invalid actor null guard — GAP-6), AC-CAI-3.4 expanded (velocity_computed disconnect — GAP-7), AC-CAI-5.5 expanded (positive movement assertion — GAP-3), AC-CAI-5.6/5.7 (cower-exit transitions). GAP-2/4/5 deferred as advisory.

**Forbidden patterns expanded**: 10 → 13. Refined #9 (mesh_instance_3d false-positive). Added #11 (missing avoidance_enabled init), #12 (`AudioServer` direct), #13 (`AudioStreamPlayer.new()`).

**Pre-implementation coord items**: 10 → 14 (added §F.5#11 flee-speed reconciliation, #13 Audio handler cost measurement, #14 AnimationTree CALM cost measurement, #15 VS alert_state_changed grep relaxation).

**File size**: 749 → 983 lines (+234, +31%)

### Disagreements adjudicated by creative-director

1. **F.3 spike framing** (ai-programmer "dishonest" vs performance-analyst "miscategorized" vs document "non-frame"): Resolution — specialists are correct, document is wrong, BLOCKING; reframe required.
2. **Cower-vs-flee bifurcation** (game-designer "looks broken" vs ai-programmer "is broken"): Resolution — same defect from two angles, both right; needs both design rule (cower exit condition) and implementation rule (`_maybe_retarget_flee` pseudocode).
3. **Terminal panic at MVP** (game-designer "Pillar 3 liability" vs document "scope-feasible"): Resolution — accept terminal panic at MVP IF Player Fantasy section names it as known degradation with VS commitment.
4. **OQ classification** (multiple specialists move OQ-CAI-1/5/6 → BLOCKING): Resolution — reclassify per departmental input.

### Acceptance decision

**User chose Accept + mark Approved without fresh re-review** despite creative-director's recommendation to re-review in a fresh session.

This is the **4th consecutive Accept-without-re-review** on this project (preceded by SAI 4th-pass, Combat 2nd-pass, F&R, Inventory).

CD validation criteria for the revision (NOT verified by re-review at user request):
- Player Fantasy section explicitly names what MVP delivers vs what VS delivers ✅ (verified by self-inspection)
- F.3 budget math reproducible from cited measurements, not assumptions — partial (formula reframed; measurements still pending OQ-CAI-3 engine-verify gate)
- Sprint start can begin without "to be resolved in pre-implementation huddle" load-bearing OQs — partial (OQ-CAI-5 reclassified BLOCKING for level-designer authoring start; resolution needed before sprint)
- Re-review by same specialists returns ≤2 disagreements (down from 4) — **NOT VERIFIED** (re-review skipped)

### Status after this review

**APPROVED 2026-04-25 post-revision pending coord items** (14 pre-implementation coord items, 5 BLOCKING OQs, ADR-0008 amendment review pending for revised 0.30 ms p95 sub-claim).

### Items carried forward

**BLOCKING for MVP sprint start**:
1. Coord item §F.5#1 — ADR-0002 amendment for `WitnessEventType` enum stub (atomic-commit per ADR-0002).
2. Coord item §F.5#2 — ADR-0008 amendment registering revised 0.30 ms p95 sub-claim + reserve allocation for panic-onset spike (producer + technical-director sign-off).
3. OQ-CAI-3 — engine-verify gate (5 sub-items: NavigationAgent3D `is_navigation_finished` lag + `_ready` vs LSS restore order + class-resolver runtime order + Jolt+`move_and_slide` from callback semantics + NavMesh RID validity at restore time).
4. OQ-CAI-5 — CALM-state animation ownership (level-designer authoring workflow).

**BLOCKING for VS sprint start**:
5. OQ-CAI-1 — witness latch trade-off (Pillar 2 design decision).
6. OQ-CAI-4 — VS feature flag mechanism (compile-time gate).
7. OQ-CAI-6 — civilian gasp VO sourcing + asset spec (3-4 week lead time).
8. Coord item §F.5#5 — ADR-0001 Proposed → Accepted gate.
9. Coord item §F.5#6 — Inventory `weapon_drawn_in_public` signal definition.

**BLOCKING for MVP playtest**:
10. OQ-CAI-6 — gasp sample library delivered.

**ADVISORY (track but non-blocking)**:
- F.5#3 Audio §Concurrency Rule 5 dead-code annotation
- F.5#4 Signal Bus L122 handler-table verification
- F.5#7 MLS L679 outline-tier reconciliation
- F.5#8 Save/Load CivilianAIState `cause: Vector3` schema touch-up
- F.5#9 panic_anchor section-validation CI
- F.5#10 SAI OQ-SAI-1 closure note
- F.5#11 (NEW) Flee speed reconciliation (V.2 ~2.4 m/s vs FLEE_SPEED_MPS 4.5 m/s)
- F.5#12 OQ-CAI-6 dual-tracker reconciliation with audio.md L689
- F.5#13 (NEW) Audio handler cost measurement (per-emission `civilian_panicked` handler ms cost)
- F.5#14 (NEW) AnimationTree CALM cost measurement (idle 8 civilians per-frame cost)
- F.5#15 (NEW) VS `alert_state_changed` grep relaxation rule

### Reviewer signature

`/design-review design/gdd/civilian-ai.md` — full mode — 2026-04-25
8 specialists + creative-director synthesis. 12 BLOCKING items. Resolved in-session. User accepted.
