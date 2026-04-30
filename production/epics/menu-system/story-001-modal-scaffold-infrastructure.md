# Story 001: ModalScaffold infrastructure — scene, queue, InputContext lifecycle

> **Epic**: Menu System
> **Status**: BLOCKED — ADR-0004 is Proposed (Gate 1: `accessibility_*` property names unverified; `Context.MODAL` enum value not yet added). Unblock when ADR-0004 Gate 1 closes + `Context.MODAL` / `Context.LOADING` amendment lands.
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/menu-system.md`
**Requirement**: `TR-MENU-002`, `TR-MENU-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (UI Framework) + ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: ADR-0004 mandates the InputContext stack for menu/gameplay context handover; modals push `Context.MODAL` and pop on dismiss via `ModalScaffold.hide_modal()`. ADR-0002 mandates that subscriptions are made in `_ready()` / disconnected in `_exit_tree()` with `is_connected()` guards. `ModalScaffold` is a custom `Control`-rooted scene (NOT `Window`, NOT `AcceptDialog`) at `CanvasLayer 20`.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (ADR-0004 Proposed; `Context.MODAL` enum addition needed; `accessibility_*` property names unverified — GATE-F7-A HIGH)
**Engine Notes**: `Control` node, `CanvasLayer`, `call_deferred`, signal connections — all stable Godot 4.0+. The `accessibility_role`, `accessibility_live`, `accessibility_name` property names on `Control` are post-cutoff (4.5 AccessKit integration) and MUST be verified via editor autocomplete before any accessibility property is set (ADR-0004 Gate 1 / GDD GATE-F7-A). `call_deferred("set", "accessibility_live", "off")` syntax must also be verified (GATE-F7-B). Do not implement accessibility properties until Gate 1 closes.

**Control Manifest Rules (Presentation)**:
- Required: all text via `tr()` — no hardcoded strings (ADR-0004)
- Required: subscribers connect in `_ready()`, disconnect in `_exit_tree()` with `is_connected()` guard (ADR-0002 IG 3)
- Required: `ModalScaffold` at `CanvasLayer 20` — above Settings (10), Cutscenes (10), Subtitles (15); below LS fade (127)
- Forbidden: `Window`-based modals (`AcceptDialog`, `ConfirmationDialog`) — they fight the period theme and fragment AccessKit semantics (GDD C.4)
- Forbidden: `_process()` or `_physics_process()` anywhere in Menu scenes (CR-18)
- Guardrail: Menu System claims zero steady-state gameplay CPU budget (GDD F.6); ModalScaffold has no per-frame work when idle

---

## Acceptance Criteria

*From GDD `design/gdd/menu-system.md` §C.4 + §H.12 + §H.10:*

- [ ] **AC-1**: `ModalScaffold.tscn` scene exists at `src/ui/menu/ModalScaffold.tscn` with root `Control` (`mouse_filter = MOUSE_FILTER_STOP`) → `ColorRect` backdrop (52% Ink Black `#1A1A1A`, full-screen) → `PanelContainer` (0 px corner radius, `StyleBoxFlat`) → content swap slot. `CanvasLayer.layer = 20` set on parent or scaffold itself per GDD C.4.
- [ ] **AC-2**: `ModalScaffold` script exposes `show_modal(content_scene_path: String, return_focus_node: Control = null)` and `hide_modal()` and signal `modal_dismissed`. `show_modal()` instantiates the content scene, adds it as child, calls `content.get_default_focus_target().call_deferred("grab_focus")`. `hide_modal()` calls `return_focus_node.call_deferred("grab_focus")` if `is_instance_valid(return_focus_node)`.
- [ ] **AC-3** (BLOCKED on `Context.MODAL` enum): `show_modal()` calls `InputContextStack.push(Context.MODAL)` before content becomes visible; `hide_modal()` calls `InputContextStack.pop()`. BLOCKED until ADR-0004 `Context.MODAL` amendment lands.
- [ ] **AC-4**: Depth-1 queue implemented: instance var `_pending_modal_content: PackedScene = null`. If `show_modal()` is called while `_is_modal_active == true` and incoming content is `SaveFailedContent` (idempotent): queue in `_pending_modal_content` replacing any prior queued `SaveFailedContent`. If incoming is a destructive-confirm type while another destructive-confirm is active: `push_error("ModalScaffold: rejected non-idempotent modal request while modal already active")` and return. On `hide_modal()`: if `_pending_modal_content != null`, call `show_modal(_pending_modal_content, null)` and clear. Verifies GDD C.4 queue policy + AC-MENU-12.1 + AC-MENU-12.2.
- [ ] **AC-5**: `hide_modal()` calls `return_focus_node.call_deferred("grab_focus")` only when `is_instance_valid(return_focus_node) == true`. When `false`: silently skips (no crash). Verifies AC-MENU-12.3.
- [ ] **AC-6**: `ModalScaffold._unhandled_input()` checks `event.is_action_pressed(&"ui_cancel")`; if content is dismissible (has method `is_dismissible()` returning `true`), calls `hide_modal()`. Boot-warning content returns `false` from `is_dismissible()` — Esc does NOT dismiss it. Verifies GDD C.4 dismiss + AC-MENU-6.2.
- [ ] **AC-7**: GIVEN modal with two focusable buttons (first + last), WHEN Tab from last button, THEN focus wraps to first (via `focus_neighbor_bottom/top` wiring on content's extreme children). WHEN Shift+Tab from first, THEN wraps to last. Focus does NOT escape to underlying menu. Verifies CR-24 focus trap + AC-MENU-12.4. (This wiring lives in each content scene, not in ModalScaffold itself — ModalScaffold documents the contract.)
- [ ] **AC-8** (BLOCKED on ADR-0004 Gate 1): Modal root has `accessibility_role = "dialog"`. One-shot assertive pattern per GDD F.7: `accessibility_live = "assertive"` set BEFORE `visible = true`; `call_deferred("set", "accessibility_live", "off")` queued for next frame. BLOCKED until GATE-F7-A + GATE-F7-B verified. Verifies CR-21 + AC-MENU-13.1.

---

## Implementation Notes

*Derived from ADR-0004 §Implementation Guidelines + GDD C.4:*

Scene structure (`src/ui/menu/ModalScaffold.tscn`):
```
ModalScaffold (Control, mouse_filter=STOP)
  BackdropRect (ColorRect, color=#1A1A1A at 52% alpha, anchors=full_rect)
  CardContainer (PanelContainer, StyleBoxFlat 0-radius, centered)
    ContentSlot (Control — content scenes are add_child'd here and removed on hide)
```

Script at `src/ui/menu/modal_scaffold.gd`:
- `_is_modal_active: bool`
- `_pending_modal_content: PackedScene`
- `_current_content: Control`
- `_return_focus_node: Control`
- `show_modal(content_scene_path: String, return_focus_node: Control = null)`: validate `assert(InputContextStack.peek() in [Context.MENU, Context.PAUSE], "ModalScaffold: show_modal requires MENU or PAUSE context")` (from GDD AC-MENU-10.2). Load content via `preload` const per content type OR `load()` at call time — prefer `preload` in the host scene to avoid hitching.
- Content type discrimination for queue policy: check `content.get_script().get_path()` against known content scene paths, OR add a typed constant `MODAL_TYPE: String` on each content scene root.

The `modal_dismissed` signal is emitted at the END of `hide_modal()` (after focus restore, after queue drain starts). Subscribers use it for post-dismiss logic (e.g., `MainMenu` re-enabling its button container after boot-warning).

**Forbidden pattern `menu_loading_full_save_for_preview`**: ModalScaffold never reads any `SaveGame` resource. It is a pure UI container — content scenes own their data access.
**Forbidden pattern `menu_calling_save_assemble_directly`**: ModalScaffold never calls `SaveLoadService.save_to_slot()` or any save-assembly method.

Per GDD C.4 recyclability: the same ModalScaffold instance receives `show_modal(PhotosensitivityWarningContent)` on boot, then `show_modal(SaveFailedContent)` if `Events.save_failed` fires later — no re-instantiation. The content child is swapped, not the scaffold.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `MainMenu.tscn` scene that instantiates ModalScaffold as a child and hosts the boot-warning poll
- Story 003: `PhotosensitivityWarningContent.tscn` and `QuitConfirmContent.tscn` content scenes
- Story 004: `PauseMenu.tscn` scene that instantiates ModalScaffold as a child
- Story 005: Save/Load grid scenes that consume ModalScaffold for save-failed dialog

Per-content-scene focus traps (AC-7): each content scene is responsible for wiring `focus_neighbor_*` on its first/last focusable children. ModalScaffold documents the contract but does not auto-wire.

---

## QA Test Cases

*Manual verification + Integration — Solo mode (QL-STORY-READY skipped).*

- **AC-1**: Setup: open `ModalScaffold.tscn` in Godot editor. Verify: scene tree matches spec (Control root → ColorRect → PanelContainer → ContentSlot). `CanvasLayer` layer = 20 on parent (set by host). Pass condition: tree structure exact, `mouse_filter = MOUSE_FILTER_STOP` on root, ColorRect `color = Color(0.102, 0.102, 0.102, 0.52)`, PanelContainer `StyleBoxFlat.corner_radius_*` all 0.
- **AC-4 (depth-1 queue)**:
  - Given: ModalScaffold instantiated in a test scene; `show_modal(QuitConfirmContent)` called first.
  - When: `show_modal(SaveFailedContent)` called while `_is_modal_active == true`.
  - Then: `_pending_modal_content` is `SaveFailedContent` packed scene; `QuitConfirmContent` remains active (not closed); `InputContextStack` depth = MODAL only (not double-pushed).
  - Edge case: second `show_modal(QuitConfirmContent)` while first is active → `push_error` fires; second content NOT queued; `_pending_modal_content` unchanged.
- **AC-5 (freed return_focus_node)**:
  - Given: `show_modal(QuitConfirmContent, return_node)` called; `return_node.queue_free()` called; then `hide_modal()`.
  - When: `is_instance_valid(return_node) == false` at call time.
  - Then: no crash; `grab_focus()` not called on freed node.
  - Edge case: `return_node` is null (not provided) → also no crash (null check before `is_instance_valid`).
- **AC-6 (ui_cancel dismiss gate)**:
  - Given: PhotosensitivityWarningContent active (returns `is_dismissible() = false`).
  - When: `ui_cancel` fires.
  - Then: modal stays open; `hide_modal()` NOT called; event consumed via `set_input_as_handled()`.
  - Edge case: QuitConfirmContent active (returns `is_dismissible() = true`) → `hide_modal()` IS called on `ui_cancel`.
- **AC-8 (one-shot assertive — blocked)**: AC-8 has no test until ADR-0004 Gate 1 closes. File a manual walkthrough doc once unblocked.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/presentation/menu_system/modal_scaffold_lifecycle_test.gd` — must exist and pass (queue logic, focus restore, dismiss gate)
- `production/qa/evidence/modal-scaffold-scene-structure-evidence.md` — screenshot of scene tree in editor

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: ADR-0004 `Context.MODAL` + `Context.LOADING` enum amendment (BLOCKING); ADR-0004 Gate 1 closes for AC-3 + AC-8 (BLOCKING for those ACs only — remaining ACs can proceed)
- Unlocks: Story 002 (MainMenu.tscn needs ModalScaffold as child), Story 003 (content scenes need ModalScaffold API), Story 004 (PauseMenu.tscn needs ModalScaffold as child)
