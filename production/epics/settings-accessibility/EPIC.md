# Epic: Settings & Accessibility

> **Layer**: Polish (Day-1 minimum slice promoted to **HARD MVP DEP** per HUD Core REV-2026-04-26 D2)
> **GDD**: `design/gdd/settings-accessibility.md`
> **Architecture Module**: Settings & Accessibility (`SettingsService` may be autoload OR scene-tree singleton — TBD by story author per ADR-0007 slot pressure; UI is scene-tree Control under Menu System)
> **Engine Risk**: LOW (`ConfigFile` API for `user://settings.cfg` per ADR-0003 settings-separate clause)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories settings-accessibility`
> **Manifest Version**: 2026-04-30

## Overview

Settings & Accessibility is normally a **Polish-layer** system, but its Day-1 minimum slice was promoted to **HARD MVP DEP** per HUD Core REV-2026-04-26 D2: the photosensitivity-toggle minimal UI is required to launch the game safely (WCAG SC 2.3.1 + Pillar 5 period-authentic boot warning). This epic owns: (1) the `user://settings.cfg` persistence layer (separate from save slots per ADR-0003); (2) the photosensitivity toggle (Day-1 HARD MVP); (3) the captions-default-on toggle (CR-23 / WCAG SC 1.2.2 — captions ON at first launch); (4) the volume sliders (Master / Music / SFX / Voice); (5) the rebind UI (post-MVP keyboard rebinding per technical-preferences "rebinding parity is post-MVP"); (6) the accessibility tier compliance (per `design/accessibility-requirements.md`).

Settings publishes one signal — `Events.settings_loaded` — at app boot so dependent systems (HUD Core, Audio mix, PostProcessStack glow intensity, Subtitle visibility default) read their initial state from a single source. Subsequent setting changes write through `SettingsService` which atomically updates `user://settings.cfg` and re-emits `settings_loaded` (or per-key change signals — TBD).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0002: Signal Bus + Event Taxonomy | Publishes `settings_loaded`; the 2026-04-28 amendment added the Settings domain row + UI domain row | LOW |
| ADR-0003: Save Format Contract | Settings stored separately in `user://settings.cfg` via `ConfigFile` — NOT in `SaveGame` slots | LOW |
| ADR-0004: UI Framework | Settings UI is scene-tree Control under Menu System; uses Theme resource; input-context stack handover when entering settings from gameplay (pause-menu path) or main menu | LOW–MEDIUM (Proposed) |
| ADR-0007: Autoload Load Order Registry | TBD by story author — `SettingsService` may be autoload (early load order, before HUD Core / Audio / PPS so they read initial state) OR a scene-tree singleton consumed at boot. Slot pressure considered. | LOW |

## GDD Requirements

**18 TR-IDs** in `tr-registry.yaml` (`TR-SET-001` .. `TR-SET-018`) cover:

- `user://settings.cfg` persistence (`ConfigFile` API; atomic write)
- Photosensitivity toggle (Day-1 HARD MVP — WCAG SC 2.3.1)
- Captions-default-on (Day-1 — WCAG SC 1.2.2 / CR-23)
- Volume sliders (Master / Music / SFX / Voice — drive Audio mix bus)
- `settings_loaded` signal publication at boot
- Photosensitivity → PostProcessStack `set_glow_intensity()` handshake
- Rebind UI (keyboard — post-MVP per technical-preferences; gamepad rebind parity post-MVP)
- Accessibility tier compliance per `design/accessibility-requirements.md`
- Forbidden patterns (`settings_in_save_slot`, `settings_published_per_key_without_loaded_event`)

Full requirement text: `docs/architecture/tr-registry.yaml` Settings & Accessibility section.

## VS Scope Guidance

- **Include (Day-1 HARD MVP minimum slice)**: `user://settings.cfg` persistence; photosensitivity toggle (default-off, must persist); captions-default-on (default-on, must persist); Master volume slider; `settings_loaded` signal publication at app boot; photosensitivity → PostProcessStack `set_glow_intensity()` handshake (writes to PPS at boot + on toggle change).
- **Include (VS scope expansion)**: Music + SFX + Voice volume sliders; settings UI accessible from Main Menu + Pause Menu.
- **Defer post-VS**: Rebind UI (keyboard rebinding is post-MVP per technical-preferences); gamepad rebind parity (post-MVP); resolution / windowed-mode / display-mode pickers; full accessibility tier suite (only HARD MVP DEP items in VS); FOV slider; subtitles styling options.

## Definition of Done

- All stories implemented, reviewed, closed via `/story-done`.
- Game launches → photosensitivity boot warning displays → user toggles (or accepts default off) → setting persists in `user://settings.cfg`.
- Captions ON at first launch (WCAG SC 1.2.2); persists across restarts.
- Master volume slider drives Audio mix bus correctly.
- `settings_loaded` signal fires at boot before HUD Core / Audio / PPS read initial state.
- `user://settings.cfg` is NEVER written into a `SaveGame` slot (forbidden-pattern fence).
- Forbidden-pattern fences registered (`settings_in_save_slot`, `settings_published_per_key_without_loaded_event`).
- Logic stories have unit tests in `tests/unit/polish/settings_accessibility/`; UI stories have evidence docs.
- Day-1 HARD MVP slice scoped boundary documented in story files (which TR-IDs are HARD MVP vs VS-expansion vs post-VS).

## Stories

| # | Story | Type | Status | Layer | ADR |
|---|-------|------|--------|-------|-----|
| 001 | [SettingsService autoload scaffold + ConfigFile persistence layer](story-001-settings-service-scaffold.md) | Logic | Ready | Polish / Day-1 HARD MVP DEP | ADR-0002, ADR-0003, ADR-0007 |
| 002 | [Boot lifecycle — burst emit, settings_loaded signal, photosensitivity warning flag](story-002-boot-lifecycle-settings-loaded.md) | Logic | Ready | Polish / Day-1 HARD MVP DEP | ADR-0002, ADR-0003, ADR-0007 |
| 003 | [Photosensitivity kill-switch + PostProcessStack glow handshake](story-003-photosensitivity-kill-switch.md) | Integration | Ready | Polish / Day-1 HARD MVP DEP (WCAG SC 2.3.1) | ADR-0002, ADR-0003, ADR-0004 |
| 004 | [Audio volume sliders — dB formula + bus apply integration](story-004-audio-volume-sliders.md) | Logic | Ready | Polish / Day-1 HARD MVP DEP (Master); VS-expansion (Music / SFX / Voice) | ADR-0002, ADR-0003 |
| 005 | [Settings panel UI shell — layout, InputContext, navigation, AccessKit, forbidden-pattern CI gates](story-005-settings-panel-ui-shell.md) | UI | BLOCKED (ADR-0004 Gates 1 + 5 OPEN) | Polish / VS-expansion | ADR-0002, ADR-0004 |
| 006 | [Subtitle defaults write + subtitle settings persistence](story-006-subtitle-defaults-write-persistence.md) | Logic | Ready | Polish / Day-1 HARD MVP DEP (captions-default-on per WCAG SC 1.2.2 / CR-23) | ADR-0002, ADR-0003, ADR-0007 |
