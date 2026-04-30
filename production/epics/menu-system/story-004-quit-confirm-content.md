# Story 004: Quit-confirm content scene — QuitConfirmContent, Case File register, destructive-quit flow

> **Epic**: Menu System
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/menu-system.md`
**Requirement**: `TR-MENU-008`, `TR-MENU-010`, `TR-MENU-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (UI Framework) + ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: ADR-0004 mandates that modals push `Context.MODAL` via ModalScaffold (not directly); the content scene is responsible only for its dismiss paths. ADR-0002 IG 3: any signal subscriptions connect in `_ready()` and disconnect in `_exit_tree()` with `is_connected()` guard. `QuitConfirmContent` is the canonical first instance of the Case File register applied to a modal scaffold (per `design/ux/quit-confirm.md` §Canonical Scaffold lineage). Its structural decisions propagate to `ReturnToRegistryContent`, `ReBriefOperationContent`, and `NewGameOverwriteContent` by inheritance.

**Engine**: Godot 4.6 | **Risk**: LOW (`get_tree().quit()` and `Control` nodes are stable Godot 4.0+)
**Engine Notes**: `get_tree().quit()` is stable since Godot 4.0. `Control.accessibility_description` confirmed settable (ADR-0004 Gate 1 CLOSED 2026-04-29). `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` constants verified (Gate 4 CLOSED 2026-04-27). No post-cutoff APIs required for the core flow.

**Control Manifest Rules (Presentation)**:
- Required: all text via `tr()` — no hardcoded strings (ADR-0004 / TR-MENU-010)
- Required: `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` on all `Label`/`Button` nodes (ADR-0004)
- Required: `is_dismissible() -> bool` returning `true` — Quit-Confirm IS dismissible by `ui_cancel` (GDD CR-9 + Story 001 AC-6 contract)
- Required: `get_default_focus_target() -> Control` returning `ContinueMissionButton` (Cancel / safe-default per GDD CR-9)
- Required: `_update_accessibility_names()` called in `_ready()` and on `NOTIFICATION_TRANSLATION_CHANGED` (GDD CR-22)
- Forbidden: `_process()` or `_physics_process()` (GDD CR-18)
- Forbidden: `Window`-based dialogs (GDD C.4)
- Forbidden: `menu_loading_full_save_for_preview` — content scene never reads any save resource
- Forbidden: `menu_calling_save_assemble_directly` — content scene never calls any save-assembly or save-write method
- Forbidden: `get_tree().quit()` called in any path not gated by the "Close File" button confirm press (per GDD CR-9 — quit must not fire on Cancel, Esc, or outside-click)

---

## Acceptance Criteria

*From GDD `design/gdd/menu-system.md` §CR-9 + §C.2 row 4 + §C.8 + `design/ux/quit-confirm.md` §Exit Destinations:*

- [ ] **AC-1**: `QuitConfirmContent.tscn` exists at `src/ui/menu/QuitConfirmContent.tscn`. Root is `Control` (`mouse_filter = MOUSE_FILTER_STOP`). Script at `src/ui/menu/quit_confirm_content.gd`. Two focusable `Button` children: `ContinueMissionButton` (default focus, `tr("menu.quit_confirm.cancel")` — "Continue Mission") and `CloseFileButton` (`tr("menu.quit_confirm.confirm")` — "Close File"). A `Label` child carries the locked body copy `tr("menu.quit_confirm.body_alt")` ("Operation abandoned."). A `Label` (or stylized header band element) carries `tr("menu.quit_confirm.title")` with Ink Black header band styling per §C.8. `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` on all `Label`/`Button` nodes. Verifies TR-MENU-008 + GDD CR-9 + UX spec §Layout.
- [ ] **AC-2**: Script exposes `is_dismissible() -> bool` returning `true`. Script exposes `get_default_focus_target() -> Control` returning `ContinueMissionButton`. Verifies ModalScaffold contract (Story 001 AC-6 + AC-2).
- [ ] **AC-3**: `ContinueMissionButton.pressed` handler calls `ModalScaffold.hide_modal()` on the hosting scaffold. No `get_tree().quit()` on this path. Focus restores to the originating button on the host menu (Close File button on MainMenu, or Quit Desktop button on PauseMenu) per ModalScaffold's `return_focus_node` contract (Story 001 AC-5). Verifies GDD CR-9 Cancel path + UX spec §Exit row "Cancel — dismiss to host menu".
- [ ] **AC-4**: `CloseFileButton.pressed` handler: (a) emits `Audio.play_sfx("ui_rubber_stamp_thud")` (or equivalent audio event bus call — see Implementation Notes); (b) calls `InputContextStack.pop()` to pop whichever context is on top (MENU or PAUSE — the scaffold owns the MODAL push/pop, but the host menu's context must be popped before quit per GDD CR-9); (c) calls `get_tree().quit()`. No `ModalScaffold.hide_modal()` on this path — the scene tree is destroyed by `quit()`. Verifies GDD CR-9 Confirm path + UX spec §Exit row "Confirm — terminate application" + AC-MENU-7.3.
- [ ] **AC-5**: `ui_cancel` (`Esc` / `JOY_BUTTON_B`) dismisses the modal — `is_dismissible()` returning `true` causes `ModalScaffold._unhandled_input()` to call `hide_modal()`. This content scene has no `_unhandled_input()` override; the cancel routing is entirely owned by ModalScaffold (Story 001 AC-6). Verifies GDD CR-9 + UX spec §Exit row "Cancel" + AC-MENU-7.2.
- [ ] **AC-6**: Tab/Shift+Tab focus cycles between `ContinueMissionButton` and `CloseFileButton` (wrap). `focus_neighbor_bottom` on `ContinueMissionButton` points to `CloseFileButton`; `focus_neighbor_top` on `CloseFileButton` points to `ContinueMissionButton`; wrap in both directions. Focus never reaches the underlying MainMenu or PauseMenu buttons. Verifies GDD CR-24 focus trap.
- [ ] **AC-7**: `_update_accessibility_names()` called in `_ready()` and on `NOTIFICATION_TRANSLATION_CHANGED`. Sets `ContinueMissionButton.accessibility_description = tr("menu.quit_confirm.cancel.desc")` and `CloseFileButton.accessibility_description = tr("menu.quit_confirm.confirm.desc")` (the "Close File" label is Case-File-period-authentic but the description provides modern-plain-language context for AT users per GDD CR-7 pattern). Verifies GDD CR-22 + TR-MENU-014.
- [ ] **AC-8**: No `_process()` or `_physics_process()` override. Zero per-frame logic. Verifies GDD CR-18.

---

## Implementation Notes

*Derived from ADR-0004 §Implementation Guidelines + GDD §CR-9 + §C.8 + `design/ux/quit-confirm.md` §CANONICAL decisions:*

Scene structure (`src/ui/menu/QuitConfirmContent.tscn`):
```
QuitConfirmContent (Control, mouse_filter=STOP)
  HeaderBand (PanelContainer — Ink Black #1A1A1A fill per §C.8)
    TitleLabel (Label — tr("menu.quit_confirm.title"), auto_translate_mode=ALWAYS)
  BodyLabel (Label — tr("menu.quit_confirm.body_alt"), auto_translate_mode=ALWAYS)
  ButtonRow (HBoxContainer)
    ContinueMissionButton (Button — tr("menu.quit_confirm.cancel"), default focus, auto_translate_mode=ALWAYS)
    CloseFileButton (Button — tr("menu.quit_confirm.confirm"), Ink Black StyleBoxFlat, auto_translate_mode=ALWAYS)
```

**Audio event call**: The rubber-stamp thud SFX on `CloseFileButton.pressed` must route through the audio event bus, NOT via `AudioStreamPlayer.play()` directly (GDD §A.1 — UI sounds on UI bus, not direct). Call pattern: `Events.ui_sfx_requested.emit("ui_rubber_stamp_thud")` or equivalent per ADR-0002 audio domain. If the audio event signal does not exist yet in `Events.gd`, stub with `push_warning("QuitConfirmContent: audio event bus signal not yet wired")` — do NOT create a direct `AudioStreamPlayer` as a workaround. Flag as a VS coord item with the audio-director.

**InputContextStack.pop() before quit()**: GDD CR-9 specifies `pop(Context.MENU)` or `pop(Context.PAUSE)` depending on host. The content scene cannot reliably know which context is at depth-1 below `Context.MODAL` — it only knows ModalScaffold will pop MODAL on `hide_modal()`. However, on the quit path `hide_modal()` is NOT called (tree destroyed by `quit()`). Therefore: on `CloseFileButton.pressed`, call `InputContextStack.pop()` once (pops MODAL), then `InputContextStack.pop()` again (pops MENU or PAUSE). Two pops are correct and safe: MODAL is on top, host context is directly below. This is an exception to the "scaffold owns all MODAL pops" rule — documented here as the only case where content pops more than its own MODAL, because quit() bypasses the scaffold's normal teardown. Alternative: leave the stack dirty since `get_tree().quit()` destroys everything — this is also valid. Use the two-pop approach for correctness; it does not cause a problem either way since the process exits immediately.

**CANONICAL scaffold decisions** (per `design/ux/quit-confirm.md` §Canonical Scaffold note): the header band layout, button-row layout (left = Cancel, right = Confirm), Ink Black destructive-button fill, rubber-stamp-thud SFX on confirm, and `ContinueMissionButton` default focus (NOT `CloseFileButton`) are canonical decisions for ALL four Case-File-register modals. Do not deviate from this layout in any sibling content scene.

**Forbidden pattern `menu_loading_full_save_for_preview`**: this content scene never reads any `SaveGame` resource. It owns no data access.
**Forbidden pattern `menu_calling_save_assemble_directly`**: this content scene never calls `SaveLoad.save_to_slot()`, `SaveLoad.assemble_save_game()`, or any persistence method. Quit does not trigger an auto-save per GDD CR-9.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: ModalScaffold infrastructure and `is_dismissible()` enforcement
- Story 002: MainMenu's `CloseFileButton` connection that calls `ModalScaffold.show_modal(QuitConfirmContent)` (that wiring is part of Main Menu shell interactivity — post-VS)
- Story 005: PauseMenu's Quit-Desktop button connection to this same content scene (VS scope)
- Sibling content scenes (`ReturnToRegistryContent`, `ReBriefOperationContent`, `NewGameOverwriteContent`) — separate stories or post-VS scope

---

## QA Test Cases

*Manual verification + Integration — Solo mode (QL-STORY-READY skipped).*

- **AC-2 (method contract)**:
  - Setup: instantiate `QuitConfirmContent` in a test scene.
  - Verify: `is_dismissible()` returns `true`; `get_default_focus_target()` returns the `ContinueMissionButton` reference.
  - Pass condition: both return values are as specified; no null reference.

- **AC-3 (Continue Mission — cancel path)**:
  - Given: `QuitConfirmContent` mounted in ModalScaffold; `_return_focus_node` set to a test button (the originating Close File button).
  - When: `ContinueMissionButton` activated.
  - Then: `hide_modal()` called; modal dismissed; `Context.MODAL` popped; focus restores to originating button; `get_tree().quit()` NOT called.
  - Edge case: `return_focus_node` is null (not passed) → dismiss still completes without crash; no `grab_focus()` attempted.

- **AC-4 (Close File — confirm path)**:
  - Given: `QuitConfirmContent` mounted; audio event test double registered.
  - When: `CloseFileButton` activated.
  - Then: audio test double records `"ui_rubber_stamp_thud"` call; `get_tree().quit()` called (process terminates — test must check that quit is called, not that the process actually exits, in an integration test context — use a test double / spy on `get_tree()`).
  - Pass condition: quit() called exactly once; rubber-stamp event fired before quit().
  - Edge case: pressing CloseFileButton twice (double-click) → quit() called only once (button is inactivated on first press OR process exits before second press can fire; either is acceptable).

- **AC-5 (ui_cancel dismisses)**:
  - Given: `QuitConfirmContent` mounted; `ContinueMissionButton` has focus.
  - When: `ui_cancel` action fires.
  - Then: `ModalScaffold.hide_modal()` called (via `is_dismissible() == true` branch in ModalScaffold); modal dismissed; `get_tree().quit()` NOT called.
  - Pass condition: no visual change except modal disappears; `peek()` returns prior context (MENU or PAUSE).

- **AC-6 (focus trap)**:
  - Setup: `QuitConfirmContent` mounted; `ContinueMissionButton` has default focus.
  - When: Tab pressed.
  - Then: focus on `CloseFileButton`.
  - When: Tab again.
  - Then: focus wraps to `ContinueMissionButton`.
  - Pass condition: focus never reaches underlying menu buttons.

- **AC-8 (no _process)**:
  - Setup: grep `src/ui/menu/quit_confirm_content.gd` for `_process` and `_physics_process`.
  - Pass condition: zero matches.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/presentation/menu_system/quit_confirm_content_test.gd` — must exist and pass (cancel path, confirm path, focus trap, ui_cancel)
- `production/qa/evidence/quit-confirm-content-evidence.md` — walkthrough doc with screenshots: (a) modal open on Main Menu with "Continue Mission" focused by default; (b) Esc dismisses cleanly; (c) "Close File" confirm triggers rubber-stamp SFX (audio dev must sign off) and terminates; (d) no underlying MainMenu focus reached during Tab cycle

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (ModalScaffold.tscn with `is_dismissible()` enforcement); Story 003 (confirms the non-dismissible path works, making the dismissible path here the correct contrast)
- Unlocks: Story 005 (PauseMenu needs `QuitConfirmContent` for its Quit Desktop button); Story 006 (Load screen's Return-to-Registry confirm inherits the same canonical scaffold pattern)

## Open Questions

- **OQ-004-1**: Audio event signal name for rubber-stamp thud SFX — `Events.ui_sfx_requested(String)` is not yet declared in `Events.gd`. Coordinate with audio-director to confirm the signal name before Story 004 implementation begins. If not yet defined, stub with `push_warning()` per Implementation Notes.
- **OQ-004-2**: `InputContextStack.pop()` on the quit path — should the content scene pop twice (MODAL + host context) or leave stack cleanup to the engine exit? Both are correct; the two-pop approach is more explicit. Flag for lead-programmer review before implementation.
