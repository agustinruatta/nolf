# Story 007: Minimal Save screen — slot 1 write via SaveLoadService, in-card overwrite-confirm, save-failed event

> **Epic**: Menu System
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/menu-system.md`
**Requirement**: `TR-MENU-004`, `TR-MENU-010`, `TR-MENU-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Save Format Contract) + ADR-0004 (UI Framework) + ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: ADR-0003 (Accepted 2026-04-29) mandates that the save action calls `SaveLoad.save_to_slot(N, save_game)`. The `SaveGame` object is assembled by Mission Scripting (or a coordinated caller) and passed to SaveLoad — Menu does NOT assemble the save itself. The forbidden pattern `menu_calling_save_assemble_directly` is the primary fence for this story. ADR-0002 mandates `Events.save_failed` subscription lifecycle. VS scope for this story is **minimal**: slot 1 only (no full 7-slot picker — post-VS).

**Engine**: Godot 4.6 | **Risk**: LOW (`SaveLoad.save_to_slot()` is a project API; `Control` nodes stable)
**Engine Notes**: `SaveLoad.save_to_slot()` returns `Error` (Godot 4.0+ `Error` enum). `ResourceSaver.save()` returns `Error`; non-`OK` triggers `Events.save_failed.emit()` (ADR-0003 §Key Interfaces). `Control.accessibility_description` confirmed settable (Gate 1 CLOSED). No new post-cutoff Godot APIs required for core save flow.

**Control Manifest Rules (Presentation)**:
- Required: all text via `tr()` — no hardcoded strings
- Required: `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` on all `Label`/`Button` nodes
- Required: `SaveLoad.slot_metadata(N)` sidecar read ONLY for card display — never ResourceLoader.load for preview (ADR-0003 IG 8)
- Required: `SaveLoad.save_to_slot(N)` called via `SaveLoad` autoload — NEVER `SaveLoad.assemble_save_game()` or direct `ResourceSaver.save()` (forbidden pattern `menu_calling_save_assemble_directly`)
- Required: in-card overwrite-confirm for OCCUPIED slot (two-press required per GDD CR-12); EMPTY slot saves immediately (no confirm per GDD CR-12)
- Required: `Events.save_failed` subscription in `_ready()`, disconnection in `_exit_tree()` with `is_connected()` guard (ADR-0002 IG 3)
- Required: default focus on slot 1 card on mount (UX spec §Layout row 5)
- Forbidden: `_process()` or `_physics_process()` (GDD CR-18)
- Forbidden: `menu_loading_full_save_for_preview` — slot_metadata reads for display only, never full .res load
- Forbidden: `menu_calling_save_assemble_directly` — this scene calls `save_to_slot()` ONLY; never assembles or constructs the SaveGame object
- Forbidden: `Context.LOADING` push from Save screen — save writes are synchronous fire-and-forget; they do NOT transition scenes (unlike load)

---

## Acceptance Criteria

*From GDD `design/gdd/menu-system.md` §CR-12 + §C.2 row 8 + §C.5 + §C.8 + `design/ux/save-game-screen.md` §Entry & Exit Points:*

- [ ] **AC-1**: `FileDispatchScreen.tscn` exists at `src/ui/menu/FileDispatchScreen.tscn`. Script at `src/ui/menu/file_dispatch_screen.gd`. Minimal VS scope: renders **1 card** — slot 1 only (slot 0 absent per GDD CR-12 / Save/Load CR-4). A `Control` (or `GridContainer` with columns=2, one card) holds a `SlotCard_1` `Control` instance. Title `Label` with `tr("menu.save.title")` ("File Dispatch") at top. Verifies GDD CR-12 (minimal scope) + UX spec §Layout.
- [ ] **AC-2**: On `_ready()`, slot 1 card hydrates from `SaveLoad.slot_metadata(1)` and `SaveLoad.slot_state(1)` (sidecar reads). No `ResourceLoader.load()` calls. Card renders OCCUPIED, EMPTY, or CORRUPT state per §C.5. Default focus on slot 1 card via `call_deferred("grab_focus")`. Verifies ADR-0003 IG 8 + TR-MENU-004.
- [ ] **AC-3**: Slot 1 EMPTY state: activating the card calls `SaveLoad.save_to_slot(1, _get_current_save_game())` immediately — no overwrite-confirm required (GDD CR-12: "Selecting EMPTY slot: write immediately"). On success (save_to_slot returns `OK`): card transitions to OCCUPIED state with updated metadata from `SaveLoad.slot_metadata(1)` re-read. On failure: `Events.save_failed` will fire via ADR-0002; `ModalScaffold` at PauseMenu level handles the dialog. Verifies GDD CR-12 EMPTY path.
- [ ] **AC-4**: Slot 1 OCCUPIED state: first activation of card triggers in-card CONFIRM_PENDING state swap (no modal opens — this is a pure visual card swap per GDD CR-12). Card interior: top text swaps to `tr("menu.save.confirm_overwrite_slot_1")` ("Overwrite Dispatch 01?"); body collapses; two focusable `Button` children appear inline: `CardCancelButton` (default focus, `tr("menu.save.card_cancel")` — "CANCEL") and `CardConfirmButton` (`tr("menu.save.card_confirm")` — "CONFIRM"). `ui_cancel` while in CONFIRM_PENDING returns card to NORMAL OCCUPIED state — does NOT close the Save grid (two-press rule per GDD CR-12). Verifies GDD CR-12 OCCUPIED path.
- [ ] **AC-5**: In CONFIRM_PENDING state, activating `CardConfirmButton`: calls `SaveLoad.save_to_slot(1, _get_current_save_game())`. On success: card returns to NORMAL OCCUPIED state with updated metadata (re-read `slot_metadata(1)`); grid stays open. On failure: `Events.save_failed` fires; card returns to NORMAL OCCUPIED state; grid stays open. Verifies GDD CR-12 Confirm path.
- [ ] **AC-6**: `_get_current_save_game()` helper returns the `SaveGame` object assembled by the caller. This helper calls a **coordinator** (Mission Scripting or Save/Load service) to assemble the current game state — it does NOT call `ResourceSaver.save()` directly, does NOT call `SaveGame.new()` and populate fields manually (that is assembly, not Menu's responsibility). Implementation: `_get_current_save_game() -> SaveGame: return SaveLoad.get_current_save_snapshot()` (if such a method exists on the `SaveLoad` autoload per ADR-0003 §Key Interfaces) OR `MissionLevelScripting.assemble_save_game()` (if MLS owns assembly). Coordinate with save-load epic and MLS epic owners before implementing. At MVP: stub with `return null` + `push_error("FileDispatchScreen: save assembly API not yet wired")`. Do NOT write any assembly logic in this scene. Verifies forbidden pattern `menu_calling_save_assemble_directly` (negative — this scene never assembles).
- [ ] **AC-7**: Two-press rule for grid exit: WHEN `ui_cancel` is pressed from CONFIRM_PENDING state, THEN card reverts to NORMAL OCCUPIED — grid does NOT close. WHEN `ui_cancel` is pressed from NORMAL state (no card in CONFIRM_PENDING), THEN grid closes (`queue_free()`); PauseMenu button stack restored; focus on `FileDispatchButton`. Verifies GDD CR-12 + UX spec §Navigation.
- [ ] **AC-8**: `Events.save_failed` subscription: connected in `_ready()`, disconnected in `_exit_tree()` with `is_connected()` guard. On `_on_save_failed(reason, slot)`: if `slot == 1` (the save just attempted), call `_modal_scaffold_ref.show_modal(SaveFailedContent, _last_activated_card_button)`. The `_last_activated_card_button` is stored before the save attempt so ModalScaffold can restore focus correctly after dismiss. The `ModalScaffold` reference is obtained from the hosting PauseMenu's modal scaffold instance. Verifies GDD CR-10 + ADR-0002 IG 3 + Story 001 AC-4.
- [ ] **AC-9**: Slot 1 CORRUPT state: card `disabled = true`; activation is no-op; `accessibility_description` announces "Dispatch damaged." per GDD §C.5 CORRUPT row. Verifies GDD CR-12 / §C.5.
- [ ] **AC-10**: `_update_accessibility_names()` in `_ready()` and `NOTIFICATION_TRANSLATION_CHANGED`. OCCUPIED card description announces section + timestamp + "Press to file over this dispatch." EMPTY card: "Available slot. Press to file new dispatch." CONFIRM_PENDING: "Confirm overwrite?" AT description is updated when CONFIRM_PENDING activates. Verifies TR-MENU-014 + GDD CR-22.
- [ ] **AC-11**: No `_process()` or `_physics_process()`. No `Context.LOADING` push from save (saves are synchronous, no scene transition). Verifies GDD CR-18.

---

## Implementation Notes

*Derived from ADR-0003 §Key Interfaces + GDD §CR-12 + §C.5 + `design/ux/save-game-screen.md`:*

Scene structure (`src/ui/menu/FileDispatchScreen.tscn`):
```
FileDispatchScreen (Control)
  TitleLabel (Label — tr("menu.save.title"), auto_translate_mode=ALWAYS)
  SlotCard_1 (Button or Control — slot 1 only at MVP)
    [NORMAL OCCUPIED state] HeaderLabel + MetadataLabel + StateStamp
    [NORMAL EMPTY state] HeaderLabel + VacantLabel + StateStamp (dimmed)
    [CONFIRM_PENDING state] OverwritePromptLabel + ButtonRow(CardCancelButton, CardConfirmButton)
    [CORRUPT state] HeaderLabel + CorruptLabel + CorruptStamp (disabled)
```

**Card state machine**: `SlotCard_1` is implemented as a state machine with three display states: `NORMAL`, `CONFIRM_PENDING`. CORRUPT is a NORMAL sub-state with `disabled = true`. Transitions: `NORMAL → CONFIRM_PENDING` on OCCUPIED slot activation; `CONFIRM_PENDING → NORMAL OCCUPIED` on CardCancelButton or `ui_cancel`; `CONFIRM_PENDING → NORMAL OCCUPIED (updated)` on CardConfirmButton + successful save. Do NOT use a separate scene swap for CONFIRM_PENDING — it is an in-card visual swap (`show()`/`hide()` on different VBox children per GDD CR-12). This keeps the card in-scene with no new InputContext push.

**`_get_current_save_game()` contract clarification**: The `SaveGame` object must be assembled by the game's state systems at the moment of the save press — not earlier (stale save) and not by this UI scene (Menu does not own state). Coordinate with save-load and MLS epic owners before the VS sprint. The stub at MVP (`return null` + `push_error`) is intentional — it surfaces the assembly API gap early so the correct owner can be identified before the VS production sprint runs.

**ModalScaffold reference from PauseMenu**: `FileDispatchScreen` is a sub-screen child of `PauseMenu.PageInterior`. The `ModalScaffold` instance lives as a sibling of `PageInterior` in the PauseMenu scene tree. To reach it: `get_parent().get_parent().get_node("ModalScaffold")` (PageInterior → FolderBody → PauseMenu, then sibling lookup). Alternatively, PauseMenu passes the scaffold reference when instantiating the sub-screen (`var screen = FileDispatchScreen.instantiate(); screen.modal_scaffold = _modal_scaffold_ref; add_child(screen)`). The latter is cleaner — prefer the explicit reference-passing pattern.

**save_to_slot return value vs Events.save_failed**: `SaveLoad.save_to_slot(N)` returns `Error`. The Menu does NOT poll the return value directly — instead, it relies on `Events.save_failed` (AC-8) for failure surfacing. This is the ADR-0002 decoupled pattern: the save domain emits the failure event; the menu reacts to the event. However, if `save_to_slot` returns a non-`OK` error AND `Events.save_failed` is not yet emitted (edge case in some async patterns), the return value acts as a guard: log with `push_error("FileDispatchScreen: save_to_slot(%d) returned non-OK error %s" % [slot, error])` and do not attempt to re-read slot metadata.

**Post-VS scope note**: full 7-slot grid (slots 1–7) is post-VS. The `GridContainer` structure is set up with `columns = 2` but only slot 1 instantiated at MVP. Adding slots 2–7 in VS production sprint is a matter of instantiating 6 additional `SlotCard` instances and populating them from `slot_metadata(N)` — the card state machine reuses identically.

**Forbidden pattern `menu_loading_full_save_for_preview`**: `operations_archive_screen.gd` and `file_dispatch_screen.gd` are the two files most at risk. Code review gate: grep both files for `ResourceLoader.load` with a save path. Zero matches expected.
**Forbidden pattern `menu_calling_save_assemble_directly`**: grep `file_dispatch_screen.gd` for `SaveGame.new()`, `assemble_save_game()`, `ResourceSaver.save()`. Zero matches expected (save_to_slot is the only save-related call, and it delegates all assembly to SaveLoad service).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: PauseMenu sub-screen swap; `FileDispatchButton` connection to this scene; `ModalScaffold` instance that hosts SaveFailedContent
- Story 001: ModalScaffold.tscn infrastructure; SaveFailedContent (DISPATCH NOT FILED dialog) — Save-failed dialog is a post-VS full implementation; AC-8 in this story hooks the signal but only surfaces a skeleton
- Post-VS: slots 2–7; `SaveFailedContent.tscn` full implementation; Retry path that re-attempts the same slot; autosave on manual save (SaveLoad CR-4: "manual save to slot N also writes slot 0" — this is SaveLoad service's responsibility on `save_to_slot()` internally; Menu does not call slot 0 separately)

---

## QA Test Cases

*Manual verification + Integration — Solo mode (QL-STORY-READY skipped).*

- **AC-2 (no full .res load)**:
  - Setup: instrument `ResourceLoader.load` with a spy; inject `slot_metadata(1)` stub.
  - When: `_ready()` runs.
  - Then: spy records zero `.res` path calls.

- **AC-3 (EMPTY slot — immediate save)**:
  - Given: `slot_state(1) = EMPTY`; `_get_current_save_game()` test double returns a mock `SaveGame`.
  - When: slot 1 card activated.
  - Then: `SaveLoad.save_to_slot(1, mock_save)` called once; no CONFIRM_PENDING swap; card transitions to OCCUPIED state.
  - Edge case: `_get_current_save_game()` returns `null` (stub) → `push_error` fires; save NOT attempted; card stays EMPTY.

- **AC-4 (OCCUPIED slot — CONFIRM_PENDING)**:
  - Given: `slot_state(1) = OCCUPIED`.
  - When: slot 1 card activated (first press).
  - Then: card swaps to CONFIRM_PENDING; `CardCancelButton` has focus; `SaveLoad.save_to_slot` NOT called.
  - When: `ui_cancel` while CONFIRM_PENDING.
  - Then: card reverts to NORMAL OCCUPIED; grid stays open; `save_to_slot` NOT called.

- **AC-5 (CONFIRM_PENDING → confirm save)**:
  - Given: slot 1 in CONFIRM_PENDING; `_get_current_save_game()` returns mock.
  - When: `CardConfirmButton` activated.
  - Then: `SaveLoad.save_to_slot(1, mock)` called; card returns to NORMAL OCCUPIED with updated metadata from `slot_metadata(1)` re-read; grid stays open.

- **AC-7 (two-press rule)**:
  - Given: slot 1 in CONFIRM_PENDING.
  - When: `ui_cancel` pressed (press 1).
  - Then: card reverts to NORMAL OCCUPIED; grid stays open.
  - When: `ui_cancel` pressed again (press 2).
  - Then: `FileDispatchScreen.queue_free()`; PauseMenu button stack restored; focus on `FileDispatchButton`.

- **AC-8 (save_failed event handled)**:
  - Given: screen mounted; `Events.save_failed` emitted with `slot = 1`.
  - When: signal fires.
  - Then: `ModalScaffold.show_modal(SaveFailedContent, ...)` called; `Context.MODAL` pushed.

- **AC-11 (no _process, no Context.LOADING)**:
  - Setup: grep `file_dispatch_screen.gd` for `_process`, `_physics_process`, `Context.LOADING`, `InputContext.push`.
  - Pass condition: zero matches for `_process`/`_physics_process`; zero matches for `Context.LOADING` push.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/presentation/menu_system/file_dispatch_screen_test.gd` — must exist and pass (EMPTY immediate save, OCCUPIED confirm flow, two-press rule, save_failed event hookup, no .res load, no Context.LOADING)
- `production/qa/evidence/file-dispatch-screen-evidence.md` — walkthrough doc with screenshots: (a) screen mounted with slot 1 EMPTY; (b) CONFIRM_PENDING card state visible with two inline buttons; (c) successful save — card updates to OCCUPIED; (d) two-press `ui_cancel` returns to PauseMenu

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005 (PauseMenu sub-screen swap and ModalScaffold reference); Story 001 (ModalScaffold for SaveFailed event; SaveFailedContent scene — may be a stub at this story's MVP implementation); ADR-0003 Accepted
- Unlocks: Full save/load round-trip (Story 006 + Story 007 together enable the complete Pause → Save → Quit → Boot → Load round-trip)

## Open Questions

- **OQ-007-1**: `_get_current_save_game()` assembly API — does `SaveLoad` expose `get_current_save_snapshot() -> SaveGame` or does `MissionLevelScripting` own assembly? Resolve with save-load and MLS epic owners before VS implementation. At MVP: stub with null + push_error.
- **OQ-007-2**: `Events.save_failed` signal signature: is it `save_failed(reason: SaveLoad.FailureReason)` or `save_failed(reason: SaveLoad.FailureReason, slot: int)`? ADR-0002 Save domain shows `save_failed(reason: SaveLoad.FailureReason)` without a slot parameter in the current registry. If no slot param, use `_last_saved_slot: int` stored at save time to match the event. Coordinate with save-load epic owner.
