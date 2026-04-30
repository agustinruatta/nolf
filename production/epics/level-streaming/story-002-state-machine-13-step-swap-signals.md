# Story 002: State machine + 13-step swap happy path + signal emission with TransitionReason

> **Epic**: Level Streaming
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 4 hours (L — 4-state state machine + 13-step coroutine + signal emit + InputContext push/pop)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/level-streaming.md`
**Requirement**: TR-LS-005 (13-step fixed-sequence swap), TR-LS-007 (TransitionReason enum on signals), TR-LS-009 (InputContext.LOADING push at step 1, pop at step 12), TR-LS-011 (perf budget ≤0.57s p90)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007 (autoload order) + ADR-0002 (signal taxonomy with `reason` 2nd param — 4th-pass amendment 2026-04-22)
**ADR Decision Summary**: ADR-0002 4th-pass amendment (2026-04-22, Accepted via Sprint 01) declares `Events.section_entered(section_id: StringName, reason: LevelStreamingService.TransitionReason)` and `Events.section_exited(section_id: StringName, reason: LevelStreamingService.TransitionReason)` — `LevelStreamingService` is the sole emitter. `InputContext.Context.LOADING` enum value is added 2026-04-28 (closes LS-Gate-2). The 13-step swap is a manual pattern (NOT `change_scene_to_packed` — godot-specialist review: that API creates a one-frame `current_scene == null` window unacceptable for an ordered-lifecycle service).

**Engine**: Godot 4.6 | **Risk**: MEDIUM (post-Sprint-01 verifications closed; OQ-LS-11 step-7 `current_scene` direct assignment flagged for verification at implementation time)
**Engine Notes**: `await get_tree().process_frame` is the canonical frame-defer pattern. `add_child` triggers `_ready()` synchronously (per godot-specialist clarification 2026-04-21 — the `await` at step 8 protects against `call_deferred` chains inside `_ready()`, NOT `_ready()` itself). `current_scene` direct reassignment per step 7 (`get_tree().current_scene = instance`) is OQ-LS-11 — verify against Godot 4.6 SceneTree invariants at implementation time; if unsafe, escalate via dedicated spike before completing the story.

**Control Manifest Rules (Foundation)**:
- Required: 13-step fixed sequence (TR-LS-005)
- Required: `Events.section_exited` emit at step 3 with `is_instance_valid(outgoing_scene) == true`; `Events.section_entered` emit at step 10 (signal contract per ADR-0002)
- Required: `InputContext.LOADING` push at step 1 / pop at step 12 (TR-LS-009)
- Forbidden: `change_scene_to_packed` for section transitions (godot-specialist rationale per CR-5)
- Performance: ≤0.57 s total p90; ≤500 ms SWAPPING phase

---

## Acceptance Criteria

*From GDD §Acceptance Criteria 1.0–1.4 + 3.1a/b/c:*

- [ ] **AC-1**: `transition_to_section(section_id: StringName, save_game: SaveGame = null, reason: TransitionReason = TransitionReason.FORWARD) -> void` is the public entry point. Calling it with valid args from IDLE state begins the 13-step sequence.
- [ ] **AC-2**: GIVEN LSS in IDLE, WHEN `transition_to_section(&"plaza", null, NEW_GAME)` is called, THEN on the SAME call frame (before any await) `InputContext.current_stack().has(InputContext.Context.LOADING) == true` AND state machine enters FADING_OUT AND `_transitioning == true`. (AC-LS-1.0 + AC-LS-1.1 from GDD.)
- [ ] **AC-3**: GIVEN state is FADING_OUT, WHEN 2 `process_frame` awaits resolve (snap-to-black complete), THEN state transitions to SWAPPING AND fade overlay `ColorRect.color.a == 1.0`. (AC-LS-1.2 from GDD.)
- [ ] **AC-4**: GIVEN state is SWAPPING and `Events.section_entered` has been emitted (step 10), THEN state transitions to FADING_IN. (AC-LS-1.3 from GDD.)
- [ ] **AC-5**: GIVEN state is FADING_IN, WHEN 2 `process_frame` awaits resolve (snap-reveal complete), THEN state returns to IDLE AND `_transitioning == false` AND `InputContext.LOADING` is NOT on the stack AND fade overlay `ColorRect.color.a == 0.0`. (AC-LS-1.4 from GDD.)
- [ ] **AC-6**: At step 3, `Events.section_exited(outgoing_id, reason)` is emitted AND `is_instance_valid(outgoing_scene) == true` at emit time (the scene is still in the tree; queue_free runs at step 4 AFTER the emit). (AC-LS-2.1 from GDD.)
- [ ] **AC-7**: At step 10, `Events.section_entered(target_id, reason)` is emitted; this happens AFTER `add_child(instance)` (step 7) and `await process_frame` (step 8) have resolved. (AC-LS-2.2 from GDD.)
- [ ] **AC-8**: GIVEN integration test from a starting `plaza` scene with `transition_to_section(&"stub_b", null, NEW_GAME)`, WHEN the 13-step sequence completes, THEN `get_tree().current_scene == stub_b_instance` AND the `plaza` instance is freed (`is_instance_valid(old_scene_ref) == false`). (AC-LS-3.1a from GDD.)
- [ ] **AC-9**: After the same integration test, `Events.section_exited` fired exactly once with `(&"plaza", TransitionReason.NEW_GAME)` AND `Events.section_entered` fired exactly once with `(&"stub_b", TransitionReason.NEW_GAME)`. (AC-LS-3.1b from GDD.)
- [ ] **AC-10**: After the same integration test, `_transitioning == false` AND `InputContext.LOADING` not on stack AND `_pending_respawn_save_game == null` AND `_pending_quicksave == false`. (AC-LS-3.1c from GDD.)

---

## Implementation Notes

*Derived from GDD §Detailed Design CR-5 (the 13-step sequence verbatim) + §States and Transitions:*

**State enum**:

```gdscript
enum State { IDLE, FADING_OUT, SWAPPING, FADING_IN }
var _state: int = State.IDLE
var _transitioning: bool = false
var _current_section_id: StringName = &""
```

**Public method**:

```gdscript
func transition_to_section(
    section_id: StringName,
    save_game: SaveGame = null,
    reason: TransitionReason = TransitionReason.FORWARD
) -> void:
    if not _registry_valid:
        push_error("[LSS] transition rejected — registry invalid")
        return
    # Step 1: synchronous push (visible on the same call frame per AC-2)
    InputContext.push(InputContext.Context.LOADING)
    _transitioning = true
    _state = State.FADING_OUT
    _run_swap_sequence(section_id, save_game, reason)  # async coroutine; NOT awaited at the public API
```

**13-step coroutine** (per CR-5 verbatim):

```gdscript
func _run_swap_sequence(target_id: StringName, save_game: SaveGame, reason: TransitionReason) -> void:
    var outgoing_id: StringName = _current_section_id
    var outgoing_scene: Node = get_tree().current_scene

    # Step 2: SNAP overlay 0 → 1 over 2 frames
    _fade_rect.color.a = 0.0
    await get_tree().process_frame
    _fade_rect.color.a = 0.5
    await get_tree().process_frame
    _fade_rect.color.a = 1.0

    _state = State.SWAPPING

    # Step 3: emit section_exited (scene STILL in tree)
    Events.section_exited.emit(outgoing_id, reason)

    # Step 3a: disconnect any LS-owned signal connections from outgoing scene nodes
    # (placeholder — populated as future stories add such connections)

    # Step 4: registry pre-check, then queue_free
    if not _registry.has(target_id):
        _abort_transition()  # Story 005
        push_error("[LSS] section_id %s not in registry" % target_id)
        return
    if outgoing_scene != null:
        outgoing_scene.queue_free()

    # Step 5: load PackedScene
    var path: String = _registry.path(target_id)
    var packed: PackedScene = ResourceLoader.load(path) as PackedScene
    if packed == null:
        _abort_transition()
        push_error("[LSS] PackedScene load failed for %s at %s" % [target_id, path])
        return

    # Step 6: instantiate
    var instance: Node = packed.instantiate()
    if instance == null:
        _abort_transition()
        push_error("[LSS] instantiate failed for %s" % target_id)
        return

    # Step 7: add to tree + reassign current_scene (OQ-LS-11 — verify at implementation time)
    get_tree().root.add_child(instance)
    get_tree().current_scene = instance

    # Step 8: await frame to let _ready()'s call_deferred chains propagate
    await get_tree().process_frame

    # Step 9: invoke registered restore callbacks (Story 003)
    _invoke_restore_callbacks(target_id, save_game, reason)

    # Step 10: emit section_entered
    _current_section_id = target_id
    Events.section_entered.emit(target_id, reason)

    _state = State.FADING_IN

    # Step 11: SNAP overlay 1 → 0 over 2 frames
    _fade_rect.color.a = 1.0
    await get_tree().process_frame
    _fade_rect.color.a = 0.5
    await get_tree().process_frame
    _fade_rect.color.a = 0.0

    # Step 12: pop InputContext.LOADING
    InputContext.pop(InputContext.Context.LOADING)

    # Step 13: process queued respawn (Story 004 — drain logic; this story leaves it as a stub no-op)
    _state = State.IDLE
    _transitioning = false
    # Story 004 adds: if _pending_respawn_save_game != null: reload_current_section(_pending_respawn_save_game)
```

**Why step 1 is synchronous before the coroutine begins**: AC-LS-1.0 demands `InputContext.LOADING` be on the stack on the SAME call frame as `transition_to_section`. Pushing inside the coroutine before the first await would also satisfy this, but pulling it ahead of the coroutine is cleaner and matches the public API's "transition has begun" semantics.

**Why `_run_swap_sequence` is fire-and-forget (not awaited)**: the public API `transition_to_section` is sync-return. Callers don't need to await the full transition; subscribers wait via `Events.section_entered`. The coroutine runs detached.

**Why step 4's queue_free runs AFTER step 3's emit**: per CR-13, subscribers MUST receive `section_exited` while the outgoing scene is still in the tree (so they can read final state synchronously). Queueing free before the emit would void the contract. Story 009 will register the CR-13 sync-subscriber violation lint as a forbidden pattern.

**Why step 8 awaits one frame after `add_child`**: `_ready()` fires synchronously inside `add_child`, but `_ready()` may itself call `call_deferred(...)` which queues work for the NEXT frame. The await ensures those deferred chains complete before step 9's restore callbacks run.

**OQ-LS-11 verification gate**: step 7's `get_tree().current_scene = instance` is flagged as needing godot-specialist verification against Godot 4.6 SceneTree invariants. At implementation time: confirm via headless test that this assignment works (scene is registered, `get_tree().current_scene` returns the new instance, no warnings logged). If unsafe, alternative: skip the assignment and rely on `add_child` to register the new scene; subsequent `current_scene` reads return the most-recently-added top-level child. Verify and document in `production/qa/evidence/`.

**`_abort_transition()` is a stub here**: Story 005 implements the full logic (set state IDLE, pop LOADING, reset overlay alpha, clear pending queues). For this story, a minimal stub is fine — `_state = IDLE; _transitioning = false; InputContext.pop(LOADING); _fade_rect.color.a = 0.0`.

**Step 9 callback invocation is also stubbed here**: Story 003 implements `register_restore_callback` + the synchronous invocation loop. For AC-LS-3.7 (callback round-trip) integration test, Story 003 adds the production path; this story's tests focus on AC-LS-1.x state machine + AC-LS-3.1x signal-and-scene round-trip without callbacks.

**Performance instrumentation**: Story 010 measures the p90 budget (AC-LS-6.1). This story's tests verify functional correctness only, not timing. Add a `VERBOSE_TRANSITION_LOGGING` flag-gated `Time.get_ticks_usec()` log at step 1 entry and step 12 exit so Story 010 can compute deltas.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: autoload registration + fade overlay scaffold (already done)
- Story 003: `register_restore_callback` + step 9 sync invocation
- Story 004: concurrency control — drop forward, queue respawn, queue drain at step 13
- Story 005: `_abort_transition` + ErrorFallback display logic
- Story 006: same-section no-op guard, focus-loss handling, cache mode
- Story 007: F5/F9 quicksave queue during transition
- Story 008: stub `plaza.tscn` + `stub_b.tscn` scenes (CR-9 contract)
- Story 010: perf measurement (p90 budget verification)

---

## QA Test Cases

**AC-1 — `transition_to_section` public method**
- **Given**: LSS in IDLE state with valid registry
- **When**: a test calls `transition_to_section(&"plaza", null, TransitionReason.NEW_GAME)`
- **Then**: function returns immediately (does not block); the coroutine has been launched
- **Edge cases**: invalid registry → `push_error` and immediate return without launching coroutine (covered by Story 005's tests; this story's path requires registry valid)

**AC-2 — Step 1 push + state transition on same frame**
- **Given**: LSS in IDLE; `InputContext.LOADING` not on stack
- **When**: `transition_to_section(...)` is called; the test reads state on the SAME frame (before any frame advance)
- **Then**: `InputContext.current_stack().has(InputContext.Context.LOADING) == true`; `_state == State.FADING_OUT`; `_transitioning == true`
- **Edge cases**: any await before the push → fails AC-LS-1.0 (the push must be synchronous)

**AC-3 — FADING_OUT → SWAPPING after 2 frames**
- **Given**: LSS just entered FADING_OUT (per AC-2)
- **When**: 2 process_frames advance
- **Then**: `_state == State.SWAPPING`; `_fade_rect.color.a == 1.0`
- **Edge cases**: 1 frame elapsed → still FADING_OUT (not yet snapped to black); 3+ frames → SWAPPING (transition completed)

**AC-4 — SWAPPING → FADING_IN after section_entered**
- **Given**: LSS in SWAPPING with successful load + instantiate at step 7
- **When**: step 10 emits `Events.section_entered`
- **Then**: `_state == State.FADING_IN` immediately after the emit
- **Edge cases**: emit suppressed by abort path → state goes to IDLE via `_abort_transition` instead (Story 005)

**AC-5 — FADING_IN → IDLE on snap-reveal complete**
- **Given**: LSS in FADING_IN
- **When**: 2 process_frames advance
- **Then**: `_state == State.IDLE`; `_transitioning == false`; `InputContext.LOADING` not on stack; `_fade_rect.color.a == 0.0`
- **Edge cases**: this is the canonical "transition complete" state; test asserts all 4 invariants

**AC-6 — section_exited emit at step 3 with valid outgoing scene**
- **Given**: LSS at step 3 of the coroutine; signal-spy on `Events.section_exited`
- **When**: step 3 executes
- **Then**: signal emitted exactly once with `(outgoing_id, reason)` arguments; at emit time `is_instance_valid(outgoing_scene) == true`
- **Edge cases**: outgoing scene was `null` (first NEW_GAME from main menu) → emit fires with `outgoing_id = &""` and `outgoing_scene` not validated; document this edge

**AC-7 — section_entered emit at step 10**
- **Given**: LSS reached step 10 with valid loaded scene
- **When**: step 10 executes
- **Then**: signal emitted exactly once with `(target_id, reason)`; emission AFTER `add_child` and the step-8 await have completed (verifiable by signal-spy timestamp comparison vs. `_ready()` call timestamp on the new scene)
- **Edge cases**: registered restore callbacks (Story 003) are invoked between step 9 and step 10 — section_entered emits after they return synchronously

**AC-8 — Full plaza → stub_b round trip (integration)**
- **Given**: integration test setup with `plaza` as `current_scene` (instantiated and added to tree); registry has both `plaza` and `stub_b` entries; stub scenes exist (Story 008 dependency)
- **When**: `transition_to_section(&"stub_b", null, TransitionReason.NEW_GAME)` is called and all coroutine awaits resolve
- **Then**: `get_tree().current_scene == stub_b_instance`; the prior `plaza` Node is freed (`is_instance_valid(plaza_ref) == false` after a frame for queue_free to process)
- **Edge cases**: stub scenes don't exist yet at story implementation time → use mock paths; fully-fledged integration test runs after Story 008 ships the stubs

**AC-9 — Both signals fire with correct payloads**
- **Given**: same as AC-8; signal-spy on both signals
- **When**: transition completes
- **Then**: `section_exited` fired with `(&"plaza", TransitionReason.NEW_GAME)`; `section_entered` fired with `(&"stub_b", TransitionReason.NEW_GAME)`; each fires exactly once
- **Edge cases**: `outgoing_id` was `&""` (first transition from main-menu boot) → `section_exited` fires with `(&"", NEW_GAME)`; subscribers handle empty-string outgoing as "no prior section"

**AC-10 — Clean state after successful transition**
- **Given**: same integration setup; transition completes
- **When**: state inspection
- **Then**: `_transitioning == false`; `InputContext.LOADING` not on stack; `_pending_respawn_save_game == null` (Story 004 will populate this; default null in this story); `_pending_quicksave == false` (Story 007 will populate; default false)
- **Edge cases**: any of the four conditions failing indicates incomplete cleanup — likely an `_abort_transition` was called silently; test catches this

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/level_streaming/level_streaming_state_machine_test.gd` — must exist and pass (covers AC-1 through AC-7)
- `tests/integration/level_streaming/level_streaming_swap_test.gd` — must exist and pass (covers AC-8 through AC-10; depends on Story 008's stub scenes)
- `production/qa/evidence/level_streaming_oq_ls_11_verification.md` — verification log for OQ-LS-11 (`get_tree().current_scene = instance` safety on Godot 4.6.x)
- Naming follows Foundation-layer convention

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (autoload + fade overlay + registry); ADR-0002 (Accepted) for `section_entered`/`section_exited` 2-param signal declarations; `InputContext.Context.LOADING` enum value (per ADR-0002 2026-04-28 amendment); Story 008's stub scenes for full integration test (test can use mocks until Story 008 ships)
- Unlocks: Story 003 (callback chain at step 9), Story 004 (concurrency atop 13-step), Story 005 (abort recovery during 13-step), Story 010 (perf measurement)
