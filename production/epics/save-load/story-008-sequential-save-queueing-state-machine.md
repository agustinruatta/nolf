# Story 008: Sequential save queueing (IDLE / SAVING / LOADING state machine)

> **Epic**: Save / Load
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 1-2 hours (S — internal state machine wrapping save_to_slot / load_from_slot; sequential queue)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/save-load.md`
**Requirement**: GDD §Detailed Design States and Transitions (`IDLE` / `SAVING` / `LOADING` state machine); GDD AC-8 (concurrent saves serialize sequentially)
*(No dedicated TR-ID for this internal concern; covers GDD AC-8 plus §Edge Cases "two simultaneous save requests" + "new game while save-in-progress" + "Load Game screen while LOADING state".)*

**ADR Governing Implementation**: ADR-0003 (Save Format Contract)
**ADR Decision Summary**: SaveLoadService is a thin service with three internal states: `IDLE` (no I/O in progress; default), `SAVING` (atomic write in progress; ≤10 ms; blocks a second concurrent save call AND blocks Quickload), `LOADING` (ResourceLoader read + caller's duplicate_deep + scene transition; ≤2 ms I/O hidden inside Level Streaming's 200–500 ms scene load; blocks any save call AND blocks a second load call). The state machine ensures atomic-write semantics are not violated by overlapping calls.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GDScript is single-threaded for the main scripting context; the only way two save calls can interleave in practice is via signal handlers re-entering the service (e.g., `Events.section_entered` triggers Mission Scripting to call `save_to_slot` while a Pause Menu "Save Game" call is mid-flight). The state machine guards against re-entrance and against deferred-call patterns where a queued call fires during the SAVING window.

**Control Manifest Rules (Foundation)**:
- Required: SaveLoadService internal state is one of `IDLE`, `SAVING`, `LOADING` per GDD §Detailed Design States table
- Required: SAVING state blocks: (a) a second concurrent save call (queues it sequentially), (b) Quickload calls (Story 007 — F9 must not race a save)
- Required: LOADING state blocks: (a) any save call (queues it sequentially after load completes), (b) a second load call
- Required: post-completion of the in-flight operation, the next queued operation processes (FIFO order)

---

## Acceptance Criteria

*From GDD §Acceptance Criteria + GDD §Detailed Design States and Transitions + GDD §Edge Cases:*

- [ ] **AC-1**: `SaveLoadService` exposes a public read-only state property `current_state: int` (returns one of the `State` enum values: `IDLE`, `SAVING`, `LOADING`). Default state on `_ready()` is `IDLE`.
- [ ] **AC-2**: GIVEN `current_state == IDLE`, WHEN `save_to_slot(N, sg)` is called, THEN state transitions to `SAVING` AND on completion (success or failure) state returns to `IDLE`. Verifiable via state-spy on entry + exit.
- [ ] **AC-3**: GIVEN a save is in progress (`current_state == SAVING`) and a second `save_to_slot(M, sg2)` call is made, WHEN the second call is processed, THEN it is queued AND processes sequentially after the first completes. (AC-8 from GDD: "the second call is queued and processes sequentially after the first completes — no overlapping writes".)
- [ ] **AC-4**: GIVEN sequential queueing in AC-3, WHEN both saves complete, THEN BOTH `Events.game_saved` emits fire — first for slot N, then for slot M, in the order the calls were made (FIFO).
- [ ] **AC-5**: GIVEN a load is in progress (`current_state == LOADING`) and a `save_to_slot(N, sg)` call is made, WHEN the save call is processed, THEN it is queued until the load completes; on load completion the state transitions LOADING → IDLE → SAVING and the save processes.
- [ ] **AC-6**: GIVEN a load is in progress (`current_state == LOADING`) and a second `load_from_slot(M)` call is made, WHEN the second load is processed, THEN it is queued sequentially (matches the save case — no concurrent loads either).
- [ ] **AC-7**: GIVEN both an autosave (Mission Scripting on `section_entered`) and a player F5 Quicksave fire in the same frame, WHEN both `save_to_slot` calls reach the service, THEN both saves complete (one immediately, one queued) AND both targeted slots are written correctly. If both target slot 0 (e.g., autosave + F5 both write slot 0), the LATTER completes after the former — the latter overwrites the former (per GDD edge case "two simultaneous save requests… the latter one wins if both target slot 0").
- [ ] **AC-8**: Queue depth limit: ≤4 pending operations. A 5th queued operation is rejected with a logged warning AND returns `false` from `save_to_slot` immediately (defense-in-depth against runaway signal cascades). At MVP, exceeding the queue is treated as an exceptional condition not a normal flow — log + drop, do not silently lose saves silently. Future: revisit if 4 is too low.
- [ ] **AC-9**: GIVEN the state machine wraps `save_to_slot` and `load_from_slot`, WHEN code review inspects `save_load_service.gd`, THEN the public methods (`save_to_slot`, `load_from_slot`) are the ONLY entry points to the queue — internal `_save_to_slot_atomic` (Story 002 helper) is NOT queued separately (it runs inside the SAVING state set by the public method).
- [ ] **AC-10**: State exit on synchronous-failure path: GIVEN `save_to_slot` fails inside the atomic write (Story 002 IO_ERROR / RENAME_FAILED paths), WHEN the failure handlers fire, THEN state transitions back to IDLE before `Events.save_failed` emits — so a subscriber that immediately calls `save_to_slot` again from the failure handler does NOT see a stale SAVING state.

---

## Implementation Notes

*Derived from GDD §Detailed Design States and Transitions + §Edge Cases:*

```gdscript
enum State { IDLE, SAVING, LOADING }

var current_state: int = State.IDLE
var _queue: Array = []  # Array of Callable; max 4 entries
const MAX_QUEUE_DEPTH: int = 4

func save_to_slot(slot: int, save_game: SaveGame) -> bool:
    if current_state != State.IDLE:
        return _enqueue(func(): _do_save(slot, save_game))
    return _do_save(slot, save_game)

func load_from_slot(slot: int) -> SaveGame:
    if current_state != State.IDLE:
        # Defer load; return null to indicate "not yet loaded"
        # NOTE: This is the simplest pattern but loses the synchronous return
        # contract. Alternative: block (synchronously process queue + then load)
        # — but that defeats the queue semantics. The cleanest pattern is:
        # callers must check current_state != IDLE before calling load_from_slot,
        # OR await Events.game_loaded / save_failed signal.
        # For MVP, document the contract: load_from_slot returns null if not IDLE,
        # caller subscribes to game_loaded for async completion.
        push_warning("load_from_slot(%d) called while busy (state=%d) — queuing" % [slot, current_state])
        _enqueue(func(): _do_load(slot))
        return null
    return _do_load(slot)

func _do_save(slot: int, sg: SaveGame) -> bool:
    current_state = State.SAVING
    var ok: bool = _save_to_slot_atomic(slot, sg)  # Story 002 + 005 + 006 logic
    current_state = State.IDLE
    _drain_queue()
    return ok

func _do_load(slot: int) -> SaveGame:
    current_state = State.LOADING
    var sg: SaveGame = _load_from_slot_internal(slot)  # Story 003 logic
    current_state = State.IDLE
    _drain_queue()
    return sg

func _enqueue(op: Callable) -> bool:
    if _queue.size() >= MAX_QUEUE_DEPTH:
        push_warning("Save/Load queue full (%d) — dropping operation" % _queue.size())
        return false
    _queue.append(op)
    return true

func _drain_queue() -> void:
    if _queue.is_empty():
        return
    var next: Callable = _queue.pop_front()
    next.call()  # may set state again, may enqueue more
```

**Re-entrance protection**: `_do_save` and `_do_load` set state on entry, clear on exit, then call `_drain_queue()`. If the drained operation enqueues another (e.g., a `game_saved` signal handler triggers another save), the new enqueue happens during the new state set by the next operation — no race.

**Async semantics for load_from_slot**: the current API is synchronous return. If the service is busy when load is called, the caller gets `null` and a warning. This is acceptable for MVP because:
- The Pause Menu Load flow shows a "loading…" overlay, so an async-via-signal pattern fits naturally
- F9 Quickload (Story 007) checks `slot_exists` first, then calls — race window is small
- Mission Scripting's `section_entered` chain is synchronous; the only loads it triggers are at section transitions, which already require a clean state

If a future audit shows synchronous-return-when-busy is too brittle, refactor to a Promise/Future pattern. Out of scope for MVP.

**Why MAX_QUEUE_DEPTH = 4**: realistic worst case is 2 (autosave from Mission Scripting + player F5 in the same frame). 4 gives 2× headroom. A 5th queued op indicates a runaway signal cascade — log + drop is the right defense.

**State enum vs string**: enum is type-safe and matches GDD's typed treatment. `current_state: int` is an enum value cast to int (Godot's enum convention).

**No async/threaded saves** (per ADR-0003 §Performance Implications): the budget is ≤10 ms per save synchronous, ≤2 ms load. Threading would add complexity without measurable payoff at this scale. The state machine handles the only realistic concurrency concern (re-entrance from signal handlers).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: atomic write protocol (already done; this story wraps it)
- Story 003: load + type-guard (already done; this story wraps it)
- Story 005: metadata sidecar (already integrated into atomic write helper)
- Story 006: 8-slot scheme + CR-4 mirror (already done; mirror is internal to `save_to_slot`, queue sees one public call per save regardless of mirror)
- Story 007: F5/F9 input handlers (already done; F5/F9 call public methods, queue handles serialization)
- Threading or async I/O (not in MVP scope per ADR-0003 §Performance)
- Promise/Future pattern for `load_from_slot` async (deferred to post-MVP if needed)

---

## QA Test Cases

**AC-1 — current_state default + read access**
- **Given**: fresh `SaveLoadService` instance from autoload
- **When**: a unit test reads `SaveLoad.current_state`
- **Then**: returns `SaveLoadService.State.IDLE`; the property is read-only (no public setter; setter is private/internal)
- **Edge cases**: state read during autoload `_ready()` — must already be `IDLE` (default initializer)

**AC-2 — IDLE → SAVING → IDLE on save**
- **Given**: state-spy hooked to `current_state` changes; populated SaveGame
- **When**: `save_to_slot(0, sg)` runs to completion (success path)
- **Then**: state-spy log: `IDLE → SAVING → IDLE`; final state is `IDLE` after `Events.game_saved` emit
- **Edge cases**: failure path — state still returns to IDLE before save_failed emits (covered in AC-10)

**AC-3 — Concurrent save calls queue sequentially**
- **Given**: `current_state == IDLE`; signal-spy on `Events.game_saved`
- **When**: a test scene fires `save_to_slot(0, sg1)` then immediately fires `save_to_slot(3, sg2)` in the same frame (the second call enters during the first's `_do_save`)
- **Then**: both saves eventually complete; `slot_0.res` and `slot_3.res` both exist; both `Events.game_saved` emits fire (one for slot 0, then one for slot 3); the second emit fires AFTER the first (FIFO order); no overlapping atomic-write tmp files
- **Edge cases**: simulating "in the same frame" — use `call_deferred` or directly invoke from inside the first's signal handler to force re-entry

**AC-4 — FIFO queue order**
- **Given**: queue scenario from AC-3
- **When**: signal-spy records emit timestamps
- **Then**: emit for slot 0 happens before emit for slot 3 (microsecond comparison); queue is FIFO not LIFO
- **Edge cases**: ordering matters for cross-system observers (Audio plays save chime; multiple saves in close succession should chime in queue order)

**AC-5 — LOADING blocks save (queued)**
- **Given**: `current_state == LOADING` (manually set or by triggering `load_from_slot`); a save is requested
- **When**: `save_to_slot(0, sg)` is called during the LOADING window
- **Then**: the save call is queued; on load completion, state transitions LOADING → IDLE → SAVING; the save then completes; both `Events.game_loaded` and `Events.game_saved` emits fire (load first, save second)
- **Edge cases**: if the load fails (corrupt/version-mismatch), state still returns to IDLE; the queued save still processes

**AC-6 — Concurrent load calls queue**
- **Given**: a load is in progress
- **When**: a second `load_from_slot(M)` is called
- **Then**: the second load is queued; first load completes, then second load processes; both `Events.game_loaded` emits fire in FIFO order
- **Edge cases**: Menu System's "Load Game" button is debounced at the UI level — but if a second click leaks through, the queue catches it

**AC-7 — Autosave + F5 in same frame both complete**
- **Given**: Mission Scripting's `section_entered` handler fires `save_to_slot(0, sg_autosave)`; in the same frame, F5 fires `save_to_slot(0, sg_f5)` (both target slot 0)
- **When**: both calls reach the service
- **Then**: both saves complete (one immediately, one queued); `slot_0.res` after the dust settles contains `sg_f5`'s payload (latter wins per GDD edge case); two `Events.game_saved` emits fire (both with slot=0)
- **Edge cases**: latter-wins semantics — if reversed (F5 first, autosave second), `slot_0.res` would contain autosave's payload; either order is correct per GDD intent (most recent intent wins)

**AC-8 — Queue overflow drops with warning**
- **Given**: `current_state == SAVING` (a save is in progress); 4 ops are already queued (`MAX_QUEUE_DEPTH`)
- **When**: a 5th `save_to_slot` call is made
- **Then**: returns `false` immediately; logs a warning ("queue full"); the 5th save is NOT scheduled; the existing 4 queued ops process normally
- **Edge cases**: dropped saves are exceptional — Mission Scripting / F&R should never queue more than 1 save in flight; this AC catches runaway signal cascades

**AC-9 — Public methods are sole entry points**
- **Given**: `src/core/save_load/save_load_service.gd` source
- **When**: a code-review test inspects which methods modify `current_state`
- **Then**: only `_do_save` and `_do_load` modify state; only `save_to_slot` and `load_from_slot` (public) call them; `_save_to_slot_atomic` (Story 002 helper) does NOT touch state directly
- **Edge cases**: future refactors that add a third public method (e.g., `save_screenshot_only`) — must integrate with the state machine via the same pattern

**AC-10 — State returns to IDLE before failure emit**
- **Given**: `save_to_slot(0, sg)` is called; the atomic-write fails (mock injection forces non-OK)
- **When**: the failure path runs
- **Then**: state-spy log: `IDLE → SAVING → IDLE` (back to IDLE BEFORE `Events.save_failed.emit` fires); a subscriber to `save_failed` that calls `save_to_slot` synchronously sees `current_state == IDLE` and proceeds (does not get stuck in SAVING)
- **Edge cases**: a save_failed subscriber that immediately retries the failed save — state machine allows it (caller's choice; service does not auto-retry per IG 9)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/save_load_state_machine_test.gd` — must exist and pass (covers all 10 ACs)
- Naming follows Foundation-layer convention
- Determinism: state transitions are deterministic given a fixed call sequence; tests do not rely on real file system timing — use mock injection for fault-path ACs (AC-10)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (`save_to_slot` core path is wrapped here), Story 003 (`load_from_slot` core path is wrapped here), Story 006 (slot scheme — public `save_to_slot` includes CR-4 mirror, queue sees the public boundary)
- Unlocks: Story 007 (F5/F9 path correctness depends on state machine catching concurrent calls); Mission Scripting epic (autosave + manual save coordination relies on queueing)
