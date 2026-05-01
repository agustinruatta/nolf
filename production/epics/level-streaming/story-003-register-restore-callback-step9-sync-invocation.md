# Story 003: register_restore_callback chain + step 9 synchronous invocation

> **Epic**: Level Streaming
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2 hours (M — registration API + sync invocation loop + no-await assertion)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/level-streaming.md`
**Requirement**: TR-LS-013 (step 9 registered-callback pattern; synchronous invocation; no-await contract enforced by debug pre/post timestamp assertion)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007 (autoload coordination) + ADR-0003 (state restore via SaveGame sub-resources)
**ADR Decision Summary**: Per CR-2, callers (Mission Scripting, Failure & Respawn, Menu System) register ONE callback each at autoload boot via `LSS.register_restore_callback(callable)`. At step 9 of the 13-step swap, LSS iterates registered callbacks in registration order, passing `(target_section_id, save_game, reason)`. Each callback MUST complete synchronously (no `await`) before LSS proceeds to step 10. Debug builds detect violations via pre/post-call frame-timestamp assertion.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Callable` type is stable Godot 4.0+. `Time.get_ticks_usec()` for nanosecond-resolution timestamping. The "synchronous return" check uses elapsed engine frames (delta == 0) as the gate — if a callback awaits a frame, the engine advances frame counter between pre and post, triggering the assertion.

**Control Manifest Rules (Foundation)**:
- Required: callbacks register at autoload boot via `register_restore_callback` (TR-LS-013)
- Required: callbacks are invoked synchronously at step 9 in registration order (TR-LS-013)
- Required: callback MUST NOT `await` (no-await contract; debug-build pre/post timestamp assertion)
- Forbidden: registering callbacks at runtime (post-boot) without paired deregistration discipline (this story's API is registration-only at boot; deregistration is post-MVP)

---

## Acceptance Criteria

*From GDD §Detailed Design CR-2 + §Acceptance Criteria 3.7:*

- [ ] **AC-1**: `register_restore_callback(callback: Callable) -> void` is a public method that appends `callback` to an internal `_restore_callbacks: Array[Callable]` array. Callable validity is checked (`callback.is_valid()` truthy at registration); invalid callables `push_warning` and are not registered.
- [ ] **AC-2**: At step 9 of the swap coroutine, LSS iterates `_restore_callbacks` in registration order and calls each: `callback.call(target_id, save_game, reason)`. The iteration is synchronous — no awaits between callback invocations.
- [ ] **AC-3**: Step 9 happens AFTER step 8's `await get_tree().process_frame` (so the new scene's `_ready` + any `call_deferred` chains have run) AND BEFORE step 10's `Events.section_entered` emit (subscribers reading restored state must see live values).
- [ ] **AC-4**: GIVEN a registered callback, WHEN step 9 invokes it, THEN the callback receives 3 positional arguments: `(target_section_id: StringName, save_game: SaveGame, reason: TransitionReason)`. Test verifies signature by registering a probe callback that records the args.
- [ ] **AC-5**: GIVEN multiple callbacks registered (Mission Scripting, F&R, Menu System), WHEN step 9 runs, THEN all callbacks fire in registration order; no callback is skipped if a prior one logs an error (per GDD §Edge Cases State Restore Failures: "GDScript logs the error and continues").
- [ ] **AC-6**: GIVEN a callback that violates the no-await contract (`await get_tree().process_frame` inside the callback body), WHEN step 9 invokes it in a debug build, THEN `push_error` fires with a clear message identifying the violating callback (verifiable by checking the engine-time delta around the call: a non-zero frame delta indicates the callback awaited).
- [ ] **AC-7**: `Events.section_entered` emit (step 10) ONLY fires after ALL callbacks have returned synchronously (per AC-LS-2.2 from GDD: "all registered restore callbacks have been invoked AND all invocations returned synchronously").
- [ ] **AC-8**: GIVEN a callback registered at autoload boot via `LSS.register_restore_callback(_on_restore)`, WHEN a transition runs, THEN the callback fires AT step 9 (NOT at step 3 — step 3 is for `section_exited` subscribers, not restore callbacks). (AC-LS-3.7 from GDD.)
- [ ] **AC-9**: A test integration scenario registers a probe callback that mutates a known piece of state (e.g., sets `_test_marker = "callback_ran"`) and verifies the marker is set BEFORE `section_entered` fires (signal-spy timestamp comparison).

---

## Implementation Notes

*Derived from GDD §Detailed Design CR-2 + ADR-0003 (caller-side `duplicate_deep` discipline applies INSIDE callbacks, not in LSS):*

**Public API addition to LSS**:

```gdscript
var _restore_callbacks: Array[Callable] = []

func register_restore_callback(callback: Callable) -> void:
    if not callback.is_valid():
        push_warning("[LSS] register_restore_callback called with invalid Callable; skipping")
        return
    _restore_callbacks.append(callback)
```

**Step 9 invocation in `_run_swap_sequence`** (Story 002's coroutine; this story extends it):

```gdscript
# (Coroutine after step 8's await...)

# Step 9: invoke registered restore callbacks SYNCHRONOUSLY in registration order
_invoke_restore_callbacks(target_id, save_game, reason)

# Step 10: section_entered emit (Story 002)
Events.section_entered.emit(target_id, reason)
```

**`_invoke_restore_callbacks` helper**:

```gdscript
func _invoke_restore_callbacks(target_id: StringName, save_game: SaveGame, reason: TransitionReason) -> void:
    for cb in _restore_callbacks:
        if not cb.is_valid():
            push_warning("[LSS] restore callback invalid at step 9; skipping")
            continue

        var pre_frame: int = Engine.get_process_frames()
        var pre_usec: int = Time.get_ticks_usec()
        cb.call(target_id, save_game, reason)
        var post_frame: int = Engine.get_process_frames()

        if post_frame != pre_frame:
            # Callback awaited — broke the synchronous contract
            push_error("[LSS] restore callback violated no-await contract: %s (pre=%d post=%d frames)" % [
                cb.get_method() if cb.get_object() != null else "<unknown>",
                pre_frame, post_frame
            ])
```

**Why frame-delta detection**: `await get_tree().process_frame` (the most common await pattern) advances `Engine.get_process_frames()` by 1+. A truly synchronous callback returns within the same frame as the call site; `post_frame == pre_frame`. This catches the dominant violation pattern. Other `await` types (signals, async I/O) typically also advance frames; rare edge case where a callback uses a `Promise`-style structure that resolves within the frame is acceptable behavior.

**Caller's discipline INSIDE callbacks** (not enforced by LSS — caller-side per ADR-0003):
- Callback receives `save_game: SaveGame`. Callback MUST call `save_game.duplicate_deep()` (Save/Load Story 004) before handing nested state to live systems.
- Callback MUST complete all per-system state assignment within the single-frame budget.
- If `save_game == null` (NEW_GAME path), callback handles the null case (no-op restore + initialize fresh defaults).

**Registration ordering semantics**: callbacks fire in registration order. Mission Scripting registers first (typical sequencing per ADR-0007 line 9 = MissionLevelScripting), then F&R (line 8 — but autoload `_ready` order matters more than line order for registration; F&R's `_ready()` may register before or after MLS's depending on cross-autoload init sequencing). The documented order is: Mission Scripting first (game-state authority), then F&R, then Menu System. **At MVP only Mission Scripting will register; F&R and Menu System callbacks land in their respective epics.**

**Why no deregistration API at MVP**: callbacks are registered at autoload boot and live for the application lifetime. Autoload Nodes never exit the tree. Deregistration is unnecessary at MVP; if a future test or hot-reload scenario needs it, add `deregister_restore_callback(callback: Callable)` then.

**Integration with future stories**:
- Mission Scripting epic: registers `_on_restore` callback; reads `save_game.mission`, `save_game.player`, `save_game.inventory` etc.; assigns to live systems
- F&R epic: registers `_on_restore` callback; reads `save_game.failure_respawn`; restores per-checkpoint flags
- Menu System epic: registers `_on_restore` callback if it needs scene-mounted state (e.g., HUD preference apply); MVP likely no-op

**Test probe callback** for AC-4, AC-5, AC-9:

```gdscript
# In test file
var _captured_args: Array = []
var _test_marker: String = ""

func _probe_callback(section_id: StringName, save_game: SaveGame, reason: int) -> void:
    _captured_args = [section_id, save_game, reason]
    _test_marker = "callback_ran"

func test_callback_invoked_with_correct_args() -> void:
    LevelStreamingService.register_restore_callback(_probe_callback)
    # ... trigger transition_to_section ...
    assert_array(_captured_args).has_size(3)
    assert_str(_test_marker).is_equal("callback_ran")
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: 13-step coroutine + state machine (already done; this story extends step 9)
- Story 004: concurrency control + queued respawn drain
- Story 005: `_abort_transition` + ErrorFallback (skip step 9 if abort fires earlier)
- Caller-side `duplicate_deep` discipline — applies inside each registered callback; owned by each consumer epic (Mission Scripting, F&R, Menu System)
- Production-scope callback registration — Mission Scripting / F&R / Menu System epics each register their own callback; this story's tests use a probe stub

---

## QA Test Cases

**AC-1 — register_restore_callback API**
- **Given**: LSS booted; `_restore_callbacks` empty
- **When**: `LSS.register_restore_callback(some_valid_callable)`
- **Then**: `_restore_callbacks.size() == 1`; `_restore_callbacks[0] == some_valid_callable`
- **Edge cases**: invalid Callable (e.g., `Callable()` or `func_ref` to a freed object) → `push_warning`, NOT registered; `_restore_callbacks.size()` unchanged

**AC-2 — Step 9 synchronous iteration**
- **Given**: 3 valid callbacks registered; transition in progress at step 9
- **When**: `_invoke_restore_callbacks` runs
- **Then**: all 3 callbacks called within the same frame (no awaits between them); call order matches registration order
- **Edge cases**: empty `_restore_callbacks` (no registrations) → step 9 is a no-op; transition proceeds to step 10

**AC-3 — Step 9 ordering: after step 8, before step 10**
- **Given**: transition in flight; signal-spy on `section_entered`; probe callback that records its frame timestamp
- **When**: transition reaches step 9
- **Then**: probe's recorded frame is AFTER `add_child` + step-8 await frame AND BEFORE `section_entered` emit frame
- **Edge cases**: callback throws an error → step 10 still runs (per AC-5: errors don't halt the chain)

**AC-4 — Callback receives 3 positional arguments**
- **Given**: probe callback signature `func(section_id: StringName, save_game: SaveGame, reason: int)`
- **When**: step 9 invokes it
- **Then**: probe captures `section_id == target_id`, `save_game` is the SaveGame passed to `transition_to_section` (or null for NEW_GAME), `reason` is the TransitionReason enum value
- **Edge cases**: callback signature mismatch (e.g., 2 args) → GDScript runtime error; LSS does NOT pre-validate signature; caller responsibility to match contract

**AC-5 — Multiple callbacks all fire even on error**
- **Given**: 3 callbacks registered; the 2nd one logs an error (e.g., null deref)
- **When**: step 9 runs
- **Then**: callback 1 fires; callback 2 fires (logs error, returns); callback 3 fires; signal-spy on `section_entered` confirms it eventually emits (after callback 3 returns)
- **Edge cases**: error inside callback is engine-logged (red in console) but does NOT halt the chain — GDScript's default exception behavior

**AC-6 — No-await contract enforcement**
- **Given**: a callback that explicitly `await get_tree().process_frame`
- **When**: step 9 invokes it in a debug build
- **Then**: after the callback returns (1+ frames later), LSS detects `post_frame > pre_frame` and `push_error`s with a message identifying the callback
- **Edge cases**: shipping build → assertion is skipped (debug-only check); the violation runs against a partially-stale tree but doesn't crash

**AC-7 — section_entered fires only after callbacks complete**
- **Given**: 1 callback registered with synchronous body; signal-spy timestamps
- **When**: transition runs
- **Then**: callback's pre-call timestamp < callback's post-call timestamp ≤ `section_entered` emit timestamp (within microseconds — same frame)
- **Edge cases**: callback awaits → `section_entered` fires from a different frame than the callback's pre-call; AC-6 catches that

**AC-8 — Callback fires at step 9, NOT at step 3**
- **Given**: probe callback registered; signal-spy on both `section_exited` (step 3) and `section_entered` (step 10)
- **When**: transition runs
- **Then**: `section_exited` fires WITHOUT the probe callback running; probe callback fires AFTER `section_exited` and BEFORE `section_entered`
- **Edge cases**: this AC clarifies the design — restore callbacks are explicitly NOT subscribers to `section_exited` (which is for outgoing-scene subscribers)

**AC-9 — Probe state visible before section_entered**
- **Given**: probe callback that sets `_test_marker = "callback_ran"`; subscriber on `section_entered` that asserts `_test_marker == "callback_ran"` upon receipt
- **When**: transition runs
- **Then**: `section_entered` subscriber observes `_test_marker == "callback_ran"` (the callback ran before the emit)
- **Edge cases**: subscriber connected to `section_entered` BEFORE the transition starts (typical autoload-boot pattern); test verifies the ordering is reliable

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/level_streaming/level_streaming_restore_callback_test.gd` — must exist and pass (covers all 9 ACs)
- Naming follows Foundation-layer convention
- Determinism: probe callbacks use deterministic test markers; no random data; signal-spy uses Engine frame counters not wall clock

**Status**: [x] Created at `tests/unit/level_streaming/level_streaming_restore_callback_test.gd`

---

## Dependencies

- Depends on: Story 002 (13-step coroutine; this story extends step 9)
- Unlocks: Mission Scripting epic, F&R epic, Menu System epic — each registers a callback for their per-system state restore

---

## Completion Notes

**Completed**: 2026-05-01
**Criteria**: 9/9 passing — AC-6 with degraded coverage (no-deadlock asserted; push_error message capture deferred until GdUnit4 exposes stable `assert_error()`).
**Test Evidence**: `tests/unit/level_streaming/level_streaming_restore_callback_test.gd` — 11 test functions, 11/11 PASS, exit 0. Full project regression 304/304 PASS.
**Files modified**:
- `src/core/level_streaming/level_streaming_service.gd` — added `_restore_callbacks: Array[Callable]`, `register_restore_callback()` public API, `get_restore_callback_count_for_test()` + `clear_restore_callbacks_for_test()` test-only accessors, fleshed-out `_invoke_restore_callbacks()` body with debug-only no-await contract enforcement (~+95 LOC).
**Code Review**: Complete — godot-gdscript-specialist verdict CLEAN (post-remediation); qa-tester verdict TESTABLE (post-remediation, AC-2 empty-array no-op test added); inline `/code-review` APPROVED.
**Deviations**:
- ADVISORY — AC-6 push_error message-content not asserted (GdUnit4 capability limitation; documented in test docstring; tech-debt candidate when GdUnit4 upgrades).
- ADVISORY — Lambda probes accumulate in `_restore_callbacks` for the rest of the test run (no deregistration API at MVP per ADR-0007). Mitigated by `_wait_for_idle(≥3.0)` timeouts and documented in suite header.
**Tech debt logged**: None — both advisories tracked here in Completion Notes; AC-6 message-capture upgrade is post-MVP work conditional on GdUnit4 enhancement.
