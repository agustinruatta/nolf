# Stealth AI Performance Evidence — 2026-05-02

**Story**: SAI-010 (Performance budget + full perception loop integration)
**Verdict**: ADVISORY (ADR-0008 numerical Iris Xe verification deferred)

---

## Environment

| Field | Value |
|---|---|
| **CPU** | Development host CPU (not target hardware — Iris Xe Gen 12 verification deferred per ADR-0008) |
| **Physics backend** | Jolt 3D (Godot 4.6 default) |
| **Godot version** | 4.6 (per `docs/engine-reference/godot/VERSION.md`) |
| **Nav mesh source** | None — headless GdUnit4 test harness uses CountingRaycastProvider stubs (no real nav mesh baking) |
| **Guards** | 12 (`_MAX_GUARDS_PER_SECTION`) |
| **Test mode** | Headless integration test (`tests/integration/feature/stealth_ai/stealth_ai_perf_budget_test.gd`) |
| **Date** | 2026-05-02 |

---

## Frame-Time Histogram (Stealth AI slot — Perception subsystem)

Measured on 60-tick run with 12 guards each calling `process_sight_fill()` once per simulated frame against an Eve stub at 5m distance, full LOS-clear path.

| Metric | Measured (µs) | Measured (ms) | Budget (ms) | Pass? |
|---|---:|---:|---:|---|
| **Total (60 frames × 12 guards)** | 2 626 µs | 2.626 ms | n/a | n/a |
| **Mean per-frame** | 43.8 µs | 0.044 ms | 3.0 ms (perception sub-budget) | ✓ |
| **Mean per-guard** | 3.6 µs | 0.0036 ms | n/a (informational) | n/a |

**Note**: Mean per-frame perception cost is **~70x under** the 3.0 ms sub-budget on dev hardware. Iris Xe Gen 12 verification (ADR-0008 Gates 1+2) is DEFERRED — when measured on target hardware, expect a 2-5× slowdown which still leaves headroom.

---

## Sub-budget Breakdown — Measured vs Documented Budget

ADR-0008 §SAI Slot allocates **6.5 ms total** to the SAI slot (perception 3.0 + nav 2.0 + signals 1.0 + GuardFireController 0.5).

| Subsystem | Measured (mean ms) | Budget (mean ms) | Notes |
|---|---:|---:|---|
| **Perception (F.1)** | 0.044 ms | 3.0 ms | F.1 process_sight_fill across 12 guards. Well under budget. |
| **Navigation** | not measured | 2.0 ms | NavigationAgent3D async-dispatch cost not directly measurable in headless harness (no real nav mesh). Deferred to playtest evidence. |
| **Signals** | not measured | 1.0 ms | Signal dispatch overhead at 12-guard scale not isolated in this test. The synchronicity contract is verified by SAI-005 receive_damage_synchronicity tests; absolute timing deferred. |

---

## Test Coverage Summary

| AC | Test | Status |
|---|---|---|
| AC-1 | `test_full_perception_loop_ordered_sequence_assertion` (UNAWARE→SUSPICIOUS→SEARCHING→COMBAT graduated) | ✓ PASS |
| AC-1 | `test_gradual_accumulator_rise_produces_stepped_transitions_not_jumps` (3 stepped transitions, not 1 direct jump) | ✓ PASS |
| AC-2 | `test_advisory_perf_one_tick_across_12_guards_completes` (sanity bound: < 1s for 60×12 ticks) | ✓ PASS (advisory) |
| AC-3 | `test_perception_sub_budget_one_raycast_per_guard_per_frame` (deduplication: 1 raycast/guard/frame) | ✓ PASS |
| AC-4 | Navigation sub-budget — DEFERRED (no real nav mesh in headless test) | ⏸ DEFERRED |
| AC-5 | Signals sub-budget — DEFERRED (subscriber cost is part of audio/dialogue slot) | ⏸ DEFERRED |
| AC-6 | `test_physics_backend_is_jolt_3d` + `test_engine_version_is_4_6_or_later` | ✓ PASS |
| AC-7 | This document | ✓ PRODUCED |
| AC-8 | `test_has_los_to_player_does_not_issue_raycast_at_12_guard_scale` (12 guards × 60 frames = 0 raycasts) | ✓ PASS |

---

## Verdict: ADVISORY

ADR-0008 Status: **Accepted with deferred numerical verification** (Gates 1, 2, 4 deferred to Iris Xe Gen 12 hardware in a later sprint).

**Structural framework verified**:
- Per-slot allocation: SAI claims 6.5 ms slot ✓
- Zero-alloc polling contract: `process_sight_fill()` does no per-call allocations ✓
- Signal-bus dispatch absorbed in emitter slots: SAI emits via Events autoload ✓
- Synchronicity guarantee: state mutation precedes signal emit (verified by SAI-005 tests) ✓

**Numerical claims pending Iris Xe verification**:
- Mean SAI frame time ≤ 6.0 ms — NOT yet measured on target hardware
- P95 ≤ 8.0 ms — NOT yet measured
- P99 ≤ 12.0 ms — NOT yet measured
- Max single-frame spike ≤ 15.0 ms — NOT yet measured

**Recommended re-verification trigger** (per ADR-0008 §Validation Criteria):
- When Plaza VS scene with baked NavigationMesh becomes available (Sprint 05+ candidate)
- When Iris Xe Gen 12 hardware test bench is set up
- When F.2 sound fill ships (post-VS) — add to perception sub-budget measurement

---

## Pillar 3 Reversibility Sign-Off

**STATUS**: Verified by integration test (`tests/integration/feature/stealth_ai/stealth_ai_pillar3_reversibility_test.gd`) — see SAI-007 Completion Notes.

The full escalation → no-stimulus → de-escalation loop has been simulated headlessly:
- Guard escalates UNAWARE → SUSPICIOUS via accumulator seeding
- Sustained no-stimulus + decay + timer ticks return guard to UNAWARE
- No persistent alert state after timeout

Manual playtest sign-off (`production/qa/evidence/stealth-ai-pillar3-feel-[YYYY-MM-DD].md` per AC-SAI-4.3) is DEFERRED to a later sprint when:
- Plaza VS scene is built and visually playable
- Eve player character has full locomotion + visible model
- 8-checklist-item playtest can be performed by a qualified tester

---

## Open Items / Follow-ups

1. **Iris Xe Gen 12 numerical verification** — re-open ADR-0008 Gates 1+2 once target hardware bench is set up.
2. **Real nav mesh perf test** — defer to Plaza VS scene availability.
3. **Subscriber cost isolation** — when Audio + Dialogue subscribers ship, isolate their per-tick cost separately from SAI Slot.
4. **F.2 sound fill perf addition** — when F.2 lands post-VS, extend `process_sight_fill` perf test to include sound-fill cost in the perception sub-budget.

---

## Reproducibility

To reproduce these measurements:

```bash
godot -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  -a tests/integration/feature/stealth_ai/stealth_ai_perf_budget_test.gd --headless
```

Look for the `[SAI-010 ADVISORY]` print line in the output for the per-frame timing values.

Suite total: **637/637 PASS exit 0** (baseline 630 + 7 new SAI-010 tests).
