# Story 006: Minimal Load screen — slot 0 + slot 1 cards, slot_metadata reads, reload_current_section call

> **Epic**: Menu System
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/menu-system.md`
**Requirement**: `TR-MENU-004`, `TR-MENU-005`, `TR-MENU-006`, `TR-MENU-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Save Format Contract) + ADR-0004 (UI Framework) + ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: ADR-0003 (Accepted 2026-04-29) mandates that Menu never opens `.res` save files directly for preview. All slot state reads go through `SaveLoad.slot_metadata(N)` (returns the `slot_N_meta.cfg` Dictionary) and `SaveLoad.slot_state(N)` (returns `SaveLoad.SlotState` enum). The forbidden pattern `menu_loading_full_save_for_preview` is the primary fence for this story. Load flow: `SaveLoad.load_from_slot(N)` → `LevelStreamingService.transition_to_section(loaded.section_id, loaded, LOAD_FROM_SAVE)` per GDD CR-11 + TR-MENU-006. Step-9 restore callback registered per TR-MENU-007. VS scope for this story is **minimal**: slot 0 (autosave) and slot 1 only — not the full 8-slot picker (post-VS).

**Engine**: Godot 4.6 | **Risk**: LOW–MEDIUM (`SaveLoad.slot_metadata()` / `slot_state()` are project APIs — stable by design; `LevelStreamingService.transition_to_section()` is a project autoload API stable by contract)
**Engine Notes**: `GridContainer` with `columns = 2` is stable Godot 4.0+. `Control.accessibility_description` confirmed settable (ADR-0004 Gate 1 CLOSED). `call_deferred("grab_focus")` is stable. `ResourceLoader` / `ResourceSaver` post-cutoff APIs (`duplicate_deep`) do NOT apply here — this scene uses `slot_metadata()` sidecar reads only, never ResourceLoader directly.

**Control Manifest Rules (Presentation)**:
- Required: all text via `tr()` — no hardcoded strings
- Required: `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` on all `Label`/`Button` nodes
- Required: `SaveLoad.slot_metadata(N)` sidecar read ONLY — never `ResourceLoader.load("user://saves/slot_N.res")` for preview (ADR-0003 IG 8 / forbidden pattern `menu_loading_full_save_for_preview`)
- Required: `SaveLoad.slot_state(N)` for state determination (EMPTY / OCCUPIED / CORRUPT / AUTOSAVE)
- Required: push `InputContext.Context.LOADING` before `SaveLoad.load_from_slot()` call (GDD CR-2 + CR-11)
- Required: step-9 restore callback registered with `LevelStreamingService` after `transition_to_section()` call (TR-MENU-007)
- Required: `accessibility_description` on each slot card announcing state + metadata + destructive-load implication (GDD §C.9 + TR-MENU-014)
- Required: default focus on slot 0 card on mount (`call_deferred("grab_focus")`) (UX spec §Layout row 5)
- Forbidden: `_process()` or `_physics_process()` (GDD CR-18)
- Forbidden: `menu_loading_full_save_for_preview` — reading full `.res` save file for any preview, display, or state check
- Forbidden: save writes of any kind from this screen

---

## Acceptance Criteria

*From GDD `design/gdd/menu-system.md` §CR-11 + §C.2 row 7 + §C.5 + §C.8 + §C.9 + `design/ux/load-game-screen.md` §Entry & Exit Points:*

- [ ] **AC-1**: `OperationsArchiveScreen.tscn` exists at `src/ui/menu/OperationsArchiveScreen.tscn`. Script at `src/ui/menu/operations_archive_screen.gd`. This is the sub-screen scene instantiated by PauseMenu (Story 005 AC-7) and by MainMenu (post-VS) via the Operations Archive button. Minimal VS scope: renders **2 cards** — slot 0 and slot 1 only. A `GridContainer` (columns = 2) holds two `SlotCard` `Control` instances. A title `Label` with `tr("menu.load.title")` ("Operations Archive") at top. Verifies GDD CR-11 (2-slot minimal) + UX spec §Layout.
- [ ] **AC-2**: On `_ready()`, both cards hydrate from `SaveLoad.slot_metadata(0)` / `SaveLoad.slot_metadata(1)` (sidecar reads) and `SaveLoad.slot_state(0)` / `SaveLoad.slot_state(1)`. `slot_metadata()` returns a `Dictionary` or `null`. Slot state values: `EMPTY`, `OCCUPIED`, `CORRUPT`, `AUTOSAVE` per ADR-0003 / `SaveLoad.SlotState` enum. No `ResourceLoader.load()` call occurs anywhere in this scene or its card subscripts. Verifies ADR-0003 IG 8 + TR-MENU-004 + forbidden pattern `menu_loading_full_save_for_preview`.
- [ ] **AC-3**: Slot 0 card renders AUTOSAVE state: 2 px BQA Blue left-border accent, `AUTO-FILED` stamp, header `tr("menu.save.card_slot_zero")`. If `slot_state(0) == OCCUPIED or AUTOSAVE`: card shows typed metadata from `slot_metadata(0)` (`section_id` field rendered as section display name via `tr()` lookup). If `slot_state(0) == EMPTY`: shows `tr("menu.save.card_empty")` centred text + 30% dimmed, `disabled = true`. If `slot_state(0) == CORRUPT`: shows `tr("menu.save.card_corrupt")` + PHANTOM Red diagonal stamp + `disabled = true`. Verifies GDD CR-11 + §C.5 AUTOSAVE/EMPTY/CORRUPT rows.
- [ ] **AC-4**: Slot 1 card renders OCCUPIED, EMPTY, or CORRUPT state (no AUTOSAVE state — slot 1 is a manual save slot). Same visual differentiation rules as AC-3 (minus AUTOSAVE styling). `disabled = true` for EMPTY and CORRUPT. Verifies GDD CR-11 + §C.5.
- [ ] **AC-5**: GIVEN a card with `slot_state == OCCUPIED or AUTOSAVE`, WHEN player activates it (`ui_accept` / Enter / click), THEN: (a) fade menu music to silence on `MAIN_MENU` bus per GDD CR-20 (stub call — actual audio implementation coord with audio-director; at MVP stub with `push_warning("OperationsArchiveScreen: music fade not yet implemented")` if audio bus API is not yet wired); (b) push `InputContext.Context.LOADING`; (c) call `SaveLoad.load_from_slot(N)` to get the `SaveGame` object; (d) call `LevelStreamingService.transition_to_section(loaded_save.section_id, loaded_save, LevelStreamingService.TransitionReason.LOAD_FROM_SAVE)`; (e) register step-9 restore callback with `LevelStreamingService` per TR-MENU-007 (see Implementation Notes). Verifies TR-MENU-005 + TR-MENU-006 + TR-MENU-007 + GDD CR-11.
- [ ] **AC-6**: GIVEN a card with `slot_state == EMPTY or CORRUPT`, WHEN player activates it, THEN: no load fires; no `transition_to_section()` called; activation is a no-op (button `disabled = true` prevents event from reaching the handler). Verifies GDD §C.5 EMPTY/CORRUPT rows.
- [ ] **AC-7**: Default focus on slot 0 card on `_ready()` via `call_deferred("grab_focus")`. Verifies UX spec §Layout row 5 (recovery-fast path — slot 0 = most-recent autosave).
- [ ] **AC-8**: `accessibility_description` on each card set in `_update_accessibility_names()`: OCCUPIED/AUTOSAVE card announces `tr("menu.load.card_slot_N.desc")` including section name + state; EMPTY card announces `tr("menu.load.card_empty.desc")` ("Available dispatch slot. Nothing to load."); CORRUPT card announces `tr("menu.load.card_corrupt.desc")` ("Dispatch damaged. Cannot load."). OCCUPIED card from Pause context (not Main Menu) must include destructive warning from `tr("menu.load.card_slot_N.desc_destructive")` per GDD §C.8 `menu.pause.load.desc` pattern. Verifies TR-MENU-014 + GDD §C.9.
- [ ] **AC-9**: `ui_cancel` at the grid top level returns to parent menu (PauseMenu button stack, or MainMenu button stack) with focus restored to the triggering button (`OperationsArchiveButton`). The sub-screen scene calls `queue_free()` on itself; the parent PauseMenu (Story 005 AC-7) re-shows its button stack and restores focus. Verifies UX spec §Exit row "Back to parent menu root".
- [ ] **AC-10**: No `_process()` or `_physics_process()` override. All state reads are one-shot in `_ready()`. Verifies GDD CR-18.
- [ ] **AC-11**: `_update_accessibility_names()` called in `_ready()` and on `NOTIFICATION_TRANSLATION_CHANGED`. Verifies GDD CR-22.

---

## Implementation Notes

*Derived from ADR-0003 §Implementation Guidelines + GDD §CR-11 + §C.5 + §C.8 + §C.9 + `design/ux/load-game-screen.md':*

Scene structure (`src/ui/menu/OperationsArchiveScreen.tscn`):
```
OperationsArchiveScreen (Control)
  TitleLabel (Label — tr("menu.load.title"), auto_translate_mode=ALWAYS)
  SlotGrid (GridContainer, columns=2)
    SlotCard_0 (Control — slot 0, AUTOSAVE visual treatment)
    SlotCard_1 (Control — slot 1, standard treatment)
```

**SlotCard structure per card**:
```
SlotCard_N (Button, focus_mode=FOCUS_ALL, disabled depending on state)
  BorderAccent (StyleBoxFlat or Control — 2px left border, BQA Blue for slot 0 only)
  HeaderLabel (Label — slot identifier text)
  StateStamp (Label or TextureRect — FILED/VACANT/DOSSIER CORROMPU stamp text)
  MetadataLabel (Label — section name + timestamp from metadata Dict)
```

**`slot_metadata(N)` return contract** (ADR-0003): the returned `Dictionary` is expected to contain at minimum `section_id: String` (non-empty) and optionally `timestamp_gmt: String` (in-mission time string, not real-world clock per GDD Pillar 5 Refusal 4). Validate with `_is_valid_metadata(dict: Dictionary) -> bool` (same helper pattern as Story 002). If validation fails, treat as CORRUPT state for display purposes (even if `slot_state(N)` returned OCCUPIED — defensive programming).

**Step-9 restore callback** (TR-MENU-007): `LevelStreamingService` accepts a registered step-9 callback that fires after the loaded section is fully mounted. The callback is used for post-load menu cleanup (e.g., ensuring PauseMenu + OperationsArchiveScreen are freed if LS triggers a `change_scene` path). Registration call: `LevelStreamingService.register_post_load_callback(callable)` (exact API name — coordinate with level-streaming epic owner; if API does not yet exist, stub with `push_warning("OperationsArchiveScreen: step-9 callback API not yet available")`). This is the Menu System's entitlement as one of the three LS-authorised load callers per TR-MENU-005 + TR-MENU-007.

**Music fade stub**: GDD CR-20 mandates fading menu music to silence before `transition_to_section()`. At MVP, call pattern: `Events.menu_music_fade_requested.emit()` (if this signal exists in ADR-0002 Audio domain) or `push_warning("OperationsArchiveScreen: music fade not yet wired")`. Do NOT block on the fade with `await` at MVP unless the audio domain confirms the `await`-able signal. At VS: implement the `await` pattern per GDD CR-20.

**`transition_to_section` call sequence**:
```gdscript
var loaded_save: SaveGame = SaveLoad.load_from_slot(slot_index)
if loaded_save == null:
    push_error("OperationsArchiveScreen: load_from_slot(%d) returned null" % slot_index)
    InputContext.pop()  # pop LOADING
    return
InputContext.push(InputContext.Context.LOADING)  # must be before load_from_slot per GDD CR-2
# NOTE: LOADING is pushed before the above load call — see GDD CR-11. Adjust order:
# Correct sequence per CR-11: push LOADING → load_from_slot → transition
```
Correct sequence per GDD CR-2 + CR-11: (1) push `Context.LOADING`, (2) call `SaveLoad.load_from_slot(N)`, (3) check result non-null, (4) call `LevelStreamingService.transition_to_section(...)`, (5) register step-9 callback. If `load_from_slot` returns null after `Context.LOADING` is pushed: pop `Context.LOADING`, show error state (re-enter PAUSE or MENU), do NOT call `transition_to_section`.

**Minimal scope constraint**: this story implements slot 0 + slot 1 ONLY. The `GridContainer.columns = 2` layout with 2 cards is the entire grid at MVP. Slots 2–7 are post-VS. Do NOT add empty card stubs for slots 2–7 — they are absent from this grid, not disabled. The UX spec describes the full 8-slot layout; implement only the 2-card subset per VS Scope Guidance.

**Forbidden pattern `menu_loading_full_save_for_preview`**: this is the PRIMARY fence for this story. `ResourceLoader.load()` must never be called with a `slot_N.res` path in this file. All data for card display comes from `slot_metadata(N)` (sidecar `.cfg`) and `slot_state(N)`. Code review gate: grep `operations_archive_screen.gd` for `ResourceLoader.load` and `load_from_slot` — only one occurrence of `load_from_slot` is expected (in the confirm-load handler, AC-5), never in hydration code.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: PauseMenu sub-screen swap and `ui_cancel` routing back to Pause root
- Story 007: File Dispatch (Save screen) — separate sub-screen
- Post-VS: full 8-slot grid (slots 2–7); slot metadata preview with screenshot thumbnail; slot metadata timestamp display; slot deletion; Return-to-Registry confirm modal (belongs to PauseMenu shell, not load screen); Main Menu Operations Archive entry-point wiring (Story 002 Out of Scope)

---

## QA Test Cases

*Manual verification + Integration — Solo mode (QL-STORY-READY skipped).*

- **AC-2 (no full .res load)**:
  - Setup: instrument `ResourceLoader.load` with a spy; mount `OperationsArchiveScreen` with stubs for `SaveLoad.slot_metadata()` and `slot_state()`.
  - When: `_ready()` runs and cards hydrate.
  - Then: `ResourceLoader.load` spy records ZERO calls with a `slot_*.res` path.
  - Pass condition: no full resource load ever called from this scene.

- **AC-3 + AC-4 (card states)**:
  - Given: test harness injects `slot_state(0) = AUTOSAVE`, `slot_metadata(0) = {section_id: "plaza", timestamp_gmt: "14:23 GMT"}`.
  - When: `_ready()` runs.
  - Then: slot 0 card shows BQA Blue left border, `AUTO-FILED` stamp, section "plaza" rendered.
  - Edge case A: inject `slot_state(0) = EMPTY` → card shows "VACANT" stamp, `disabled = true`.
  - Edge case B: inject `slot_state(1) = CORRUPT` → card shows PHANTOM Red "DOSSIER CORROMPU" stamp, `disabled = true`.

- **AC-5 (load flow)**:
  - Given: slot 0 card OCCUPIED; `SaveLoad.load_from_slot(0)` test double returns a mock `SaveGame` with `section_id = "plaza"`; `LevelStreamingService.transition_to_section()` test double callable.
  - When: slot 0 card activated.
  - Then: `InputContext.peek() == LOADING` immediately after activation (before transition fires); `LevelStreamingService.transition_to_section("plaza", mock_save, LOAD_FROM_SAVE)` called once; step-9 callback registered.
  - Edge case: `load_from_slot` returns `null` → `transition_to_section` NOT called; `Context.LOADING` popped; error state shown.

- **AC-6 (disabled slot no-op)**:
  - Given: slot 1 EMPTY (`disabled = true`).
  - When: player presses Enter on slot 1 card.
  - Then: no load fires; `Context.LOADING` NOT pushed; `transition_to_section` NOT called.

- **AC-9 (ui_cancel returns to parent)**:
  - Given: `OperationsArchiveScreen` mounted as sub-screen in PauseMenu.
  - When: `ui_cancel` fires.
  - Then: `OperationsArchiveScreen.queue_free()` called; PauseMenu button stack restored; focus on `OperationsArchiveButton`.

- **AC-10 (no _process)**:
  - Setup: grep `operations_archive_screen.gd` for `_process` / `_physics_process`.
  - Pass condition: zero matches.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/presentation/menu_system/operations_archive_screen_test.gd` — must exist and pass (slot hydration from metadata, no .res load, OCCUPIED load flow, EMPTY no-op, CORRUPT no-op, InputContext.LOADING push, step-9 callback registration)
- `production/qa/evidence/operations-archive-screen-evidence.md` — walkthrough doc with screenshots: (a) screen mounted in PauseMenu with slot 0 (AUTOSAVE) and slot 1 (OCCUPIED) both visible; (b) EMPTY slot rendered with VACANT stamp; (c) CORRUPT slot rendered with red stamp; (d) successful load transition to Plaza section

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (ModalScaffold.tscn for save-failed modal from this context); Story 005 (PauseMenu sub-screen swap hosts this scene); ADR-0003 Accepted (confirmed 2026-04-29 — `SaveLoad.slot_metadata()` contract is stable)
- Unlocks: None within this epic. Enables QA to verify the full Load Game round-trip.

## Open Questions

- **OQ-006-1**: `LevelStreamingService.register_post_load_callback(callable)` — exact API name not confirmed in LS GDD. Coordinate with level-streaming epic owner before implementing AC-5 step-9 registration. If API does not exist yet, stub with `push_warning()`.
- **OQ-006-2**: Music fade before transition — `Events.menu_music_fade_requested` signal name not confirmed in ADR-0002 Audio domain. Coordinate with audio-director. At MVP: stub with `push_warning()`.
- **OQ-006-3**: `SaveLoad.slot_state(N)` vs `SaveLoad.slot_metadata(N)` return-null-for-corrupt: does `slot_state(N)` return `CORRUPT` when metadata is absent/malformed, or does it return `EMPTY` for an absent file? Coordinate with save-load epic owner. Defensive validation in `_is_valid_metadata()` handles the ambiguity at display level.
