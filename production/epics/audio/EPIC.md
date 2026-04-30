# Epic: Audio

> **Layer**: Foundation
> **GDD**: `design/gdd/audio.md`
> **Architecture Module**: Audio (`Audio` autoload — registered in `project.godot [autoload]` per ADR-0007)
> **Engine Risk**: LOW–MEDIUM (Godot 4.6 audio bus configuration; AudioStreamPolyphonic for stinger pool)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories audio`
> **Manifest Version**: 2026-04-30

## Overview

Audio is the **subscriber-side mix-bus orchestrator** that routes spoken lines, music states, alert stingers, footstep variants, takedown SFX, and ambient layers through Godot's audio bus graph. It is autoload per ADR-0007 (registered before downstream subscribers) and subscribes to many domain signals — `dialogue_line_started/finished` (ducking), `alert_state_changed` + `actor_became_alerted` (music state grid + stingers), `footstep_emitted` (footstep variant routing), `takedown_performed` (SFX variant by `TakedownType`), `respawn_triggered` (cut-to-silence + 2.0 s fade-in), `document_opened/closed` (mute world bus, restore on close), `mission_started/completed` (briefing SFX). Audio owns the **music state grid** (5 locations × 4 alert states + 4 special states: DOCUMENT_OVERLAY, CUTSCENE, MAIN_MENU, MISSION_COMPLETE) and the dynamic-music transition rules (faithful to NOLF1's dynamic music system).

Per Pillar 5 (Period Authenticity), all music + SFX assets must be period-appropriate; no anachronistic synth pads or modern game-trailer cues. Audio also owns the F.1 ducking implementation — Dialogue & Subtitles publishes signals, but never reaches into the mix bus directly.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0002: Signal Bus + Event Taxonomy | Subscriber to Dialogue + SAI + PC + F&R + Document + Mission domain signals; publishes nothing (read-side autoload) | LOW |
| ADR-0007: Autoload Load Order Registry | `Audio` autoload registered after `Events` + `EventLogger`, before gameplay autoloads | LOW |
| ADR-0008: Performance Budget Distribution | Audio claims a slot in the 16.6 ms frame budget for mix-bus + dynamic-music transition logic | LOW–MEDIUM (Proposed) |

## GDD Requirements

**12 TR-IDs** in `tr-registry.yaml` (`TR-AUD-001` .. `TR-AUD-012`) cover:

- `Audio` autoload registration + load-order constraint
- Music state grid (5 locations × 4 alert states + 4 special states)
- Ducking on `dialogue_line_started` (F.1 — restore on `dialogue_line_finished`)
- Stinger emission on `actor_became_alerted` (gated by `Severity = MAJOR`; SCRIPTED cause suppresses stinger)
- Takedown SFX routing by `TakedownType` (MELEE_NONLETHAL = chloroform whoosh; STEALTH_BLADE = blade stroke)
- `respawn_triggered` cut-to-silence + 2.0 s fade-in
- Footstep variant routing on `footstep_emitted` (surface-keyed)
- World-bus mute on `document_opened`; restore on `document_closed`
- Forbidden patterns (`audio_publishing_signals`, `dialogue_subtitles_reaching_into_audio_bus`)

Full requirement text: `docs/architecture/tr-registry.yaml` Audio section.

## VS Scope Guidance

- **Include (basic-pipeline validation)**: `Audio` autoload registered; ambient layer for Plaza; one alert stinger on COMBAT transition; ducking on Plaza VO line; cut-to-silence on `respawn_triggered`; one footstep variant for stone-Plaza-floor; one world-bus mute on `document_opened`.
- **Defer post-VS**: Full music state grid (one location × 2 alert states sufficient for VS — UNAWARE ambient + COMBAT music; SUSPICIOUS / SEARCHING music omitted); takedown SFX library (no takedowns in VS); special-state music (CUTSCENE / MISSION_COMPLETE OK as silence); full footstep variant matrix.

## Definition of Done

- All stories implemented, reviewed, closed via `/story-done`.
- `Audio` autoload registered in `project.godot` per ADR-0007 load order.
- Plaza ambient layer plays during VS gameplay; transitions to COMBAT music on guard COMBAT state; cut-to-silence on player death.
- Footstep SFX plays on `footstep_emitted` (one variant); world bus mutes on `document_opened`.
- Ducking demonstrably works: VO line plays → ambient ducks 6 dB → line ends → ambient restores.
- Forbidden-pattern fences registered (`audio_publishing_signals`, `dialogue_subtitles_reaching_into_audio_bus`).
- Logic stories have unit tests in `tests/unit/foundation/audio/`; integration stories validate ducking + state-transition timing.
- Audio assets registered in `assets/audio/` per pipeline conventions; period-authenticity sign-off in `production/qa/evidence/`.

## Stories

Not yet created. Run `/create-stories audio` (with VS-narrowed scope flag) to break this epic into implementable stories.
