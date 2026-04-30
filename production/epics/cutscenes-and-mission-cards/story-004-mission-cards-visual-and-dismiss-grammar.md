# Story 004: Mission briefing + closing cards — visual spec, localization, and dismiss grammar

> **Epic**: Cutscenes & Mission Cards
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 4-5 hours (L — full card scene implementation, localization integration, PPS lifecycle, dismiss-gate timer, manual walkthrough evidence)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/cutscenes-and-mission-cards.md`
**Requirements**: TR-CMC-009, TR-CMC-010, TR-CMC-013, TR-CMC-014
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

- **TR-CMC-009**: Outline escape-hatch via `OutlineTier.set_tier` for cinematic emphasis (restoration on exit) per ADR-0001 stencil contract.
- **TR-CMC-010**: `PostProcessStack` lifecycle calls `enable_sepia_dim()`/`disable_sepia_dim()` for narrative dim per ADR-0004 §IG4 (PPS API).
- **TR-CMC-013**: Localization: all visible card text uses `tr()` keys; `auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED` per CR-CMC-15 + ADR-0004.
- **TR-CMC-014**: Input action for cutscene-dismiss (`cutscene_dismiss`; owned by Input GDD per CR-CMC-18); 4.0/5.0/3.0 s dismiss-gate trio per `InputContext.CUTSCENE`. (AC-CMC-4.1 through AC-CMC-4.4)

**UX Spec**: `design/ux/re-brief-operation.md` (Re-Brief Operation modal — not a card spec, but its `modal-scaffold` pattern governs sibling modal patterns; card dismiss grammar derives from the same parent).

**ADR Governing Implementation**: ADR-0004 (UI Framework — Theme, FontRegistry, InputContext) + ADR-0001 (Outline Pipeline — save-restore discipline) + ADR-0002 (Signal Bus)
**ADR Decision Summary**: Cards use `project_theme.tres` as `fallback_theme`; per-surface child Themes override only surface-specific values. `FontRegistry` provides typed font getters with Futura→DIN size-floor substitution. Modal dismiss via `_unhandled_input()` checking `cutscene_dismiss` action (NOT `ui_cancel`) — sidestepping Godot 4.6 dual-focus split (ADR-0004 §Decision rule 4). `auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED` on all card Labels with manual `_notification` handler for live locale re-resolution (ADR-0004 Gate 4 closed). PPS sepia-dim called at `_open_card` entry / `_dismiss` exit for briefing card only; fade-to-black called at closing card dismiss (CR-CMC-22).

**Engine**: Godot 4.6 | **Risk**: MEDIUM (ADR-0004 status Proposed; Godot 4.6 dual-focus split affects `_unhandled_input` + `cutscene_dismiss` action; `AUTO_TRANSLATE_MODE_DISABLED` verified 4.5+ per Gate 4)
**Engine Notes**: `_unhandled_input` dispatch on a `CanvasLayer` root is verified stable since Godot 4.0 per ADR-0004 Gate 3. `cutscene_dismiss` is a project-defined InputMap action (default Esc + B/Circle); must be registered in `project.godot [input]` block per ADR-0004 Finding F3 (gamepad requires explicit binding — no engine default for custom actions). `PostProcessStack.enable_fade_to_black(duration_s)` is a new API added per OQ-CMC-5 BLOCKING coord; verify it exists before calling.

> "PostProcessStack.enable_fade_to_black() was introduced per OQ-CMC-5 coord — verify against PostProcessStack GDD before implementing; flag if not yet available."

**Control Manifest Rules (Presentation Layer)**:
- Required: all card text via `tr(key)` at render time; `auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED` on all Label nodes; `_notification` handler re-resolves on `NOTIFICATION_TRANSLATION_CHANGED` (CR-CMC-15, ADR-0004)
- Required: `fallback_theme` set on the surface's root Control pointing to `project_theme.tres` (ADR-0004 §Decision rule 1; property is `fallback_theme` NOT `base_theme` — the latter does not exist per Gate 2 closure)
- Required: `FontRegistry.menu_title()` for card title (Futura Extra Bold Condensed @ 36 px), `FontRegistry.document_body()` for body text (American Typewriter Regular @ 18 px) — ADR-0004 §Key Interfaces
- Required: `OutlineTier.restore_prior_tier()` called in `_cleanup()` from ALL exit paths if `set_tier(NONE)` was called at cinematic start (CR-CMC-14, ADR-0001 IG 3)
- Forbidden: `cmc_pushing_subtitle_visibility` — Cutscenes never calls HUD Core or D&S to hide/show; HUD auto-hides via InputContext (CR-CMC-9)
- Forbidden: hardcoded English strings in any Label or RichTextLabel on card nodes — all text via `tr()` (CR-CMC-15)
- Forbidden: `corner_radius_*` non-zero, `shadow_*` non-zero, `glow_*` non-zero on any card StyleBoxFlat (FP-V-CMC-5, FP-V-CMC-6, FP-V-CMC-3)
- Forbidden: `ui_cancel` in `_unhandled_input` dismiss handler — use `cutscene_dismiss` action only (C.2.4)
- Guardrail: Slot 7 CPU peak ≤ 0.20 ms with card active (F.1); briefing card 0.03–0.07 ms; no `_process` or `_physics_process` overrides in card sub-scripts (F.2)

---

## Acceptance Criteria

*From GDD §V.1, AC-CMC-4.1 through AC-CMC-8.3, CR-CMC-14, CR-CMC-22:*

**Dismiss grammar (F.4, C.2):**

- [ ] **AC-1**: GIVEN Mission Briefing Card displayed (`_dismiss_gate_active == true`, `t_elapsed < 4.0 s`), WHEN synthetic `cutscene_dismiss` action delivered to `_unhandled_input`, THEN `set_input_as_handled()` called, `_dismiss()` NOT called, `_dismiss_gate_active` remains `true`. (AC-CMC-4.1) — BLOCKED on OQ-CMC-9 (`cutscene_dismiss` in InputMap)
- [ ] **AC-2**: GIVEN Briefing Card and `SceneTree.create_timer(4.0, true)` has fired (mocked clock), WHEN synthetic `cutscene_dismiss` delivered, THEN `_dismiss_gate_active == false`, `_dismiss()` called once, `InputContext.pop()` fires, `_context_pushed == false`. Hard-cut to gameplay — no fade, no animation. (AC-CMC-4.2) — BLOCKED on OQ-CMC-9
- [ ] **AC-3**: GIVEN Briefing Card, Closing Card, and Objective Card instantiated separately, WHEN dismiss-gate timer fires per surface, THEN `gate_duration_s` matches: Briefing 4.0 s / Closing 5.0 s / Objective 3.0 s. Assert via spy on `get_tree().create_timer(duration, true)` call argument. (AC-CMC-4.3)
- [ ] **AC-4**: GIVEN `cutscene_dismiss` fires at any point during CT-05 first-watch AND `accessibility_allow_cinematic_skip == false` (default), THEN `_dismiss()` NOT called. Cinematics have no dismiss-gate (CR-CMC-2.2 default). Assert `_dismiss()` call count == 0 throughout. (AC-CMC-4.4)
- [ ] **AC-5**: GIVEN `cutscenes_and_mission_cards.gd`, WHEN `grep -n "ui_cancel"` run, THEN zero matches. Sole dismiss action is `cutscene_dismiss`. (AC-CMC-4.5) — BLOCKED on OQ-CMC-9

**Localization (CR-CMC-15):**

- [ ] **AC-6**: GIVEN Briefing Card with `title_key = &"cutscenes.mission_card.briefing.title"` and `body_key = &"cutscenes.mission_card.briefing.body"`, WHEN `_populate_briefing_card(title_key, body_key)` executes, THEN `_briefing_title_label.text == tr(title_key)` AND `_briefing_body_label.text == tr(body_key)`. `_current_title_key` stores the StringName key, not the translated string. (AC-CMC-8.1)
- [ ] **AC-7**: GIVEN `cutscenes_and_mission_cards.gd` + `.tscn`, WHEN `grep -nE "auto_translate_mode\s*=\s*(ALWAYS|AUTO_TRANSLATE_MODE_ALWAYS)"` run on card Label nodes, THEN zero matches. All Labels declare `AUTO_TRANSLATE_MODE_DISABLED`. (AC-CMC-8.2)
- [ ] **AC-8**: GIVEN Briefing Card displayed with title Label visible, WHEN `_notification(NOTIFICATION_TRANSLATION_CHANGED)` fires, THEN `_briefing_title_label.text == tr(_current_title_key)` in new locale AND `_briefing_body_label.text == tr(_current_body_key)` — same frame, no card rebuild, no dismiss-gate reset. Handler returns early if no card visible. (AC-CMC-8.3)

**PPS + Outline lifecycle (CR-CMC-10, CR-CMC-14, CR-CMC-22):**

- [ ] **AC-9**: GIVEN Briefing Card `_open_card()` executes, WHEN `enable_sepia_dim()` is called, THEN Cutscenes spy records 1 call. WHEN `_dismiss()` executes, `disable_sepia_dim()` called once (1:1 pairing). `enable_fade_to_black()` NOT called for briefing (briefing exits via hard cut). (AC-CMC-6.4) — BLOCKED on OQ-CMC-5
- [ ] **AC-10**: GIVEN Mission Closing Card `_dismiss()` called, WHEN closing dismiss executes, THEN `PostProcessStack.enable_fade_to_black(0.4)` called once (24 × 1/60 = 0.4 s). WHEN fade completes, `disable_fade_to_black()` called once. (AC-CMC-6.3) — BLOCKED on OQ-CMC-5
- [ ] **AC-11**: GIVEN `OutlineTier.set_tier(OutlineTier.NONE)` called at cinematic start, WHEN `_cleanup()` called from normal dismiss, THEN `OutlinePipeline.restore_prior_tier()` called once. GIVEN `_cleanup()` called via `_exit_tree` abort (section unload), THEN `restore_prior_tier()` still called once. Spy count == 1 regardless of exit route. (AC-CMC-6.1, AC-CMC-6.2) — BLOCKED on OQ-CMC-5

**Visual fidelity (V.1 spec — ADVISORY):**

- [ ] **AC-12** [ADVISORY]: GIVEN live Godot editor at 1920×1080 with Mission Briefing Card displayed, WHEN screenshot captured, THEN: full-screen Parchment `#F2E8C8`; BQA Blue `#1B3A6B` header strip 80 px tall flush top; `OPERATION: PARIS AFFAIR` Futura Extra Bold Condensed @ 36 px Ink Black tracking −10 at 148 px from top; American Typewriter Regular @ 18 px body left-aligned 72 px margin; classification stamp "CLASSIFIED — BQA EYES ONLY" rotated −5° bottom-right; zero rounded corners, zero drop shadows, zero glow; HUD hidden. Art-director sign-off. (AC-CMC-11.1)

---

## Implementation Notes

*Derived from ADR-0004 Implementation Guidelines + GDD §C.11, §C.12, §V.1, §V.2, §C.8:*

**Scene layout** (GDD V.1 spec — implement in `.tscn`):

Briefing Card root: `Control` (MOUSE_FILTER_IGNORE, FOCUS_NONE) with children:
- `ColorRect` Parchment `#F2E8C8` anchored FULL_RECT
- `ColorRect` BQA Blue `#1B3A6B` header strip 80 px × full width flush top
- `Label` title: `FontRegistry.menu_title()` 36 px Ink Black `#0A0A0A` tracking −10, positioned 148 px from top, center-horizontal; `auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED`
- `RichTextLabel` body: `FontRegistry.document_body()` 18 px Ink Black, left-aligned 72 px margin; `custom_minimum_size = Vector2(560, 0)` (52-char line cap); `auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED`
- `TextureRect` classification stamp: `ui_stamp_classified_bqa.png` bottom-right 32 px × 72 px margin, rotation `−5°`

**FontRegistry usage** (ADR-0004 §Key Interfaces):

```gdscript
func _ready() -> void:
    _title_label.add_theme_font_override("font", FontRegistry.menu_title())
    _title_label.add_theme_font_size_override("font_size", 36)
    _body_label.add_theme_font_override("font", FontRegistry.document_body())
    _body_label.add_theme_font_size_override("font_size", 18)
```

**Localization integration** (GDD §C.11 + CR-CMC-15):

```gdscript
func _populate_briefing_card(title_key: StringName, body_key: StringName) -> void:
    _briefing_title_label.text = tr(title_key)
    _briefing_body_label.text = tr(body_key)
    _current_title_key = title_key
    _current_body_key = body_key

func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED:
        if not _briefing_card.visible:
            return
        _briefing_title_label.text = tr(_current_title_key)
        _briefing_body_label.text = tr(_current_body_key)
```

`AUTO_TRANSLATE_MODE_DISABLED` prevents the engine's built-in translate pass from racing with the manual `_notification` handler. Matches Document Overlay UI CR-7/CR-8 pattern.

**Translation keys for VS scope** (GDD §C.6 localization key naming convention):

```
cutscenes.mission_card.briefing.title     → "OPERATION: PARIS AFFAIR"
cutscenes.mission_card.briefing.body      → (BQA body copy per §C.4.1)
cutscenes.mission_card.briefing.stamp_classification  → "CLASSIFIED — BQA EYES ONLY"
cutscenes.mission_card.closing.title      → "OPERATION: PARIS AFFAIR — STATUS: CLOSED"
cutscenes.mission_card.closing.body       → (BQA closing copy per §C.4.2)
cutscenes.mission_card.closing.stamp_status  → "STATUS: CLOSED"
cutscenes.mission_card.closing.stamp_ref  → "REF: IT-65-002 ROUTED TO SECTION 6. ROME STATION ADVISED."
```

Register all 7 keys in `translations/cutscenes.csv` (OQ-CMC-8 partial delivery).

**Dismiss handler** (GDD §C.2.4 — `cutscene_dismiss` not `ui_cancel`):

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if not InputContext.is_active(InputContext.Context.CUTSCENE):
        return
    if not event.is_action_pressed(&"cutscene_dismiss"):
        return
    if _dismiss_gate_active:
        get_viewport().set_input_as_handled()
        return  # silent drop per FP-CMC-3
    _dismiss()
    get_viewport().set_input_as_handled()
```

**Hard-cut entry for Mission Cards** (CR-CMC-19 + Art Bible §3.7 + Pillar 5): Card appears instantaneously on the frame `_open_card()` is called. No Tween, no AnimationPlayer, no fade-in. `card.visible = true` is the only entry transition. Per-objective card uses 8-frame `TRANS_SINE EASE_OUT` translate-in (GDD V.2) — this story covers Mission Cards only.

**Closing card exit: 24-frame fade-to-black** (CR-CMC-19, CR-CMC-22): On `_dismiss()` for Closing Card, call `PostProcessStack.enable_fade_to_black(0.4)` (24/60 = 0.4 s). On fade completion, cut to credits/post-mission state and call `disable_fade_to_black()`. This is the only fade in the system per CR-CMC-19. Briefing card exits via hard cut (0 frames — `card.visible = false`).

**Outline save-restore discipline** (CR-CMC-14, ADR-0001 IG 3): `_cleanup()` is the sole site of `restore_prior_tier()`. It must be called from ALL exit paths: normal dismiss, timer-triggered auto-dismiss, `_exit_tree` abort. Code review must verify the call appears in every exit route.

**PPS sepia-dim** (CR-CMC-22): `enable_sepia_dim()` called at Briefing Card `_open_card()` start (not for Closing Card — Closing Card follows CT-05 which has already silenced everything). `disable_sepia_dim()` called at `_dismiss()`. 1:1 pairing enforced by `_context_pushed`-style guard (or directly in `_cleanup()`).

**AccessKit accessibility** (GDD §UI.3): Mission Briefing + Closing Cards:
- `accessibility_role = ROLE_DIALOG` (modal — CUTSCENE context blocks all other input)
- `accessibility_name = tr(title_key)`
- `accessibility_description = tr(body_key) + " " + tr(stamp_key)`
- `accessibility_live = LIVE_ASSERTIVE` on hard-cut entry
- Dismiss-gate open announcement: when `_dismiss_gate_active` becomes `false`, set `accessibility_description` to re-trigger screen-reader announcement via `LIVE_POLITE` channel (WCAG 2.1 SC 4.1.3 per GDD §UI.3)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: `_try_fire_card` replay suppression and one-active invariant (prerequisite for `_open_card` being called at all)
- Story 005: CI grep-based forbidden-pattern enforcement scripts (`check_forbidden_patterns_cutscenes.sh`)
- Per-objective opt-in cards visual spec (deferred post-VS per epic VS-narrowing — `CardType.OBJECTIVE_OPT_IN` stub may exist but no visual rendering at VS1)
- CT-03/CT-04/CT-05 cinematic AnimationPlayer implementation (deferred post-VS per epic VS-narrowing)
- CT-05 letterbox bars + op-art sub-CanvasLayer 11 (deferred post-VS)
- Full 16-key `translations/cutscenes.csv` roster (Story 005 delivers AC-CMC-8.4 smoke check; this story delivers the 7 keys for briefing + closing cards)
- `translations/cutscenes.csv` creation itself (OQ-CMC-8 Localization Scaffold coord — this story registers the keys but the CSV file authoring is Localization epic scope)

---

## QA Test Cases

*Solo mode — UI story. Manual verification steps per coding standards.*

**AC-6: Labels populated via tr() at render**
- Setup: Add `CutscenesAndMissionCards` to test scene; mock `tr()` to return key + "_translated" suffix
- When: `_populate_briefing_card(&"cutscenes.mission_card.briefing.title", &"cutscenes.mission_card.briefing.body")` called
- Verify: `_briefing_title_label.text == "cutscenes.mission_card.briefing.title_translated"`; `_current_title_key == &"cutscenes.mission_card.briefing.title"` (stored as key not string)
- Pass condition: `text` uses `tr()` result; `_current_title_key` stores raw StringName for re-resolution

**AC-8: Locale switch re-renders visible card**
- Setup: `CutscenesAndMissionCards` in test scene; Briefing Card visible; current locale = "en"
- When: `_notification(NOTIFICATION_TRANSLATION_CHANGED)` called (simulating locale switch to "fr")
- Verify: `_briefing_title_label.text` and `_briefing_body_label.text` updated to French locale strings; no card rebuild; `_dismiss_gate_active` unchanged
- Pass condition: Labels show new locale text in same frame; gate timer not reset

**AC-3 (manual): Dismiss gate durations**
- Setup: Add a test that spies on `SceneTree.create_timer(duration, true)` call arguments
- When: `_open_card` called for MISSION_BRIEFING, then MISSION_CLOSING, then OBJECTIVE_OPT_IN
- Verify: create_timer called with 4.0, 5.0, 3.0 respectively
- Pass condition: all three durations match GDD §G.1 exactly

**AC-12 (manual walkthrough — ADVISORY)**:
- Setup: Run game, reach Plaza section, observe `mission_started` fire
- Verify: Full-screen Parchment background; BQA Blue header strip; "OPERATION: PARIS AFFAIR" in correct typeface at correct position; classification stamp rotated -5deg bottom-right; HUD not visible; no drop shadows; no rounded corners
- Pass condition: screenshot matches V.1 spec; art-director sign-off in `production/qa/evidence/`

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `tests/unit/presentation/cutscenes_and_mission_cards/dismiss_gate_test.gd` — must exist and pass (AC-1, AC-2, AC-3, AC-4)
- `tests/unit/presentation/cutscenes_and_mission_cards/localization_test.gd` — must exist and pass (AC-6, AC-7, AC-8)
- `tests/unit/presentation/cutscenes_and_mission_cards/pps_lifecycle_test.gd` — must exist and pass (AC-9, AC-10, AC-11)
- `production/qa/evidence/story-004-mission-cards-visual-evidence.md` — manual walkthrough doc covering: card visual spec at 1080p (AC-12 ADVISORY), dismiss-gate silent-drop behavior observed, locale switch live re-render observed, HUD hidden during card display, no "Press any key" prompt visible at any point

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (scene scaffold DONE), Story 003 (replay suppression DONE — `_open_card` is called from `_try_fire_card`)
- BLOCKED on: OQ-CMC-1 (`InputContext.Context.CUTSCENE`) for dismiss handler; OQ-CMC-5 (PPS `enable_fade_to_black()` API) for AC-10; OQ-CMC-9 (`cutscene_dismiss` in InputMap) for AC-1, AC-2, AC-5
- Unlocks: Story 005 (forbidden-pattern CI fences — visual implementation must be in place to grep StyleBoxFlat corner_radius, auto_translate_mode, etc.); epic Definition of Done (Plaza briefing card + closing card are the VS deliverables)
