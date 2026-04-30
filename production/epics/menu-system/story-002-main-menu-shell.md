# Story 002: Main Menu shell — boot scene, InputContext, Continue label-swap, localization

> **Epic**: Menu System
> **Status**: BLOCKED — ADR-0004 is Proposed (`Context.MODAL` enum addition required for modal lifecycle; Theme `base_theme`/`fallback_theme` Gate 2 unresolved). Structural scene + label-swap logic can be drafted; full InputContext wiring and Theme inheritance blocked.
> **Layer**: Presentation
> **Type**: UI
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/menu-system.md`
**Requirement**: `TR-MENU-001`, `TR-MENU-008`, `TR-MENU-009`, `TR-MENU-010`, `TR-MENU-011`, `TR-MENU-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (UI Framework) + ADR-0007 (Autoload Load Order Registry) + ADR-0003 (Save Format Contract — sidecar read for label-swap)
**ADR Decision Summary**: ADR-0007 guarantees all autoload `_ready()` calls complete before `MainMenu._ready()` fires — `SettingsService._boot_warning_pending` is safe to read synchronously. ADR-0004 governs Theme inheritance via `project_theme.tres` + per-surface child themes + FontRegistry static class. ADR-0003 sidecar read: `SaveLoad.slot_metadata(0)` returns the `slot_0_meta.cfg` Dictionary — Menu never opens `slot_0.res` directly. `MainMenu.tscn` is set as Project Settings → Application → Run → Main Scene (NOT loaded via `change_scene_to_file()` on cold boot per CR-1).

**Engine**: Godot 4.6 | **Risk**: LOW–MEDIUM (ADR-0004 Proposed; Theme property name Gate 2 open)
**Engine Notes**: `MainMenu.tscn` as boot scene via Project Settings Main Scene is stable Godot 4.0+. `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` on `Label`/`Button` — verify constant name in 4.6 (may be `AUTO_TRANSLATE_MODE_ALWAYS` or integer). FontRegistry static class usage — verify `FontRegistry.get_body_font()` / `get_header_font()` API per ADR-0004 §FontRegistry before use. This API may have changed in versions 4.4–4.6 (post-cutoff — verify against engine reference).

**Control Manifest Rules (Presentation)**:
- Required: `MainMenu.tscn` is Project Settings main scene; no `change_scene_to_file()` on cold boot (ADR-0007 + CR-1)
- Required: all visible strings via `tr("menu.*")` — no hardcoded English (TR-MENU-010)
- Required: `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` on every static Label/Button (ADR-0004 / Localization L129)
- Required: `accessibility_name` re-resolve on `NOTIFICATION_TRANSLATION_CHANGED` via `_update_accessibility_names()` (CR-22 / TR-MENU-014)
- Required: `SaveLoad.slot_metadata(0)` sidecar read only — never open `slot_0.res` (ADR-0003 IG 8)
- Forbidden: `_process()` or `_physics_process()` in MainMenu scene (CR-18)
- Forbidden: `Window`-based built-in dialogs in this scene tree (GDD C.4)
- Forbidden: `menu_loading_full_save_for_preview` — reading full `.res` save file for label-swap state determination
- Guardrail: no per-frame polling; all state transitions are signal-driven or one-shot in `_ready()` (CR-18)

---

## Acceptance Criteria

*From GDD `design/gdd/menu-system.md` §CR-1, §CR-2, §CR-5, §CR-18, §CR-19, §CR-22, §H.1, §H.3, §H.10, §H.11:*

- [ ] **AC-1**: `MainMenu.tscn` exists at `src/ui/menu/MainMenu.tscn`; its root node matches class `MainMenu` (script at `src/ui/menu/main_menu.gd`). Project Settings → Application → Run → Main Scene is set to `res://src/ui/menu/MainMenu.tscn`. Verifies CR-1.
- [ ] **AC-2** (BLOCKED on `Context.MENU`): `main_menu.gd._ready()` calls `InputContextStack.push(Context.MENU)` as its first logical action (before slot metadata read or modal show). `_exit_tree()` calls `InputContextStack.pop()` if `Context.MENU` is still on stack, guarded by `assert(InputContextStack.peek() in [Context.MENU, Context.LOADING])`. Verifies CR-2 + AC-MENU-10.1 + AC-MENU-10.4. BLOCKED on `Context.MENU` enum existing in ADR-0004.
- [ ] **AC-3**: `_ready()` reads `SaveLoad.slot_metadata(0)`. If result is non-null and has valid required keys (non-empty `section_id`): `ContinueButton.text = tr("menu.main.continue")` ("Resume Surveillance") + sets `_slot_0_available = true`. If null, empty, or CORRUPT state: `ContinueButton.text = tr("menu.main.continue_empty")` ("Begin Operation") + sets `_slot_0_available = false`. Both paths: button is `enabled = true`. Verifies CR-5 + AC-MENU-3.1 + AC-MENU-3.2 + AC-MENU-3.3.
- [ ] **AC-4**: Button Z2 stack contains at minimum (MVP): `ContinueButton`, `NewGameButton`, `PersonnelFileButton`, `CloseFileButton`. All have `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS`. English label strings match §C.8 table exactly. Verifies TR-MENU-008 + TR-MENU-010.
- [ ] **AC-5**: `PersonnelFileButton.accessibility_description = tr("menu.main.settings.desc")` — set in `_update_accessibility_names()` called from `_ready()` AND from `_notification(NOTIFICATION_TRANSLATION_CHANGED)`. Verifies CR-7 + CR-22 + AC-MENU-13.4.
- [ ] **AC-6**: `ContinueButton.accessibility_description` = `tr("menu.main.continue.desc")` when `_slot_0_available == true`; `tr("menu.main.continue_empty.desc")` when `false`. Updated in `_update_accessibility_names()`. Verifies AC-MENU-13.4 + §C.9 AccessKit table.
- [ ] **AC-7** (BLOCKED on ADR-0004 Gate 2): Theme inheritance from `project_theme.tres` applied. Every visible `Label`/`Button` in scene has `theme_override_fonts/font` set via FontRegistry (FP-9 compliance). No Godot default theme leakage. BLOCKED on ADR-0004 Gate 2 (`base_theme` vs `fallback_theme` property name).
- [ ] **AC-8**: `main_menu.gd` has no `_process()` or `_physics_process()` override. Zero subscriptions to `Events.*` signals at boot except the ones required by CR-10 (`save_failed`) and CR-15 (`game_saved`, `game_loaded`) — subscription in `_ready()`, disconnection in `_exit_tree()` with `is_connected()` guard per ADR-0002 IG 3. Verifies CR-18 + CR-19 + AC-MENU-8.1.
- [ ] **AC-9**: GIVEN `peek() == Context.MENU` at Main Menu top level, WHEN `ui_cancel` fires, THEN no action is taken — no modal opens, no quit-confirm. Verifies C.6 + AC-MENU-11.1.
- [ ] **AC-10**: `MainMenu._ready()` calls `set_process_input(false)` on the button container BEFORE any other initialization (boot-warning poll gate per CR-8 / GDD C.3 step 4). This AC is tested as a precondition to Story 003's boot-warning integration.

---

## Implementation Notes

*Derived from ADR-0004 + ADR-0007 + ADR-0003 §Implementation Guidelines + GDD §C.1 + §C.3 + §C.7 + §C.8:*

Scene structure (`src/ui/menu/MainMenu.tscn`):
```
MainMenu (CanvasLayer — layer implicitly 0; is root/boot scene)
  BackgroundFill (ColorRect — BQA Blue #1B3A6B, full rect)
  EiffelSilhouette (TextureRect — flat silhouette, anchored bottom-right)  [MVP stub]
  ButtonContainer (VBoxContainer — Z2 Action Stack)
    ContinueButton (Button)
    NewGameButton (Button)
    PersonnelFileButton (Button)
    CloseFileButton (Button)
  ModalScaffold (instance of ModalScaffold.tscn — child of MainMenu)
```

`main_menu.gd` initialization sequence (matching GDD C.3 exactly):
1. `push(Context.MENU)` (BLOCKED on ADR-0004 enum)
2. Instantiate ModalScaffold (already in scene tree as child — `@onready` reference)
3. Subscribe `Events.save_failed`, `Events.game_saved`, `Events.game_loaded`
4. `set_custom_mouse_cursor(fountain_pen_nib_texture, ...)` (VS; stub at MVP)
5. `button_container.set_process_input(false)`
6. Read `SaveLoad.slot_metadata(0)` → perform label-swap (AC-3)
7. Step 5 gates on boot-warning resolution (Story 003 wires this)

The slot metadata read at step 6 is a synchronous read of the sidecar `slot_0_meta.cfg` via `SaveLoad.slot_metadata(0)`. Validate the returned Dictionary with `_is_valid_metadata(dict: Dictionary) -> bool` (checks non-empty `section_id` key). CORRUPT detection: if `SaveLoad.slot_state(0) == SaveLoad.SlotState.CORRUPT`, treat as empty.

`_update_accessibility_names()` pattern per GDD F.8 must cover: `ContinueButton.accessibility_name`, `ContinueButton.accessibility_description`, `PersonnelFileButton.accessibility_description`. All stored as `const` tr-key strings on the script.

BQA dossier register (TR-MENU-008): button labels are locked English strings from §C.8. No modern labels ("New Game", "Quit", "Settings"). The `tr()` keys are as specified. FP-2 grep gate: no value in `translations/menu.csv` may contain "Quit to", "Main Menu" standalone, "Game", "Play", "New Game".

**Forbidden pattern `menu_calling_save_assemble_directly`**: MainMenu never calls `SaveLoad.save_to_slot()` or `SaveLoad.assemble_save_game()`. Menu reads metadata (sidecar) only.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: `ModalScaffold.tscn` infrastructure (prerequisite)
- Story 003: Boot-warning poll + photosensitivity modal mount + `process_input` gate release
- Story 004: `QuitConfirmContent.tscn` and Quit-Confirm flow (Close File button connection)
- Story 005: `NewGameOverwriteContent.tscn` and New Game flow (Continue / New Game button connection to LS)
- Story 006: Settings entry-point wiring (`PersonnelFileButton` → `SettingsService.open_panel()`)
- VS scope: Operations Archive button, dossier-card backdrop, fountain-pen cursor, gamepad nav

---

## QA Test Cases

*Manual verification + UI (Solo mode — QL-STORY-READY skipped).*

- **AC-1 (boot scene)**:
  - Setup: open Project Settings → Application → Run → Main Scene in Godot editor.
  - Verify: value is `res://src/ui/menu/MainMenu.tscn`.
  - Pass condition: `MainMenu.tscn` is listed and the scene file exists on disk at that path.

- **AC-3 (label-swap)**:
  - Given: test harness injects `SaveLoad.slot_metadata(0)` returning non-null Dict with `section_id = "plaza"`.
  - When: `MainMenu._ready()` runs.
  - Then: `ContinueButton.text == "Resume Surveillance"` (English locale); `_slot_0_available == true`.
  - Edge case A: inject `slot_metadata(0)` returning `null` → label is "Begin Operation", `_slot_0_available == false`.
  - Edge case B: inject `slot_metadata(0)` returning `{}` (empty dict) → same as null.
  - Edge case C: inject `slot_state(0) == CORRUPT` → "Begin Operation", `_slot_0_available == false`.

- **AC-5 + AC-6 (accessibility_description)**:
  - Setup: run game to Main Menu with screen reader active (or use AccessKit inspector).
  - Verify: Personnel File button announces its description "Adjust audio, graphics, accessibility, and control settings." when focused.
  - Pass condition: AT announces description text; no raw tr-key string announced.

- **AC-8 (no _process, signal lifecycle)**:
  - Setup: grep `src/ui/menu/main_menu.gd` for `_process` and `_physics_process`.
  - Then: zero matches.
  - Edge case: inspect Godot profiler for per-frame callback from `main_menu.gd` — must be absent.

- **AC-9 (Esc at top level does nothing)**:
  - Setup: Main Menu interactive (no modal open).
  - When: press Esc.
  - Then: no modal opens, no visible change; `peek()` remains `Context.MENU`.

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `production/qa/evidence/main-menu-shell-evidence.md` — walkthrough doc with screenshots showing: (a) "Resume Surveillance" label with slot 0 occupied; (b) "Begin Operation" label with slot 0 absent; (c) all four MVP buttons visible; (d) no `_process` in profiler

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (ModalScaffold.tscn must exist as child); ADR-0004 `Context.MENU` enum must be defined (exists in current ADR-0004 Proposed state — `MODAL` + `LOADING` are the additions needed for other stories)
- Unlocks: Story 003 (boot-warning poll wiring into MainMenu._ready()), Story 004 (Quit-Confirm connection), Story 005 (New Game flow), Story 006 (Settings entry-point)
