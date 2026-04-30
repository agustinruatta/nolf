# Story 005: Settings panel UI shell — layout, InputContext, navigation, AccessKit, forbidden-pattern CI gates

> **Epic**: Settings & Accessibility
> **Status**: BLOCKED — ADR-0004 is Proposed pending Gate 5 (BBCode → AccessKit plain-text serialization). Gate 1 (AccessKit property names on custom Controls) is also OPEN. Cannot implement TR-SET-012 (AccessKit) or TR-SET-011 (Theme inheritance property `fallback_theme`) until ADR-0004 advances to Accepted. Run `/architecture-decision` to advance ADR-0004.
> **Layer**: Polish (VS-expansion scope — settings UI accessible from Main Menu + Pause Menu)
> **Type**: UI
> **Estimate**: 6-8 hours (L — 6-sub-screen panel + navigation + focus model + AccessKit + CI gates)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/settings-accessibility.md`
**UX Spec**: `design/ux/settings-and-accessibility.md`
**Requirement**: TR-SET-006, TR-SET-011, TR-SET-012, TR-SET-013, TR-SET-016, TR-SET-017, TR-SET-018
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

- **TR-SET-006**: Settings panel pushes `InputContext.SETTINGS` on open, pops on close per ADR-0004 IG3 + CR-3.
- **TR-SET-011**: Theme inheritance: Settings sub-screens set `fallback_theme = preload(project_theme.tres)` per ADR-0004 Gate 2 closure (A5).
- **TR-SET-012**: AccessKit screen-reader integration for all settings widgets (Day-1 mandate per ADR-0004 IG10; BLOCKED on Gate 1 property-name verification).
- **TR-SET-013**: Modal dismiss via `_unhandled_input()` + `ui_cancel` action (Esc / B / Circle per ADR-0004 IG3).
- **TR-SET-016**: Keyboard rebinding captures one `InputEventKey/MouseButton` + one `InputEventJoypadButton/Motion` per action (no two-key bind) per CR-20.
- **TR-SET-017**: Settings owns UI debouncing on slider/spinner changes via `InputEvent.is_released()` gate per CR-14.
- **TR-SET-018**: Dead-end navigation announces two distinct `tr()` keys (`SETTINGS_NAV_DEAD_END_TOP` / `SETTINGS_NAV_DEAD_END_BOTTOM`) for grammatical correctness per Localization Scaffold.

**ADR Governing Implementation**: ADR-0004 (UI Framework — Proposed, Gates 1 + 5 OPEN) + ADR-0002 (Signal Bus)

**ADR Decision Summary**: ADR-0004 specifies: (1) `project_theme.tres` with `fallback_theme` inheritance (Gate 2 CLOSED 2026-04-27 — property is `fallback_theme`, NOT `base_theme`); (2) `InputContext.push(Context.SETTINGS)` on panel open, `InputContext.pop()` on close (Gate 3 CLOSED 2026-04-29 — `_unhandled_input()` + `ui_cancel` confirmed for modal dismiss); (3) AccessKit `accessibility_role`, `accessibility_name`, `accessibility_description`, `accessibility_live` on custom Controls (Gate 1 OPEN — exact property names unverified in Godot 4.6). CanvasLayer 10 is mutually exclusive with Cutscene letterbox per ADR-0004 §IG7 2026-04-27 annotation.

**BLOCKED: ADR-0004 Gate 1 — AccessKit property names**. The GDD §C.5 per-widget AccessKit table specifies property names for all widget classes (`HSlider` → `"slider"` role, `CheckButton` → `"switch"` role, etc.), but the actual Godot 4.6 property names are unverified. ADR-0004 Gate 1 notes: *"likely `accessibility_description` (NOT `accessibility_name`); `accessibility_role` may be inferred from node type rather than settable as string property; `accessibility_live` semantics + AT-flush timing require verification."* Do NOT implement TR-SET-012 until Gate 1 closes.

**BLOCKED: ADR-0004 Gate 5 — BBCode → AccessKit serialization**. Gate 5 is deferred to runtime AT testing — closure path is "Settings & Accessibility production story includes a runtime AT inspection task." This story IS that task. Upon implementation, the developer must run NVDA (Windows) or Orca (Linux) on the Document Overlay scene and confirm BBCode-formatted content is announced as plain text. Gate 5 verification is a prerequisite for marking TR-SET-012 done.

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: Godot 4.6 introduces dual-focus (mouse/touch focus separate from keyboard/gamepad focus). Every programmatic `grab_focus()` call in the Settings panel must set keyboard/gamepad focus only — mouse hover focus is independent (OQ-SA-10). `ItemList`, `HSplitContainer`, `ScrollContainer`, `HSlider`, `CheckButton`, `OptionButton` are all standard Godot Controls. ADR-0004 Gate 1 must be verified before AccessKit properties are set on any custom Control. `_unhandled_input()` + `ui_cancel` modal dismiss confirmed on Godot 4.6.2 stable (ADR-0004 Gate 3).

> "Godot 4.5 introduced AccessKit screen reader integration — verify actual property names against `docs/engine-reference/godot/` before implementing TR-SET-012. ADR-0004 Gate 1 is explicitly OPEN on this point."

**Control Manifest Rules (Presentation layer)**:
- Required: `InputContext.push(Context.SETTINGS)` on panel open; `InputContext.pop()` on close — source: ADR-0004 IG3 + TR-SET-006
- Required: Settings panel on CanvasLayer 10 — exclusive layer per ADR-0004 §IG7; no siblings on layer 10
- Required: `fallback_theme = preload("res://assets/ui/project_theme.tres")` on the panel root Control — source: ADR-0004 Gate 2 (A5); property is `fallback_theme`, NOT `base_theme`
- Required: `mouse_filter = MOUSE_FILTER_STOP` on panel root; `MOUSE_FILTER_PASS` on all interactive child widgets — source: GDD §C.4
- Required: modal dismiss via `_unhandled_input()` checking `ui_cancel`, NOT via a focused Button signal — source: ADR-0004 IG3; avoids Godot 4.6 dual-focus sidestep issues
- Required: Tab cycles within current focus column only (detail pane Tab wraps, does not cross to category list) — source: GDD §C.4 focus model + AC-SA-11.7 BLOCKING
- Required: `tr()` wrapper on ALL player-visible string assignments (FP-8) — source: GDD §C.8
- Required: dead-end navigation announces via `tr("SETTINGS_NAV_DEAD_END_BOTTOM")` / `tr("SETTINGS_NAV_DEAD_END_TOP")` — source: TR-SET-018, GDD AC-SA-11.8
- Forbidden: `grab_focus()` without confirming dual-focus behavior (OQ-SA-10) — verify mouse focus is not inadvertently overridden
- Forbidden: zero-padding, animate transitions between sub-screens, fade-in on panel mount — source: GDD §V.3 forbidden animation patterns

---

## Acceptance Criteria

*From GDD `design/gdd/settings-accessibility.md` §H.4, §H.5, §H.6, §H.10, §H.11 + UX spec `design/ux/settings-and-accessibility.md`, scoped to this story:*

- [ ] **AC-1** (TR-SET-006): GIVEN the Main Menu or Pause Menu is active, WHEN `SettingsService.open_panel("")` is called, THEN `InputContext.push(Context.SETTINGS)` fires before the panel renders, and `InputContext.pop()` fires when the player presses `ui_cancel` (Esc / B) or clicks the `[Back]` footer button. (GDD §UI-3)
- [ ] **AC-2** (TR-SET-013): GIVEN the Settings panel is open (not in CAPTURING rebind state), WHEN the player presses `Esc` (`ui_cancel`), THEN the panel closes via `_unhandled_input()` handler — NOT via a Button's `pressed` signal. (GDD AC aligned with ADR-0004 IG3 + TR-INP-007)
- [ ] **AC-3** (TR-SET-006 + CanvasLayer): GIVEN the Settings panel is mounted, WHEN the CanvasLayer hierarchy is inspected, THEN the Settings panel root sits on CanvasLayer 10 with no sibling nodes on that layer. (UX Spec §Navigation Position)
- [ ] **AC-4** (TR-SET-011): GIVEN the Settings panel root Control is inspected, WHEN the `fallback_theme` property is read, THEN it references `res://assets/ui/project_theme.tres` — NOT `null` and NOT `base_theme` (which does not exist in Godot 4.x). (ADR-0004 Gate 2 A5)
- [ ] **AC-5** (TR-SET-012 — BLOCKED on ADR-0004 Gate 1): GIVEN ADR-0004 Gate 1 has closed (AccessKit property names verified), WHEN the Accessibility sub-screen `DamageFlashEnabledToggle` (`CheckButton`) is inspected in the editor, THEN `accessibility_role = "switch"`, `accessibility_name = tr("DAMAGE_FLASH_ENABLED_LABEL")`, `accessibility_description = tr("DAMAGE_FLASH_ENABLED_DESC")` are set (or equivalent verified property names). Mark this AC as pending until Gate 1 closes.
- [ ] **AC-6** (TR-SET-017 + CR-8): GIVEN the Master volume `HSlider` is dragged continuously, WHEN `drag_ended(value_changed: bool)` fires with `value_changed == true`, THEN `ConfigFile.save()` is called exactly once — no save during continuous drag ticks. WHEN `value_changed == false` (no change), THEN `ConfigFile.save()` is NOT called. (GDD AC-SA-2.1)
- [ ] **AC-7** (TR-SET-007 + UI clamp): GIVEN the `damage_flash_cooldown_ms` `HSlider` is inspected after panel mount, WHEN `slider.min_value` is read, THEN the value is exactly `333` — the UI widget cannot be dragged below 333 ms via any mouse or keyboard interaction. (GDD AC-SA-5.3 BLOCKING)
- [ ] **AC-8** (TR-SET-018 + dead-end announce): GIVEN keyboard focus is on the LAST focusable widget in the detail pane, WHEN the player presses `ui_down`, THEN focus does not move (no-op) AND AccessKit announces `tr("SETTINGS_NAV_DEAD_END_BOTTOM")` via `accessibility_live = "polite"` (or verified equivalent per Gate 1). Symmetric for `ui_up` at first widget → announces `tr("SETTINGS_NAV_DEAD_END_TOP")`. (GDD AC-SA-11.8)
- [ ] **AC-9** (Tab order — BLOCKING per ADR-0004 IG10): GIVEN keyboard focus is on a widget in the detail pane, WHEN the player presses Tab repeatedly, THEN focus cycles through ONLY the detail pane widgets (not the category list), wraps from last to first, and Shift+Tab reverses direction. Tab does NOT reach the FooterRow directly from either column. (GDD AC-SA-11.7 BLOCKING)
- [ ] **AC-10** (TR-SET-016 + rebind capture): GIVEN the Controls sub-screen rebind capture machine is in CAPTURING state, WHEN the player releases a key (key-UP event for `use_gadget`), THEN that key-up event is captured — NOT the key-down. The `use_gadget` binding changes; the `takedown` binding is unaffected. (GDD AC-SA-6.3, AC-SA-6.5)
- [ ] **AC-11** (rebind + Esc capture gate): GIVEN the rebind capture machine is in CAPTURING state, WHEN the player presses and releases `Esc`, THEN the machine transitions to NORMAL_BROWSE without binding `Esc`, and the Settings panel does NOT close. (GDD AC-SA-6.6)
- [ ] **AC-12** (CR-15 close-as-confirm): GIVEN the Settings panel shows the Graphics sub-screen with the resolution-scale revert banner active, WHEN the player presses `ui_cancel` to close the panel before the revert timer elapses, THEN the panel closes, the NEW value is kept (not reverted), and `ConfigFile.save()` writes the new value. (GDD AC-SA-11.10 BLOCKING)
- [ ] **AC-13** (FP-8 / tr() guard): GIVEN all Settings panel widget label assignments in `src/ui/settings/`, WHEN CI runs grep for string literals assigned to label properties without a `tr()` wrapper, THEN zero bare-string label assignments are found. (GDD AC-SA-9.8)
- [ ] **AC-14** (resolution_scale revert — Keep button): GIVEN the revert banner is visible, WHEN the player presses `[Keep This Resolution]`, THEN the new value persists (`ConfigFile.save()` fires), the banner dismisses, the timer cancels, and no additional `setting_changed` re-emit occurs. (GDD AC-SA-11.11)

---

## Implementation Notes

*Derived from GDD §C.4 (modal panel architecture) + UX Spec §Layout Zones + ADR-0004 §IG7:*

**Scene structure** — `src/ui/settings/SettingsPanel.tscn` root Control node (`class_name SettingsPanelController extends Control`), added to a CanvasLayer 10 node at mount time:

```
SettingsPanel (Control)
└── PanelContainer (fallback_theme = project_theme.tres)
    └── VBoxContainer
        ├── Z1_Header (Label — tr("SETTINGS_HEADER_TITLE"))
        ├── HSplitContainer
        │   ├── Z2_CategoryList (ItemList — 6 rows)
        │   └── Z3_DetailPane (ScrollContainer → VBoxContainer)
        ├── Z4_RevertBanner (HBoxContainer — hidden by default; CR-15)
        └── Z5_Footer (HBoxContainer — Back + RestoreDefaults buttons)
```

**`open_panel(pre_navigate: StringName = &"")` method** — called by Menu System:
1. Mount `SettingsPanel` into a new `CanvasLayer` with `layer = 10`.
2. `InputContext.push(Context.SETTINGS)`.
3. If `pre_navigate` is non-empty (e.g., `"accessibility.damage_flash_enabled"`), parse the `category.key` string, select the matching category row in Z2, scroll Z3 to the matching widget, call `widget.grab_focus()`.
4. Otherwise, select the last-visited category from session memory (default: Audio).

**`_dismiss_panel()` method** — called by `ui_cancel` in `_unhandled_input()` and by `[Back]` button:
1. If resolution-scale revert banner is active: commit the pending value (close-as-confirm per CR-15 step 4), call `ConfigFile.save()`.
2. `InputContext.pop()`.
3. Queue-free the panel instance.

**Focus model** (column-first, per GDD §C.4):
- `_focus_column: int` tracks current column (0 = category list, 1 = detail pane).
- `ui_right` from column 0 → `_focus_column = 1`, grab first focusable widget in detail pane.
- `ui_left` from column 1 → `_focus_column = 0`, grab the currently-selected category row.
- `ui_down` at last widget in detail pane → no-op + AccessKit announce `tr("SETTINGS_NAV_DEAD_END_BOTTOM")`.
- `ui_up` at first widget in detail pane → no-op + AccessKit announce `tr("SETTINGS_NAV_DEAD_END_TOP")`.
- Tab key: cycles within current column only, wraps internally, does NOT cross columns.

**Category sub-screens** — each category is a separate `PackedScene` loaded lazily when its row is selected:
- `AudioSubScreen.tscn` — 6 HSlider rows (all MVP; wire `drag_ended` → `_on_slider_committed`)
- `GraphicsSubScreen.tscn` — 1 OptionButton (MVP); CR-15 revert banner integration
- `AccessibilitySubScreen.tscn` — photosensitivity cluster at top (Day-1 HARD MVP DEP); subtitle cluster; `DamageFlashCooldownSlider.min_value = 333` (AC-SA-5.3 BLOCKING)
- `HUDSubScreen.tscn` — cross-reference label only (MVP); VS widgets hidden at MVP
- `ControlsSubScreen.tscn` — motor toggles + sensitivity sliders + RebindRows (36 MVP)
- `LanguageSubScreen.tscn` — non-interactive Label with `tr("LANGUAGE_MVP_NOTICE")` at MVP

**Rebind capture** (`ControlsSubScreen`) — three-state machine:
- `NORMAL_BROWSE → CAPTURING`: player presses Enter on RebindRow capture button.
- CAPTURING: `_input(event)` at root level captures ALL keys including `ui_cancel` (NOT `_unhandled_input`); bind on key-UP; Esc → NORMAL_BROWSE without binding.
- `CAPTURING → NORMAL_BROWSE or CONFLICT_RESOLUTION`: after key-up, call `has_conflict()` (GDD F.4) on the captured event.
- Conflict banner is inline within the RebindRow (not a modal). All other capture buttons `disabled = true` while CONFLICT_RESOLUTION is active.

**Restore Defaults button** — in Z5 FooterRow:
1. Shows confirmation modal (CR-25: `accessibility_role = "dialog"`, default focus `[Cancel]`).
2. On `[Restore]`: calls `SettingsService._restore_defaults()` (Stories 001 + 002 implement the photosensitivity cluster preservation).
3. `Events.settings_loaded` is NOT re-emitted after restore (AC-SA-11.3 — one-shot per session).

**`open_panel()` pre-navigation deep-link format** — locked 2026-04-29 per `design/ux/photosensitivity-boot-warning.md` OQ #10: `"category.key"` dotted string (e.g., `"accessibility.damage_flash_enabled"`). Panel mounts even if key is unknown — falls back to top-level entry and logs warning in debug builds.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001-004: logic layer (service, burst, formula) — already implemented before this story
- Post-VS: rebind gamepad column (OQ-SA-5 — second binding column layout decision deferred to VS sprint)
- Post-VS: resolution / windowed-mode / display-mode pickers (GDD §VS Scope — deferred post-VS)
- Post-VS: FOV slider, full accessibility tier suite (colorblind mode, reduced motion toggle render)
- Post-VS: subtitles styling options beyond the MVP-write keys (D&S VS-consume contract)
- ADR-0004 Gate 5 AT runtime test (developer task: run Orca/NVDA on Document Overlay after panel is built; required to advance Gate 5 and set ADR-0004 to Accepted)

---

## QA Test Cases

*Solo mode — no QA-lead gate. Manual verification steps required (UI story type).*

**AC-1 — InputContext lifecycle**
- Setup: Main Menu active; open Settings via `[Personnel File]` button
- Verify: `InputContext.current()` is `SETTINGS` while panel is open; gameplay `_unhandled_input` handlers early-return (no accidental input leakage)
- Pass condition: `InputContext.current()` returns `MENU` (or `PAUSE`) immediately after pressing Esc to close the panel

**AC-7 — damage_flash_cooldown_ms HSlider min_value**
- Setup: Load the Accessibility sub-screen in the editor via the scene runner
- Verify: `$DamageFlashCooldownSlider.min_value` equals `333` (property assertion, not pixel inspection)
- Pass condition: automated scene-loaded property query passes; attempting to drag the slider below 333 in-game has no effect (slider snaps to 333)

**AC-9 — Tab order within detail pane**
- Setup: Open Settings panel, navigate to Audio sub-screen, focus on Master Volume slider
- Verify: pressing Tab moves focus to Music Volume (not to the Category List); pressing Tab 5 more times wraps back to Master Volume; pressing `ui_left` at any time returns focus to the Category List
- Pass condition: focus never crosses to category list via Tab; focus chain is deterministic

**AC-10 — rebind capture key-up semantics**
- Setup: Open Controls sub-screen, press Enter on `use_gadget` RebindRow capture button (panel enters CAPTURING state)
- Verify: pressing and holding `G` does NOT bind immediately; releasing `G` (key-up) triggers the bind
- Pass condition: `use_gadget` is bound to `G` after key-up; `takedown` binding is unchanged

**AC-12 — close-as-confirm for resolution scale**
- Setup: Open Graphics sub-screen, change resolution scale to 50% (revert banner appears with 7-second countdown)
- Verify: press Esc before timer elapses; panel closes
- Pass condition: `settings.cfg` reads `graphics.resolution_scale = 0.5` (the new value) after panel close — NOT the previous value

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `production/qa/evidence/settings-accessibility/panel-shell-walkthrough.md` — manual walkthrough doc covering AC-1, AC-3, AC-9, AC-10, AC-12, AC-14
- `tests/unit/settings/tab_order_test.gd` — automated focus-chain inspection for AC-9 (automatable via focus-chain inspection, no pixel inspection required — per GDD AC-SA-11.7)
- `tests/integration/settings/close_as_confirm_test.gd` — integration test for AC-12 (GDD AC-SA-11.10)
- `tests/unit/settings/resolution_keep_test.gd` — unit test for AC-14 (GDD AC-SA-11.11)
- `tests/unit/settings/dead_end_announce_test.gd` — unit test for AC-8 (GDD AC-SA-11.8)
- Existing `tests/unit/settings/forbidden_patterns_ci_test.gd` updated for AC-13 (FP-8 tr() gate)
- ADR-0004 Gate 5 closure doc: developer note in this story's evidence doc after running Orca/NVDA AT test

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (SettingsService + ConfigFile persistence) must be DONE
- Depends on: Story 002 (boot lifecycle + `dismiss_warning()` method) must be DONE
- Depends on: Story 003 (photosensitivity slider `min_value` UI clamp must be wired from this story) must be DONE
- Depends on: Story 004 (dB formula + audio bus apply — HSlider `drag_ended` wired here) must be DONE
- Depends on: ADR-0004 advancing to Accepted (for TR-SET-011 and TR-SET-012 full implementation; partial panel can be built with Proposed status but AccessKit properties blocked)
- Depends on: Menu System epic (provides entry-point buttons that call `SettingsService.open_panel()`)
- Unlocks: Story 006 (subtitle settings UI sub-cluster visible in Accessibility sub-screen built here)
