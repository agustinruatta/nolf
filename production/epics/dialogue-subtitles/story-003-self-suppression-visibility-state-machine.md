# Story 003: Self-suppression + subtitle visibility state machine

> **Epic**: Dialogue & Subtitles
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 2-3 hours (M — subscriber wiring + 3-state machine + integration test)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/dialogue-subtitles.md`
**Requirement**: TR-DLG-002, TR-DLG-003, TR-DLG-004, TR-DLG-006, TR-DLG-007
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy), ADR-0004 (UI Framework — self-suppression rule IG5), ADR-0007 (Autoload Load Order Registry)
**ADR Decision Summary**:
- ADR-0002: D&S subscribes to `Events.document_opened`, `Events.document_closed`, and `Events.ui_context_changed(new_ctx, old_ctx)` in `_ready()` and disconnects in `_exit_tree()` with `is_connected()` guards. All three connections are subscriber-side only — D&S never emits these signals.
- ADR-0004 §IG5: Subtitle owns its OWN visibility suppression by subscribing to overlay signals. Document Overlay UI is forbidden from calling any method on `DialogueAndSubtitles` or `SubtitleCanvasLayer` (FP-OV-6). D&S self-suppresses — it is NOT pushed by DOV or any other system. This is the defining architectural constraint of this story.
- ADR-0007: D&S is NOT autoload. Both `InputContext` (autoload line 4) and `Events` (autoload line 1) are available from `_ready()` since both are registered before the per-section `DialogueAndSubtitles` node initializes.

**Engine**: Godot 4.6 | **Risk**: LOW–MEDIUM
**Engine Notes**: `CanvasLayer.visible = false` suppresses visual rendering in Godot 4.6. VG-DS-3 (whether `CanvasLayer.visible = false` also suppresses AccessKit announcements from child Labels) is OPEN but J.3 mitigation is implemented preemptively — both `SubtitleCanvasLayer.visible = false` AND `_label.visible = false` are set in CR-DS-4's suppression path (belt-and-suspenders per GDD §C.12). This story does NOT require VG-DS-3 to be resolved before shipping.

**ADR-0004 (Proposed — G5 deferred)**: ADR-0004 Gates 1-4 are CLOSED. Gate 5 (BBCode→AccessKit serialization) is deferred to runtime AT testing post-MVP and affects only post-VS BBCode body parsing — not this story's plain-text suppression logic. The self-suppression rule (§IG5) is an Accepted design decision within the Proposed ADR and is load-bearing for VS delivery.

**ADR-0008 (Proposed — non-blocking)**: Self-suppression is a one-shot event handler (fired by `document_opened`/`document_closed` at ≤2 Hz per ADR-0002 frequency analysis). Zero steady-state cost. Fits within the 0.10 ms peak event-frame sub-claim.

**Control Manifest Rules (Feature layer)**:
- Required: subscribers connect in `_ready`, disconnect in `_exit_tree` with `is_connected` guards (ADR-0002 IG 3)
- Required: `is_instance_valid(node)` guard before dereferencing any Node-typed payload (ADR-0002 IG 4)
- Forbidden: `subtitle_visibility_pushed_externally` — no system other than `DialogueAndSubtitles` may call any method or set any property on `SubtitleCanvasLayer` or `SubtitleLabel` to change their visibility
- Forbidden: `audio_ducking_in_dialogue_subtitles` — D&S MUST NOT read or write Audio bus values as part of suppression logic; Audio independently subscribes to `document_opened` for voice ducking per CR-DS-17 (Audio's responsibility)
- Forbidden: `dialogue_signal_emitted_outside_d&s` — D&S subscribes to `document_opened`/`document_closed` but NEVER emits them; Document Collection is the sole publisher

---

## Acceptance Criteria

*From GDD `design/gdd/dialogue-subtitles.md` §H.3 Suppression / Overlay + §C.2 State Machine, scoped to VS (one `document_opened` → suppress → `document_closed` → restore flow):*

- [ ] **AC-1** (from AC-DS-3.1): GIVEN a bark in flight with caption visible, WHEN `Events.document_opened` fires, THEN `SubtitleCanvasLayer.visible = false` AND `_label.visible = false` AND `_caption_suppressed = true` are set; audio continues playing; `dialogue_line_finished` fires at natural completion.
- [ ] **AC-2** (from AC-DS-3.2): GIVEN the state from AC-1 (SUPPRESSED, line still in flight), WHEN `Events.document_closed` fires before the line ends, THEN `SubtitleCanvasLayer.visible = true`, `_label.visible = true`, `_caption_suppressed = false`, and the caption re-renders for the remaining duration with the same `text_key`.
- [ ] **AC-3** (from AC-DS-3.3): GIVEN D&S in VISIBLE state, WHEN `Events.ui_context_changed(MENU, GAMEPLAY)` fires (new_ctx = MENU), THEN `_caption_suppressed = true` and both `SubtitleCanvasLayer.visible` and `_label.visible` are false. Audio continues; `dialogue_line_finished` fires at natural completion. When context returns to GAMEPLAY with no line in flight, state is HIDDEN.
- [ ] **AC-4** (from AC-DS-3.4): GIVEN the full `src/` tree, WHEN CI runs `grep -rn --exclude-dir=tests "\bDialogueAndSubtitles\b\|\bSubtitleCanvasLayer\b\|\b_caption_suppressed\b" src/` excluding `dialogue_and_subtitles.gd` and its test file, THEN zero matches are returned. This verifies DOV and all other systems never reach into D&S.
- [ ] **AC-5** (from AC-DS-2.2 §C.2 state table): GIVEN the §C.2 state transition table, WHEN each trigger is replayed in a GUT test, THEN the resulting state matches the table for all 8 rows: HIDDEN→VISIBLE, HIDDEN→HIDDEN (subtitles disabled), HIDDEN→SUPPRESSED, SUPPRESSED→SUPPRESSED (line started while suppressed), VISIBLE→HIDDEN, VISIBLE→SUPPRESSED, SUPPRESSED→VISIBLE, SUPPRESSED→HIDDEN.
- [ ] **AC-6** (from AC-DS-2.5b): GIVEN all `Events.*` subscriptions connected by this story (`document_opened`, `document_closed`, `ui_context_changed`), WHEN `_exit_tree()` is called, THEN each subscription is disconnected with `is_connected()` guard before returning. Combined with Story 002's teardown, all subscriptions (including Story 002's + Story 003's) are disconnected.
- [ ] **AC-7** (from AC-DS-1.3): GIVEN `dialogue_and_subtitles.gd`, WHEN CI runs `grep -n "connect.*dialogue_line_started\|connect.*dialogue_line_finished" dialogue_and_subtitles.gd`, THEN zero matches (D&S does not subscribe to its own signals — FP-DS-1).

---

## Implementation Notes

*Derived from ADR-0002 IG 3, ADR-0004 §IG5, GDD CR-DS-3, CR-DS-4, §C.2 state machine:*

The three suppression subscriptions are added to `_ready()` in `dialogue_and_subtitles.gd` (extending Story 002's implementation):

```gdscript
func _ready() -> void:
    # ... Story 002 subscriptions (actor_became_alerted, etc.) ...
    Events.document_opened.connect(_on_document_opened)
    Events.document_closed.connect(_on_document_closed)
    Events.ui_context_changed.connect(_on_ui_context_changed)
    # ... player ref deferred resolution ...
```

Suppression path (CR-DS-4):

```gdscript
func _on_document_opened(_id: StringName) -> void:
    _caption_suppressed = true
    _subtitle_canvas_layer.visible = false
    _label.visible = false          # J.3 mitigation — belt-and-suspenders for VG-DS-3

func _on_document_closed(_id: StringName) -> void:
    _caption_suppressed = false
    _subtitle_canvas_layer.visible = true
    _label.visible = true
    # If a line is still in flight: SUPPRESSED → VISIBLE transition (§C.2)
    # If no line in flight: SUPPRESSED → HIDDEN transition (§C.2) — no-op, label is already empty
```

`_on_ui_context_changed` checks `new_ctx != InputContext.Context.GAMEPLAY` for suppression. Uses `InputContext` autoload (registered at line 4 per ADR-0007 — available from `_ready()` since D&S is a per-section node, initialized after all autoloads).

Internal flag is named `_caption_suppressed: bool` (v0.3 — renamed from `_suppressed` for unambiguous grep per AC-DS-3.4). This name must be consistent throughout the implementation.

Architectural invariant: D&S never calls `Audio.duck()` or reads any Audio bus in this handler — the suppression path only toggles `CanvasLayer.visible`. Audio independently subscribes to `document_opened` and applies Voice bus ducking (CR-DS-17) as its own subscriber-side logic. This separation is enforced by the `audio_ducking_in_dialogue_subtitles` forbidden pattern.

J.3 mitigation note: `_label.visible = false` is implemented preemptively alongside `SubtitleCanvasLayer.visible = false` in the suppression path. This adds zero cost and eliminates AT-leak risk regardless of VG-DS-3 outcome.

The SUPPRESSED state during a bark-in-flight (§C.2 row 4): when `dialogue_line_started` fires while `_caption_suppressed = true`, audio plays normally via Story 002's lifecycle; the `_label.text` assignment in step 5 of CR-DS-2 is skipped (label stays hidden). On `document_closed`, if the line is still in flight, `_caption_suppressed = false` re-shows the label — the `text_key` is already stored in `_current_text_key` and re-displayed.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: Signal declarations and `DialogueLine` schema (must be DONE)
- Story 002: Orchestrator playback lifecycle (must be DONE)
- Story 004: `SubtitleLabel` typography, Theme resource, `auto_translate_mode`, layout dimensions, accessibility name composition (§C.12 AccessKit — deferred post-VS for VG-DS-2 verification)
- Story 005: Integration smoke test (Plaza BQA briefing + one `document_opened` → suppress → restore flow verified end-to-end)
- Post-VS: Full `ui_context_changed` context resolution beyond GAMEPLAY/non-GAMEPLAY binary; CURIOSITY_BAIT full-bark protection across suppression (CR-DS-6 plays into Cluster C.4 edge case)

---

## QA Test Cases

**AC-1 — document_opened suppression**
- **Given**: `DialogueAndSubtitles` with mock `Events`; line in flight (caption VISIBLE)
- **When**: mock-emit `Events.document_opened(&"doc_001")`
- **Then**: `SubtitleCanvasLayer.visible == false`; `_label.visible == false`; `_caption_suppressed == true`; mock `AudioLinePlayer` still playing (not stopped)
- **Edge cases**: `document_opened` fires with no line in flight — suppression still applies (HIDDEN→SUPPRESSED transition per §C.2); next bark trigger queues audio but caption deferred until `document_closed`

**AC-2 — document_closed restore (line still in flight)**
- **Given**: state from AC-1 (SUPPRESSED, mock audio still playing)
- **When**: mock-emit `Events.document_closed(&"doc_001")`
- **Then**: `SubtitleCanvasLayer.visible == true`; `_label.visible == true`; `_caption_suppressed == false`; `_label.text` equals the stored `_current_text_key` (caption restored)
- **Edge cases**: `document_closed` fires after line has finished — state SUPPRESSED→HIDDEN; layer re-shown but label is empty (correct)

**AC-3 — ui_context_changed suppression**
- **Given**: line in flight (VISIBLE state); mock `InputContext` with `Context.GAMEPLAY` → `Context.MENU` transition
- **When**: mock-emit `Events.ui_context_changed(InputContext.Context.MENU, InputContext.Context.GAMEPLAY)`
- **Then**: `_caption_suppressed == true`; audio continues (not stopped); `dialogue_line_finished` fires at natural audio+timer completion
- **When**: mock-emit back to `Events.ui_context_changed(InputContext.Context.GAMEPLAY, InputContext.Context.MENU)` with no line in flight
- **Then**: `_caption_suppressed == false`; state HIDDEN

**AC-4 — Reverse-grep isolation**
- **Given**: full `src/` tree
- **When**: CI runs `grep -rn --exclude-dir=tests "\bDialogueAndSubtitles\b\|\bSubtitleCanvasLayer\b\|\b_caption_suppressed\b" src/` excluding `dialogue_and_subtitles.gd` and its test
- **Then**: zero matches (DOV, Audio, HSS, MLS — none reference D&S internals)
- **Edge cases**: test file grep-exclusion must be correct (`--exclude-dir=tests` + file-level exclusion of `dialogue_and_subtitles.gd`)

**AC-5 — Full §C.2 state machine**
- **Given**: `DialogueAndSubtitles` test instance with mock `Events`, mock audio player
- **When**: each §C.2 trigger is applied to the correct starting state in sequence
- **Then**: resulting state matches each row of the §C.2 table (all 8 transitions verified as separate assertions)
- **Edge cases**: SUPPRESSED + `dialogue_line_started` (row 4) — audio plays; caption label deferred; state stays SUPPRESSED (not VISIBLE)

**AC-6 — Subscription teardown (combined with Story 002)**
- **Given**: all subscriptions active (Story 002's actor/settings subscriptions + Story 003's document/context subscriptions)
- **When**: `_exit_tree()` called
- **Then**: `Events.document_opened.is_connected(_on_document_opened) == false`; `Events.document_closed.is_connected(_on_document_closed) == false`; `Events.ui_context_changed.is_connected(_on_ui_context_changed) == false`; and Story 002 subscriptions also disconnected

**AC-7 — FP-DS-1 self-subscribe grep**
- **Given**: `dialogue_and_subtitles.gd`
- **When**: `grep -n "connect.*dialogue_line_started\|connect.*dialogue_line_finished"`
- **Then**: zero matches

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/feature/dialogue_subtitles/suppression_state_machine_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 DONE (orchestrator must exist for suppression handlers to attach to)
- Unlocks: Story 004 (renderer can now be configured with suppression already in place), Story 005 (Plaza smoke requires suppression to demonstrate the document → suppress → restore flow)
