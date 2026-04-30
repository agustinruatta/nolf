# Story 003: Photosensitivity boot-warning content scene — modal content, dismiss contract, SettingsService handshake

> **Epic**: Menu System
> **Status**: BLOCKED — ADR-0004 is Proposed (Gate 5: `RichTextLabel` BBCode → AccessKit plain-text serialization unverified; accessibility one-shot assertive pattern from AC-8 in Story 001 is similarly gated). Core dismiss logic and SettingsService handshake can be drafted; AccessKit one-shot implementation blocked until ADR-0004 Gate 5 closes or is resolved in favour of a plain `Label`.
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/menu-system.md`
**Requirement**: `TR-MENU-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (UI Framework) + ADR-0002 (Signal Bus + Event Taxonomy) + ADR-0007 (Autoload Load Order Registry)
**ADR Decision Summary**: ADR-0004 Gate 1 CLOSED 2026-04-29 — `Control.accessibility_description` is a settable String property; `accessibility_role` is inferred from node type, NOT settable as a string property. One-shot assertive pattern (`accessibility_live` set before visible, cleared via `call_deferred`) remains unverified (Gate 5 deferred to runtime AT testing). ADR-0007 guarantees `SettingsService._ready()` completes — and `_boot_warning_pending` is fully committed — before `MainMenu._ready()` fires; no `await` needed. ADR-0002 mandates `is_connected()` guard on all signal disconnections.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (ADR-0004 Gate 5 open; `accessibility_live` property name unverified post-cutoff — verify via editor autocomplete before setting)
**Engine Notes**: `Control.accessibility_description` confirmed settable (Gate 1 CLOSED 2026-04-29). `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` constants verified (Gate 4 CLOSED 2026-04-27). `accessibility_live` and the deferred-clear pattern are post-cutoff (Godot 4.5 AccessKit) and MUST be verified via editor autocomplete before use (GATE-F7-B). Do not implement the `accessibility_live` one-shot until Gate 5 closes or a runtime AT test confirms it.

**Control Manifest Rules (Presentation)**:
- Required: all text via `tr()` — no hardcoded strings (ADR-0004 / TR-MENU-010)
- Required: `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` on every `Label`/`Button` (ADR-0004)
- Required: `is_dismissible() -> bool` method on content root returning `false` — boot-warning is non-dismissible by `ui_cancel` (GDD CR-8 + Story 001 AC-6 contract)
- Required: `get_default_focus_target() -> Control` method on content root — returns `ContinueButton` (Story 001 AC-2 contract)
- Required: subscribers connect in `_ready()`, disconnect in `_exit_tree()` with `is_connected()` guard (ADR-0002 IG 3)
- Forbidden: `_process()` or `_physics_process()` (GDD CR-18)
- Forbidden: `Window`-based dialogs (GDD C.4)
- Forbidden: `menu_loading_full_save_for_preview` — this content scene never reads any save resource
- Forbidden: `menu_calling_save_assemble_directly` — this content scene never calls `SaveLoadService.save_to_slot()` or assembly methods

---

## Acceptance Criteria

*From GDD `design/gdd/menu-system.md` §CR-8 + §C.2 row 2 + §F.7 + §H.10 + `design/ux/photosensitivity-boot-warning.md` §Entry & Exit Points:*

- [ ] **AC-1**: `PhotosensitivityWarningContent.tscn` scene exists at `src/ui/menu/PhotosensitivityWarningContent.tscn`. Root node is a `Control` (`mouse_filter = MOUSE_FILTER_STOP`). Script at `src/ui/menu/photosensitivity_warning_content.gd`. The scene has two focusable `Button` children: `ContinueButton` (default focus, `tr("menu.boot_warning.continue")` — "Continue") and `GoToSettingsButton` (`tr("menu.boot_warning.go_to_settings")` — "Go to Settings"). A `Label` child carries the 38-word locked body copy from `tr("menu.boot_warning.body")`. `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` on all `Label`/`Button` nodes. Verifies TR-MENU-003 + GDD CR-8 + UX spec §Entry.
- [ ] **AC-2**: `photosensitivity_warning_content.gd` exposes `is_dismissible() -> bool` returning `false`. Exposes `get_default_focus_target() -> Control` returning `ContinueButton`. Both methods are required by the `ModalScaffold` contract (Story 001 AC-6 + AC-2). Verifies ModalScaffold integration.
- [ ] **AC-3**: `ContinueButton.pressed` signal handler calls `SettingsService.dismiss_warning()`. If `dismiss_warning()` returns `true` (success): call `ModalScaffold.hide_modal()` on the hosting scaffold (via `_get_scaffold()` helper or passed reference — see Implementation Notes). If `dismiss_warning()` returns `false` (disk-full / write failure): modal stays open; button remains enabled; `push_warning("PhotosensitivityWarningContent: dismiss_warning() failed — disk full?")` is called; no crash. Verifies UX spec §Exit Destinations row "Dismiss-to-Main-Menu (Continue path)" + AC-MENU-6.3 + AC-MENU-6.4.
- [ ] **AC-4**: `GoToSettingsButton.pressed` signal handler calls `SettingsService.dismiss_warning()` (same success/failure contract as AC-3). On success: calls `ModalScaffold.hide_modal()` THEN calls `SettingsService.open_panel(pre_navigate: "accessibility.damage_flash_enabled")`. The `hide_modal()` call completes before `open_panel()` fires — no race condition. On failure: modal stays open (same as AC-3 failure path). Verifies UX spec §Exit Destinations row "Dismiss-to-Settings (Go to Settings path)".
- [ ] **AC-5**: `ui_cancel` (`Esc` / `JOY_BUTTON_B`) does NOT dismiss this modal. The `is_dismissible() -> bool` method returning `false` is the contract gate; `ModalScaffold._unhandled_input()` (Story 001 AC-6) enforces it. No `_unhandled_input()` override is needed in this content scene — ModalScaffold is the owner of dismiss routing. Verifies GDD CR-8 + UX spec §Exit Destinations row "`ui_cancel` — non-dismissible" + AC-MENU-6.2.
- [ ] **AC-6**: Tab/Shift+Tab focus cycles within the two-button set: `ContinueButton` → `GoToSettingsButton` → `ContinueButton` (wrap). `focus_neighbor_bottom` on `ContinueButton` points to `GoToSettingsButton`; `focus_neighbor_top` on `GoToSettingsButton` points to `ContinueButton`; `focus_neighbor_bottom` on `GoToSettingsButton` points to `ContinueButton` (wraps back); `focus_neighbor_top` on `ContinueButton` points to `GoToSettingsButton`. Focus never escapes to the underlying MainMenu buttons per Story 001 AC-7 contract. Verifies GDD CR-24 focus trap.
- [ ] **AC-7**: `_update_accessibility_names()` called in `_ready()` and from `_notification(NOTIFICATION_TRANSLATION_CHANGED)`. Sets `ContinueButton.accessibility_description = tr("menu.boot_warning.continue.desc")` and `GoToSettingsButton.accessibility_description = tr("menu.boot_warning.go_to_settings.desc")`. Verifies GDD CR-22 + TR-MENU-014.
- [ ] **AC-8** (BLOCKED on ADR-0004 Gate 5): Modal root has `accessibility_live = "assertive"` set BEFORE `visible = true`; `call_deferred("set", "accessibility_live", "off")` queued for next frame (one-shot pattern per GDD CR-21). BLOCKED until ADR-0004 Gate 5 resolves the `RichTextLabel` / `accessibility_live` property name. Verifies GDD CR-21 + AC-MENU-13.1.
- [ ] **AC-9**: `photosensitivity_warning_content.gd` has no `_process()` or `_physics_process()` override. Zero per-frame logic. Verifies GDD CR-18.

---

## Implementation Notes

*Derived from ADR-0004 §Implementation Guidelines + GDD §CR-8 + §C.3 + §C.4 + `design/ux/photosensitivity-boot-warning.md`:*

Scene structure (`src/ui/menu/PhotosensitivityWarningContent.tscn`):
```
PhotosensitivityWarningContent (Control, mouse_filter=STOP)
  TitleLabel (Label — tr("menu.boot_warning.title"), auto_translate_mode=ALWAYS)
  BodyLabel (Label — tr("menu.boot_warning.body"), auto_translate_mode=ALWAYS)
  ButtonRow (HBoxContainer)
    ContinueButton (Button — tr("menu.boot_warning.continue"), default focus, auto_translate_mode=ALWAYS)
    GoToSettingsButton (Button — tr("menu.boot_warning.go_to_settings"), auto_translate_mode=ALWAYS)
```

**ModalScaffold reference pattern**: The content scene does not hold a direct reference to the scaffold. The host scene (MainMenu) passes the scaffold reference when it calls `ModalScaffold.show_modal(PhotosensitivityWarningContent)`. The content scene calls `hide_modal()` by calling `get_parent().get_parent()` (content → ContentSlot → CardContainer → ModalScaffold) OR (preferred for maintainability) by exposing a `var scaffold: ModalScaffold` settable property that the ModalScaffold's `show_modal()` implementation sets on the instantiated content before adding it to the tree. Coordinate with Story 001 implementation to agree on the call-back pattern — the contract is `hide_modal()` must be callable from within the content scene. The forbidden direct-`queue_free()` pattern is never used.

**dismiss_warning() failure path**: `SettingsService.dismiss_warning()` returns `bool`. On `false`: log with `push_warning()` (not `push_error()` — this is a recoverable failure path per the UX spec; the player can retry by pressing Continue again). Do not disable the button on failure — the player must be able to retry the dismiss. Do not show a separate error modal — the UX spec does not specify one and the save-failed dialog pattern (Story 001 AC-4 queue) is the wrong scope for a settings write failure.

**`pre_navigate` parameter**: `SettingsService.open_panel(pre_navigate: String)` is called by `GoToSettingsButton` handler. The `pre_navigate` value is the const string literal `"accessibility.damage_flash_enabled"` — do NOT hardcode as a magic string in-line; store as a `const PRE_NAVIGATE_TARGET: String = "accessibility.damage_flash_enabled"` at the top of the script. This is the one string in this scene that does NOT go through `tr()` — it is an internal settings key, not a player-visible string (per ADR-0003 sidecar key patterns as a convention). Document this exception with a comment.

**review-mode dismiss (CR-24)**: When this scene is opened from Settings → Accessibility (CR-24 player-initiated review), `dismiss_warning()` must NOT be called (the dismissed-flag is already `true`). The distinguishing signal is provided by the host: when opened from Settings via CR-24, the ModalScaffold passes a `review_mode: bool = false` flag into `show_modal()`. The content scene stores this in `_review_mode: bool`. In `ContinueButton.pressed` and `GoToSettingsButton.pressed`, check `if _review_mode: skip dismiss_warning()`. This is a VS-scope enhancement — at MVP, `_review_mode` always reads `false` (boot-warning path only). Document as a VS-scope note.

**Forbidden pattern `menu_loading_full_save_for_preview`**: This scene never reads any `SaveGame` resource. It is a pure UI + SettingsService handshake. No `SaveLoad.*` call of any kind belongs in this file.
**Forbidden pattern `menu_calling_save_assemble_directly`**: This scene never calls `SaveLoadService.save_to_slot()` or `SaveLoadService.assemble_save_game()`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: `ModalScaffold.tscn` infrastructure that hosts this content scene; `is_dismissible()` enforcement in `_unhandled_input()`
- Story 002: `MainMenu._ready()` boot-warning poll (step 5 of boot sequence) and `set_process_input` gate release on dismiss
- Story 008: `SettingsService.open_panel()` internal implementation; the Settings panel itself (settings-accessibility epic)
- VS scope: CR-24 player-initiated review mode (`_review_mode` flag wiring from Settings)

---

## QA Test Cases

*Manual verification + Integration — Solo mode (QL-STORY-READY skipped).*

- **AC-2 (method contract)**:
  - Setup: instantiate `PhotosensitivityWarningContent` in a test scene.
  - Verify: `is_dismissible()` returns `false`; `get_default_focus_target()` returns the `ContinueButton` node reference.
  - Pass condition: both method return values are as specified; no null reference.

- **AC-3 (Continue dismiss — success path)**:
  - Given: `PhotosensitivityWarningContent` mounted in a `ModalScaffold` child of `MainMenu`; `SettingsService.dismiss_warning()` test double returning `true`.
  - When: `ContinueButton` is activated (keyboard Enter / mouse click).
  - Then: `dismiss_warning()` called exactly once; `ModalScaffold.hide_modal()` called; `Context.MODAL` popped; focus restores to `MainMenu.ContinueButton`; no crash.
  - Edge case: `dismiss_warning()` test double returns `false` → modal stays open; `push_warning` fired; `ContinueButton` still enabled and functional for retry.

- **AC-4 (Go to Settings — success path)**:
  - Given: same setup as AC-3; `SettingsService.open_panel()` test double callable with a string argument.
  - When: `GoToSettingsButton` activated.
  - Then: `dismiss_warning()` called; `hide_modal()` called; THEN `open_panel("accessibility.damage_flash_enabled")` called. Order verified by test double call log: `dismiss_warning` fires before `open_panel`.
  - Edge case: `dismiss_warning()` returns `false` → `open_panel` NOT called; modal stays open.

- **AC-5 (ui_cancel non-dismissible)**:
  - Given: `PhotosensitivityWarningContent` active in modal.
  - When: `ui_cancel` action fires.
  - Then: modal remains open; `hide_modal()` NOT called; `ModalScaffold._unhandled_input()` consumed the event (modal still visible after keypress).
  - Pass condition: no visual change; `peek()` remains `Context.MODAL`.

- **AC-6 (focus trap)**:
  - Setup: `PhotosensitivityWarningContent` mounted; `ContinueButton` has default focus.
  - When: Tab pressed once.
  - Then: focus moves to `GoToSettingsButton`.
  - When: Tab pressed again.
  - Then: focus wraps to `ContinueButton`.
  - When: Shift+Tab from `ContinueButton`.
  - Then: focus moves to `GoToSettingsButton` (wrap from first to last).
  - Pass condition: focus never reaches any MainMenu button during cycle.

- **AC-7 (accessibility_description re-resolve)**:
  - Setup: launch with English locale; inspect `ContinueButton.accessibility_description`.
  - Verify: non-empty, matches localized string for `"menu.boot_warning.continue.desc"`.
  - Pass condition: description non-empty; no raw tr-key leaked; re-fires correctly after `NOTIFICATION_TRANSLATION_CHANGED`.

- **AC-9 (no _process)**:
  - Setup: grep `src/ui/menu/photosensitivity_warning_content.gd` for `_process` and `_physics_process`.
  - Pass condition: zero matches.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/presentation/menu_system/photosensitivity_warning_dismiss_test.gd` — must exist and pass (Continue success path, Continue failure path, GoToSettings success path, focus trap)
- `production/qa/evidence/photosensitivity-boot-warning-evidence.md` — manual walkthrough doc with screenshots showing: (a) modal mounted before Main Menu is interactive; (b) Esc does not dismiss; (c) Continue dismisses and restores focus to Main Menu; (d) Go to Settings dismisses and opens Settings panel

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (ModalScaffold.tscn must exist with `show_modal()` / `hide_modal()` API + `is_dismissible()` gate in `_unhandled_input()`); Story 002 (MainMenu.tscn must mount ModalScaffold and call `show_modal(PhotosensitivityWarningContent)` from boot-warning poll step)
- Unlocks: Story 004 (QuitConfirmContent — shares the same ModalScaffold infrastructure; boot-warning being non-dismissible must be verified before quit-confirm tests the dismissible path); Story 008 (Settings entry-point wiring references `SettingsService.open_panel()` which is the same method tested here in GoToSettings path)

## Open Questions

- **OQ-003-1**: The `_review_mode` flag for CR-24 player-initiated review (from Settings → Accessibility → `[Show Photosensitivity Notice]`): should `show_modal()` accept an optional `content_params: Dictionary` to pass review_mode, or should the content scene expose a `set_review_mode(val: bool)` method that ModalScaffold calls before mounting? The second is simpler and avoids Dictionary typing. Defer to VS sprint; at MVP `_review_mode` always reads `false`.
- **OQ-003-2**: `accessibility_live` property name: Gate 5 deferred to runtime AT testing. If Gate 5 resolves that `accessibility_live` is NOT a settable `String` property on `Control` in Godot 4.6, AC-8 requires a redesign. This is the only AC in this story blocked on Gate 5 — all other ACs can proceed.
