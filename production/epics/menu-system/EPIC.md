# Epic: Menu System

> **Layer**: Presentation
> **GDD**: `design/gdd/menu-system.md`
> **Architecture Module**: Menu System (`CanvasLayer`-rooted state-swap scenes under root; NOT autoload per ADR-0007)
> **Engine Risk**: LOW (state-swap pattern; SaveLoad + Settings integration)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories menu-system`
> **Manifest Version**: 2026-04-30

## Overview

Menu System is the **suite of non-gameplay screens**: the photosensitivity boot warning, the main menu shell, the load/save game screens, the pause menu, the settings entry-point. State swaps between these screens are managed by a top-level `MenuController` consuming the input-context stack (ADR-0004). Menu System is one of three authorised callers of `LevelStreamingService.reload_current_section` (alongside Mission & Level Scripting and Failure & Respawn) — used by Save/Load → Load Game flow.

The Day-1 MVP slice is HARD-blocking on HUD Core + Settings & Accessibility per HUD Core REV-2026-04-26 D2: photosensitivity boot-warning modal scaffold + Settings entry-point + minimal Main Menu shell. The full VS surface (slot picker, save metadata preview, full pause-menu options) ships in the VS production sprint.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0002: Signal Bus + Event Taxonomy | Publishes UI-domain signals (`menu_opened`, `menu_closed`); subscribes to `game_loaded`, `save_failed` | LOW |
| ADR-0003: Save Format Contract | Reads slot metadata sidecars (`slot_N_meta.cfg`) without loading full `.res`; calls `SaveLoadService.load_from_slot()` | LOW |
| ADR-0004: UI Framework | Theme resource; input-context stack manages menu/gameplay context handover; modal stack for nested screens | LOW–MEDIUM (Proposed) |
| ADR-0007: Autoload Load Order Registry | NOT autoload — state-swap scenes under root | LOW |

## GDD Requirements

**15 TR-IDs** in `tr-registry.yaml` (`TR-MENU-001` .. `TR-MENU-015`) cover:

- Photosensitivity boot-warning modal scaffold (Day-1 MVP slice)
- Main Menu shell (New Game, Load Game, Settings, Quit)
- Load Game screen (consumes `slot_N_meta.cfg` metadata; never loads `.res` for preview)
- Save Game screen (writes via SaveLoadService)
- Pause menu (Resume, Save, Load, Settings, Quit-to-Menu, Quit-to-Desktop)
- Settings entry-point (handover to Settings & Accessibility)
- One of three authorised callers of `reload_current_section`
- State-swap pattern + input-context stack integration
- Forbidden patterns (`menu_loading_full_save_for_preview`, `menu_calling_save_assemble_directly`)

Full requirement text: `docs/architecture/tr-registry.yaml` Menu System section.

## VS Scope Guidance

- **Include (Day-1 HARD MVP slice)**: Photosensitivity boot-warning modal; minimal Main Menu shell (New Game + Quit); Settings entry-point handover.
- **Include (VS scope)**: Pause menu (Resume + Save + Load + Quit-to-Menu); minimal Load/Save screen (slot 0 + slot 1 only — full 8-slot picker post-VS); `reload_current_section` call from Load.
- **Defer post-VS**: Slot metadata preview (date, mission, screenshot); rebind UI within Settings; controller navigation polish; full 8-slot save picker; transition animations.

## Definition of Done

- All stories implemented, reviewed, closed via `/story-done`.
- Photosensitivity boot warning displays on first launch; click-to-dismiss persists in `user://settings.cfg`.
- Main Menu loads on game start (post-warning); New Game starts Plaza VS; Quit exits cleanly.
- Pause menu opens during VS gameplay (Esc); Save to slot 1 + Load from slot 1 round-trip works.
- Forbidden-pattern fences registered.
- Logic stories have unit tests in `tests/unit/presentation/menu_system/`; UI stories have evidence docs with screenshots of all VS screens.

## Stories

Not yet created. Run `/create-stories menu-system` (with VS-narrowed scope flag) to break this epic into implementable stories.
