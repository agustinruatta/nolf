# Story 010: Performance budget measurement — p90 verification + VERBOSE_TRANSITION_LOGGING

> **Epic**: Level Streaming
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2 hours (M — instrumentation + 10-run measurement harness + perf reporting doc)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/level-streaming.md`
**Requirement**: TR-LS-011 (Performance budget: ≤0.57s total p90 on Iris Xe; 33ms snap-out + ≤500ms SWAPPING + 33ms snap-in)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007 + ADR-0001 (min-spec hardware reference: Intel Iris Xe per Engine Compatibility)
**ADR Decision Summary**: Per GDD §States and Transitions: total transition budget ≤0.57s from `transition_to_section` call to player regaining control. Per AC-LS-6.1: p90 across 10 consecutive runs ≤0.57s; no individual run >0.8s. Per AC-LS-6.2: SWAPPING phase isolated ≤500ms. Measurement: `VERBOSE_TRANSITION_LOGGING` engine-time timestamps via `Time.get_ticks_usec()` (NOT wall-clock). If any single run fails, repeat the 10-run set once; only flag as FAIL if both sets contain a failing run.

**Engine**: Godot 4.6 | **Risk**: LOW (post-Sprint-01 verification of the autoload mechanism; perf is implementation-quality)
**Engine Notes**: `Time.get_ticks_usec()` provides microsecond-resolution timestamps. Engine time excludes `pause`-related delays. Min-spec measurement is the authoritative target; CI runner results are advisory only — human-hardware QA on Iris Xe (or representative integrated graphics) is the canonical verification.

**Control Manifest Rules (Foundation)**:
- Performance: ≤0.57s p90 total transition; ≤500ms SWAPPING phase (TR-LS-011)
- Required: `VERBOSE_TRANSITION_LOGGING` flag-gated instrumentation captures step-level timestamps
- Required: 10-run measurement harness reports min/p50/p90/max + FAIL/PASS verdict

---

## Acceptance Criteria

*From GDD §Acceptance Criteria 6.1, 6.2, 6.3 + §States and Transitions:*

- [ ] **AC-1**: `VERBOSE_TRANSITION_LOGGING` is a project-level flag (e.g., `OS.is_debug_build()` OR a `ProjectSettings` boolean) that gates step-level timestamp logging in `_run_swap_sequence`. When enabled, each step's entry and exit time are recorded via `Time.get_ticks_usec()` and logged with the step number.
- [ ] **AC-2**: Step-level timestamps recorded include: step 1 entry (`transition_to_section` call), step 3 entry (section_exited emit), step 5 entry (load), step 6 entry (instantiate), step 7 entry (add_child), step 9 entry (callback chain), step 10 entry (section_entered emit), step 12 entry (LOADING pop), step 13 (IDLE).
- [ ] **AC-3**: A measurement harness `tests/integration/level_streaming/level_streaming_perf_p90_test.gd` runs `transition_to_section(plaza → stub_b)` 10 consecutive times and captures the duration from step 1 entry to step 12 exit per run. Computes min, p50, p90, max.
- [ ] **AC-4**: The harness asserts: p90 ≤ 570 ms (570000 µs); no individual run > 800 ms (800000 µs). On individual run failure, repeat the 10-run set once; only flag overall FAIL if both sets contain a failing run. (AC-LS-6.1 from GDD.)
- [ ] **AC-5**: A separate harness or sub-test isolates the SWAPPING phase (step 3 entry to step 10 entry) and asserts elapsed time ≤500 ms across the 10 runs. (AC-LS-6.2 from GDD.)
- [ ] **AC-6**: GIVEN two consecutive forward transitions into the same section (`plaza → stub_b → plaza`), WHEN peak heap memory is measured via `OS.get_static_memory_usage()`, THEN peak across the second transition ≤110% of peak during the first transition. (AC-LS-6.3 from GDD; this AC is co-owned with Story 006 — Story 006 implements the test, Story 010 verifies the perf assertion against the budget.)
- [ ] **AC-7**: A perf report doc at `production/qa/evidence/level_streaming_perf_p90_[date].md` is produced after each measurement run, containing: timestamp, hardware (CPU + GPU), Godot version, all 10 run durations, computed statistics (min/p50/p90/max), per-step breakdown for the slowest run (which steps consumed the most time), PASS/FAIL verdict.
- [ ] **AC-8**: Min-spec (Intel Iris Xe) verification is the authoritative target. CI runner results are advisory: CI threshold is 800 ms p90 (50% headroom over min-spec budget); failures on CI but passes on min-spec are downgraded to "advisory FAIL — verify on min-spec".
- [ ] **AC-9**: GIVEN a regression in a future PR (e.g., a new step-9 callback adds 200 ms), WHEN the perf harness runs, THEN the p90 budget is exceeded AND the test fails AND the report identifies the slowest step (callback chain) for triage.

---

## Implementation Notes

*Derived from GDD §States and Transitions + §Acceptance Criteria 6.x + ADR-0001 min-spec context:*

**Instrumentation in LSS** (extending Story 002's coroutine):

```gdscript
const VERBOSE_TRANSITION_LOGGING_ENABLED: bool = true  # MVP: always on; ship-build can flip to false
var _step_timings: Dictionary = {}  # step_id (int) -> usec timestamp

func _log_step(step_id: int, label: String) -> void:
    if not VERBOSE_TRANSITION_LOGGING_ENABLED:
        return
    var now: int = Time.get_ticks_usec()
    _step_timings[step_id] = now
    print("[LSS] step %d (%s) at %d µs" % [step_id, label, now])
```

Inserted at each step entry in `_run_swap_sequence`:

```gdscript
func _run_swap_sequence(target_id, save_game, reason):
    _step_timings.clear()
    _log_step(1, "transition begin")  # Step 1 already happened pre-coroutine
    # ... step 2 fade out start
    _log_step(2, "fade out start")
    # ... step 3 emit
    _log_step(3, "section_exited emit")
    Events.section_exited.emit(outgoing_id, reason)
    # ... step 5 load
    _log_step(5, "load begin")
    var packed = ResourceLoader.load(...)
    # ... step 6 instantiate
    _log_step(6, "instantiate")
    # ... step 7 add_child
    _log_step(7, "add_child")
    # ... step 9 callback chain
    _log_step(9, "callback chain begin")
    _invoke_restore_callbacks(...)
    # ... step 10 emit
    _log_step(10, "section_entered emit")
    # ... step 12 pop
    _log_step(12, "LOADING pop")
    # ... step 13 IDLE
    _log_step(13, "IDLE")
```

**Measurement harness**:

```gdscript
# tests/integration/level_streaming/level_streaming_perf_p90_test.gd
extends GdUnitTestSuite

const TARGET_P90_USEC: int = 570000  # 0.57 s
const TARGET_MAX_USEC: int = 800000  # 0.8 s
const RUN_COUNT: int = 10

func test_transition_p90_within_budget() -> void:
    var durations: Array[int] = []
    for i in range(RUN_COUNT):
        var start_usec := Time.get_ticks_usec()
        LevelStreamingService.transition_to_section(&"stub_b", null, NEW_GAME)
        await Events.section_entered
        # Wait for FADING_IN to complete (state == IDLE)
        while LevelStreamingService.current_state != State.IDLE:
            await get_tree().process_frame
        var end_usec := Time.get_ticks_usec()
        durations.append(end_usec - start_usec)

        # Reset for next run: transition back to plaza
        LevelStreamingService.transition_to_section(&"plaza", null, FORWARD)
        await Events.section_entered
        while LevelStreamingService.current_state != State.IDLE:
            await get_tree().process_frame

    durations.sort()
    var p90: int = durations[int(durations.size() * 0.9) - 1]
    var max_d: int = durations[durations.size() - 1]

    var report := _format_perf_report(durations, p90, max_d)
    _write_perf_report(report)

    # Assertions per AC-4
    assert_int(p90).is_less_or_equal(TARGET_P90_USEC)
    assert_int(max_d).is_less_or_equal(TARGET_MAX_USEC)
```

**Perf report doc** (`production/qa/evidence/level_streaming_perf_p90_[date].md`):

```markdown
# Level Streaming Perf Measurement — [YYYY-MM-DD]

## Environment
- Hardware: [CPU + GPU description]
- Godot: 4.6.x
- Build: debug / release
- Runner: CI / local dev

## 10-Run Durations (µs)
| Run | Total (µs) | Total (ms) | SWAPPING (µs) |
|---|---|---|---|
| 1 | 432000 | 432 | 280000 |
| 2 | 458000 | 458 | 295000 |
| ... |

## Statistics
- Min: 432 ms
- p50: 461 ms
- p90: 510 ms
- Max: 547 ms

## Verdict
- p90 ≤ 570 ms: PASS
- max ≤ 800 ms: PASS

## Slowest Run Step Breakdown
- Step 1 → 2: 0.5 ms
- Step 2 → 3 (fade-out): 33 ms
- Step 3 → 5 (queue_free + registry check): 12 ms
- Step 5 (load): 250 ms ← dominant
- Step 6 (instantiate): 35 ms
- Step 7 → 8 (add_child + frame await): 16 ms
- Step 9 (callbacks): 5 ms
- Step 10 → 11 (section_entered emit): 2 ms
- Step 11 → 12 (fade-in): 33 ms
- Total: ~386 ms (slowest run was 547 ms — discrepancy = OS scheduling variance)
```

**Why p90 not p99 or mean**: per GDD AC-LS-6.1, p90 is the canonical metric (matches industry "feels responsive" threshold). p99 is too tail-sensitive for 10-run samples; mean hides outliers.

**Why `Time.get_ticks_usec` not `OS.get_ticks_usec`**: `Time.get_ticks_usec` is the canonical Godot 4.x API (`OS.get_ticks_usec` was deprecated in 4.0).

**Report file naming**: `[date]` is `YYYY-MM-DD-HHMM` to allow multiple measurements on the same day; latest run wins (or all kept; manual cleanup post-MVP).

**Perf-as-test gate**: this story's tests run on every PR via CI. CI variance is high (CI runners are not min-spec Iris Xe), so CI threshold is set to 800 ms (50% headroom). Failing tests on CI prompt manual verification on min-spec; the manual verification is canonical.

**Memory invariant test (AC-6)**: implemented in Story 006 (`level_streaming_focus_memory_test.gd`); this story's role is to verify the assertion against the budget (≤110% second-transition peak) is correctly tied to TR-LS-011's broader perf scope.

**Performance regression-detection workflow**: future PRs that touch LSS or any step-9 callback should re-run the perf harness. If a regression is detected (p90 jumps), the perf report's slowest-run step breakdown identifies the offending step.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: 13-step coroutine
- Story 003: register_restore_callback chain (instrumented but not modified by this story)
- Story 006: memory invariant test (AC-LS-6.3) — implemented there; this story verifies it's connected to TR-LS-011
- Async ResourceLoader migration (post-MVP per OQ-LS-1) — if perf budget cannot be met on min-spec, OQ-LS-1 reopens; out of MVP scope
- Min-spec hardware procurement — operations concern, not engineering

---

## QA Test Cases

**AC-1 — VERBOSE_TRANSITION_LOGGING gates instrumentation**
- **Given**: LSS source after this story
- **When**: `VERBOSE_TRANSITION_LOGGING_ENABLED` is true; a transition runs
- **Then**: `print` lines are emitted with step numbers + timestamps; `_step_timings` dictionary is populated
- **Edge cases**: flag false → no print, no dictionary writes (zero overhead in shipping)

**AC-2 — Step-level timestamps captured**
- **Given**: a transition completes
- **When**: `_step_timings` is inspected
- **Then**: dictionary contains keys for steps 1, 2, 3, 5, 6, 7, 9, 10, 12, 13; each value is a positive int (microseconds)
- **Edge cases**: aborted transition → only steps before abort are recorded; this is acceptable diagnostic state

**AC-3 — 10-run measurement harness**
- **Given**: stub plaza + stub_b scenes (Story 008); LSS post-Stories 002–008
- **When**: harness runs 10 transitions plaza → stub_b → plaza alternating
- **Then**: 10 durations recorded; min/p50/p90/max computed; perf report file written
- **Edge cases**: a single run fails (e.g., transient CI hang) → full set repeats once per AC-4; only fails overall if both sets fail

**AC-4 — p90 + max budget assertions**
- **Given**: 10 durations from harness on min-spec
- **When**: assertions run
- **Then**: `p90 ≤ 570000 µs` AND `max ≤ 800000 µs`
- **Edge cases**: CI runs with relaxed thresholds (800 ms p90); failures downgraded to advisory if min-spec PASSes manually

**AC-5 — SWAPPING phase isolation**
- **Given**: per-run step timestamps from instrumentation
- **When**: SWAPPING phase computed (step 3 entry to step 10 entry)
- **Then**: SWAPPING ≤ 500 ms across all runs (or p90 ≤ 500 ms in stricter formulation)
- **Edge cases**: SWAPPING dominated by ResourceLoader.load (cold cache) — first run typically slowest; cached subsequent runs faster

**AC-6 — Memory invariant cross-reference (Story 006)**
- **Given**: Story 006's `level_streaming_focus_memory_test.gd` exists
- **When**: this story's perf scope verifies the budget
- **Then**: `OS.get_static_memory_usage()` second-transition peak ≤ 110% of first-transition peak; cross-referenced via test docstring
- **Edge cases**: covered by Story 006; this story confirms the budget alignment

**AC-7 — Perf report doc generated**
- **Given**: harness runs to completion
- **When**: `_write_perf_report` fires
- **Then**: file at `production/qa/evidence/level_streaming_perf_p90_[date].md` exists with the documented sections (Environment, 10-Run table, Statistics, Verdict, Slowest Run Breakdown)
- **Edge cases**: filesystem write failure → log warning, test still asserts pass/fail from in-memory data

**AC-8 — CI vs min-spec verdict differentiation**
- **Given**: harness runs
- **When**: assertions evaluate
- **Then**: in CI environment (e.g., GitHub Actions runner), thresholds use 800 ms p90; in local dev (developer's machine), tighter 570 ms threshold; the report logs which threshold was applied
- **Edge cases**: detection of "is this CI?" via env var (`CI=true` is GitHub Actions standard) or absence of expected min-spec hardware

**AC-9 — Regression detection scenario**
- **Given**: hypothetically, a future PR adds a 200 ms blocking call to a step-9 callback
- **When**: perf harness runs against that PR
- **Then**: p90 exceeds 570 ms; test FAILs; report's "Slowest Run Step Breakdown" highlights step 9 as the dominant cost
- **Edge cases**: this AC is a "by-design" test — verify the harness can detect regressions, not just pass on the current state

---

## Test Evidence

**Story Type**: Logic (perf measurement is logic over collected data)
**Required evidence**:
- `tests/integration/level_streaming/level_streaming_perf_p90_test.gd` — must exist and pass on local dev (CI advisory)
- `production/qa/evidence/level_streaming_perf_p90_[date].md` — initial perf report from first measurement run
- `production/qa/evidence/level_streaming_min_spec_verification_[date].md` — manual verification on Iris Xe hardware (post-MVP — initially flagged as deferred)
- Naming follows Foundation-layer convention

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (13-step coroutine — instrumentation hooks at step entries), Story 003 (callback chain — step 9 timing), Story 008 (stub scenes — harness loads/swaps them), Story 006 (memory invariant cross-ref)
- Unlocks: shipping-readiness verification — without perf budget compliance, the epic cannot close per Definition of Done; future Polish phase work has a baseline to regress against
