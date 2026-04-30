# Story 007: Quicksave (F5) / Quickload (F9) + InputContext gating

> **Epic**: Save / Load
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2 hours (M — F5/F9 input handlers + 4-state InputContext gate + HUD toast emit)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/save-load.md`
**Requirement**: TR-SAV-014 (Quicksave F5 / Quickload F9 — non-blocking, brief HUD toast on success/failure), TR-SAV-015 (saves blocked during non-GAMEPLAY/MENU/PAUSE InputContext)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Save Format Contract) + ADR-0004 (UI Framework — InputContext stack)
**ADR Decision Summary**: F5 fires `save_to_slot(0, sg)` if `InputContext.current() in {GAMEPLAY, MENU, PAUSE}` (extended 2026-04-28 per GDD CR-6 to also exclude `DOCUMENT_OVERLAY`, `MODAL`, `LOADING`). F9 fires `load_from_slot(0)` if `slot_exists(0)`; otherwise emits a HUD toast "No quicksave available". InputContext-gated keypresses are silently dropped (no error dialog, no deferred-save queue) — the player must close the overlay/modal/cutscene to re-enable F5. F5/F9 are bound to the `quicksave` and `quickload` actions in Input's action catalog (per Input GDD).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Input.is_action_just_pressed(action_name)` is stable. `InputContext` is an autoload at line 4 (per ADR-0007); SaveLoad at line 3 → SaveLoad's `_ready()` MUST NOT reference InputContext (line 4 is later). InputContext queries should happen at input-event time (`_unhandled_input` or `_input`), not at SaveLoad's `_ready()`. SaveLoad's input handler is in a scene-attached helper Node, NOT in the autoload itself, since the autoload's `_ready()` precedes InputContext per the registration order — moving the input handler to a child Node sidesteps the load-order issue.

**Control Manifest Rules (Foundation)**:
- Required: F5 fires only if `InputContext.current() in {GAMEPLAY, MENU, PAUSE}` per GDD CR-6 (extended 2026-04-28)
- Required: F9 fires only if `slot_exists(0)`; if not, emit HUD toast "No quicksave available" (per GDD §Detailed Design Quicksave/Quickload UX sketch)
- Required: gated keypresses are silently dropped — no deferred queue, no error dialog (per Input GDD context-gating rules)
- Forbidden: SaveLoadService's `_ready()` referencing `InputContext` (line 4 — later than line 3) per ADR-0007 §Cross-Autoload Reference Safety rule 3
- Performance: F5 quicksave latency target ≤10 ms (same budget as `save_to_slot` from ADR-0003)

---

## Acceptance Criteria

*From GDD §Acceptance Criteria + GDD §Detailed Design Quicksave/Quickload UX sketch:*

- [ ] **AC-1**: GIVEN player presses F5 with `InputContext.current() == GAMEPLAY`, WHEN the input handler runs, THEN `SaveLoad.save_to_slot(0, sg)` is called AND on success `Events.game_saved.emit(0, ...)` fires AND a HUD toast signal "Quicksave to slot 0" is emitted (HUD State Signaling owns the visual; this story emits the data signal). (AC-3 from GDD.)
- [ ] **AC-2**: GIVEN player presses F5 with `InputContext.current() == CUTSCENE`, WHEN the input handler runs, THEN no save fires AND no HUD toast emit AND no signals fire (silent no-op per CR-6). (AC-4 from GDD.)
- [ ] **AC-3**: GIVEN player presses F5 with `InputContext.current() == DOCUMENT_OVERLAY`, WHEN the input handler runs, THEN no save fires (silent no-op; same gating as CUTSCENE per 2026-04-28 CR-6 extension).
- [ ] **AC-4**: GIVEN player presses F5 with `InputContext.current() == MODAL`, WHEN the input handler runs, THEN no save fires.
- [ ] **AC-5**: GIVEN player presses F5 with `InputContext.current() == LOADING`, WHEN the input handler runs, THEN no save fires.
- [ ] **AC-6**: GIVEN player presses F9 with `slot_exists(0) == false`, WHEN the input handler runs, THEN no load fires AND a HUD toast signal "No quicksave available" is emitted. (AC-5 from GDD.)
- [ ] **AC-7**: GIVEN player presses F9 with `slot_exists(0) == true` AND `InputContext.current() in {GAMEPLAY, MENU, PAUSE}`, WHEN the input handler runs, THEN `SaveLoad.load_from_slot(0)` is called AND `Events.game_loaded.emit(0)` fires on success.
- [ ] **AC-8**: F5 implements debounce per GDD §Tuning Knobs `QUICKSAVE_KEY_DEBOUNCE_MS = 500`: a second F5 press within 500 ms of the previous SUCCESSFUL save is ignored. (Prevents F5-spam from producing rapid duplicate saves.)
- [ ] **AC-9**: SaveLoadService's `_ready()` body contains zero references to `InputContext` (per ADR-0007 §Cross-Autoload Reference Safety rule 3 — line 3 cannot reference line 4). InputContext queries happen at input-event time inside an `_unhandled_input` handler attached to a child Node (or a scene helper), not in autoload `_ready()`.
- [ ] **AC-10**: GIVEN F5 fires a save while a save is already in flight (e.g., autosave from Mission Scripting), WHEN the F5 handler runs, THEN it defers to Story 008's state machine (sequential queueing) — F5 itself does NOT implement queueing; it just calls `save_to_slot(0, sg)` and lets the service serialize.

---

## Implementation Notes

*Derived from GDD §Detailed Design Quicksave/Quickload UX sketch + ADR-0007 §Cross-Autoload Reference Safety:*

**Architecture**: F5/F9 input handling is NOT in `save_load_service.gd` (the autoload at line 3) because that autoload's `_ready()` cannot reference `InputContext` at line 4. Instead, place the input handler in a small companion script attached to a Node added via the Mission Scripting layer or as a child of the SaveLoad autoload at runtime AFTER all autoloads are in the tree.

**Recommended approach**: add a helper Node `QuicksaveInputHandler` instantiated by the SaveLoad autoload's `_ready()` (the helper Node itself doesn't reference InputContext until `_unhandled_input` fires, which is well after autoload init). Or, place the helper at the section-scene root (whichever owner aligns with the scene-tree topology Mission Scripting owns).

```gdscript
# src/core/save_load/quicksave_input_handler.gd
class_name QuicksaveInputHandler extends Node

const QUICKSAVE_DEBOUNCE_MS: int = 500
var _last_quicksave_msec: int = -100000  # far in the past on init

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("quicksave"):
        _try_quicksave()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("quickload"):
        _try_quickload()
        get_viewport().set_input_as_handled()

func _try_quicksave() -> void:
    # InputContext gate (line 4 autoload — safe to reference at input-event time)
    var ctx: int = InputContext.current()
    if not (ctx == InputContext.GAMEPLAY or ctx == InputContext.MENU or ctx == InputContext.PAUSE):
        return  # silent no-op per CR-6

    # Debounce
    var now_msec: int = Time.get_ticks_msec()
    if now_msec - _last_quicksave_msec < QUICKSAVE_DEBOUNCE_MS:
        return

    # Caller assembles SaveGame (deferred to Mission Scripting or a stub at MVP — see notes)
    var sg: SaveGame = _assemble_quicksave()
    if sg == null:
        return

    var ok: bool = SaveLoad.save_to_slot(0, sg)
    if ok:
        _last_quicksave_msec = now_msec
        # Emit HUD toast signal (owned by HUD State Signaling — Story 007 emits the data event)
        Events.hud_toast_requested.emit(&"quicksave_success", {"slot": 0})

func _try_quickload() -> void:
    var ctx: int = InputContext.current()
    if not (ctx == InputContext.GAMEPLAY or ctx == InputContext.MENU or ctx == InputContext.PAUSE):
        return

    if not SaveLoad.slot_exists(0):
        Events.hud_toast_requested.emit(&"quicksave_unavailable", {})
        return

    var sg: SaveGame = SaveLoad.load_from_slot(0)
    # load_from_slot already emits game_loaded; downstream caller will duplicate_deep + apply
```

**`_assemble_quicksave()` at MVP**: For Foundation-layer MVP, this can return a stub SaveGame (so the input handler can be tested in isolation). The production assembler is owned by Mission Scripting / F&R / a player save action (per ADR-0003 IG 2 — the service does NOT assemble). At Foundation-layer integration time, the test fixture provides a stub assembler; when Mission Scripting epic ships, the real assembler is wired in.

**HUD toast signal**: `Events.hud_toast_requested(toast_id: StringName, payload: Dictionary)` is owned by HUD State Signaling's signal taxonomy. If not yet declared in Signal Bus epic, this story is BLOCKED on adding the signal declaration (or coordinate with HUD State Signaling epic).

**InputContext enum values**: per ADR-0004 + Input GDD, the enum values are GAMEPLAY, MENU, PAUSE, CUTSCENE, DOCUMENT_OVERLAY, MODAL, LOADING. Save-eligible contexts are GAMEPLAY, MENU, PAUSE. Non-save contexts silently drop F5.

**`get_viewport().set_input_as_handled()`**: prevents F5 from leaking to other handlers (e.g., a debug menu also bound to F5). Per ADR-0004, this is the canonical way to consume an input event.

**No deferred-save queue** (GDD CR-6 + Edge Cases): the keypress is silently dropped. No "Save will fire when cutscene ends" UI or queue. Matches Input GDD context-gating rules.

**Integration test scope** (Story Type: Integration): exercises the full F5 path from `Input.parse_input_event(simulated_F5)` through InputContext query through SaveLoad call through Events emit. Multiple autoloads cooperating — proves the line-order discipline holds at runtime.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `save_to_slot` core path (already done; this story calls it)
- Story 003: `load_from_slot` core path (already done; this story calls it)
- Story 006: slot scheme + `slot_exists` (already done; this story calls `slot_exists(0)` for F9 gating)
- Story 008: state machine for concurrent saves (this story does not queue — it defers to Story 008)
- Production SaveGame assembler — owned by Mission Scripting epic; at MVP a stub is fine
- HUD toast visual rendering — owned by HUD State Signaling epic; this story emits the data signal only
- Pause Menu "Save Game" / "Load Game" UI flows — owned by Menu System epic

---

## QA Test Cases

**AC-1 — F5 in GAMEPLAY context fires save**
- **Given**: `InputContext.current() == GAMEPLAY`; signal-spy on `Events.game_saved` and `Events.hud_toast_requested`; `_assemble_quicksave()` returns a valid stub SaveGame
- **When**: simulated F5 input event (`Input.parse_input_event` with the `quicksave` action)
- **Then**: `Events.game_saved` fires once with slot=0; `Events.hud_toast_requested` fires once with toast_id `&"quicksave_success"`; `slot_0.res` exists on disk
- **Edge cases**: F5 fires twice rapidly within 500 ms → second fire is debounced (covered in AC-8)

**AC-2 — F5 in CUTSCENE context is silent no-op**
- **Given**: `InputContext.current() == CUTSCENE`; signal-spy on `Events.game_saved`, `Events.save_failed`, `Events.hud_toast_requested`
- **When**: simulated F5 input event
- **Then**: zero signal emissions; no file system mutations; no warnings logged
- **Edge cases**: F5 fires immediately after cutscene ends (transition window) — first F5 in CUTSCENE drops; player must press F5 again after `InputContext.pop()` returns to GAMEPLAY

**AC-3 — F5 in DOCUMENT_OVERLAY context is silent no-op**
- **Given**: `InputContext.current() == DOCUMENT_OVERLAY`
- **When**: simulated F5 input event
- **Then**: zero signal emissions; no file system mutations
- **Edge cases**: this AC validates the 2026-04-28 CR-6 extension (Document Overlay UI's IDLE state is the only save-eligible overlay state; OPENING/READING/CLOSING all gate F5)

**AC-4 — F5 in MODAL context is silent no-op**
- **Given**: `InputContext.current() == MODAL`
- **When**: simulated F5
- **Then**: zero signal emissions; no file system mutations

**AC-5 — F5 in LOADING context is silent no-op**
- **Given**: `InputContext.current() == LOADING`
- **When**: simulated F5
- **Then**: zero signal emissions; no file system mutations

**AC-6 — F9 with empty slot 0 emits unavailable toast**
- **Given**: `InputContext.current() == GAMEPLAY`; `slot_0.res` does NOT exist
- **When**: simulated F9 input event
- **Then**: `Events.hud_toast_requested` fires once with toast_id `&"quicksave_unavailable"`; no `Events.game_loaded` emit; no `Events.save_failed` emit
- **Edge cases**: `slot_0_meta.cfg` exists but `slot_0.res` is missing (incomplete cleanup) → `slot_exists(0)` correctly returns false (it checks the `.res`); same behavior

**AC-7 — F9 with occupied slot 0 fires load**
- **Given**: `slot_0.res` exists from a prior save with `section_id = &"plaza"`; `InputContext.current() == GAMEPLAY`
- **When**: simulated F9
- **Then**: `Events.game_loaded` fires once with slot=0; `load_from_slot(0)` returned a valid SaveGame; downstream consumers (Mission Scripting) will handle scene transition + duplicate_deep — out of scope here
- **Edge cases**: `slot_0.res` is corrupt → `load_from_slot(0)` returns null and emits `save_failed(CORRUPT_FILE)` per Story 003; F9 itself does not retry or fall back

**AC-8 — F5 debounce within 500 ms**
- **Given**: F5 fires successfully at t=0 (`Events.game_saved` recorded); `InputContext.current() == GAMEPLAY` throughout
- **When**: F5 fires again at t=300 ms; then again at t=600 ms
- **Then**: t=300 ms F5 is dropped (debounce — within 500 ms of previous successful save); t=600 ms F5 fires successfully (debounce window expired); signal-spy records exactly 2 `game_saved` emits total (t=0 and t=600)
- **Edge cases**: failed F5 (e.g., InputContext blocked) does NOT update `_last_quicksave_msec` — the debounce only applies to successful saves; first non-blocked F5 after a string of blocked ones fires immediately

**AC-9 — SaveLoadService autoload `_ready()` does not reference InputContext**
- **Given**: `src/core/save_load/save_load_service.gd` source
- **When**: a code-review test greps the file for `InputContext` (any reference) inside `_ready()` body or `_init()` body
- **Then**: zero matches inside `_ready()` and `_init()` (per ADR-0007 §Cross-Autoload Reference Safety rule 3); the helper `QuicksaveInputHandler` (separate file) may reference InputContext at input-event time
- **Edge cases**: comments containing the word "InputContext" — strict grep accepts comments only outside `_ready`/`_init` body; or use AST-based check

**AC-10 — F5 during in-flight save defers to state machine**
- **Given**: a save is already in progress (Story 008's state machine has `state == SAVING`); F5 fires
- **When**: the F5 handler calls `SaveLoad.save_to_slot(0, sg)`
- **Then**: the F5 handler does NOT block or queue itself; it calls the service and returns; the service's state machine (Story 008) handles the queueing/serialization; if Story 008 is not yet implemented, the second save call may overlap (acceptable for this story — the state machine fix is Story 008's responsibility)
- **Edge cases**: this AC documents the design boundary — F5 is "fire and forget" from the input handler's perspective; serialization is the service's concern

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/foundation/save_load_quicksave_test.gd` — must exist and pass (covers all 10 ACs)
- Integration test exercises 3 autoloads (Events line 1, SaveLoad line 3, InputContext line 4) cooperating at input-event time — proves load-order discipline holds at runtime
- Determinism: `Time.get_ticks_msec()` is mocked or controlled in debounce tests; `InputContext.current()` is set deterministically per-test via the InputContext push/pop API

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (`save_to_slot`), Story 003 (`load_from_slot`), Story 006 (`slot_exists`), InputContext autoload (line 4 — owned by ADR-0004 / UI Framework epic), Signal Bus epic (`Events.hud_toast_requested` signal declaration)
- Unlocks: HUD State Signaling epic (consumes `Events.hud_toast_requested` to render the toast); Mission Scripting epic (provides the production `_assemble_quicksave()` SaveGame builder)
