# Story 003: Open lifecycle — signal subscription, InputContext push, sepia-dim handshake

> **Epic**: Document Overlay UI
> **Status**: Blocked — BLOCKED: ADR-0004 is Proposed — run `/architecture-decision` to advance it (Gate 5 deferred to runtime AT testing). Unblock when ADR-0004 reaches Accepted.
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/document-overlay-ui.md`
**Requirement**: TR-DOU-002, TR-DOU-003, TR-DOU-004
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (UI Framework) + ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: ADR-0004 §IG2 (Proposed) specifies that modals push `InputContext.push(InputContextStack.Context.DOCUMENT_OVERLAY)` before any visual change on open. ADR-0004 §IG4 specifies the sepia-dim lifecycle (`PostProcessStack.enable_sepia_dim()`). ADR-0002 §Accepted declares DC as sole publisher of `document_opened`; Overlay subscribes only, never emits (CR-1 + FP-OV-1). The Overlay's `_on_document_opened` handler executes the strict 8-step lifecycle (GDD §C.4) synchronously — no `await` between steps.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (ADR-0004 Proposed; InputContextStack autoload, PostProcessStack API require runtime verification)
**Engine Notes**: `Signal.connect(callable)` typed form is stable Godot 4.0+. `Input.mouse_mode` enum values are stable. `InputContextStack.Context.DOCUMENT_OVERLAY` is an enum value from ADR-0004 §IG2 — verify the autoload is registered at `project.godot` line matching ADR-0007 §Key Interfaces. `PostProcessStack.enable_sepia_dim(duration_override: float)` API must be confirmed per OQ-DOV-COORD-2 (BLOCKING) before AC-DOV-1.2 can be verified. Godot 4.5+ `Node.AUTO_TRANSLATE_MODE_DISABLED` verified closed Gate D.

> **Post-cutoff risk**: `InputContextStack` and `PostProcessStack` are project-defined autoloads (not Godot builtins). Their APIs are defined in their respective GDDs and epics. Verify against those GDDs, not training data.

**Control Manifest Rules (Presentation + Foundation)**:
- Required: subscribers connect in `_ready` and disconnect in `_exit_tree` with `is_connected` guards (ADR-0002 IG 3)
- Required: every Node-typed signal payload checked with `is_instance_valid(node)` before dereferencing (ADR-0002 IG 4) — applied at GDD §C.4 step 1 (`is_instance_valid(doc)`)
- Required: InputContext push precedes any visual change on open (ADR-0004 §IG2) — steps 3 → 4 → 5 order
- Required: consume `set_input_as_handled()` BEFORE `InputContext.pop()` on close (ADR-0004 §IG3 / Input CR-7) — enforced in Story 005; referenced here for step-order context
- Forbidden: `Events.document_opened.emit()` / `document_closed.emit()` from Overlay (FP-OV-1 + ADR-0002 IG 1)
- Forbidden: `overlay_calls_audio_api` — no `AudioServer` calls from open handler (FP-OV-7)
- Forbidden: `overlay_manages_subtitles` — no subtitle visibility calls from open handler (FP-OV-6; ADR-0004 §IG5 self-suppression rule: Subtitle subscribes to `document_opened` directly and manages its own visibility)
- Guardrail: open-frame T_open ≤ 5 ms soft ceiling (GDD F.1; requires FontRegistry.preload_font_atlas() at section-load per OQ-DOV-COORD-2 amendment)

---

## Acceptance Criteria

*From GDD `design/gdd/document-overlay-ui.md` §H.1 + §H.3, scoped to this story:*

- [ ] **AC-1** (TR-DOU-004): `document_overlay_ui.gd` connects `Events.document_opened` to `_on_document_opened` and `Events.document_closed` to `_on_document_closed` in `_ready()`, with `is_connected` guards in `_exit_tree()`. When `_disabled == true`, connections are NOT made (per Story 001 AC-2 guard).
- [ ] **AC-2** (TR-DOU-002, TR-DOU-003): GIVEN Overlay `_state == IDLE`, WHEN `_on_document_opened(valid_doc_id)` fires, THEN all 8 C.4 lifecycle steps execute synchronously in the exact order specified by GDD §C.4: (1) cache `_current_title_key` and `_current_body_key` from `DocumentCollection.get_document(id)`; (2) save `_prev_mouse_mode = Input.mouse_mode`; (3) `InputContext.push(InputContextStack.Context.DOCUMENT_OVERLAY)`; (4) `Input.mouse_mode = Input.MOUSE_MODE_VISIBLE`; (5) `PostProcessStack.enable_sepia_dim()` (or `enable_sepia_dim(0.0)` if `reduced_motion_enabled`); (6) populate `TitleLabel.text = tr(_current_title_key)` and `BodyText.text = tr(_current_body_key)`; (7) `DocumentCard.visible = true`, `BodyScrollContainer.scroll_vertical = 0`, `call_deferred("_update_scroll_hint_visibility")`, `TitleLabel.grab_focus()`; (8) `ModalBackdrop.accessibility_description` assertive announce deferred. `_state == OPENING` on exit.
- [ ] **AC-3** (TR-DOU-002): GIVEN `reduced_motion_enabled == true` (BLOCKED-pending OQ-DOV-COORD-2 PPS API amendment), WHEN `_on_document_opened`, THEN `PostProcessStack.enable_sepia_dim(0.0)` called with explicit `0.0` duration override. Evidence: PPS spy double.
- [ ] **AC-4** (TR-DOU-004): GIVEN Overlay `_state == IDLE`, WHEN `_on_document_opened(invalid_id)` (null or freed Document resource), THEN `push_error("document_opened with invalid id: %s" % id)` emitted; `_state` unchanged (`== IDLE`); no `InputContext.push` call; no `Input.mouse_mode` write; `DocumentCard.visible == false`.
- [ ] **AC-5** (TR-DOU-005, TR-DOU-018): GIVEN `_state ∈ {OPENING, READING, CLOSING}`, WHEN `_on_document_opened(any_id)` fires (defensive guard CR-3), THEN `push_error("document_opened in state %s")` emitted; `_state` unchanged; no second `InputContext.push`; labels unchanged; no sepia call. Covers all three non-IDLE guard branches (OPENING, READING, CLOSING — per AC-DOV-3.2, 3.3, 3.4).
- [ ] **AC-6** (TR-DOU-005, TR-DOU-018): GIVEN Overlay IDLE, WHEN `_on_document_opened(id)` resolves to a Document with empty `title_key` or `body_key` (`&""`), THEN `push_error("document_opened with malformed Document: empty key field for %s")` emitted; `_state == IDLE`; no `InputContext.push`.
- [ ] **AC-7** (TR-DOU-003): GIVEN open lifecycle ran and `_state == OPENING`, WHEN the OPENING → READING transition timer fires (duration matching `sepia_dim_transition_duration_s` per OQ-DOV-COORD-2 — pending PPS signal or Timer approach), THEN `_state == READING`.
- [ ] **AC-8** (FP-OV-6 + ADR-0004 §IG5 self-suppression): CI grep `fp_ov_6` (`grep -rn "Subtitle.*visible\|subtitle.*suppress\|set_subtitle_visible" src/ui/document_overlay/`) → zero matches. The Overlay does NOT push visibility onto Subtitle; Subtitle subscribes to `document_opened` directly and manages its own suppression per ADR-0004 §IG5.
- [ ] **AC-9** (FP-OV-7): CI grep `fp_ov_7` (`grep -rn "AudioServer\|AudioStreamPlayer\|set_bus_volume_db" src/ui/document_overlay/`) → zero matches. Audio ducks via its own `document_opened` subscription; Overlay never calls Audio API.

---

## Implementation Notes

*Derived from ADR-0004 §IG2, §IG4, §IG5 + GDD §C.1–C.4 + Input CR-7 + ADR-0002 IG 3–4:*

**Signal subscription (adds to Story 001's `_ready()` skeleton)**:

```gdscript
func _ready() -> void:
    # ... (Story 001 group-registration and process-disable) ...
    if _disabled:
        return

    # ADR-0002 IG 3: connect in _ready with typed callables
    if not Events.document_opened.is_connected(_on_document_opened):
        Events.document_opened.connect(_on_document_opened)
    if not Events.document_closed.is_connected(_on_document_closed):
        Events.document_closed.connect(_on_document_closed)
    # section_unloading subscription added in Story 005 (CR-12)

func _exit_tree() -> void:
    # ADR-0002 IG 3: disconnect in _exit_tree with is_connected guards
    if Events.document_opened.is_connected(_on_document_opened):
        Events.document_opened.disconnect(_on_document_opened)
    if Events.document_closed.is_connected(_on_document_closed):
        Events.document_closed.disconnect(_on_document_closed)
    # ... (Story 001 group removal, Story 005 safety-net teardown) ...
```

**Open lifecycle (`_on_document_opened`) — 8-step synchronous order** (no `await` between steps; GDD §C.4):

```gdscript
func _on_document_opened(document_id: StringName) -> void:
    # CR-3 defensive guard
    if _state != State.IDLE:
        push_error("document_opened in state %s — discarding %s" % [_state, document_id])
        return

    # Step 1: cache keys (NOT resolved values — Localization CR-9 + CR-7)
    var doc: Document = DocumentCollection.get_document(document_id)
    if not is_instance_valid(doc):
        push_error("document_opened with invalid id: %s" % document_id)
        return
    if doc.title_key == &"" or doc.body_key == &"":
        push_error("document_opened with malformed Document: empty key field for %s" % document_id)
        return
    _current_doc_id = document_id
    _current_title_key = doc.title_key
    _current_body_key = doc.body_key

    # Step 2: save previous mouse mode (Input CR-8)
    _prev_mouse_mode = Input.mouse_mode

    # Step 3: push InputContext FIRST (ADR-0004 §IG2 — input locked before visual change)
    InputContext.push(InputContextStack.Context.DOCUMENT_OVERLAY)

    # Step 4: set mouse mode VISIBLE (Input CR-8)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

    # Step 5: engage sepia (ADR-0004 §IG4 — respect reduced-motion)
    var reduced_motion: bool = SettingsService.get_value(
        "accessibility", "reduced_motion_enabled", false
    )
    if reduced_motion:
        PostProcessStack.enable_sepia_dim(0.0)  # instant — OQ-DOV-COORD-2 API
    else:
        PostProcessStack.enable_sepia_dim()     # default 0.5s

    # Step 6: resolve tr() at THIS moment (CR-7 + Localization CR-9)
    %TitleLabel.text = tr(_current_title_key)
    %BodyText.text = tr(_current_body_key)     # bbcode_enabled=true → auto-parse

    # Step 7: show card + scroll reset + deferred scroll-hint + focus
    %DocumentCard.visible = true
    %BodyScrollContainer.scroll_vertical = 0
    call_deferred("_update_scroll_hint_visibility")
    %TitleLabel.grab_focus()  # heading announce AT path (GDD §C.4 step 7b)

    # Step 8: AccessKit assertive announce (Gate A — pseudocode until confirmed)
    # Actual property name: accessibility_description (verified Gate 1 Sprint 01)
    # accessibility_live semantics pending Gate A full closure
    %ModalBackdrop.accessibility_description = tr("overlay.accessibility.dialog_name")
    call_deferred("_clear_accessibility_announce")

    _state = State.OPENING
    _start_opening_to_reading_transition()  # OQ-DOV-COORD-2 — Timer or PPS signal

func _on_document_closed(document_id: StringName) -> void:
    # CLOSING → IDLE (close lifecycle in Story 005 drives READING → CLOSING)
    _current_doc_id = &""
    _current_title_key = &""
    _current_body_key = &""
    _state = State.IDLE
```

**ADR-0004 §IG5 self-suppression rule (IG5 = "no visibility push onto Subtitle")**: the Overlay's `_on_document_opened` MUST NOT call any Subtitle visibility method. Subtitle subscribes to `Events.document_opened` directly and suppresses ambient VO independently. This is the IG5 contract. CI grep FP-OV-6 enforces it (AC-8 above). No code change needed — the absence of Subtitle calls is the implementation.

**OPENING → READING transition** (`_start_opening_to_reading_transition`): pending resolution of OQ-DOV-COORD-2. Two options: (a) PPS emits a `sepia_dim_complete` signal after the fade Tween finishes — Overlay subscribes and advances state; (b) Overlay starts a local `Timer` with `wait_time = sepia_dim_transition_duration_s` (0.5 s default). Option (a) is preferred (eliminates the implicit duration coupling). Implement with a `Timer` stub pending PPS coordination; replace with PPS signal when OQ-DOV-COORD-2 is resolved.

**`_update_scroll_hint_visibility`** (deferred, called at step 7): checks whether `BodyText.get_content_height() > BodyScrollContainer.size.y`. If so, sets `ScrollHintLabel.visible = true`. Deferred because `fit_content = true` on `RichTextLabel` sets body height after `_ready()`; the one-frame deferral lets layout settle before measuring overflow.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: scene scaffold (CanvasLayer, node tree, process-mode flags)
- Story 002: CI forbidden-patterns script and test helpers
- Story 004: `tr()` FontRegistry font application; `NOTIFICATION_TRANSLATION_CHANGED` re-resolve handler; Theme StyleBoxFlat
- Story 005: `_unhandled_input` dismiss handler; `_close()` 6-step lifecycle; `section_unloading` subscription; `_exit_tree()` safety-net
- Story 006: scroll grammar; gamepad right-stick routing; Tab/focus consumption
- Story 007: AccessKit `accessibility_description` full verification (Gate A); reduced-motion sepia-instant verification (Gate E)
- Story 008: performance profiling; Slot 7 draw-call proxy test

---

## QA Test Cases

**AC-2 (open lifecycle step order)**
- Given: Overlay `_state == IDLE`; `DocumentCollection`, `InputContext`, `PostProcessStack`, `SettingsService` all spy-doubled; `CallOrderRecorder` from Story 002 injected.
- When: `_on_document_opened("test_doc_id")` called.
- Then: recorder asserts call order: `[&"cache_keys", &"save_mouse_mode", &"ic_push", &"set_mouse_visible", &"pps_enable_sepia", &"tr_populate", &"card_visible", &"scroll_reset", &"grab_focus"]`; `_state == OPENING`.
- Edge cases: `DocumentCollection.get_document()` returns null → push_error; state remains IDLE.

**AC-4 (invalid document id guard)**
- Given: Overlay IDLE; `DocumentCollection.get_document("bad_id")` returns null.
- When: `_on_document_opened("bad_id")`.
- Then: `push_error` fired; `_state == IDLE`; `InputContext.push` NOT called; `Input.mouse_mode` unchanged.

**AC-5 (CR-3 defensive guard — all three non-IDLE states)**
- Given: Overlay in each of `{OPENING, READING, CLOSING}` states.
- When: `_on_document_opened("any_id")` fires.
- Then: `push_error` with state name in message; `_state` unchanged for each; `InputContext.push` NOT called; `is_connected` count for each spy = 0 additional calls.

**AC-8 (FP-OV-6 CI assertion)**
- Given: `tools/ci/check_forbidden_patterns_overlay.sh` (Story 002).
- When: run against `src/ui/document_overlay/`.
- Then: exit 0; no FP-OV-6 matches (no subtitle visibility calls).

**AC-9 (FP-OV-7 CI assertion)**
- Given: same script.
- When: run against `src/ui/document_overlay/`.
- Then: exit 0; no AudioServer / AudioStreamPlayer calls.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/document_overlay/open_lifecycle_test.gd` — must exist and pass (AC-2, AC-3, AC-4, AC-5, AC-6, AC-7)
- `tools/ci/check_forbidden_patterns_overlay.sh` exit 0 on clean implementation (AC-8, AC-9)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (scene scaffold must exist), Story 002 (CI script + CallOrderRecorder must exist)
- Unlocks: Story 004 (body rendering builds on the opened state), Story 005 (close lifecycle depends on READING state transitions established here)

## Open Questions

- **OQ-DOV-COORD-1 (BLOCKING)**: DC §C.10 / CR-11 must confirm that `DC.collect()` + `DC.open_document()` execute in the same frame on `interact`. Without this, the Overlay may open with a null document reference if `collect()` hasn't committed state yet.
- **OQ-DOV-COORD-2 (BLOCKING)**: PPS must expose `enable_sepia_dim(duration_override: float = 0.5)` before AC-3 (reduced-motion path) can be implemented. Also required to resolve the OPENING → READING transition mechanism.
- **OQ-DOV-COORD-6 (BLOCKING)**: ADR-0004 §IG3 code snippet shows `InputContext.pop()` BEFORE `set_input_as_handled()`. GDD CR-5 and Input CR-7 prose contradict this. The authoritative order is: consume FIRST, then pop. This story implements the correct prose order; ADR-0004 §IG3 code snippet needs annotation before merge.
