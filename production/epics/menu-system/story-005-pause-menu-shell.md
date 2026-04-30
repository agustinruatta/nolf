# Story 005: Pause menu shell — PauseMenu.tscn, PauseMenuController, InputContext.PAUSE lifecycle, sub-screen swap

> **Epic**: Menu System
> **Status**: BLOCKED — ADR-0004 is Proposed (Gate 5: `accessibility_live` one-shot assertive pattern unverified; Pause Menu mount must emit `assertive` on appearance per GDD CR-21). Core CanvasLayer overlay, InputContext push/pop, and button stack can be drafted; one-shot AccessKit annotation blocked.
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/menu-system.md`
**Requirement**: `TR-MENU-012`, `TR-MENU-002`, `TR-MENU-008`, `TR-MENU-010`, `TR-MENU-014`, `TR-MENU-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (UI Framework) + ADR-0002 (Signal Bus + Event Taxonomy) + ADR-0007 (Autoload Load Order Registry)
**ADR Decision Summary**: ADR-0004 mandates `InputContext.PAUSE` push on Pause Menu mount and pop on unmount (CR-2). Pause Menu is a `CanvasLayer` overlay at `layer = 8` per GDD C.2 owned-surfaces table — NOT a scene change (GDD CR-4). `PauseMenuController` is a lightweight script that listens for the `pause` action while `peek() == GAMEPLAY` and instantiates/frees `PauseMenu.tscn` (preloaded const). `get_tree().paused` remains `false` (GDD CR-4 + UX spec §Purpose). `MOUSE_MODE_VISIBLE` pushed by Pause `_ready()` (UX spec §Player Context §Held inputs). ADR-0002: `Events.save_failed` subscription managed in `_ready()` / `_exit_tree()` with `is_connected()` guard.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (ADR-0004 Proposed; `add_child` overlay pattern stable but `CanvasLayer` layer precedence with section scene must be verified at runtime)
**Engine Notes**: `CanvasLayer` with explicit `layer` int is stable since Godot 4.0. `add_child` to `get_tree().current_scene` from a controller script is stable. `Input.set_custom_mouse_cursor()` is stable 4.0+. `get_tree().paused = false` (Pause Menu must NOT set this — omission, not a call). `accessibility_live` one-shot: BLOCKED on ADR-0004 Gate 5 per Story 001/003 lineage. Verify `CanvasLayer.layer = 8` renders above section geometry but below ModalScaffold (layer 20) and HUD (layer range per HUD Core epic) at runtime.

**Control Manifest Rules (Presentation)**:
- Required: all text via `tr()` — no hardcoded strings (ADR-0004 / TR-MENU-010)
- Required: `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` on all `Label`/`Button` nodes (ADR-0004)
- Required: `get_tree().paused` must remain `false` at all times while PauseMenu is open (GDD CR-4)
- Required: `MOUSE_MODE_VISIBLE` set on `_ready()`; restored to `MOUSE_MODE_CAPTURED` on `queue_free()` or export to `Input.set_mouse_mode()` call (UX spec §Player Context + §Exit)
- Required: `Events.save_failed` subscription in `_ready()`, disconnection in `_exit_tree()` with `is_connected()` guard (ADR-0002 IG 3 / GDD CR-10)
- Required: reduced-motion conditional branch — all paper-movement Tweens wrap in `if AccessibilitySettings.reduced_motion_enabled: _show_immediately() else: _play_tween()` (GDD CR-23 / TR-MENU-015)
- Forbidden: `_process()` or `_physics_process()` anywhere in PauseMenu or PauseMenuController (GDD CR-18)
- Forbidden: `get_tree().paused = true` (GDD CR-4 — world continues to tick)
- Forbidden: `Window`-based dialogs (GDD C.4)
- Forbidden: `menu_loading_full_save_for_preview` — PauseMenu never reads any full `.res` save resource
- Forbidden: `menu_calling_save_assemble_directly` — PauseMenu never calls `SaveLoad.save_to_slot()` or assembly directly from the shell; save actions are delegated to the File Dispatch sub-screen (Story 007)

---

## Acceptance Criteria

*From GDD `design/gdd/menu-system.md` §CR-3 + §CR-4 + §CR-7 + §CR-10 + §CR-18 + §CR-22 + §CR-23 + §C.2 rows 5–8 + §H.2 + `design/ux/pause-menu.md` §Navigation + §Layout:*

- [ ] **AC-1**: `PauseMenu.tscn` exists at `src/ui/menu/PauseMenu.tscn`. Root is a `CanvasLayer` (layer = 8, script at `src/ui/menu/pause_menu.gd`). Children: `OverlayRect` (`ColorRect`, 52% Ink Black `#1A1A1A`, full-screen anchors), `FolderBody` (`Control` or `TextureRect`, 760×720 px, bottom-right anchor per UX spec §Layout Zone C), `PageInterior` (VBoxContainer for buttons, inside FolderBody). A child instance of `ModalScaffold.tscn` (layer 20 per Story 001). Verifies GDD CR-4 + UX spec §Layout Zones.
- [ ] **AC-2**: `PauseMenuController` script exists at `src/ui/menu/pause_menu_controller.gd` and is intended to be attached to the section scene root (or `SectionRoot` base) as a `Node` child. It preloads `PauseMenu.tscn` as a `const`. `_unhandled_input()` checks `event.is_action_pressed(&"pause")` AND `InputContext.peek() == InputContext.Context.GAMEPLAY`. When both true: instantiate `_pause_menu_instance`, call `get_tree().current_scene.add_child(_pause_menu_instance)`, push `InputContext.GAMEPLAY` is already on stack — the instantiation happens, `PauseMenu._ready()` pushes `Context.PAUSE`. See Implementation Notes on mounting sequence. Verifies GDD CR-3 + CR-4 + AC-MENU-2.3.
- [ ] **AC-3** (BLOCKED on `Context.PAUSE` enum): `pause_menu.gd._ready()` calls `InputContext.push(InputContext.Context.PAUSE)` as its first logical action. `_exit_tree()` calls `InputContext.pop()` if `InputContext.peek() == InputContext.Context.PAUSE`, guarded by the check. `get_tree().paused` is NOT set in either method. Verifies GDD CR-2 + CR-4 + AC-MENU-2.1 + AC-MENU-2.5. BLOCKED on `Context.PAUSE` enum — verify it is defined in ADR-0004 `InputContext.Context` enum (it should be per ADR-0004 A6, but confirm).
- [ ] **AC-4**: Pause Menu button stack contains MVP buttons: `ResumeSurveillanceButton`, `FileDispatchButton` (Save), `OperationsArchiveButton` (Load), `PersonnelFileButton` (Settings), `ReturnToRegistryButton`, `CloseFileButton`. Default focus on `ResumeSurveillanceButton`. All buttons have `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS`. English labels match GDD §C.8 table exactly (bureaucratic register). Verifies TR-MENU-008 + TR-MENU-010.
- [ ] **AC-5**: `ResumeSurveillanceButton.pressed` handler calls `queue_free()` on the PauseMenu instance (which triggers `_exit_tree()` → pops Context.PAUSE → restores MOUSE_MODE_CAPTURED). Pressing `ui_cancel` at the Pause root also triggers resume: `_unhandled_input()` in `pause_menu.gd` checks `event.is_action_pressed(&"ui_cancel")` and calls `queue_free()` when NO sub-screen is active and NO modal is open. Verifies GDD + UX spec §Exit row "Resume gameplay".
- [ ] **AC-6**: `PersonnelFileButton.pressed` calls `SettingsService.open_panel()` (no pre-navigate argument from Pause Menu — opens Settings root). Focus restores to `PersonnelFileButton` on Settings dismiss (Settings pops its own `Context.SETTINGS`; InputContext returns to `PAUSE`; focus restore is handled by Settings via `return_focus_node` if SettingsService accepts one — see Implementation Notes). Verifies GDD CR-7 + UX spec §Exit row "Settings panel".
- [ ] **AC-7**: Sub-screen swap pattern: `FileDispatchButton.pressed` swaps `PageInterior` content to the Save grid (Story 007 scene). `OperationsArchiveButton.pressed` swaps to the Load grid (Story 006 scene). Sub-screen swap does NOT push a new InputContext — context remains `PAUSE`. `ui_cancel` from sub-screen returns to Pause root (button stack restored). Focus restores to triggering button on return. Verifies GDD §C.2 rows 7+8 + UX spec §Navigation.
- [ ] **AC-8**: `Events.save_failed` subscription connected in `_ready()`, disconnected in `_exit_tree()` with `is_connected()` guard. On `_on_save_failed(reason)`: call `_modal_scaffold.show_modal(SaveFailedContent, null)` (Story 001 AC-4 queue handles the non-blocking semantics). Verifies GDD CR-10 + ADR-0002 IG 3.
- [ ] **AC-9**: GIVEN `get_tree().paused == false` at section open, WHEN PauseMenu mounts, THEN `get_tree().paused` remains `false`. WHEN PauseMenu unmounts, THEN `get_tree().paused` remains `false`. Verified by reading `get_tree().paused` in a test scenario before, during, and after a PauseMenu lifecycle. Verifies GDD CR-4 + AC-MENU-2.5.
- [ ] **AC-10**: `MOUSE_MODE_VISIBLE` is set via `Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)` in `pause_menu.gd._ready()`. `MOUSE_MODE_CAPTURED` is restored in `_exit_tree()` via `Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)`. Verifies UX spec §Player Context §Held inputs.
- [ ] **AC-11**: `_update_accessibility_names()` called in `_ready()` and on `NOTIFICATION_TRANSLATION_CHANGED`. Sets `accessibility_description` on at minimum `OperationsArchiveButton` ("Load a previously filed dispatch. Current unsaved progress is lost." per GDD §C.8 `menu.pause.load.desc`) and `PersonnelFileButton`. Verifies GDD CR-22 + TR-MENU-014.
- [ ] **AC-12**: All Tween calls (folder slide-in from bottom-right, 180 ms) wrap in `if AccessibilitySettings.reduced_motion_enabled: _show_immediately() else: _play_tween()`. At MVP `reduced_motion_enabled` always reads `false` (Consumer Default Strategy per Settings GDD CR-6) — animations always play. Branch must exist in the code even if always false at MVP. Verifies GDD CR-23 + TR-MENU-015.
- [ ] **AC-13** (BLOCKED on ADR-0004 Gate 5): Pause Menu root has `accessibility_live = "assertive"` set BEFORE `visible = true` on mount; `call_deferred("set", "accessibility_live", "off")` queued for next frame (one-shot per GDD CR-21). BLOCKED until Gate 5 verifies `accessibility_live` property name.

---

## Implementation Notes

*Derived from ADR-0004 + GDD §CR-3 + §CR-4 + §C.2 + `design/ux/pause-menu.md` §Layout Zones:*

Scene structure (`src/ui/menu/PauseMenu.tscn`):
```
PauseMenu (CanvasLayer, layer=8)
  OverlayRect (ColorRect, color=#1A1A1A at 52% alpha, anchor=full_rect, mouse_filter=IGNORE — gameplay framebuffer shows through)
  FolderBody (Control, size=(760,720), anchor=ANCHOR_BOTTOM_RIGHT, offset=(0,0))
    TabLabel (Label — tr("menu.pause.folder_tab"), not interactive — folder tab text per §V.1)
    PageInterior (VBoxContainer — the content swap zone)
      ResumeSurveillanceButton (Button)
      FileDispatchButton (Button)
      OperationsArchiveButton (Button)
      PersonnelFileButton (Button)
      ReturnToRegistryButton (Button)
      CloseFileButton (Button)
  ModalScaffold (instance of ModalScaffold.tscn, CanvasLayer layer=20 set by ModalScaffold per Story 001)
```

**Mounting by `PauseMenuController`**: `PauseMenuController` lives on the section root as a `Node` (not CanvasLayer — it is a pure script controller). On `pause` action while GAMEPLAY: `var inst = _pause_menu_scene.instantiate(); get_tree().current_scene.add_child(inst)`. `PauseMenu._ready()` then fires: sets `MOUSE_MODE_VISIBLE`, pushes `Context.PAUSE`, subscribes signals. On resume: `inst.queue_free()` (triggered by `ResumeSurveillanceButton` or `ui_cancel`). `PauseMenuController` does NOT hold a long-lived reference after `queue_free()`.

**`PauseMenuController._unhandled_input()` guard order**: check `InputContext.peek() == GAMEPLAY` FIRST, then `event.is_action_pressed(&"pause")`. If GAMEPLAY is not on top, consume the event silently (`set_input_as_handled()`) without mounting the menu. This prevents the `pause` action from leaking through when a modal or settings panel is open.

**Sub-screen swap**: `PageInterior.get_children()` are the button stack. Sub-screen content (Load grid, Save grid) replaces the button stack via: hide all existing children of `PageInterior`, instantiate sub-screen scene, add as child of `PageInterior`. On `ui_cancel` from sub-screen: `sub_screen.queue_free()`, restore visibility of button stack, restore focus to triggering button. Store triggering button reference in `_active_sub_screen_return_focus: Control` before swapping.

**ModalScaffold instance**: PauseMenu instantiates ModalScaffold as a child (same pattern as MainMenu in Story 002). It is the separate scaffold instance for Pause — ModalScaffold is not shared between MainMenu and PauseMenu (they are separate scene trees during their respective lifetimes).

**Settings return focus**: `SettingsService.open_panel()` does not accept a `return_focus_node` parameter in the current spec. Settings owns its own dismiss path via `Context.SETTINGS` pop. On Settings dismiss, `InputContext` returns to PAUSE — Pause Menu must re-obtain focus. Pattern: connect `SettingsService.panel_closed` signal (if it exists in ADR-0002 Settings domain) or use `NOTIFICATION_WM_FOCUS_IN` on the PauseMenu root to detect return. If no dismiss signal, use `InputContext`'s `ui_context_changed(new, old)` signal (ADR-0002 UI domain) to detect `new == PAUSE, old == SETTINGS` and call `PersonnelFileButton.call_deferred("grab_focus")`. Flag as OQ-005-1 if signal shape is unclear.

**Folder slide-in tween** (AC-12 / CR-23): target: `FolderBody.offset_bottom` from +50 (off-screen bottom) to 0, duration 180 ms, trans `TRANS_EXPO`, ease `EASE_OUT`. Wrapped in reduced-motion conditional — `_show_immediately()` sets offset to 0 directly.

**Re-Brief Operation button**: NOT included in MVP button stack (GDD CR-13 — surfaces only when `FailureRespawn.has_checkpoint() == true`; no checkpoints at MVP). Include as `ReBriefOperationButton` hidden by default (`visible = false`). VS scope: show/hide logic based on `FailureRespawn.has_checkpoint()` — deferred to VS sprint.

**Forbidden pattern `menu_loading_full_save_for_preview`**: PauseMenu.tscn never reads any `.res` save file. Save-card metadata reads belong exclusively in Story 006 (Load) and Story 007 (Save) sub-screen scenes.
**Forbidden pattern `menu_calling_save_assemble_directly`**: PauseMenu never calls `SaveLoad.save_to_slot()` from the shell. The File Dispatch sub-screen (Story 007) owns save writes.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: ModalScaffold.tscn infrastructure
- Story 006: Operations Archive sub-screen (Load grid — slot 0 + slot 1 minimal)
- Story 007: File Dispatch sub-screen (Save grid — slot 1 minimal)
- Story 008: Settings entry-point (`SettingsService.open_panel()` is called here but Settings internals are settings-accessibility epic)
- Post-VS: Re-Brief Operation button visibility logic (requires F&R `has_checkpoint()` API); Return-to-Registry confirm scene; full gamepad nav polish; folder-tab text dynamic update with section name

---

## QA Test Cases

*Manual verification + Integration — Solo mode (QL-STORY-READY skipped).*

- **AC-2 (PauseMenuController mounts only from GAMEPLAY)**:
  - Given: `InputContext.peek() == MENU` (Main Menu is open).
  - When: `pause` action fires.
  - Then: PauseMenu is NOT instantiated; `_is_modal_active` remains false; no new node added to scene tree.
  - Edge case: `InputContext.peek() == GAMEPLAY` → PauseMenu instantiates, adds to `current_scene`, `Context.PAUSE` pushed.

- **AC-3 (InputContext lifecycle)**:
  - Given: section scene with PauseMenuController; `peek() == GAMEPLAY`.
  - When: `pause` action fires → PauseMenu mounts.
  - Then: `peek() == PAUSE`. When `ResumeSurveillanceButton` activated → PauseMenu queued free → `peek() == GAMEPLAY`.
  - Edge case: PauseMenu `queue_free()` called while a sub-screen is active → sub-screen freed first, then PauseMenu → context pops correctly.

- **AC-5 (Resume / ui_cancel)**:
  - Given: PauseMenu mounted, no sub-screen active, no modal open.
  - When: `ui_cancel` fires.
  - Then: PauseMenu frees; `peek() == GAMEPLAY`; `MOUSE_MODE_CAPTURED` restored.
  - Edge case: `ui_cancel` fires while File Dispatch sub-screen is active → sub-screen dismissed first (returns to button stack); second `ui_cancel` closes PauseMenu.

- **AC-9 (get_tree().paused stays false)**:
  - Given: section running; `get_tree().paused == false`.
  - When: PauseMenu mounted.
  - Then: `get_tree().paused` still `false`.
  - When: PauseMenu unmounted.
  - Then: `get_tree().paused` still `false`.

- **AC-10 (mouse mode)**:
  - Given: section running with `MOUSE_MODE_CAPTURED`.
  - When: PauseMenu mounts.
  - Then: `Input.get_mouse_mode() == MOUSE_MODE_VISIBLE`.
  - When: PauseMenu unmounts.
  - Then: `Input.get_mouse_mode() == MOUSE_MODE_CAPTURED`.

- **AC-12 (reduced-motion branch)**:
  - Setup: grep `src/ui/menu/pause_menu.gd` for `reduced_motion_enabled` and Tween calls.
  - Verify: every Tween call is wrapped in the conditional branch.
  - Pass condition: no bare Tween calls outside the conditional; `_show_immediately()` function exists.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/presentation/menu_system/pause_menu_lifecycle_test.gd` — must exist and pass (mount-only-from-GAMEPLAY, InputContext push/pop, paused-stays-false, mouse-mode restore, ui_cancel at root, ui_cancel from sub-screen)
- `production/qa/evidence/pause-menu-shell-evidence.md` — walkthrough doc with screenshots: (a) Pause Menu open mid-section with gameplay framebuffer visible behind overlay; (b) Pause Menu closed, player back in gameplay; (c) all 6 MVP buttons visible with correct labels; (d) `get_tree().paused == false` confirmed in debugger during Pause Menu open

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (ModalScaffold.tscn); Story 004 (QuitConfirmContent.tscn needed for CloseFileButton wiring — optional at shell-only MVP but required for full integration)
- Unlocks: Story 006 (Operations Archive sub-screen is hosted by PauseMenu's PageInterior swap); Story 007 (File Dispatch sub-screen is hosted by PauseMenu's PageInterior swap)

## Open Questions

- **OQ-005-1**: `SettingsService.open_panel()` return path — does `SettingsService` emit a dismiss signal, or does PauseMenu use `ui_context_changed(new: PAUSE, old: SETTINGS)` to detect return and restore focus to `PersonnelFileButton`? Coordinate with settings-accessibility epic lead before implementing AC-6 focus restore.
- **OQ-005-2**: `PauseMenuController` attachment point — GDD CR-4 says "per-section CanvasLayer overlay" but notes `PauseMenuController` should live on "each section scene root or on the project's `SectionRoot` base script if one exists — TBD with level-streaming team." Resolve with level-streaming epic before implementing AC-2.
- **OQ-005-3**: Re-Brief Operation button: at MVP `visible = false` always. VS wiring needs `FailureRespawn.has_checkpoint()` API (GDD CR-13 BLOCKING coord with F&R GDD — "F&R GDD must add public query API `has_checkpoint() -> bool`"). Keep hidden at MVP; document VS coord item.
