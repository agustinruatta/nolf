# Story 007: F5/F9 quicksave/quickload queue during transition

> **Epic**: Level Streaming
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2 hours (M — F5/F9 hooks + queue + drain at FADING_IN→IDLE)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/level-streaming.md`
**Requirement**: TR-LS-006 (queued state during in-flight transition); GDD CR-16 (queued F5/F9 during transition; drain at FADING_IN → IDLE)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007 (autoload coordination — InputContext + SaveLoad + LSS) + ADR-0003 (Save/Load API)
**ADR Decision Summary**: Per CR-16, LSS queues F5 (Quicksave) and F9 (Quickload) presses arriving during FADING_OUT/SWAPPING/FADING_IN. `_pending_quicksave: bool` and `_pending_quickload_slot: int = -1` track the queue. On FADING_IN → IDLE, LSS fires the queued action via Save/Load's normal API. Player hears save-confirm chime post-transition, not mid-cut. This replaces the Save/Load Story 007 silent-drop behavior with intent-preserved queueing.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: F5/F9 input handling owned by Save/Load Story 007's `QuicksaveInputHandler` companion Node; that handler queries `InputContext.current()` to decide whether to fire. LSS provides a different gating layer: even when InputContext is GAMEPLAY, if a transition is in flight, the press should be queued by LSS rather than fired by Save/Load. The two gates compose: InputContext.current() must be in {GAMEPLAY, MENU, PAUSE} (Save/Load's gate), AND LSS state must be IDLE (this story's gate); if LSS state is not IDLE, the press is queued for later.

**Control Manifest Rules (Foundation)**:
- Required: F5/F9 presses during FADING_OUT/SWAPPING/FADING_IN are QUEUED (CR-16)
- Required: queued presses drain at FADING_IN → IDLE transition (CR-16)
- Required: only ONE F5 and ONE F9 can be queued at a time (newer overwrites older)
- Required: `_abort_transition` clears queued presses (Story 004 already does this)
- Forbidden: silently dropping F5/F9 during transition (the behavior this story replaces)

---

## Acceptance Criteria

*From GDD §Detailed Design CR-16 + §Acceptance Criteria 1.10, 5.3:*

- [ ] **AC-1**: `_pending_quicksave: bool = false` and `_pending_quickload_slot: int = -1` are state variables on LSS, modified only via the F5/F9 queue path (or cleared via `_abort_transition`).
- [ ] **AC-2**: A public method `queue_quicksave_or_fire() -> void` is the entry point for F5 presses. If `_state == IDLE`, fires `SaveLoad.save_to_slot(0, _assemble_quicksave())` directly. If non-IDLE, sets `_pending_quicksave = true` and returns.
- [ ] **AC-3**: A public method `queue_quickload_or_fire() -> void` is the entry point for F9 presses. If `_state == IDLE` AND `SaveLoad.slot_exists(0)`, calls `SaveLoad.load_from_slot(0)` and triggers a `LOAD_FROM_SAVE` transition (Mission Scripting / consumer logic). If non-IDLE, sets `_pending_quickload_slot = 0` and returns.
- [ ] **AC-4**: GIVEN a transition in FADING_IN, WHEN `queue_quicksave_or_fire()` is called, THEN `_pending_quicksave = true`; `Save/Load.save_to_slot` is NOT called during the transition; AND on FADING_IN → IDLE transition, `Save/Load.save_to_slot(0, ...)` IS called synchronously. (AC-LS-1.10 from GDD.)
- [ ] **AC-5**: GIVEN a transition in progress, WHEN both F5 and F9 are queued, THEN both fire on FADING_IN → IDLE in order: quicksave first, then quickload (save before load to preserve player intent — or document the alternative order if implementation differs). Test verifies the ordering.
- [ ] **AC-6**: GIVEN `_pending_quicksave == true` and a SECOND F5 is pressed during transition, WHEN `queue_quicksave_or_fire` is called, THEN `_pending_quicksave` remains true (idempotent — only one quicksave will fire on drain). Same for F9: second F9 press during transition with slot 0 → no change to `_pending_quickload_slot`.
- [ ] **AC-7**: GIVEN `_abort_transition` runs (Story 005's failure path), WHEN it executes, THEN `_pending_quicksave = false` AND `_pending_quickload_slot = -1` (cleared along with other state). (Story 004 AC-4 already covers this; this story verifies `_abort_transition` clears these specific fields.)
- [ ] **AC-8**: GIVEN a transition in progress (any state other than IDLE), WHEN the player presses F5 or F9, THEN the press is queued AND no save/load action fires during the transition AND on FADING_IN → IDLE the queued action fires synchronously with full Audio feedback (save-confirm chime / load hard-cut) firing post-transition. (AC-LS-5.3 from GDD; manual walkthrough evidence.)
- [ ] **AC-9**: Save/Load's QuicksaveInputHandler (Save/Load Story 007) calls `LevelStreamingService.queue_quicksave_or_fire()` instead of `SaveLoad.save_to_slot(0, ...)` directly. The InputContext gate runs first (handler-side); the LSS state gate runs second (this story's queueing).

---

## Implementation Notes

*Derived from GDD §Detailed Design CR-16 + ADR-0003 Save/Load API:*

**State variables** (extending Story 004's pending-state additions):

```gdscript
var _pending_quicksave: bool = false
var _pending_quickload_slot: int = -1  # -1 sentinel for "no quickload pending"; 0 = quicksave slot
```

**Public methods**:

```gdscript
func queue_quicksave_or_fire() -> void:
    if _state != State.IDLE:
        _pending_quicksave = true  # idempotent
        return
    # IDLE — fire immediately
    var sg: SaveGame = _assemble_quicksave_payload()
    if sg == null:
        return
    SaveLoad.save_to_slot(0, sg)

func queue_quickload_or_fire() -> void:
    if _state != State.IDLE:
        _pending_quickload_slot = 0
        return
    # IDLE — fire immediately
    if not SaveLoad.slot_exists(0):
        Events.hud_toast_requested.emit(&"quicksave_unavailable", {})
        return
    var sg: SaveGame = SaveLoad.load_from_slot(0)
    if sg == null:
        return  # save_failed already emitted by Save/Load
    transition_to_section(sg.section_id, sg, TransitionReason.LOAD_FROM_SAVE)
```

**Drain at FADING_IN → IDLE** (extends Story 002's coroutine end + Story 004's queue drain):

```gdscript
# (At step 13 / end of coroutine, after Story 004's pending-respawn check:)
_state = State.IDLE
_transitioning = false

# F5/F9 drain (CR-16) — fires AFTER state is IDLE, BEFORE pending-respawn drain
# Order: quicksave first (preserves "I want to save my progress NOW" intent), then quickload
if _pending_quicksave:
    _pending_quicksave = false  # clear before re-entry
    queue_quicksave_or_fire()  # now in IDLE — fires immediately

if _pending_quickload_slot >= 0:
    var slot: int = _pending_quickload_slot
    _pending_quickload_slot = -1  # clear before re-entry
    # Use direct load path (queue_quickload_or_fire would re-check IDLE which is now true)
    queue_quickload_or_fire()

# Story 004's pending-respawn drain runs AFTER F5/F9 drain
if _pending_respawn_save_game != null:
    var queued_save: SaveGame = _pending_respawn_save_game
    _pending_respawn_save_game = null
    transition_to_section(_current_section_id, queued_save, TransitionReason.RESPAWN)
```

**Drain ordering rationale**: F5 (quicksave) should fire BEFORE any pending respawn — the player wanted to save the state they were in, not the post-respawn state. F9 (quickload) before respawn is moot — the quickload kicks off a LOAD_FROM_SAVE transition which will run instead of the respawn (queue-while-queued last-wins clearing); document this edge in the test.

**Edge case: F5 queued AND respawn queued AND F9 queued**:
- F5 fires (saves current state) → `save_to_slot(0)`
- F9 fires (load slot 0) → transition_to_section LOAD_FROM_SAVE — but slot 0 is what we just saved, so it's a no-op load that returns to the just-saved state
- Respawn queue: `_pending_respawn_save_game` would still be set; the new transition (from F9) might queue another respawn... or the F9-triggered transition's step 13 fires the respawn
- Documented as: the player should not realistically queue all three; ordering is best-effort and the system stays consistent

**`_assemble_quicksave_payload()` at MVP**: Foundation-layer Mission Scripting epic owns the production assembler. At MVP, this returns a stub SaveGame for testing OR delegates to a placeholder method that will be replaced by Mission Scripting when its epic ships. Save/Load Story 007 made the same point — the real assembler comes from Mission Scripting; LSS / Save/Load handlers receive an injected stub at MVP.

**Why the queueing lives on LSS (not Save/Load)**: Save/Load's input handler queries InputContext (Save/Load's discipline). The transition-state gate is LSS's concern (LSS owns `_state`). Putting the LSS gate inside Save/Load would couple Save/Load to LSS internals; cleanly inverting: Save/Load's handler delegates to LSS's queue method, LSS decides fire-vs-queue.

**Save/Load Story 007 integration update**:

```gdscript
# In src/core/save_load/quicksave_input_handler.gd (Save/Load Story 007 update)
func _try_quicksave() -> void:
    # InputContext gate (Save/Load Story 007's existing logic)
    if not _is_save_eligible_context():
        return
    # Debounce (Save/Load Story 007's existing logic)
    if _is_debounce_window():
        return
    # Delegate to LSS for transition-state gating + actual fire/queue decision
    LevelStreamingService.queue_quicksave_or_fire()
```

This means Save/Load Story 007 needs an update once this story lands; the change is small (replace direct `save_to_slot` with `LSS.queue_quicksave_or_fire()`).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: 13-step coroutine
- Story 004: respawn queue + `_abort_transition` clearing of pending fields (already done; this story adds the F5/F9 fields to that clear list)
- Save/Load Story 007: F5/F9 input handling, InputContext gating, debounce — already done in the Save/Load epic; this story updates Save/Load Story 007's handler to call into LSS
- Production `_assemble_quicksave_payload` — Mission Scripting epic
- HUD toast rendering — HUD State Signaling epic

---

## QA Test Cases

**AC-1 — Pending state variables initialized**
- **Given**: LSS booted
- **When**: a test reads `_pending_quicksave` and `_pending_quickload_slot`
- **Then**: `_pending_quicksave == false`; `_pending_quickload_slot == -1`
- **Edge cases**: post-`_abort_transition` → both reset to defaults

**AC-2 — queue_quicksave_or_fire fires immediately in IDLE**
- **Given**: `_state == IDLE`; signal-spy on `Events.game_saved`
- **When**: `LSS.queue_quicksave_or_fire()` is called
- **Then**: `SaveLoad.save_to_slot(0, ...)` was called; `Events.game_saved` fired with slot=0; `_pending_quicksave` remains false
- **Edge cases**: `_assemble_quicksave_payload` returns null → return without firing; no `Events.game_saved` emit

**AC-3 — queue_quickload_or_fire fires immediately in IDLE with slot 0 occupied**
- **Given**: `_state == IDLE`; `SaveLoad.slot_exists(0) == true`
- **When**: `LSS.queue_quickload_or_fire()` is called
- **Then**: `SaveLoad.load_from_slot(0)` was called; `transition_to_section(...)` was launched with `LOAD_FROM_SAVE` reason
- **Edge cases**: slot 0 empty → `Events.hud_toast_requested(&"quicksave_unavailable", ...)` fires instead

**AC-4 — F5 during transition queues, fires on drain**
- **Given**: transition in FADING_IN; signal-spy on `Events.game_saved`
- **When**: `queue_quicksave_or_fire()` is called during FADING_IN
- **Then**: `_pending_quicksave == true` immediately; `Events.game_saved` does NOT fire; on FADING_IN → IDLE, `_pending_quicksave` becomes false AND `Events.game_saved` fires once with slot=0
- **Edge cases**: `_pending_quicksave` was already true (second F5 within window) — no change; only one save fires on drain

**AC-5 — Both F5 and F9 queued, order on drain**
- **Given**: transition in SWAPPING; both `queue_quicksave_or_fire()` and `queue_quickload_or_fire()` are called during the transition
- **When**: `_state` reaches IDLE
- **Then**: `_pending_quicksave` was true and `_pending_quickload_slot` was 0 before drain; quicksave fires first (`Events.game_saved`); quickload fires second (`Events.game_loaded` or another transition_to_section call)
- **Edge cases**: this is an unusual scenario (player rapidly pressing both keys); document that the F9 might trigger a new LOAD_FROM_SAVE transition that overrides any queued respawn

**AC-6 — Idempotent re-queuing**
- **Given**: `_pending_quicksave == true`
- **When**: `queue_quicksave_or_fire()` is called a second time during the same transition
- **Then**: `_pending_quicksave` remains true (no change); only one quicksave fires on drain
- **Edge cases**: same for `_pending_quickload_slot` — second F9 press is idempotent

**AC-7 — _abort_transition clears pending F5/F9**
- **Given**: `_pending_quicksave == true` AND `_pending_quickload_slot == 0`
- **When**: `_abort_transition()` runs (e.g., from a step-5 failure path)
- **Then**: `_pending_quicksave == false`; `_pending_quickload_slot == -1`
- **Edge cases**: covered by Story 004 AC-4; this AC verifies the specific F5/F9 fields are in the clear list

**AC-8 — Manual walkthrough: F5 during transition produces post-transition save chime**
- **Given**: running game; player triggers a section transition; mid-transition presses F5
- **When**: transition completes
- **Then**: save-confirm chime audible AFTER the snap-reveal completes (not during the cut); save card visible if Menu is opened (slot 0 has a fresh save)
- **Edge cases**: manual playtest — evidence captured in `production/qa/evidence/` doc; full Audio integration depends on Audio epic

**AC-9 — Save/Load Story 007 handler delegates to LSS**
- **Given**: `src/core/save_load/quicksave_input_handler.gd` source (Save/Load Story 007 update)
- **When**: code review inspects `_try_quicksave` body
- **Then**: it calls `LevelStreamingService.queue_quicksave_or_fire()` (NOT `SaveLoad.save_to_slot(0, ...)` directly)
- **Edge cases**: Save/Load Story 007 was authored before this story; the update is a pull request paired with this story's landing

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/level_streaming/level_streaming_quicksave_queue_test.gd` — must exist and pass (covers AC-1 through AC-7, AC-9)
- `production/qa/evidence/level_streaming_f5_during_transition.md` — manual walkthrough evidence for AC-8 (post-transition chime + save card visible)
- Naming follows Foundation-layer convention

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (state machine), Story 004 (`_abort_transition` clears pending fields), Save/Load Story 007 (F5/F9 input handler — update required to delegate to LSS); Save/Load Story 002 (`save_to_slot`); Save/Load Story 003 (`load_from_slot`); Save/Load Story 006 (`slot_exists`)
- Unlocks: Mission Scripting epic (provides production `_assemble_quicksave_payload`); HUD State Signaling epic (renders `hud_toast_requested` toast for quicksave_unavailable)
