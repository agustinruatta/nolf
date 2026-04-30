# Story 008: Settings entry-point handover — Personnel File button, SettingsService.open_panel(), focus restore

> **Epic**: Menu System
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/menu-system.md`
**Requirement**: `TR-MENU-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (UI Framework) + ADR-0007 (Autoload Load Order Registry)
**ADR Decision Summary**: ADR-0004 mandates that Settings owns its own `CanvasLayer 10`, its own `InputContext.SETTINGS` push/pop, and its own dismiss. Menu System's responsibility is exactly two things: call `SettingsService.open_panel()` from the Personnel File button, and restore focus to that button when Settings dismisses. Menu does NOT push `Context.SETTINGS` — Settings does. ADR-0007 guarantees `SettingsService` is a registered autoload (line 10 per §Canonical Registration Table) and its `open_panel()` method is callable synchronously. TR-MENU-013 is the bootstrap-blocking dependency (Settings & Accessibility Day-1 UI must ship before Menu MVP).

**Engine**: Godot 4.6 | **Risk**: LOW (`SettingsService.open_panel()` is a project autoload API; call pattern is stable)
**Engine Notes**: `SettingsService` autoload reference is stable (ADR-0007 Accepted). `InputContext.Context.SETTINGS` enum value — verify it is declared in ADR-0004 `InputContext.Context` (should be per the spec; confirm it is not mis-named). `ui_context_changed(new, old)` signal (ADR-0002 UI domain) for focus-restore detection — verify signal name in `Events.gd` skeleton. `Control.accessibility_description` confirmed settable (Gate 1 CLOSED 2026-04-29).

**Control Manifest Rules (Presentation)**:
- Required: `PersonnelFileButton.accessibility_description` = `tr("menu.main.settings.desc")` ("Adjust audio, graphics, accessibility, and control settings.") — per GDD CR-7, this is the one Case File label genuinely ambiguous to AT users
- Required: `_update_accessibility_names()` called in `_ready()` and on `NOTIFICATION_TRANSLATION_CHANGED` (GDD CR-22)
- Required: focus restores to `PersonnelFileButton` on Settings dismiss (GDD CR-7 + UX spec return path)
- Forbidden: Menu pushes `Context.SETTINGS` — Settings owns its own context push (ADR-0004)
- Forbidden: Menu calls any Settings-internal method other than `SettingsService.open_panel()` (Menu is not authorised to read Settings internal state)
- Forbidden: `_process()` or `_physics_process()` (GDD CR-18)
- Forbidden: `menu_loading_full_save_for_preview` — this story has no save access
- Forbidden: `menu_calling_save_assemble_directly` — this story has no save access

---

## Acceptance Criteria

*From GDD `design/gdd/menu-system.md` §CR-7 + §C.2 row 3 + §C.8 + `design/ux/pause-menu.md` §Exit row "Settings panel":*

- [ ] **AC-1**: `PersonnelFileButton` exists in `MainMenu.tscn` (Story 002) and in `PauseMenu.tscn` (Story 005) with label `tr("menu.main.settings")` / `tr("menu.pause.settings")` ("Personnel File" in English per §C.8). `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS`. Verifies TR-MENU-008 + TR-MENU-010. (This AC validates the button exists in both shells — the connecting logic is what this story implements.)
- [ ] **AC-2**: `PersonnelFileButton.pressed` handler in `MainMenu` and `PauseMenu` calls `SettingsService.open_panel()` with no pre-navigate argument (Settings opens at its root/default panel, not pre-navigated to Accessibility — pre-navigate is reserved for the boot-warning GoToSettings path in Story 003). Settings owns the `Context.SETTINGS` push internally. Verifies GDD CR-7.
- [ ] **AC-3**: Focus restores to `PersonnelFileButton` when Settings dismisses. Detection method: subscribe to `Events.ui_context_changed(new, old)` (ADR-0002 UI domain); when `new == Context.PAUSE or Context.MENU` AND `old == Context.SETTINGS`: call `PersonnelFileButton.call_deferred("grab_focus")`. Subscription in `_ready()`, disconnection in `_exit_tree()` with `is_connected()` guard. Verifies GDD CR-7 + UX spec §Exit row "Settings panel" (focus restores to Personnel File) + AC-MENU-5.2.
- [ ] **AC-4**: `PersonnelFileButton.accessibility_description` = `tr("menu.main.settings.desc")` (MainMenu) and `tr("menu.pause.settings.desc")` (PauseMenu) — both descriptions provide plain-language explanation because "Personnel File" is the Case File label AT users cannot decode without context (per GDD CR-7). Set in `_update_accessibility_names()` per host script. Verifies GDD CR-7 + CR-22 + TR-MENU-014.
- [ ] **AC-5**: `_update_accessibility_names()` called in `_ready()` of both `main_menu.gd` and `pause_menu.gd`, and on `NOTIFICATION_TRANSLATION_CHANGED`. Verifies GDD CR-22 (localization re-resolve — already partially covered in Story 002 AC-5 for MainMenu; this story extends to PauseMenu).
- [ ] **AC-6**: GIVEN Settings is open (`Context.SETTINGS` on stack), WHEN player presses `ui_cancel` within Settings, THEN Settings dismisses itself (pops `Context.SETTINGS`), InputContext returns to `Context.MENU` or `Context.PAUSE`, and the `Events.ui_context_changed` handler in the host menu fires, restoring focus to `PersonnelFileButton`. Menu does NOT re-push `Context.SETTINGS` or call `open_panel()` again on this event. Verifies AC-MENU-5.2 + GDD CR-7.
- [ ] **AC-7**: GIVEN Menu is in `Context.MENU` or `Context.PAUSE`, WHEN `PersonnelFileButton` pressed a second time (after returning from Settings once), THEN `SettingsService.open_panel()` is called again correctly (no stale reference, no double-subscription). Verifies re-entry path correctness.

---

## Implementation Notes

*Derived from ADR-0004 §Implementation Guidelines + GDD §CR-7 + ADR-0007:*

**Personnel File button in MainMenu** (Story 002 `main_menu.gd`): connect `PersonnelFileButton.pressed` to `_on_personnel_file_pressed()`. In that handler: `SettingsService.open_panel()`. That is the entire implementation of the open path.

**Personnel File button in PauseMenu** (Story 005 `pause_menu.gd`): identical pattern — `PersonnelFileButton.pressed` → `SettingsService.open_panel()`.

**Focus restore via `ui_context_changed`**: the `Events.ui_context_changed(new: InputContext.Context, old: InputContext.Context)` signal (ADR-0002 UI domain, added 2026-04-28) is the correct mechanism. Connect in `_ready()` of both `main_menu.gd` and `pause_menu.gd`:
```gdscript
func _ready() -> void:
    # ... other init ...
    if not Events.ui_context_changed.is_connected(_on_ui_context_changed):
        Events.ui_context_changed.connect(_on_ui_context_changed)

func _exit_tree() -> void:
    if Events.ui_context_changed.is_connected(_on_ui_context_changed):
        Events.ui_context_changed.disconnect(_on_ui_context_changed)

func _on_ui_context_changed(new_ctx: InputContext.Context, old_ctx: InputContext.Context) -> void:
    if old_ctx == InputContext.Context.SETTINGS:
        PersonnelFileButton.call_deferred("grab_focus")
```

**Guard against false-positive focus restores**: `old_ctx == SETTINGS` is sufficient — the menu is only mounted while its own context (MENU or PAUSE) is on the stack, so the transition `SETTINGS → MENU/PAUSE` unambiguously means "Settings was dismissed from this menu."

**`SettingsService.open_panel()` pre-navigate parameter**: This story does NOT use the pre-navigate parameter (that is Story 003's GoToSettings path only). `SettingsService.open_panel()` is called with no arguments for the Personnel File button path. Verify that the method signature allows zero-argument calls (confirm the `pre_navigate` parameter is optional with a default value — coordinate with settings-accessibility epic).

**TR-MENU-013 bootstrap note**: This story satisfies the bootstrap-blocking constraint (Settings & Accessibility Day-1 UI must exist before Menu MVP). The handover is a two-line button handler — the depth of work is in the Settings epic, not here. This story's job is to wire the button and restore focus cleanly.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: `GoToSettingsButton` in PhotosensitivityWarningContent calls `SettingsService.open_panel(pre_navigate: "accessibility.damage_flash_enabled")` — pre-navigate path is Story 003's responsibility
- Settings & Accessibility epic: `SettingsService.open_panel()` internal implementation; all Settings panel internals, `Context.SETTINGS` push/pop; Accessibility category layout; `damage_flash_enabled` toggle
- Post-VS: deep-link pre-navigate from Pause Menu Personnel File (not in VS scope — opens Settings root only)

---

## QA Test Cases

*Manual verification + Integration — Solo mode (QL-STORY-READY skipped).*

- **AC-2 (open_panel called)**:
  - Given: Main Menu or Pause Menu mounted with `SettingsService` test double.
  - When: `PersonnelFileButton` activated.
  - Then: `SettingsService.open_panel()` called once with no arguments. `Context.SETTINGS` is pushed by Settings internally (verify `peek() == SETTINGS` after `open_panel()` if test double simulates it).
  - Edge case: `PersonnelFileButton` pressed while Settings is already open (should not happen in normal flow since `SETTINGS` context blocks menu nav — verify `open_panel()` called only once, not twice).

- **AC-3 (focus restore)**:
  - Given: Main Menu mounted; Settings open via Personnel File; `Events.ui_context_changed` signal connected.
  - When: Settings dismisses → `Events.ui_context_changed.emit(Context.MENU, Context.SETTINGS)`.
  - Then: `PersonnelFileButton.call_deferred("grab_focus")` fires; `PersonnelFileButton` has focus after the deferred call.
  - Pass condition: Verify via accessibility tree inspection that `PersonnelFileButton` is focused after Settings close.

- **AC-4 (accessibility_description)**:
  - Setup: Main Menu booted; inspect `PersonnelFileButton.accessibility_description`.
  - Verify: non-empty string, matches localized `"menu.main.settings.desc"` value.
  - Pass condition: Screen reader announces description when button is focused; no raw tr-key string leaked.

- **AC-6 (re-entry after dismiss)**:
  - Given: Settings was opened and dismissed (PersonnelFileButton regained focus).
  - When: PersonnelFileButton activated again.
  - Then: `SettingsService.open_panel()` called again without error; Settings opens correctly on second entry.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/presentation/menu_system/settings_entry_point_test.gd` — must exist and pass (open_panel called, focus restore on dismiss, no double-call, re-entry)
- `production/qa/evidence/settings-entry-point-evidence.md` — walkthrough doc with screenshots: (a) Main Menu with Personnel File button in focus with correct accessibility description; (b) Settings panel open after button press; (c) Settings dismissed with focus restored to Personnel File; (d) same flow from Pause Menu

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (MainMenu.tscn must exist with `PersonnelFileButton`); Story 005 (PauseMenu.tscn must exist with `PersonnelFileButton`); Settings & Accessibility epic must have `SettingsService.open_panel()` implemented (bootstrap-blocking per TR-MENU-013)
- Unlocks: Epic Definition of Done — all VS-scope stories implemented; settings navigation path verified end-to-end

## Open Questions

- **OQ-008-1**: `SettingsService.open_panel()` signature — does it accept an optional `pre_navigate: String = ""` parameter, or is the parameterless call a separate method? Coordinate with settings-accessibility epic owner before implementing AC-2. If the method requires a parameter, call with empty string.
- **OQ-008-2**: `Events.ui_context_changed` signal declaration — confirmed added in ADR-0002 2026-04-28 amendment as `ui_context_changed(new: InputContext.Context, old: InputContext.Context)`. Verify it is declared in `src/core/signal_bus/events.gd` skeleton before implementing AC-3.
