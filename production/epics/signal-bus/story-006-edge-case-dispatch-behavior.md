# Story 006: Edge case dispatch behavior — no-dedup + continue-on-error tests

> **Epic**: Signal Bus
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-29
> **Completed**: 2026-05-01

## Context

**GDD**: `design/gdd/signal-bus.md`
**Requirement**: Signal Bus AC 15 (no deduplication on same-frame double-emit), AC 16 (continue-on-error dispatch)

**ADR Governing Implementation**: ADR-0002 §Edge Cases (rows 3, 5)
**ADR Decision Summary**: Godot's signal dispatch has two documented behaviors that the project's reactive code must rely on: (a) same-frame double-emit produces two dispatches in emit order with no merging or dedup; (b) if a subscriber's handler raises an error, Godot logs the error and continues dispatching to remaining subscribers. Both are intended Godot behavior, not Signal Bus behavior — but they are load-bearing assumptions for downstream subscribers, so this story locks them in via regression tests.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Both behaviors verified in ADR-0002 against Godot 4.0+ documented signal semantics. These tests serve as engine-version-upgrade smoke tests — if a future Godot release changes either behavior, these tests fail and surface the regression immediately.

**Control Manifest Rules (Foundation)**:
- Required: subscriber handlers that emit a signal of their own (chained dispatch) must terminate — no recursive cycles
- Required: subscribers must handle their own errors defensively; a crashing subscriber MUST NOT block others
- Performance: same-frame double-emit cost = 2× single-emit cost; documented in ADR-0002 §Performance Implications

---

## Acceptance Criteria

*From GDD §Acceptance Criteria:*

- [ ] **AC-15**: GIVEN two publishers emit `mission_completed` in the same frame, WHEN the signal is emitted twice, THEN subscribers receive two invocations in emit order with no merging or deduplication.
- [ ] **AC-16**: GIVEN subscriber A raises an unhandled error in its handler, WHEN the signal is emitted to [A, B] in that order, THEN subscriber B's handler is still invoked (validates Godot's continue-on-error dispatch).

---

## Implementation Notes

*Derived from ADR-0002 §Edge Cases:*

1. **AC-15 — no deduplication test** at `tests/unit/foundation/signal_dispatch_no_dedup_test.gd`:
   - Create a `TestRecorder extends Node` with a single subscriber method that appends to an `_invocations: Array[Dictionary]` log.
   - In one `func test_*()`: connect the recorder to `Events.mission_completed`; emit twice in succession (`Events.mission_completed.emit(&"mission_a")`, then `Events.mission_completed.emit(&"mission_b")`); assert `_invocations.size() == 2` AND `_invocations[0].mission_id == &"mission_a"` AND `_invocations[1].mission_id == &"mission_b"`.
   - Edge case test: emit the SAME mission_id twice in the same call sequence; assert two invocations with identical args (no dedup).
2. **AC-16 — continue-on-error test** at `tests/unit/foundation/signal_dispatch_continue_on_error_test.gd`:
   - Create two subscriber Nodes: `CrashingSubscriber` whose handler calls `assert(false, "intentional crash")` (or `push_error` + return — depending on whether the test framework treats `assert` as fatal); `NormalSubscriber` whose handler appends to a log.
   - Connect both to `Events.weapon_fired` in registration order: crashing FIRST, normal SECOND.
   - Emit `Events.weapon_fired.emit(null, Vector3.ZERO, Vector3.FORWARD)`.
   - Assert that `NormalSubscriber._invocations.size() == 1` (the crash did not block downstream dispatch); also assert that the test framework captured the crashing subscriber's error (e.g., via `assert_error_logged`).
3. Both tests use `Events` autoload directly. No mocks. No alternate signal hub. The point is to verify the actual production bus behaves as ADR-0002 documents.
4. Subscriber lifecycle: both tests properly disconnect in `_exit_tree` per Story 004's pattern. Test cleanup runs `assert_no_warnings` to confirm no leaked connections.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the actual signal declarations being emitted (these tests use them as fixtures)
- Story 004: lifecycle pattern reference template (these tests follow the template; they do not redefine it)
- Story 005: forbidden-pattern enforcement (orthogonal)

---

## QA Test Cases

**AC-15**: Same-signal double-emit produces two dispatches
- **Given**: a TestRecorder subscriber connected to `Events.mission_completed`; recorder's invocation log is empty
- **When**: `Events.mission_completed.emit(&"mission_a")` then `Events.mission_completed.emit(&"mission_b")` are called in the same `func test_*()` (within the same frame from the test's perspective)
- **Then**: recorder's invocation log has exactly 2 entries; entries[0] = `mission_a`; entries[1] = `mission_b`
- **Edge cases**:
  - Both emits use the same payload (`mission_a` twice) — log has 2 identical entries (no merging)
  - More than 2 emits in the same frame — log size matches emit count
  - Two different subscribers each emitting once — both subscribers receive both emits (Cartesian product behavior matches expected)

**AC-16**: Subscriber crash does not block other subscribers
- **Given**: CrashingSubscriber + NormalSubscriber both connected to `Events.weapon_fired` in that registration order
- **When**: `Events.weapon_fired.emit(null, Vector3.ZERO, Vector3.FORWARD)` is called once
- **Then**: NormalSubscriber's invocation log has exactly 1 entry; the test framework captured the crashing subscriber's error in stderr/output
- **Edge cases**:
  - Reverse order (NormalSubscriber first, CrashingSubscriber second) — both should receive the emit; this just exercises the same continue-on-error from the OTHER direction
  - Both subscribers crash — both errors are logged; no assertion that "all subscribers must succeed" is implied
  - Subscriber that emits ANOTHER signal from inside its handler — chained dispatch tested separately if needed; out of scope here unless a downstream story flags it

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/signal_dispatch_no_dedup_test.gd` — must exist and pass (AC-15)
- `tests/unit/foundation/signal_dispatch_continue_on_error_test.gd` — must exist and pass (AC-16)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (signals exist for these tests to emit), Story 004 (lifecycle pattern referenced for test subscriber setup)
- Unlocks: nothing within this epic; downstream consumer epics inherit the verified dispatch guarantees

---

## Completion Notes

**Completed**: 2026-05-01
**Criteria**: AC-15 (no-dedup) + AC-16 (continue-on-error) covered by 7 test functions across 2 files.
**Test results**: 4/4 in `signal_dispatch_no_dedup_test.gd` + 3/3 in `signal_dispatch_continue_on_error_test.gd` PASS.

### Files added
- `tests/unit/foundation/signal_dispatch_no_dedup_test.gd` (4 tests: 2-distinct-emits, 2-identical-emits, many-successive, two-recorders × two-emits Cartesian).
- `tests/unit/foundation/signal_dispatch_continue_on_error_test.gd` (3 tests: crashing-then-normal, normal-then-crashing, both-crashing).

### Engine-version-upgrade smoke value
These tests serve as upgrade smoke: if Godot 4.7+ changes either dispatch behavior (deduplicates same-frame emits, OR halts dispatch on subscriber error), the affected tests fail and surface the regression immediately. Both behaviors are documented Godot semantics that the project's reactive code relies on.

### Verdict
COMPLETE.
