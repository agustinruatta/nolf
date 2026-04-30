# Story 005: Close lifecycle — dismiss input, call order, section-unload, exit-tree safety net

> **Epic**: Document Overlay UI
> **Status**: Blocked — BLOCKED: ADR-0004 is Proposed — run `/architecture-decision` to advance it (Gate 5 deferred to runtime AT testing). Unblock when ADR-0004 reaches Accepted.
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/document-overlay-ui.md`
**Requirement**: TR-DOU-006, TR-DOU-007
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (UI Framework) + ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: ADR-0004 §IG3 (Proposed) specifies modal dismiss via `_unhandled_input()` + `ui_cancel` action at the root Control — never via a focused Button widget (FP-OV-9, sidesteps Godot 4.6 dual-focus split). Input CR-7 (adopted in GDD CR-5) specifies the close lifecycle step order: `get_viewport().set_input_as_handled()` FIRST, then `InputContext.pop()`. ADR-0004 §IG3 code snippet shows the reverse order — GDD §C.5 prose is authoritative (Coord OQ-DOV-COORD-6 BLOCKING annotation needed). ADR-0002 subscriber discipline requires `_exit_tree` signal disconnection with `is_connected` guards.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (ADR-0004 Proposed; `_unhandled_input` + `ui_cancel` grammar verified Gate 3; dual-focus split is sidestepped by the chosen pattern)
**Engine Notes**: Gate 3 closed 2026-04-29 — `event.is_action_pressed("ui_cancel")` returns true for `KEY_ESCAPE` (KB) and `JOY_BUTTON_B` (gamepad, added to `project.godot [input]` as Finding F3). `_unhandled_input()` lifecycle on a real Control hierarchy is engine-stable since Godot 4.0. `get_viewport().set_input_as_handled()` is stable. No post-cutoff API risk in this story's core path.

> **Post-cutoff risk**: `InputContextStack.pop()` and the `InputContextStack.is_active()` predicate are project-defined autoload APIs. Verify return types against InputContext GDD, not training data.

**Control Manifest Rules (Presentation + Foundation)**:
- Required: `get_viewport().set_input_as_handled()` BEFORE `InputContext.pop()` in `_close()` (Input CR-7 + ADR-0004 §IG3 prose — not the code snippet which shows the wrong order)
- Required: dismiss via `_unhandled_input(event)` checking `event.is_action_pressed(&"ui_cancel")` at the root Control; NEVER via a focused Button's `pressed` signal (FP-OV-9)
- Required: `_unhandled_input` handler guards `InputContext.is_active(InputContextStack.Context.DOCUMENT_OVERLAY)` — returns early if NOT active (GDD CR-5 defensive pattern)
- Required: `_exit_tree()` safety net restores `Input.mouse_mode = _prev_mouse_mode` if captured; pops InputContext only if `is_active(DOCUMENT_OVERLAY)` (GDD E.16)
- Required: `section_unloading(section_id)` subscription in `_ready()`; handler executes force-close for READING state and OPENING-state teardown for OPENING state (GDD CR-12, OQ-DOV-COORD-9)
- Required: signal disconnection in `_exit_tree` with `is_connected` guards (ADR-0002 IG 3)
- Forbidden: `Button` node in `DocumentOverlayUI.tscn`; `ui_accept` action wired to `_close` (FP-OV-9)
- Forbidden: time-based or signal-based auto-dismiss (FP-OV-2; only `section_unloading` may force-close — CR-12 exception)

---

## Acceptance Criteria

*From GDD `design/gdd/document-overlay-ui.md` §H.2 + §H.4 + §H.5 + §H.8, scoped to this story:*

- [ ] **AC-1** (TR-DOU-006): GIVEN Overlay `_state == READING`, WHEN `_close()` is called, THEN all 6 C.5 lifecycle steps execute in exact order: (1) `get_viewport().set_input_as_handled()`; (2) `Input.mouse_mode = _prev_mouse_mode`; (3) `InputContext.pop()`; (4) `PostProcessStack.disable_sepia_dim()`; (5) `%DocumentCard.visible = false`, `%TitleLabel.text = ""`, `%BodyText.text = ""`; (6) `DocumentCollection.close_document()`; `_state == CLOSING` on exit. `CallOrderRecorder` (Story 002) verifies step order.
- [ ] **AC-2** (TR-DOU-006): GIVEN Overlay CLOSING, WHEN `_on_document_closed(doc_id)` callback fires, THEN `_current_doc_id == &""`, `_current_title_key == &""`, `_current_body_key == &""`; `_state == IDLE`.
- [ ] **AC-3** (TR-DOU-006): GIVEN `_close()` called while `_state != READING` (idempotency guard), THEN early-return fires; no lifecycle steps execute a second time; each API called exactly once total across any number of `_close()` calls.
- [ ] **AC-4** (TR-DOU-007): GIVEN Overlay READING + `InputContext.is_active(DOCUMENT_OVERLAY) == true`, WHEN synthetic `ui_cancel` `InputEvent` injected to `_unhandled_input`, THEN `get_viewport().set_input_as_handled()` called BEFORE `InputContext.pop()` (call-order spy from `ViewportMock`); `_state == CLOSING`; event does NOT propagate to Pause Menu (Pause spy call_count == 0 same frame).
- [ ] **AC-5** (TR-DOU-007): GIVEN Overlay `_state == IDLE` (DOCUMENT_OVERLAY NOT active), WHEN `_unhandled_input` receives `ui_cancel`, THEN early-return fires (guard: `InputContext.is_active()` returns false); `set_input_as_handled` NOT called; `_state == IDLE`.
- [ ] **AC-6** (Input CR-8 + GDD §C.5 step 2): GIVEN open ran with `_prev_mouse_mode == MOUSE_MODE_CAPTURED`, Overlay READING, WHEN `_close()`, THEN `Input.mouse_mode` restored to `MOUSE_MODE_CAPTURED` at step 2 BEFORE `InputContext.pop()` at step 3 (`CallOrderRecorder` verifies).
- [ ] **AC-7** (GDD E.13): GIVEN precondition `Input.mouse_mode == MOUSE_MODE_VISIBLE` (prior modal was already visible), WHEN open + close runs, THEN mode is `VISIBLE` throughout; net change == none; `_prev_mouse_mode` captured as `VISIBLE` on open.
- [ ] **AC-8** (GDD CR-12, OQ-DOV-COORD-9 BLOCKED-pending): GIVEN Overlay READING, WHEN `section_unloading(matching_section_id)` fires, THEN full C.5 lifecycle executes synchronously; `_state == IDLE` before handler returns; `DocumentCollection.close_document()` called; `InputContext.pop()` called; `Input.mouse_mode` restored. (BLOCKED-pending OQ-DOV-COORD-3: MLS GDD must define `section_unloading` signal.)
- [ ] **AC-9** (GDD E.7 / E.19 + OQ-DOV-COORD-9 BLOCKED): GIVEN Overlay OPENING (sepia in progress), WHEN `section_unloading` fires, THEN OPENING-state teardown branch: `InputContext.pop()`, `Input.mouse_mode` restored, `PostProcessStack.disable_sepia_dim()` (instant — section going away), `%DocumentCard.visible = false`, `_state == IDLE`. `DocumentCollection.close_document()` is NOT called (DC being freed).
- [ ] **AC-10** (GDD E.16 + GAP-1 promoted to VS): GIVEN Overlay `_state == READING`, WHEN `queue_free()` called externally without `_close()` first, THEN `_exit_tree()` safety net: `Input.mouse_mode = _prev_mouse_mode` (if `_prev_mouse_mode != MOUSE_MODE_VISIBLE` OR if different from current); `InputContext.pop()` only if `InputContext.is_active(DOCUMENT_OVERLAY)` is true; `DocumentCollection.close_document()` SKIPPED (guarded by `is_instance_valid(DocumentCollection)`); no push_error raised.
- [ ] **AC-11** (FP-OV-9): CI grep `fp_ov_9` (`grep -n "Button\|ui_accept" src/ui/document_overlay/DocumentOverlayUI.tscn`) → zero matches (no Button node types or `ui_accept` dismiss handlers).
- [ ] **AC-12** (GDD H.3 AC-DOV-3.6): GIVEN Overlay state READING for section A, WHEN `section_unloading(section_B_id)` fires (different section), THEN no-op; `_state == READING` unchanged; `_close()` not called.

---

## Implementation Notes

*Derived from ADR-0004 §IG3 + Input CR-7 + GDD §C.5 + GDD CR-12 + ADR-0002 IG 3:*

**`_unhandled_input` dismiss handler** (GDD §C.5 + ADR-0004 §IG3):

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    # Gate: only consume when this surface is the active modal (CR-6)
    if not InputContext.is_active(InputContextStack.Context.DOCUMENT_OVERLAY):
        return

    if event.is_action_pressed(&"ui_cancel"):
        _close()
        return

    # Tab/focus consumption (CR-16 — Story 006)
    # Gamepad right-stick scroll routing (CR-9 — Story 006)
```

**`_close()` — 6-step synchronous lifecycle** (GDD §C.5; Input CR-7 order: consume FIRST):

```gdscript
func _close() -> void:
    # Defensive guard: only close from READING state
    if _state != State.READING:
        return

    # Step 1: consume input event FIRST (Input CR-7 — silent-swallow prevention)
    # Note: _get_viewport() seam allows ViewportMock injection in tests
    _get_viewport().set_input_as_handled()

    # Step 2: restore previous mouse mode (Input CR-8 push/pop discipline)
    Input.mouse_mode = _prev_mouse_mode

    # Step 3: pop InputContext (ADR-0004 §IG2)
    InputContext.pop()

    # Step 4: disable sepia (ADR-0004 §IG4)
    PostProcessStack.disable_sepia_dim()

    # Step 5: hide card + clear text SYNCHRONOUSLY (Option B)
    %DocumentCard.visible = false
    %TitleLabel.text = ""
    %BodyText.text = ""

    # Step 6: notify DC (DC emits document_closed; _on_document_closed callback fires)
    DocumentCollection.close_document()

    _state = State.CLOSING

# Viewport seam for testing (ViewportMock injectable)
func _get_viewport() -> Viewport:
    return get_viewport()
```

**`_on_section_unloading` handler** (GDD CR-12 + OQ-DOV-COORD-9):

```gdscript
func _on_section_unloading(section_id: StringName) -> void:
    # AC-12: ignore if different section
    if section_id != _my_section_id:
        return

    match _state:
        State.READING:
            # Standard close — calls DC.close_document() (step 6)
            _close()
            _state = State.IDLE  # force IDLE immediately (don't wait for document_closed)
        State.OPENING:
            # OPENING-state teardown (OQ-DOV-COORD-9): skip DC.close_document()
            InputContext.pop()
            Input.mouse_mode = _prev_mouse_mode
            PostProcessStack.disable_sepia_dim()  # instant — section going away
            %DocumentCard.visible = false
            _state = State.IDLE
        State.CLOSING:
            # Already closing; tolerate missing document_closed callback (E.20)
            _state = State.IDLE
        State.IDLE:
            pass  # E.18 no-op
```

**`_exit_tree()` safety net** (GDD E.16 + GAP-1):

```gdscript
func _exit_tree() -> void:
    # Signal disconnection (ADR-0002 IG 3)
    if Events.document_opened.is_connected(_on_document_opened):
        Events.document_opened.disconnect(_on_document_opened)
    if Events.document_closed.is_connected(_on_document_closed):
        Events.document_closed.disconnect(_on_document_closed)
    # section_unloading disconnect added here alongside subscription

    # Safety net: abnormal queue_free while _state != IDLE
    if _state != State.IDLE:
        # Restore mouse mode if we captured it and it's still different from current
        if Input.mouse_mode != _prev_mouse_mode:
            Input.mouse_mode = _prev_mouse_mode
        # Pop InputContext only if we pushed it
        if InputContext.is_active(InputContextStack.Context.DOCUMENT_OVERLAY):
            InputContext.pop()
        # Do NOT call DC.close_document() — DC may be in own _exit_tree
        # is_instance_valid guard prevents crash on freed autoload
        # (DC is autoload; freed only at app exit — but guard is defensive)

    # Group removal (Story 001)
    if is_in_group(&"document_overlay_instances"):
        remove_from_group(&"document_overlay_instances")
```

**`_my_section_id`**: the section ID is injected by MLS when it instantiates the Overlay scene (per CR-13). Add `@export var section_id: StringName = &""` to `document_overlay_ui.gd` so MLS can set it in the section's `.tscn` or via `DocumentOverlayUI.section_id = my_section_id` at instantiation. `_on_section_unloading` uses this to filter events (AC-12).

**ADR-0004 §IG3 code snippet discrepancy** (OQ-DOV-COORD-6): ADR-0004 §IG3 code shows `InputContext.pop()` before `set_input_as_handled()`. GDD §C.5 prose and Input CR-7 are authoritative: consume FIRST. This implementation follows the GDD prose. The ADR code snippet should be annotated "prose order is authoritative" before sprint close.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: scene scaffold, `ModalBackdrop` node creation
- Story 002: CI script for FP-OV-9 check (script exists; ACs invoke it here)
- Story 003: `_on_document_opened` open lifecycle (Story 003 drives IDLE → OPENING → READING)
- Story 004: `_notification(NOTIFICATION_TRANSLATION_CHANGED)` locale re-resolve
- Story 006: Tab/focus consumption (CR-16); gamepad right-stick scroll routing (CR-9)
- Post-VS: multi-page document scrolling; smooth-close animation (FP-OV-3 forbids card transitions)

---

## QA Test Cases

**AC-1 (close lifecycle step order)**
- Given: Overlay READING; `DocumentCollection`, `InputContext`, `PostProcessStack`, `ViewportMock`, `CallOrderRecorder` all spy-doubled and injected.
- When: `_close()` called.
- Then: recorder asserts order `[&"set_input_as_handled", &"restore_mouse_mode", &"ic_pop", &"pps_disable_sepia", &"card_hide", &"dc_close"]`; `_state == CLOSING`; `ViewportMock.set_input_as_handled_calls == 1`.
- Edge cases: `_close()` called from IDLE → early return; no calls recorded; state unchanged.

**AC-4 (dismiss via ui_cancel — call order proof)**
- Given: Overlay READING; active modal; `ViewportMock` injected; Pause Menu spy with call_count = 0.
- When: synthetic `InputEventAction` for `ui_cancel` (pressed=true) injected to `_unhandled_input`.
- Then: `ViewportMock.set_input_as_handled_calls == 1`; `set_input_as_handled` occurred BEFORE `InputContext.pop()` (order spy); Pause Menu spy call_count == 0.

**AC-5 (dismiss guard — DOCUMENT_OVERLAY not active)**
- Given: Overlay IDLE; `InputContext.is_active(DOCUMENT_OVERLAY)` returns false.
- When: `ui_cancel` injected.
- Then: early return; `ViewportMock.set_input_as_handled_calls == 0`; `_state == IDLE`.

**AC-6 (mouse mode restore — CAPTURED precondition)**
- Given: Overlay opened while `Input.mouse_mode == MOUSE_MODE_CAPTURED`; Overlay READING.
- When: `_close()`.
- Then: at step 2, `Input.mouse_mode == MOUSE_MODE_CAPTURED` again (restored); confirmed BEFORE InputContext.pop at step 3.

**AC-8 (section_unloading — force close, READING state)**
- Given: Overlay READING; `section_id = &"section_a"`; `DocumentCollection` spy doubled.
- When: `_on_section_unloading(&"section_a")`.
- Then: C.5 lifecycle executes synchronously; `_state == IDLE`; `DocumentCollection.close_document()` called; `InputContext.pop()` called; `Input.mouse_mode` restored.

**AC-9 (section_unloading — OPENING state teardown)**
- Given: Overlay OPENING; `section_id = &"section_a"`; sepia fade Tween in progress.
- When: `_on_section_unloading(&"section_a")`.
- Then: `InputContext.pop()` called; `Input.mouse_mode` restored; `PostProcessStack.disable_sepia_dim()` called; `%DocumentCard.visible == false`; `_state == IDLE`; `DocumentCollection.close_document()` NOT called.

**AC-10 (exit_tree safety net)**
- Given: Overlay READING; `Input.mouse_mode == MOUSE_MODE_CAPTURED`; `InputContext` is_active returns true.
- When: `_exit_tree()` called directly (simulating abnormal queue_free).
- Then: `Input.mouse_mode == MOUSE_MODE_CAPTURED` restored; `InputContext.pop()` called once; `DocumentCollection.close_document()` NOT called; no push_error.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/document_overlay/close_lifecycle_test.gd` — must exist and pass (AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7)
- `tests/integration/document_overlay/section_unload_test.gd` — must exist and pass (AC-8, AC-9, AC-12)
- `tests/unit/document_overlay/exit_tree_safety_net_test.gd` — must exist and pass (AC-10)
- `tools/ci/check_forbidden_patterns_overlay.sh` exit 0 on clean implementation (AC-11)
- `production/qa/evidence/ac-dov-4-4-dismiss-walkthrough.md` — manual KB (Esc) + gamepad (B) dismiss verification with Gate C result

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (scene scaffold + `ModalBackdrop` script), Story 002 (CI script, `CallOrderRecorder`, `ViewportMock`), Story 003 (READING state established by open lifecycle)
- Unlocks: Story 006 (Tab consumption + gamepad scroll routing live in the same `_unhandled_input` handler)

## Open Questions

- **OQ-DOV-COORD-3 (BLOCKING)**: MLS GDD must define + emit `section_unloading(section_id: StringName)` pre-unload signal before AC-8 can be implemented. Also: MLS must define how `_my_section_id` is injected into the Overlay instance at section load time.
- **OQ-DOV-COORD-6 (BLOCKING)**: ADR-0004 §IG3 code snippet shows wrong dismiss step order. Annotation or amendment needed before sprint close to prevent future regressions from the misleading snippet.
- **OQ-DOV-COORD-8 (BLOCKING)**: Confirm `DocumentCollection.close_document()` emits `document_closed` synchronously (same call stack). If deferred, CLOSING state duration is non-zero and an E.4 exposure window exists; the `_on_section_unloading` handler in AC-8 would need a one-frame CLOSING-window guard.
- **OQ-DOV-COORD-9 (BLOCKING)**: This story implements the OPENING-state teardown branch in `_on_section_unloading` (AC-9). MLS must confirm it emits `section_unloading` before any `queue_free()` on section nodes so this handler fires while all referenced nodes are still valid.
