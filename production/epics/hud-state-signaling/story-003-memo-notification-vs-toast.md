# Story 003: MEMO_NOTIFICATION — document pickup toast (VS scope)

> **Epic**: HUD State Signaling
> **Status**: Complete — 2026-05-03 (Sprint 06)
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 2-3 hours (S — new subscription + state-entry + resolver extension + VS-flag test skip scaffold)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/hud-state-signaling.md`
**Requirement**: TR-HSS-011 (VS scope: MEMO_NOTIFICATION document pickup toast, ~3 s, subscriber-only pattern)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: HSS subscribes to `Events.document_collected(document_id: StringName)` (frozen ADR-0002 signal signature). On receipt, HSS resolves the `Document` Resource via DC's public method `DC.get_document_resource(document_id) -> Document` (Document Collection §C.0 public API — not an Events signal; a direct method call on the DC system node, which is a sibling under `Section/Systems/`). If DC is not available or `document_id` is not found in its registry, HSS suppresses with `push_warning` and does not enter MEMO_NOTIFICATION state. MEMO_NOTIFICATION text composes `tr("HUD_DOCUMENT_COLLECTED") + " — " + tr(doc.title_key)`. Priority is 6 (lowest HSS state per CR-6 — MEMO is informational; ALERT_CUE at priority 3 preempts it). The single-deep queue buffer holds at most one lower-priority state; MEMO may be dropped if queued behind ALERT_CUE whose Timer exceeds `queued_state_max_age_s = 5.0 s` (GDD §C.3). This is acceptable: the document is in the inventory; the toast is informational, not authoritative.

**Engine**: Godot 4.6 | **Risk**: LOW–MEDIUM (ADR-0004 Proposed)
**Engine Notes**: No post-cutoff APIs introduced in this story beyond those already present in Story 002 (`accessibility_description`, `accessibility_live` via deferred-AccessKit pattern). `StringName` concatenation for document title composition uses `tr(doc.title_key)` — `doc.title_key` is a `StringName` key registered in the Localization Scaffold; `tr()` accepts `StringName` directly in Godot 4.0+. The composed string `tr("HUD_DOCUMENT_COLLECTED") + " — " + tr(doc.title_key)` is dynamically constructed at state-entry and never cached (locale may change during the 3 s window per CR-7 + E.12).

> **VS feature-flag gate**: All MEMO_NOTIFICATION tests use `ProjectSettings.get_setting("game/feature_flags/hss_vs_scope_enabled", false)` to skip when the flag is `false`. This is the VS-blocked AC skip mechanism per GDD §CI skip mechanism (REV-2026-04-28). Tests MUST NOT silently pass when VS-gated — they must explicitly `skip()` with reason `"BLOCKED-on VS sprint"`.

**Control Manifest Rules (Presentation)**:
- Required: all visible strings through `tr()` — composed title string uses `tr(doc.title_key)`, never a raw title (GDD CR-7, FP-HSS-7)
- Required: defensive null-check on `DC.get_document_resource(id)` return — if null, `push_warning` and suppress (GDD §C.2 MEMO_NOTIFICATION trigger row)
- Required: `accessibility_live = "polite"` (GDD CR-8) — MEMO_NOTIFICATION is a bureaucratic acknowledgment, never demands attention
- Required: `accessibility_description` cleared on state-exit via `call_deferred` (deferred-AccessKit pattern, same as Story 002)
- Forbidden: any `Events.*.emit(...)` call in HSS source — pattern `hss_publishing_signals` (GDD FP-HSS-8 + CR-1)
- Forbidden: `_label.text` direct write — text is returned via `_resolve_hss_state()` callback only (GDD CR-4 REV-2026-04-28)
- Forbidden: MEMO_NOTIFICATION auto-dismiss `wait_time > 8.0 s` — FP-HSS-6 absolute cap; default is 3.0 s per §G.1

---

## Acceptance Criteria

*From GDD `design/gdd/hud-state-signaling.md` §Acceptance Criteria, VS-scope, scoped to this story. All ACs here are BLOCKING VS (skip when `hss_vs_scope_enabled == false`).*

- [ ] **AC-MEMO-1** [BLOCKING VS]: GIVEN `Events.document_collected(doc_id)` fires AND DC registry contains the document AND ALERT_CUE is NOT active (no higher-priority HSS state), WHEN the signal handler runs, THEN: `_memo_timer.is_stopped() == false` AND `_memo_timer.time_left == memo_notification_duration_s` (default 3.0) AND `_resolve_hss_state()` returns `{"text": tr("HUD_DOCUMENT_COLLECTED") + " — " + tr(doc.title_key), "state_id": HSSState.MEMO_NOTIFICATION}`. [§C.2 MEMO row, CR-5, CR-7]

- [ ] **AC-MEMO-2** [BLOCKING VS]: GIVEN `Events.document_collected(doc_id)` fires AND ALERT_CUE is currently active (priority 3 > priority 6), WHEN the priority resolver evaluates, THEN MEMO_NOTIFICATION is placed in `_queued_state` (single-deep buffer, `queued_at_time = now`) AND the ALERT_CUE label text is unchanged. [CR-6, §C.3 single-deep buffer]

- [ ] **AC-MEMO-3** [BLOCKING VS]: GIVEN MEMO_NOTIFICATION is queued behind ALERT_CUE with `queued_at_time = T_queue`, WHEN ALERT_CUE's Timer expires AND `(now - T_queue) <= queued_state_max_age_s` (5.0 s), THEN MEMO_NOTIFICATION activates: `_resolve_hss_state()` returns the composed MEMO text AND `_memo_timer` is running. [§C.3 freshness check, §G.1 `queued_state_max_age_s`]

- [ ] **AC-MEMO-4** [BLOCKING VS]: GIVEN MEMO_NOTIFICATION is queued with `queued_at_time = T_queue`, WHEN ALERT_CUE's Timer expires AND `(now - T_queue) > queued_state_max_age_s` (5.0 s), THEN MEMO_NOTIFICATION is discarded: `_resolve_hss_state()` returns HIDDEN AND `_queued_state` is empty. [§C.3 discard rule — document already in inventory; toast is informational]

- [ ] **AC-MEMO-5** [BLOCKING VS]: GIVEN `Events.document_collected(doc_id)` fires AND `DC.get_document_resource(doc_id)` returns null (unknown id), WHEN the signal handler runs, THEN HSS calls `push_warning(...)` AND does NOT enter MEMO_NOTIFICATION state (timer not started, no text update). [§C.2 defensive suppression]

- [ ] **AC-MEMO-6** [BLOCKING VS]: GIVEN MEMO_NOTIFICATION active, WHEN `Events.ui_context_changed.emit(Context.DOCUMENT_OVERLAY, Context.GAMEPLAY)` fires, THEN `_memo_timer.is_stopped() == true` AND state cleared (CR-11 applies to all HSS states). [CR-11]

- [ ] **AC-MEMO-7** [BLOCKING VS]: GIVEN HSS source with MEMO_NOTIFICATION added, WHEN CI grep runs `Events\..*\.emit\(` against `src/ui/hud_state_signaling.gd`, THEN zero matches (subscriber-only posture maintained). [CR-1, FP-HSS-8]

- [ ] **AC-MEMO-8** [BLOCKING VS] (subscriber lifecycle for VS subscription): GIVEN the section is loaded, WHEN HSS `_ready()` runs, THEN `Events.document_collected.is_connected(_on_document_collected) == true`. AND: GIVEN section is unloaded, WHEN `_exit_tree()` runs, THEN `Events.document_collected.is_connected(_on_document_collected) == false`. [CR-10, ADR-0002 IG 3]

- [ ] **AC-MEMO-9** [BLOCKING VS]: GIVEN all five VS Timer nodes exist in `HUDStateSignaling.tscn`, WHEN scene is instantiated, THEN `_memo_timer.wait_time == 3.0` (matching §G.1 default). [F.1, §G.1, AC-HSS-4.2 partial coverage for MEMO]

---

## Implementation Notes

*Derived from ADR-0002 IG 3 + GDD §C.2, §C.3, CR-1, CR-5, CR-7, CR-10, CR-11:*

**New Timer node** in `HUDStateSignaling.tscn` (added alongside existing `AlertCueTimer`):

```
HUDStateSignaling (root)
├── AlertCueTimer     (one_shot = true, wait_time = 2.0)  ← Story 001/002
└── MemoTimer         (one_shot = true, wait_time = 3.0)  ← this story
```

**New `@onready` declaration** in `hud_state_signaling.gd`:

```gdscript
@onready var _memo_timer: Timer = $MemoTimer
```

**`_ready()` additions** (alongside existing connections from Story 001 / 002):

```gdscript
# CR-10: VS subscription — synchronous connect, no CONNECT_DEFERRED (FP-HSS-15)
Events.document_collected.connect(_on_document_collected)
_memo_timer.timeout.connect(_on_memo_dismissed)
```

**Signal handler** — with DC registry lookup and defensive null-guard:

```gdscript
func _on_document_collected(document_id: StringName) -> void:
    # Resolve Document resource via DC's public API (not a scene-tree walk)
    var doc: Document = DC.get_document_resource(document_id) if is_instance_valid(DC) else null
    if doc == null:
        push_warning("HSS: document_collected fired for unknown id '%s'; MEMO_NOTIFICATION suppressed." % document_id)
        return

    _enter_memo_notification_state(doc)


func _enter_memo_notification_state(doc: Document) -> void:
    var priority: int = HSSState.get_priority(HSSState.MEMO_NOTIFICATION)
    var current_priority: int = HSSState.get_priority(_current_hss_state)

    if priority > current_priority:
        # Lower-priority arrival: queue in single-deep buffer
        _queued_state = {
            "state_id": HSSState.MEMO_NOTIFICATION,
            "doc": doc,
            "queued_at_time": Time.get_ticks_msec() / 1000.0
        }
        return

    # Priority equal or higher: activate immediately (same-priority → drop per §C.3)
    if priority == current_priority:
        return  # Same-priority collision — dropped (E.1 / §C.3 same-priority collision rule)

    _current_hss_state = HSSState.MEMO_NOTIFICATION
    _current_memo_doc = doc
    call_deferred("_set_accesskit_for_current_state")
    _memo_timer.start(_memo_notification_duration_s)
```

**`_resolve_hss_state()` extension** — returns MEMO text when active:

```gdscript
func _resolve_hss_state() -> Dictionary:
    match _current_hss_state:
        HSSState.ALERT_CUE:
            return {"text": tr("HUD_GUARD_ALERTED"), "state_id": HSSState.ALERT_CUE}
        HSSState.MEMO_NOTIFICATION:
            var title_text: String = tr(_current_memo_doc.title_key) if _current_memo_doc != null else ""
            return {
                "text": tr("HUD_DOCUMENT_COLLECTED") + " — " + title_text,
                "state_id": HSSState.MEMO_NOTIFICATION
            }
        _:
            return {"text": "", "state_id": HSSState.HIDDEN}
```

The em-dash separator `" — "` uses the Unicode literal `—` to avoid FP-HSS-2's emoji regex while preserving the period-typographic BQA register per §V.2. The composer must NOT use any Unicode pictogram characters (FP-HSS-2).

**Queue drain on ALERT_CUE dismiss** — add to `_on_alert_cue_dismissed()`:

```gdscript
func _on_alert_cue_dismissed() -> void:
    _current_hss_state = HSSState.HIDDEN
    call_deferred("_clear_accesskit")
    _drain_queued_state()  # check single-deep buffer


func _drain_queued_state() -> void:
    if _queued_state.is_empty():
        return
    var age: float = (Time.get_ticks_msec() / 1000.0) - _queued_state["queued_at_time"]
    if age > _queued_state_max_age_s:
        _queued_state.clear()
        return
    # Activate the queued state
    var queued_id: HSSState = _queued_state["state_id"]
    if queued_id == HSSState.MEMO_NOTIFICATION:
        var doc: Document = _queued_state.get("doc")
        _queued_state.clear()
        if doc != null:
            _enter_memo_notification_state(doc)
```

**`_exit_tree()` additions**:

```gdscript
if Events.document_collected.is_connected(_on_document_collected):
    Events.document_collected.disconnect(_on_document_collected)
if not _memo_timer.is_stopped():
    _memo_timer.stop()
_queued_state.clear()
```

**VS feature-flag skip pattern** in test files:

```gdscript
func test_memo_notification_happy_path() -> void:
    if not ProjectSettings.get_setting("game/feature_flags/hss_vs_scope_enabled", false):
        skip("BLOCKED-on VS sprint")
        return
    # ... test body
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: structural scaffold, HUD Core handshake, `_label` reference — must be DONE
- Story 002: ALERT_CUE logic and the rate-gate pattern that this story relies on for priority arbitration — must be DONE
- VS-scope states ALARM_STINGER, RESPAWN_BEAT, SAVE_FAILED — deferred post-VS per VS-narrowing (these require additional signal subscriptions and their priority slots in the resolver)
- Full priority resolver multi-state tests (AC-HSS-3.1..3.7) covering ALARM_STINGER and INTERACT_PROMPT preemption — post-VS
- CR-18 critical-health pulse — VS only, separate HUD Core API needed
- AC-HSS-7.1 / 7.2 save/load transient discipline tests — VS; depend on SaveGame schema being final
- AC-HSS-10.2 playtest validation (VS full Tower session) — Advisory; separate QA activity

---

## QA Test Cases

*Solo mode — test cases following GDD AC structure. All tests skip if `hss_vs_scope_enabled == false`.*

**AC-MEMO-1** — Happy path, no active HSS state
- **Given**: HSS instance (Stories 001 + 002 in place), mock DC returning a valid `Document` with `title_key = &"doc_memo_tower_sanitation"`, no active HSS state
- **When**: `Events.document_collected.emit(&"doc_001")`
- **Then**: `_memo_timer.is_stopped() == false` AND `_resolve_hss_state()["state_id"] == HSSState.MEMO_NOTIFICATION` AND resolved text contains `"DOCUMENT FILED"` (EN) AND `" — "` separator AND `tr(&"doc_memo_tower_sanitation")`
- **Edge cases**: Document with very long title (>40 chars) — Label uses `clip_text = true` per HUD Core §C.2; text is set correctly even if clipped in render

**AC-MEMO-2 / AC-MEMO-3 / AC-MEMO-4** — Queue behavior
- **Given**: ALERT_CUE active (Timer running, time_left = 1.5 s)
- **When**: `document_collected` fires
- **Then**: `_queued_state` contains `{state_id: MEMO_NOTIFICATION, doc: <doc>, queued_at_time: T}`; ALERT_CUE label unchanged
- **When** (fresh): ALERT_CUE Timer expires AND age(MEMO) ≤ 5.0 s → MEMO activates
- **When** (stale): ALERT_CUE Timer expires AND age(MEMO) > 5.0 s → `_queued_state.is_empty() == true`
- **Edge cases**: Two `document_collected` signals arrive while ALERT_CUE is active → second overwrites first in single-deep buffer (latest wins per §C.3)

**AC-MEMO-5** — Unknown document id
- **Given**: `DC.get_document_resource(&"nonexistent_id")` returns null
- **When**: `Events.document_collected.emit(&"nonexistent_id")`
- **Then**: `push_warning` is called (verify via GUT `assert_has_push_warning`) AND `_resolve_hss_state()["state_id"] == HSSState.HIDDEN` (no state entry)
- **Edge cases**: DC system node itself is null (not in scene) → `is_instance_valid(DC)` guard → `push_warning` AND no crash

**AC-MEMO-7** — Subscriber-only posture maintained after VS additions
- **Given**: `src/ui/hud_state_signaling.gd` after this story's changes
- **When**: `grep "Events\..*\.emit(" src/ui/hud_state_signaling.gd`
- **Then**: zero matches
- **Edge cases**: any future contributor adding a `document_collected` re-emit accidentally → CI catches it

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `production/qa/evidence/hss-memo-notification-evidence.md` — manual walkthrough showing MEMO_NOTIFICATION renders briefly on document pickup in Plaza VS (screenshot evidence + timing notes); required before story can be marked Done
- `tests/unit/presentation/hud_state_signaling/test_memo_notification.gd` — AC-MEMO-1, AC-MEMO-5; must exist and pass (VS-flagged skip when disabled)
- `tests/unit/presentation/hud_state_signaling/test_priority_resolver_queue.gd` — AC-MEMO-2, AC-MEMO-3, AC-MEMO-4; must exist and pass (VS-flagged skip when disabled)
- `tests/integration/presentation/hud_state_signaling/test_section_unload.gd` — AC-MEMO-8 VS extension; must pass (VS-flagged skip when disabled)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (structural scaffold) must be DONE
- Depends on: Story 002 (ALERT_CUE logic + priority machinery) must be DONE — MEMO_NOTIFICATION builds on the state-machine pattern and priority arbitration established there
- Depends on: DC's `get_document_resource(id)` public API confirmed available (Document Collection §C.0 — DC OQ-DC-8 closed per GDD §F.3)
- Depends on: `HUD_DOCUMENT_COLLECTED` translation key registered in Localization Scaffold (Coord item §F.5 #4)
- Depends on: VS feature flag `game/feature_flags/hss_vs_scope_enabled` mechanism in place (GDD §CI skip mechanism REV-2026-04-28)
- Unlocks: post-VS story for ALARM_STINGER / RESPAWN_BEAT / SAVE_FAILED (full VS state machine); closes DC OQ-DC-8 BLOCKING coord
