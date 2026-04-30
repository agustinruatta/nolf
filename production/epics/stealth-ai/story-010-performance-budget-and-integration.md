# Story 010: Performance budget + full perception loop integration

> **Epic**: Stealth AI
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 3-4 hours (L — perf harness, sub-budget measurement, manual evidence artifact)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/stealth-ai.md`
**Requirement**: `TR-SAI-018`, `TR-SAI-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008 (Performance Budget Distribution)
**ADR Decision Summary**: Stealth AI claims a dedicated slot in the 16.6 ms frame budget: Slot #2 = Guard systems 6.5 ms total (SAI perception 3.0 ms + nav 2.0 ms + signals 1.0 ms for 12 guards; + Combat GuardFireController 0.5 ms P95). This is a cap, not a target. Any system exceeding its slot at the Restaurant reference scene (or Plaza baseline for VS) fails CI regardless of total frame time. ADR-0008 is Proposed — hardware measurement is OPEN. Stories may proceed; sub-budget assertions are advisory until ADR-0008 reaches Accepted.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `NavigationServer3D` path-query dispatch is asynchronous in Godot 4.6 (runs on a background thread); main-thread timing measurements exclude off-thread nav work. `Time.get_ticks_usec()` (NOT `OS.get_ticks_msec()` — deprecated) is the microsecond timer. `Engine.get_physics_frames()` for frame counting. Jolt 3D is the default physics engine in 4.6 — assert `ProjectSettings.get_setting("physics/3d/physics_engine") == "JoltPhysics"` at test start.

**Control Manifest Rules (Feature/Global)**:
- Required: performance evidence file MUST document CPU model, physics backend, nav mesh source, frame-time histogram
- Guardrail: SAI sub-budget 6.0 ms mean / 8.0 ms P95 / 12.0 ms P99 / 15.0 ms max spike (plus 0.5 ms GuardFireController = 6.5 ms slot total)
- Note: ADR-0008 Proposed → sub-budget assertions are advisory; overall 6.5 ms slot is binding when ADR reaches Accepted

---

## Acceptance Criteria

*From GDD AC-SAI-4.4 + AC-SAI-3.9 + TR-SAI-018 + TR-SAI-012:*

- [ ] **AC-1** (AC-SAI-4.1 — full perception loop end-to-end): Spawn PC + one guard in a test scene. Eve walks in front of guard at 5 m, unobstructed, for 3 simulated seconds (180 ticks at delta=1/60). Capture all `alert_state_changed` emissions. Assert the sequence `(old → new)` pairs is EXACTLY in order: `(UNAWARE → SUSPICIOUS)`, `(SUSPICIOUS → SEARCHING)`, `(SEARCHING → COMBAT)` — no state skipped, no state appearing twice.
- [ ] **AC-2** (AC-SAI-4.4.a — overall budget): Spawn `MAX_GUARDS_PER_SECTION = 12` guards in a test scene with Plaza NavigationMesh baked, Eve performing continuous-locomotion movement. Run for 600 physics frames (10 s). Assert:
  - Mean Stealth-AI frame time ≤ **6.0 ms**
  - P95 ≤ **8.0 ms**
  - P99 ≤ **12.0 ms**
  - Max single-frame spike ≤ **15.0 ms**
  Advisory (ADR-0008 Proposed): if ADR-0008 is still Proposed at story-done time, log a `push_warning` with the measured values rather than failing CI — but the evidence file is still required.
- [ ] **AC-3** (AC-SAI-4.4.b — perception sub-budget): Sum of F.1 sight LOS raycasts (all guards) + F.2a occlusion (stub for VS — F.2 deferred) ≤ **3.0 ms mean / 4.0 ms P95** per frame. Verified via `CountingRaycastProvider.call_count` per frame ≤ `12 × 1 = 12` raycasts (1 per guard for VS with just Eve — no dead bodies in VS). Raycast deduplication (Story 004 AC-4): each guard issues at most 1 raycast per frame for the guard→Eve pair.
- [ ] **AC-4** (AC-SAI-4.4.c — navigation sub-budget): Sum of `NavigationAgent3D` async-dispatch invocation + `move_and_slide()` + repath trigger logic ≤ **2.0 ms mean / 3.0 ms P95** per frame. Assert `NavigationServer3D.map_get_path` is NOT called synchronously (AC-SAI-3.12.b fence from Story 009).
- [ ] **AC-5** (AC-SAI-4.4.d — signals sub-budget): `emit_signal` dispatch + state-transition logic ≤ **1.0 ms mean / 1.5 ms P95** per frame. Subscriber handlers stubbed with empty handlers during perf test (subscriber cost excluded — counts against Audio/Dialogue budgets).
- [ ] **AC-6**: Test environment pins (all must be asserted at test start):
  - `ProjectSettings.get_setting("physics/3d/physics_engine") == "JoltPhysics"` (Godot 4.6 default; catch configuration drift)
  - `DebugFlags.ai_debug == false` (debug overlays excluded from measurement)
  - Plaza NavigationMesh baked (not a flat-plane simplification)
  - CPU model documented in evidence file
- [ ] **AC-7**: Manual evidence artifact `production/qa/evidence/stealth-ai-perf-[YYYY-MM-DD].md` must exist and contain: CPU model, physics backend, nav mesh source, frame-time histogram (P50/P95/P99/max), per-subsystem timing table (perception / nav / signals), and a verdict of PASS or ADVISORY (if ADR-0008 still Proposed).
- [ ] **AC-8** (AC-SAI-3.9 — has_los_to_player at scale): With 12 guards active and `Combat.GuardFireController` calling `has_los_to_player()` at 10 Hz per guard: `CountingRaycastProvider.call_count` increments by at most 1 per guard per physics frame (cache-hit path ensures no new raycast per accessor call between F.1 ticks). Total raycasts per second ≤ `12 × 60 = 720` worst-case (one per guard per physics frame, with cache).

---

## Implementation Notes

*Derived from GDD AC-SAI-4.4 (custom profiling harness spec) + ADR-0008:*

Sub-budget measurement requires a **custom profiling harness** injected at test init — NOT GUT's built-in timing assertions (insufficient resolution):

```gdscript
# Conceptual profiling harness pattern
class ProfiledPerception extends Perception:
    var total_usec: int = 0
    var frame_samples: Array[int] = []
    func tick_sight_fill(target, delta) -> void:
        var t0 := Time.get_ticks_usec()
        super.tick_sight_fill(target, delta)
        var elapsed := Time.get_ticks_usec() - t0
        total_usec += elapsed
        frame_samples.append(elapsed)
```

The harness wraps Perception, PatrolController, and signal-dispatch entry points with `Time.get_ticks_usec()` entry/exit timers. Production code is unchanged — the wrapper is injected only in the test scene.

`NavigationServer3D` async dispatch: guard's `NavigationAgent3D.velocity_computed` fires on the main thread when the server delivers a velocity. The `velocity_computed` handler's timing is what is measured for the nav sub-budget — the server's background path-computation thread time is intentionally excluded (it runs concurrently and does not block the main thread).

P95/P99 calculation: collect all `frame_samples`, sort ascending, and index at `0.95 × count` and `0.99 × count`.

Test environment setup:
```gdscript
func before_test() -> void:
    assert(ProjectSettings.get_setting("physics/3d/physics_engine") == "JoltPhysics")
    # Spawn 12 guards with Plaza nav mesh baked
    # Eve stub performing continuous locomotion
    # Stub subscribers (empty callables) connected to prevent real Audio/Dialogue costs
```

Evidence file template:
```markdown
# Stealth AI Performance Evidence — [DATE]

## Environment
- CPU: [model]
- Physics backend: JoltPhysics (Godot 4.6)
- Nav mesh: Plaza baked (geometry baseline)
- Guards: 12 (MAX_GUARDS_PER_SECTION)
- Eve: continuous locomotion

## Frame-Time Histogram (Stealth AI slot only)
| Metric | Value (ms) | Budget (ms) | Pass? |
|--------|-----------|-------------|-------|
| Mean | X.X | 6.0 | ✓/✗ |
| P95 | X.X | 8.0 | ✓/✗ |
| P99 | X.X | 12.0 | ✓/✗ |
| Max spike | X.X | 15.0 | ✓/✗ |

## Sub-budget Breakdown
| Subsystem | Mean (ms) | P95 (ms) | Budget (ms) |
|-----------|-----------|----------|-------------|
| Perception | X.X | X.X | 3.0 |
| Navigation | X.X | X.X | 2.0 |
| Signals | X.X | X.X | 1.0 |

## Verdict: [PASS / ADVISORY]
ADR-0008 status: [Proposed / Accepted]
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Post-VS (TR-SAI-008): F.2 sound fill sub-budget (HearingPoller at 10 Hz adds to perception sub-budget; measured separately when F.2 ships)
- Post-VS (TR-SAI-010): F.4 propagation burst-case performance (12 guards all repathing simultaneously — nav P99 touches 3 ms ceiling; documented as accepted per GDD AC-SAI-4.4.c)
- Post-VS: dead-body raycast budget (4 targets per guard worst case: Eve + 3 corpses at `12 × 4 = 48` raycasts/frame; VS has no corpses — measured when SAW_BODY mechanic ships)
- Post-VS: Restaurant section as performance regression test (wider/more complex nav mesh than Plaza — deferred to production sprint)

---

## QA Test Cases

**AC-1 — Full perception loop ordered sequence**
- Given: one guard UNAWARE at origin; Eve stub walking toward guard at 5 m, unobstructed; `RealRaycastProvider` (requires a real nav scene) OR `CountingRaycastProvider` with `scripted_result` set to clear LOS
- When: 180 physics ticks simulated
- Then: `alert_state_changed` emissions captured; sequence is exactly `[(UNAWARE, SUSPICIOUS), (SUSPICIOUS, SEARCHING), (SEARCHING, COMBAT)]`; no duplicate states; no skipped states (UNAWARE→COMBAT direct does not occur for a slowly-approaching Eve at 5 m)
- Edge cases: Eve too far / too fast → sequence may differ; test setup must ensure 5 m approach guarantees the graduated sequence

**AC-2 — Overall budget (12 guards)**
- Given: 12 guards active, Plaza nav mesh, Eve continuous locomotion; profiling harness injected
- When: 600 physics frames measured
- Then: mean, P95, P99, max within budget (advisory if ADR-0008 Proposed)
- Edge cases: spike frames during nav repath burst → P99 allowed to touch 12 ms; max allowed to touch 15 ms (documented accepted vsync drop)

**AC-8 — has_los_to_player at scale**
- Given: 12 guards; each guard's `Perception` has `CountingRaycastProvider` with combined call count tracked across all guards
- When: 60 physics frames simulated
- Then: total combined `call_count` across all 12 guards ≤ `12 × 60 = 720` (one raycast per guard per frame max); no guard exceeds 1 raycast per frame (deduplication confirmed)
- Edge cases: F.2a sound occlusion also calls raycast (deferred in VS — guard may issue 0 or 1 raycast if F.2 stub)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/feature/stealth_ai/stealth_ai_full_perception_loop_test.gd` — AC-SAI-4.1
- `tests/integration/feature/stealth_ai/stealth_ai_perf_budget_test.gd` — AC-SAI-4.4.a overall
- `tests/integration/feature/stealth_ai/stealth_ai_perf_subbudget_test.gd` — AC-SAI-4.4.b/c/d sub-budgets
- `production/qa/evidence/stealth-ai-perf-[YYYY-MM-DD].md` — manual evidence with CPU model, histogram, verdict

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001-009 all DONE (full perception + state + behavior + signal pipeline must be operational for a meaningful performance measurement)
- Unlocks: Epic Definition of Done — last story; all ACs verified closes the epic
